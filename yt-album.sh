#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

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

die(){
    >&2 printf %s\\n "$*"
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
        -h|--help|help|"")
            usage
            exit
            ;;
        --sections)
            if [[ -n "$2" && -f "$2" ]]; then
                SECTION_FILE="$2"
                shift
            else
                die "The command option --sections requires a path to a file"
            fi
            ;;
        # Anything remaining that starts with a dash triggers a fatal error
        -?*)
            die "The command line option is unknown: " "$1"
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
        printf "%s is not installed. Please install it first.\n" "$cmd" >&2
        exit 1
    fi
}

print_success_msg() {
    local path="$1"
    printf "Done. Your sections are in %s.\n" "$path"
}

cmd_exists_or_exit "yt-dlp"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUT="$SCRIPT_DIR/sections"
TMP="$(mktemp -d)"
CACHE="$SCRIPT_DIR/.cache"
trap 'rm -rf -- "$TMP"' EXIT
URL="$1"

rm -rf "$OUT"
mkdir -p "$OUT"
mkdir -p "$CACHE"

# Download and maybe split into sections.
yt-dlp -x --split-chapters ${SECTION_FILE:+"--no-split-chapters"} --audio-quality 0 --audio-format mp3                                              \
       --quiet --progress --console-title --progress-template "postprocess:[Processing: %(info.title)s ...]" \
       --windows-filenames --restrict-filenames --print-to-file title "$TMP/title.txt" --print-to-file id "$TMP/id.txt"                       \
       -o "$CACHE/%(id)s.mp3" -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s"        \
       "$URL"
printf "\n"

if [[ -z "${SECTION_FILE-}" ]]; then
    # Done.
    print_success_msg "$OUT"
    exit 0
fi

ALBUM_TITLE="$(cat "$TMP/title.txt")"

# Split downloaded file into sections.
cmd_exists_or_exit "ffmpeg"
if [[ ! -f $SECTION_FILE ]]; then
    printf "%s is not a file! See README.md.\n" "$SECTION_FILE" >&2
    exit 2
fi

# Preprocess $SECTION_FILE into a single file in the format:
# 00:00 04:01 No 1 Party Anthem
# 04:01 07:11 Suck It and See
# Remove empty lines.
clean="$TMP/clean.txt"
awk '!/^[[:blank:]]*$/' "$SECTION_FILE" > "$clean"
cut -d" " --field 1 "$clean" > "$TMP/first.txt"
tail "$TMP/first.txt" --lines +2 > "$TMP/second.txt"
echo "99:59:59" >> "$TMP/second.txt"
cut -d" " --field 2- "$clean" > "$TMP/third.txt"
# Merge the three files into a single file.
paste "$TMP/first.txt" "$TMP/second.txt" "$TMP/third.txt" > "$TMP/out.txt"

i=1
while read -r start end section; do
    echo "$start - $end - $section"
    section_nr="$(printf %03d $i)"
    ID="$(cat "$TMP/id.txt")"
    ffmpeg -hide_banner -loglevel warning -nostdin -y -ss "$start" -to "$end" -i "$CACHE/$ID.mp3" "$OUT/$ALBUM_TITLE-$section_nr-$section.mp3"
    ((i++))
done < "$TMP/out.txt"

print_success_msg "$OUT"
