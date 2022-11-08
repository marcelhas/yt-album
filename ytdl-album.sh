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
'
}

if [[ -z "${1-}" || "${1-}" =~ ^-*h(elp)?$ ]]; then
    usage
    exit
fi

URL="$1"
TMP="$(mktemp -d)"
ALBUM="$TMP/album.mp3"
# TODO: Use script directory instead of hardcoding.
OUT="./out"

rm -rf "$OUT"
mkdir -p "$OUT"

yt-dlp -x --split-chapters --audio-quality 0 --audio-format mp3 \
       --quiet --progress --console-title --newline --progress-template "postprocess:[Processing: %(info.title)s ...]" \
       --windows-filenames --restrict-filenames                 \
       -o "$ALBUM" -o "chapter:$OUT/%(title)s_%(section_number)03d_%(section_title)s%(ext)s" \
       "$URL"

while read -r start end out; do
    echo "$start - $end - $out"
    ffmpeg -nostdin -y -ss "$start" -to "$end" -i album.mp3 "out/$out.mp3"
done < time.txt
