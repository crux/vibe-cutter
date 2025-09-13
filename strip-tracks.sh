#!/bin/bash

# This script strips all tracks but the ones specified from a video file.
# The output file's video and audio tracks are copied, not re-encoded.
#
# Usage: ./strip-tracks.sh <input-video> <output-video> [ <tracks-to-keep> ... ]
#
# Example:
#   ./strip-tracks.sh input.mkv output.mkv 0:s:0
#   This will keep the first subtitle track.
#
# Example (strip all extra tracks):
#   ./strip-tracks.sh input.mkv output.mkv
#   This will keep only video and audio tracks.

set -euo pipefail

# --- Configuration ---
# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"

# --- Input Validation ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <input-video> <output-video> [ <track-specifier> ... ]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
shift 2
TRACKS_TO_KEEP=("$@")

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# --- FFmpeg Command Construction ---
MAP_OPTIONS=("-map" "0:v" "-map" "0:a")

if [ ${#TRACKS_TO_KEEP[@]} -gt 0 ]; then
    for track_specifier in "${TRACKS_TO_KEEP[@]}"; do
        MAP_OPTIONS+=("-map" "$track_specifier")
    done
fi

echo "MAP_OPTIONS: ${MAP_OPTIONS[@]}"

# --- Execution ---
echo "Processing '$INPUT_FILE'"
echo "Keeping tracks: ${TRACKS_TO_KEEP[*]:-(none)}"

"$FFMPEG_BIN" -i "$INPUT_FILE" \
    -c:v copy \
    -c:a copy \
    -c:s copy \
    "${MAP_OPTIONS[@]}" \
    -y "$OUTPUT_FILE"

echo "Output written to '$OUTPUT_FILE'"
