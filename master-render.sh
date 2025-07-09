#!/bin/bash

# =============================================================================
# Master Video Rendering Script
# This script orchestrates the execution of other rendering scripts to produce
# a final video with title, trimmed content, audio shift, and freeze frame credits.
# Usage: ./master-render.sh <input-video> <output-video>
# =============================================================================

# Load environment variables from .env file
source .env

# Export FFmpeg and FFprobe binaries to make them available to sub-scripts
export FFMPEG_BIN
export FFPROBE_BIN

# --- Argument Handling ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input-video> <output-video>"
    exit 1
fi

# Get absolute paths for input and output videos
INPUT_VIDEO_RELATIVE="$1"
OUTPUT_VIDEO_RELATIVE="$2"

# Resolve absolute paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INPUT_VIDEO="$(realpath "$INPUT_VIDEO_RELATIVE")"
OUTPUT_VIDEO="$(realpath "$OUTPUT_VIDEO_RELATIVE")"

# Temporary directory (absolute path)
TMP_DIR="${SCRIPT_DIR}/tmp"
mkdir -p "$TMP_DIR"

# Intermediate file paths (all in tmp directory, absolute paths)
TRIMMED_VIDEO="${TMP_DIR}/trimmed_content_${RANDOM}.mp4"
PREROLLED_VIDEO="${TMP_DIR}/prerolled_content_${RANDOM}.mp4"
SHIFTED_AUDIO_VIDEO="${TMP_DIR}/shifted_audio_content_${RANDOM}.mp4"
TITLE_VIDEO_TEMP="${TMP_DIR}/title_sequence_${RANDOM}.mp4"
FREEZE_FRAME_VIDEO_TEMP="${TMP_DIR}/freeze_frame_sequence_${RANDOM}.mp4"
RENDERED_CREDITS_VIDEO="${TMP_DIR}/rendered_credits_sequence_${RANDOM}.mp4"

echo "--- Starting Master Video Rendering Process ---"

# --- 1. Shift Audio ---
echo "Running shift-audio.sh..."
bash "${SCRIPT_DIR}/shift-audio.sh" "$INPUT_VIDEO" "$SHIFTED_AUDIO_VIDEO" 1 # Shift audio by 1 second
if [ $? -ne 0 ]; then
    echo "Error: shift-audio.sh failed. Aborting."
    exit 1
fi

# --- 2. Trim to First Content Cut ---
echo "Running trim-to-first-cut.sh..."
bash "${SCRIPT_DIR}/trim-to-first-cut.sh" "$SHIFTED_AUDIO_VIDEO" "$TRIMMED_VIDEO"
if [ $? -ne 0 ]; then
    echo "Error: trim-to-first-cut.sh failed. Aborting."
    exit 1
fi

# --- 2.5. Add Preroll First Frame ---
echo "Running preroll-first-frame.sh..."
bash "${SCRIPT_DIR}/preroll-first-frame.sh" "$TRIMMED_VIDEO" "$PREROLLED_VIDEO" 2 # Preroll for 2 seconds
if [ $? -ne 0 ]; then
    echo "Error: preroll-first-frame.sh failed. Aborting."
    exit 1
fi

# --- 3. Generate Title Sequence ---
echo "Running render-title.sh..."
bash "${SCRIPT_DIR}/render-title.sh" "$INPUT_VIDEO" "$TITLE_VIDEO_TEMP"
if [ $? -ne 0 ]; then
    echo "Error: render-title.sh failed. Aborting."
    exit 1
fi

# --- 4. Generate Freeze Frame Credits ---
echo "Running freeze-frame.sh..."
bash "${SCRIPT_DIR}/freeze-frame.sh" "$INPUT_VIDEO" "$FREEZE_FRAME_VIDEO_TEMP" 4 # Freeze frame for 4 seconds
if [ $? -ne 0 ]; then
    echo "Error: freeze-frame.sh failed. Aborting."
    exit 1
fi

# --- 4.5. Render Credits ---
echo "Running render-credits.sh..."
bash "${SCRIPT_DIR}/render-credits.sh" "$INPUT_VIDEO" "$RENDERED_CREDITS_VIDEO" # Assuming render-credits.sh takes input video for probing and output path
if [ $? -ne 0 ]; then
    echo "Error: render-credits.sh failed. Aborting."
    exit 1
fi

# --- 5. Combine All Videos ---
echo "Running combine-video.sh..."
bash "${SCRIPT_DIR}/concat-videos.sh" "$TITLE_VIDEO_TEMP" "$PREROLLED_VIDEO" "$FREEZE_FRAME_VIDEO_TEMP" "$RENDERED_CREDITS_VIDEO" "$OUTPUT_VIDEO"
if [ $? -ne 0 ]; then
    echo "Error: concat-videos.sh failed. Aborting."
    exit 1
fi

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$TRIMMED_VIDEO" "$PREROLLED_VIDEO" "$SHIFTED_AUDIO_VIDEO" "$TITLE_VIDEO_TEMP" "$FREEZE_FRAME_VIDEO_TEMP" "$RENDERED_CREDITS_VIDEO"
rmdir "$TMP_DIR" 2>/dev/null # Remove tmp directory if empty
echo "Temporary files removed."

echo "--- Master Video Rendering Process Finished Successfully ---"
