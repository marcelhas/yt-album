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

while read -r start end out; do
    echo "$start - $end - $out"
    ffmpeg -nostdin -y -ss "$start" -to "$end" -i album.mp3 "out/$out.mp3"
done < time.txt
