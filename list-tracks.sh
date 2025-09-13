#!/bin/bash

# This script lists all tracks from a video file in a format
# that can be directly used with the strip-tracks.sh script.
#
# Usage: ./list-tracks.sh <input-video>
#
# Example:
#   ./list-tracks.sh input.mkv

set -euo pipefail

# --- Configuration ---
# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

FFPROBE_BIN="${FFPROBE_BIN:-ffprobe}"

# --- Input Validation ---
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input-video>"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# --- FFprobe Command ---
echo "Probing '$INPUT_FILE'..."

"$FFPROBE_BIN" -v error -show_entries stream=index,codec_name,codec_type:stream_tags=language,title -of json "$INPUT_FILE" | 
jq -r '.streams[] | "0:\(.index) # \(.codec_type), \(.codec_name), lang:\(.tags.language // "n/a"), title:\(.tags.title // "n/a")"'
