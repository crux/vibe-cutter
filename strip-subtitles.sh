#!/bin/bash

# This script strips all subtitle tracks but the ones specified from a video file.
# The output file's video and audio tracks are copied, not re-encoded.
#
# Usage: ./strip-subtitles.sh <input-video> <output-video> [ <subtitle-track-index> ... ]
#
# Example:
#   ./strip-subtitles.sh input.mkv output.mkv 0 2
#   This will keep subtitle tracks with index 0 and 2.
#
# Example (strip all subtitles):
#   ./strip-subtitles.sh input.mkv output.mkv

set -euo pipefail

# --- Configuration ---
# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"

# --- Input Validation ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <input-video> <output-video> [ <subtitle-track-index> ... ]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
shift 2
SUBTITLE_TRACKS_TO_KEEP=("$@")

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# --- FFmpeg Command Construction ---
MAP_OPTIONS=("-map" "0:v" "-map" "0:a")

if [ ${#SUBTITLE_TRACKS_TO_KEEP[@]} -gt 0 ]; then
    for track_index in "${SUBTITLE_TRACKS_TO_KEEP[@]}"; do
        #MAP_OPTIONS+=("-map" "0:s:$track_index")
        MAP_OPTIONS+=("-map" "0:$track_index")
    done
else
    # No subtitle tracks to keep, so we don't add any subtitle map options.
    # FFmpeg will not include any subtitle tracks by default unless mapped.
    # To be explicit, we can use -sn
    MAP_OPTIONS+=("-sn")
fi

echo "MAP_OPTIONS: ${MAP_OPTIONS[@]}"

# --- Execution ---
echo "Processing '$INPUT_FILE'"
echo "Keeping subtitle tracks: ${SUBTITLE_TRACKS_TO_KEEP[*]:-(none)}"

"$FFMPEG_BIN" -i "$INPUT_FILE" \
    -c:v copy \
    -c:a copy \
    -c:s copy \
    "${MAP_OPTIONS[@]}" \
    -y "$OUTPUT_FILE"

echo "Output written to '$OUTPUT_FILE'"
