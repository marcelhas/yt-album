#!/usr/bin/env bash

set -euo pipefail

# Allows running in debug mode by setting the TRACE environment variable.
# e.g. <TRACE=1 ./ytdl-album.sh>
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

usage() {
    printf \
    'Usage: ./ytdl-album URL

Example:
./ytdl-album https://www.youtube.com/watch?v=lmvUFhjZdFc
TRACE=1 ./ytdl-album https://www.youtube.com/watch?v=lmvUFhjZdFc
'
}

if [[ -z "${1-}" || "${1-}" =~ ^-*h(elp)?$ ]]; then
    usage
    exit
fi

CHAPTERS="./chapters.txt"
# TODO: Use script directory instead of hardcoding.
OUT="./out"
TMP="$(mktemp -d)"
URL="$1"

rm -rf "$OUT"
mkdir -p "$OUT"

yt-dlp -x --split-chapters --audio-quality 0 --audio-format mp3                                                        \
       --quiet --progress --console-title --newline --progress-template "postprocess:[Processing: %(info.title)s ...]" \
       --windows-filenames --restrict-filenames --print-to-file title "$TMP/title.txt"                                                                        \
       -o "$TMP/album.mp3" -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s.%(ext)s"                          \
       "$URL"
echo

ALBUM_TITLE="$(cat "$TMP/title.txt")"
CHAPTER_COUNT="$(find "$OUT" -maxdepth 1 -type f | wc -l)"

if [[ "$CHAPTER_COUNT" == "0" ]]; then
    printf "No chapters found, falling back to manual splitting.\n"
    if [[ ! -f $CHAPTERS ]]; then
        printf "No ./chapters.txt file found, aborting.\n" >&2
        exit 1
    fi

    # Preprocess chapters.txt into a single file in the format:
    # 00:00 04:01 No 1 Party Anthem
    # 04:01 07:11 Suck It and See
    cut -d" " --field 1 $CHAPTERS > "$TMP/first.txt"
    tail "$TMP/first.txt" --lines +2 > "$TMP/second.txt"
    echo "99:59:59" >> "$TMP/second.txt"
    cut -d" " --field 2- $CHAPTERS > "$TMP/third.txt"
    paste "$TMP/first.txt" "$TMP/second.txt" "$TMP/third.txt" > "$TMP/out.txt"

    while read -r start end out; do
        echo "$start - $end - $out"
        ffmpeg -hide_banner -loglevel warning -nostdin -y -ss "$start" -to "$end" -i "$TMP/album.mp3" "out/$ALBUM_TITLE-$out.mp3"
    done < "$TMP/out.txt"
fi
