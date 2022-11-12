#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

log_succ() {
    printf "${GREEN}%s${RESET}\n" "${*}"
}

log_warn() {
    printf "${YELLOW}%s${RESET}\n" "${*}" 1>&2
}

log_err() {
    printf "${RED}%s${RESET}\n" "${*}" 1>&2
}

log_success_msg() {
    local path="$1"
    log_succ "Done. Your sections are in $path."
}

usage() {
    cat <<USAGE
Usage: ./yt-album.sh URL
   or: ./yt-album.sh --sections sections.txt -- URL
Download from YouTube and split into sections.

 -h, --help
    Show this help message and exit.
 --sections FILE
    Split the downloaded video into sections defined in FILE.
    The required format is defined in the README.md.

Examples:
./yt-album.sh https://www.youtube.com/watch?v=lmvUFhjZdFc
./yt-album.sh --sections sections.txt -- https://www.youtube.com/watch?v=lmvUFhjZdFc
# Debug mode
TRACE=1 ./yt-album.sh https://www.youtube.com/watch?v=lmvUFhjZdFc

Required:
- yt-dlp
- ffmpeg
USAGE
}

die() {
    log_err "${*}"
    usage
    exit 1
}

while :; do
    case ${1-} in
    # Two hyphens ends the options parsing
    --)
        shift
        break
        ;;
    -h | --help | help | "")
        usage
        exit
        ;;
    --sections)
        if [[ -n "$2" ]]; then
            SECTION_FILE="$2"
            shift
        else
            die "The command option --sections requires a path to a file"
        fi
        ;;
    # Anything remaining that starts with a dash triggers a fatal error
    -?*)
        die "The command line option is unknown: $1"
        ;;
    # Anything remaining is treated as content not a parseable option
    *)
        break
        ;;
    esac
    shift
done

cmd_exists_or_exit() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_err "$cmd is not installed. Please install it first."
        exit 1
    fi
}

valid_section_file_or_exit() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_err "The section file $file does not exist."
        exit 2
    fi
    set +e
    res="$(grep --perl-regexp --line-number --initial-tab --invert-match \
        "^(\d+:)?(0|1|2|3|4|5)?\d:(0|1|2|3|4|5)\d\s.*$" "$file")"
    set -e
    if [[ $res != "" ]]; then
        log_err "The following lines in $file are not in the correct format."
        log_warn "The correct format is: <(hh:)mm:ss Title>"
        log_err "$res"
        exit 3
    fi
}

cmd_exists_or_exit "yt-dlp"
# ffmpeg is only required if a section file is provided.
[[ -n "${SECTION_FILE-}" ]] && cmd_exists_or_exit "ffmpeg" && valid_section_file_or_exit "$SECTION_FILE"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
OUT="$SCRIPT_DIR/sections"
TMP="$(mktemp -d)"
CACHE="$SCRIPT_DIR/.cache"
trap 'rm -rf -- "$TMP"' EXIT
URL="$1"

rm -rf "$OUT"
mkdir -p "$OUT"
mkdir -p "$CACHE"

# Download and maybe split into sections.
yt-dlp -x --audio-quality 0 --audio-format mp3 \
    --split-chapters ${SECTION_FILE:+"--no-split-chapters"} \
    --progress-template "postprocess:[Processing: %(info.title)s ...]" \
    --quiet --progress --console-title --windows-filenames --restrict-filenames \
    --print-to-file title "$TMP/title.txt" --print-to-file id "$TMP/id.txt" \
    -o "$CACHE/%(id)s.mp3" \
    -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s" \
    "$URL"
printf "\n"

if [[ -z "${SECTION_FILE-}" ]]; then
    # Done.
    log_success_msg "$OUT"
    exit 0
fi

# Preprocess $SECTION_FILE into a single file in the format:
# 00:00 04:01 No 1 Party Anthem
# 04:01 07:11 Suck It and See
# Remove empty lines.
clean="$TMP/clean.txt"
awk '!/^[[:blank:]]*$/' "$SECTION_FILE" >"$clean"
cut -d" " --field 1 "$clean" >"$TMP/first.txt"
tail "$TMP/first.txt" --lines +2 >"$TMP/second.txt"
echo "99:59:59" >>"$TMP/second.txt"
cut -d" " --field 2- "$clean" >"$TMP/third.txt"
# Merge the three files into a single file.
paste "$TMP/first.txt" "$TMP/second.txt" "$TMP/third.txt" >"$TMP/out.txt"

album_title="$(cat "$TMP/title.txt")"
id="$(cat "$TMP/id.txt")"
i=1
# Split the downloaded video into sections.
while read -r start end section; do
    echo "$start - $end - $section"
    section_nr="$(printf %03d $i)"
    ((i++))
    section="$OUT/$album_title-$section_nr-$section.mp3"
    ffmpeg -hide_banner -loglevel warning -nostdin -y \
        -ss "$start" -to "$end" \
        -i "$CACHE/$id.mp3" -codec copy \
        "$section"

    # Sanity check filesize, because ffmpeg does not always warn.
    minimum_size=5000
    actual_size=$(wc -c <"$section")
    if [[ $actual_size -lt $minimum_size ]]; then
        log_warn \
            "File is very small! Check if $SECTION_FILE matches your video."
    fi
done <"$TMP/out.txt"

log_success_msg "$OUT"
