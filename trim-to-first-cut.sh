#!/bin/bash

# =============================================================================
# trim-to-first-cut.sh
# This script trims an input video to start at its first detected scene change.
# Usage: ./trim-to-first-cut.sh <input-video-file> <output-video-file>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input-video-file> <output-video-file>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"

# Temporary directory
TMP_DIR="./tmp"
mkdir -p "$TMP_DIR"

# --- Validate Inputs ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file not found: '$INPUT_VIDEO'"
    exit 1
fi

if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

if ! command -v "$FFPROBE_BIN" &> /dev/null; then
    echo "Error: $FFPROBE_BIN command not found. Please install FFmpeg (ffprobe is usually included)."
    exit 1
fi

echo "--- Trimming Video to First Scene Change ---"

# --- Detect Scene Change ---
echo "Detecting the first scene change in '$INPUT_VIDEO'..."

# First, find the end of any initial black frames
BLACK_DETECT_OUTPUT=("$FFMPEG_BIN" -i "$INPUT_VIDEO" -vf "blackdetect=d=0.1:pix_th=0.20" -an -f null - 2>&1 | grep 'black_start')

BLACK_END_TIME="0"
if [ -n "$BLACK_DETECT_OUTPUT" ]; then
    FIRST_BLACK_START=$(echo "$BLACK_DETECT_OUTPUT" | head -n1 | sed -n 's/.*black_start:\([0-9.]*\).*/\1/p')
    if [ "$(echo "$FIRST_BLACK_START < 0.1" | bc)" -eq 1 ]; then
        BLACK_END_TIME=$(echo "$BLACK_DETECT_OUTPUT" | head -n1 | sed -n 's/.*black_end:\([0-9.]*\).*/\1/p')
    fi
fi
echo "Black frames end at: ${BLACK_END_TIME}s"

# Now, find the next scene change after the black frames
SCENE_DETECT_OUTPUT=("$FFMPEG_BIN" -ss "$BLACK_END_TIME" -i "$INPUT_VIDEO" -vf "select='gt(scene,0.4)',showinfo" -f null - 2>&1 | grep 'pts_time')

TRIM_START_TIME=$BLACK_END_TIME
if [ -n "$SCENE_DETECT_OUTPUT" ]; then
    # The first scene change time is relative to the trimmed start, so we add it to BLACK_END_TIME
    SCENE_CHANGE_TIME=$(echo "$SCENE_DETECT_OUTPUT" | head -n1 | sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')
    TRIM_START_TIME=$(echo "$BLACK_END_TIME + $SCENE_CHANGE_TIME" | bc)
fi

echo "First fullscreen content frame detected at: ${TRIM_START_TIME}s"

# --- Trim the Video ---
echo "Trimming '$INPUT_VIDEO' from ${TRIM_START_TIME}s to '$OUTPUT_VIDEO'..."

"$FFMPEG_BIN" -y \
              -ss "$TRIM_START_TIME" \
              -i "$INPUT_VIDEO" \
              -c copy \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Video trimming failed. FFmpeg command exited with an error."
    exit 1
fi

echo "✅ Video trimmed successfully to '$OUTPUT_VIDEO'"