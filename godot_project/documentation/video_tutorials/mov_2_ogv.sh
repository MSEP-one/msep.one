#!/bin/bash


# Convert input filename to snake_case
filename=$(basename "$1")
filename="${filename%.*}"  # Remove extension
output_file=$(echo "$filename" | sed -e 's/\([a-z]\)\([A-Z]\)/\1_\2/g' -e 's/[ -]/_/g' | tr '[:upper:]' '[:lower:]').ogv

ffmpeg -i "$1" \
-c:v libtheora -q:v 7 \
-vf "scale=1920:1080:flags=lanczos,format=yuv444p" \
-pix_fmt yuv444p \
-color_range tv \
-colorspace bt709 \
-color_primaries bt709 \
-color_trc bt709 \
-c:a libvorbis -q:a 5 \
"$output_file"