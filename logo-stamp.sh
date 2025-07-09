#!/bin/bash

# =============================================================================
# logo-stamp.sh
# This script overlays a logo onto a video.
# Usage: ./logo-stamp.sh <input-video> <logo-png> <output-video>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-video> <logo-png> <output-video>"
    exit 1
fi

INPUT_VIDEO="$1"
LOGO_FILE="$2"
OUTPUT_VIDEO="$3"

# --- Main Logic ---
# ffmpeg command to overlay the logo.
# -i "$INPUT_VIDEO": Specifies the main video input file.
# -i "$LOGO_FILE": Specifies the logo image input file.
# -filter_complex "[1:v]crop=iw/2:ih:0:0,scale=iw*0.1:-1[logo];[0:v][logo]overlay=main_w-overlay_w-10:10": The filtergraph.
#   [1:v] selects the video stream from the second input (the logo).
#   crop=iw/2:ih:0:0: crops the logo to its left half.
#   scale=iw*0.1:-1: scales the logo to 10% of the input video's width, maintaining aspect ratio.
#   [logo]: assigns the output of the crop and scale to a named pad 'logo'.
#   [0:v][logo]overlay=main_w-overlay_w-10:10: overlays the 'logo' pad onto the first video stream.
#     x=main_w-overlay_w-10: 10 pixels from the right edge.
#     y=10: 10 pixels from the top edge.
# -c:a copy: Copies the audio stream without re-encoding, which is fast and preserves quality.
"$FFMPEG_BIN" -i "$INPUT_VIDEO" -i "$LOGO_FILE" -filter_complex "[1:v]crop=iw/2:ih:0:0,scale=iw*0.1:-1[logo];[0:v][logo]overlay=main_w-overlay_w-10:10" -c:a copy "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Logo overlay failed. FFmpeg command exited with an error."
    exit 1
fi

echo "✅ Logo overlay applied. Video saved to $OUTPUT_VIDEO"
