#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./yt-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

usage() {
    printf \
    'Usage: ./yt-album URL

Examples:
./yt-album https://www.youtube.com/watch?v=lmvUFhjZdFc
# Debug mode
TRACE=1 ./yt-album https://www.youtube.com/watch?v=lmvUFhjZdFc

Required:
 - yt-dlp
 - ffmpeg
'
}

if [[ -z "${1-}" || "${1-}" =~ ^-*h(elp)?$ ]]; then
    usage
    exit
fi

cmd_exists_or_exit() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        printf "%s is not installed. Please install it first.\n" "$cmd" >&2
        exit 1
    fi
}

cmd_exists_or_exit "yt-dlp"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CHAPTERS="$SCRIPT_DIR/chapters.txt"
OUT="$SCRIPT_DIR/tracks"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
URL="$1"

rm -rf "$OUT"
mkdir -p "$OUT"

yt-dlp -x --split-chapters --audio-quality 0 --audio-format mp3                                              \
       --quiet --progress --console-title --progress-template "postprocess:[Processing: %(info.title)s ...]" \
       --windows-filenames --restrict-filenames --print-to-file title "$TMP/title.txt"                       \
       -o "$TMP/album.mp3" -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s"        \
       "$URL"
echo

ALBUM_TITLE="$(cat "$TMP/title.txt")"
CHAPTER_COUNT="$(find "$OUT" -maxdepth 1 -type f | wc -l)"

if [[ "$CHAPTER_COUNT" == "0" ]]; then
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
        ffmpeg -hide_banner -loglevel warning -nostdin -y -ss "$start" -to "$end" -i "$TMP/album.mp3" "out/$ALBUM_TITLE-$track_nr-$track.mp3"
        ((i++))
    done < "$TMP/out.txt"
fi

printf "Done. Your tracks are in the ./tracks directory.\n"
