#!/bin/bash

# =============================================================================
# combine-video.sh
# This script concatenates multiple video files into a single output video.
# Usage: ./combine-video.sh <title-video> <main-video> <credits-video> <output-video>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <title-video> <main-video> <credits-video> <output-video>"
    exit 1
fi

INPUT_VIDEO_TITLE="$1"
INPUT_VIDEO_MAIN="$2"
INPUT_VIDEO_CREDITS="$3"
OUTPUT_VIDEO="$4"

# Temporary directory
TMP_DIR="./tmp"
mkdir -p "$TMP_DIR"

# --- Validate Inputs ---
if [ ! -f "$INPUT_VIDEO_TITLE" ]; then
    echo "Error: Title video file not found: '$INPUT_VIDEO_TITLE'"
    exit 1
fi

if [ ! -f "$INPUT_VIDEO_MAIN" ]; then
    echo "Error: Main video file not found: '$INPUT_VIDEO_MAIN'"
    exit 1
fi

if [ ! -f "$INPUT_VIDEO_CREDITS" ]; then
    echo "Error: Credits video file not found: '$INPUT_VIDEO_CREDITS'"
    exit 1
fi

if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

# Temporary file for concatenation list
CONCAT_LIST_FILE="${TMP_DIR}/temp_final_concat_list_${RANDOM}.txt"

# --- Create Concatenation List File ---
echo "Creating concatenation list file ('$CONCAT_LIST_FILE')..."

echo "file '$INPUT_VIDEO_TITLE'" > "$CONCAT_LIST_FILE"
echo "file '$INPUT_VIDEO_MAIN'" >> "$CONCAT_LIST_FILE"
echo "file '$INPUT_VIDEO_CREDITS'" >> "$CONCAT_LIST_FILE"

if [ $? -ne 0 ]; then
    echo "Error creating concatenation list file."
    exit 1
fi

echo "Concatenation list file created."

# --- Concatenate Videos ---
echo "Concatenating '$INPUT_VIDEO_TITLE', '$INPUT_VIDEO_MAIN' and '$INPUT_VIDEO_CREDITS' into '$OUTPUT_VIDEO'..."

"$FFMPEG_BIN" -y \
              -f concat \
              -safe 0 \
              -i "$CONCAT_LIST_FILE" \
              -c copy \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Video concatenation failed (exit code $?)."
    echo "This can happen if the streams are not perfectly compatible for direct copying."
    echo "You might need to re-encode if issues persist."
    rm -f "$CONCAT_LIST_FILE"
    exit 1
fi

echo "Videos concatenated successfully: '$OUTPUT_VIDEO'"

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$CONCAT_LIST_FILE"
echo "Temporary files removed."
