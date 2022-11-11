#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

usage() {
    cat <<USAGE
Usage: ./yt-album.sh URL
   or: ./yt-album.sh --chapters chapters.txt -- URL
Download from YouTube and split into chapters.

 -h, --help
    Show this help message and exit.
 -c, --chapters FILE
    Use the specified file as the chapters file.
    The required format is defined in the README.md.

Examples:
./yt-album.sh https://www.youtube.com/watch?v=lmvUFhjZdFc
./yt-album.sh --chapters chapters.txt -- https://www.youtube.com/watch?v=lmvUFhjZdFc
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
        -c|--chapters)
            if [[ -n "$2" && -f "$2" ]]; then
                CHAPTERS="$2"
                shift
            else
                die "The command option --chapters requires a path to a file"
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
    printf "Done. Your tracks are in %s.\n" "$path"
}

cmd_exists_or_exit "yt-dlp"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUT="$SCRIPT_DIR/tracks"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
URL="$1"

rm -rf "$OUT"
mkdir -p "$OUT"

# Download and maybe split into chapters.
yt-dlp -x --split-chapters ${CHAPTERS:+"--no-split-chapters"} --audio-quality 0 --audio-format mp3                                              \
       --quiet --progress --console-title --progress-template "postprocess:[Processing: %(info.title)s ...]" \
       --windows-filenames --restrict-filenames --print-to-file title "$TMP/title.txt"                       \
       -o "$TMP/album.mp3" -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s"        \
       "$URL"
printf "\n"

if [[ -z "$CHAPTERS" ]]; then
    # Done.
    print_success_msg "$OUT"
    exit 0
fi

ALBUM_TITLE="$(cat "$TMP/title.txt")"

# Split downloaded file into chapters.
cmd_exists_or_exit "ffmpeg"
printf "No chapters found, falling back to manual splitting.\n"
if [[ ! -f $CHAPTERS ]]; then
    printf "No ./chapters.txt file found. See README.md.\n" >&2
    exit 2
fi

# Preprocess chapters.txt into a single file in the format:
# 00:00 04:01 No 1 Party Anthem
# 04:01 07:11 Suck It and See
# Remove empty lines.
clean="$TMP/clean.txt"
awk '!/^[[:blank:]]*$/' "$CHAPTERS" > "$clean"
cut -d" " --field 1 "$clean" > "$TMP/first.txt"
tail "$TMP/first.txt" --lines +2 > "$TMP/second.txt"
echo "99:59:59" >> "$TMP/second.txt"
cut -d" " --field 2- "$clean" > "$TMP/third.txt"
# Merge the three files into a single file.
paste "$TMP/first.txt" "$TMP/second.txt" "$TMP/third.txt" > "$TMP/out.txt"

i=1
while read -r start end track; do
    echo "$start - $end - $track"
    track_nr="$(printf %03d $i)"
    ffmpeg -hide_banner -loglevel warning -nostdin -y -ss "$start" -to "$end" -i "$TMP/album.mp3" "$OUT/$ALBUM_TITLE-$track_nr-$track.mp3"
    ((i++))
done < "$TMP/out.txt"

print_success_msg "$OUT"
