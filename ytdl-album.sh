#!/usr/env/bash

while read -r start end out; do
    echo "$start - $end - $out"
    ffmpeg -nostdin -y -ss "$start" -to "$end" -i album.mp3 "out/$out.mp3"
done < time.txt