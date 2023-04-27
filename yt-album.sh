#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

readonly CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/yt-album"
readonly DEFAULT_OUTPUT="./sections"
readonly EXT="mp3"
TMP="$(mktemp -d)"
readonly TMP

trap 'rm -rf -- "$TMP"' EXIT

log_succ() {
    printf "${GREEN}%s${RESET}\n" "${*}"
}

log_warn() {
    printf "${YELLOW}%s${RESET}\n" "${*}" 1>&2
}

log_err() {
    printf "${RED}%s${RESET}\n" "${*}" 1>&2
}

usage() {
    cat <<USAGE
Usage: ./yt-album.sh URL
   or: ./yt-album.sh --sections sections.txt -- URL
Download from YouTube and split into sections.

Options:
  -h, --help
    Show this help message and exit.
  --sections FILE
    Split the downloaded video into sections defined in FILE.
    The required format is defined in the README.md.
  --output DIR
    Output directory for the downloaded files.
    Default: $DEFAULT_OUTPUT
  --no-color
    Disable colored output.
  --no-progress
    Disable download progress bar.

Examples:
  ./yt-album.sh https://www.youtube.com/watch?v=lmvUFhjZdFc
  ./yt-album.sh --sections sections.txt -- https://www.youtube.com/watch?v=lmvUFhjZdFc
  ./yt-album.sh --output ~/Music/ -- https://www.youtube.com/watch?v=lmvUFhjZdFc
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
    --output)
        if [[ -n "$2" && -d "$2" ]]; then
            OUTPUT="$2"
            shift
        else
            die "The command option --output requires a path to a directory"
        fi
        ;;
    --no-color)
        GREEN=""
        YELLOW=""
        RED=""
        RESET=""
        ;;
    --no-progress)
        NO_PROGRESS=1
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

main() {
    local URL="$1"
    local OUT="${OUTPUT:-$DEFAULT_OUTPUT}"

    cmd_exists_or_exit "yt-dlp"
    # ffmpeg is only required if a section file is provided.
    [[ -n "${SECTION_FILE-}" ]] && cmd_exists_or_exit "ffmpeg" && valid_section_file_or_exit "$SECTION_FILE"

    # Prepare environment.
    mkdirs "$OUT"

    # Download URL and split into sections if no section file is provided.
    download "$URL" "$EXT" "$OUT"

    # Update output folder based on video title.
    local title
    title="$(cat "$TMP/title.txt")"
    title="$(slugify "$title")"
    OUT="$OUT/$title"


    if [[ -n "${SECTION_FILE-}" ]]; then
        # Split into sections if section file is provided.
        mkdir "$OUT"
        local id
        id=$(cat "$TMP/id.txt")
        process_section_file "$title" "$CACHE/$id.$EXT" "$OUT"
    fi

    if is_ok "$OUT"; then
        log_success_msg "$OUT"
        exit 0
    else
        log_err "$OUT is empty! Try to provide a section file and check the output option."
        exit 4
    fi
}

cmd_exists_or_exit() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_err "$cmd is not installed. Please install it first."
        exit 1
    fi
}

valid_section_file_or_exit() {
    local file="$1"
    [[ ! -f "$file" ]] && log_err "The section file $file does not exist." && exit 2
    [[ ! -s "$file" ]] && log_err "The section file $file is empty." && exit 2
    set +e
    local res
    res="$(grep --perl-regexp --line-number --initial-tab --invert-match \
        "^(\d+:)?(0|1|2|3|4|5)?((\d:(0|1|2|3|4|5)\d\s.*)|\s*)$" "$file")"
    set -e
    if [[ -n $res ]]; then
        log_err "The following lines in $file are not in the correct format."
        log_warn "The correct format is: <(hh:)mm:ss Title>"
        log_err "$res"
        exit 3
    fi
}

mkdirs() {
    local out="$1"
    mkdir -p "$out"
    mkdir -p "$CACHE"
}

download() {
    local url="$1"
    local ext="$2"
    local out="$3"

    # Download and split into sections if a section file is given.
    yt-dlp -x --audio-quality 0 --audio-format "$ext" \
        --split-chapters ${SECTION_FILE:+"--no-split-chapters"} \
        --progress-template "postprocess:[Processing: %(info.title)s ...]" \
        --quiet --progress ${NO_PROGRESS:+"--no-progress"} --console-title \
        --windows-filenames --restrict-filenames \
        --print-to-file title "$TMP/title.txt" --print-to-file id "$TMP/id.txt" \
        -o "$CACHE/%(id)s.$EXT" \
        -o "chapter:$out/%(title)s/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s" \
        "$url"
    printf "\n"
}

# See <https://gist.github.com/oneohthree/f528c7ae1e701ad990e6>.
slugify() {
    echo "$1" | iconv -t ascii//TRANSLIT | sed -r s/[^a-zA-Z0-9]+/-/g | sed -r s/^-+\|-+$//g | tr "[:upper:]" "[:lower:]"
}

is_ok() {
    local out="$1"
    section_count=$(find "$out" -type f | wc -l)
    [[ $section_count -gt 0 ]]
}

log_success_msg() {
    local path
    path="$1"
    log_succ "Done. Your sections are in $path"
}

process_section_file() {
    local title="$1"
    local video_path="$2"
    local out="$3"

    local prepared_section_file
    prepared_section_file=$(prepare_section_file)

    section_number=1
    # Split the downloaded video into sections.
    while read -r start end section_name; do
        echo "$start - $end - $section_name"
        section_title="$(format_section_title "$title" "$section_number" "$section_name")"
        target_file="$out/$section_title"
        ffmpeg -hide_banner -loglevel warning -nostdin -y \
            -ss "$start" -to "$end" \
            -i "$video_path" -codec copy \
            "$target_file"

        # Sanity check filesize, because ffmpeg does not always warn.
        minimum_size=5000
        actual_size=$(wc -c <"$target_file")
        if [[ $actual_size -lt $minimum_size ]]; then
            log_warn \
                "File is very small! Check if $SECTION_FILE matches your video."
        fi
        ((section_number++))
    done <<<"$prepared_section_file"
}

# Preprocess $SECTION_FILE into a single file in the format:
# 00:00 04:01 No 1 Party Anthem
# 04:01 07:11 Suck It and See
# ...
prepare_section_file() {
    # Remove empty lines.
    local no_newlines
    no_newlines=$(strip_newlines "$SECTION_FILE")

    # 00:00
    local first_column
    first_column="$(printf %s "$no_newlines" | cut -d" " --field 1)"

    # 04:01
    local second_column
    # Skip first row and append 99:59:59 at the end.
    second_column="$(tail --lines +2 <(printf "%s\n%s\n" "$first_column" "99:59:59"))"

    # No 1 Party Anthem
    local third_column
    third_column=$(cut -d" " --field 2- <(printf %s "$no_newlines"))

    # Merge the three files into a single file.
    local merged
    merged=$(paste <(printf %s "$first_column") <(printf %s "$second_column") <(printf %s "$third_column"))
    printf "%s" "$merged"
}

strip_newlines() {
    local file="$1"
    sed '/^$/d' "$file"
}

format_section_title() {
    local album_title="$1"
    local section_nr
    printf -v section_nr '$%03d' "$2"
    local section_name="$3"
    local section_title="${album_title}_${section_nr}_${section_name}"
    local clean_section_title
    clean_section_title="$(printf "%s" "$section_title" | tr -cs '[:alnum:]-' '_' | sed 's/_*$//')"
    printf "%s.$EXT" "$clean_section_title"
}

main "$@"
