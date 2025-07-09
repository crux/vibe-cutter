#!/bin/bash

# =============================================================================
# Master Video Rendering Script
# This script orchestrates the execution of other rendering scripts.
# Usage: ./master_render.sh <input-video> <output-video>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input-video> <output-video>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"

# Temporary files
TITLE_VIDEO="title.mp4"
CREDITS_VIDEO="credits.mp4"

echo "--- Starting Master Video Rendering Process ---"

# --- 1. Run Title Screen Rendering ---
echo "Running render-title.sh..."
bash render-title.sh "$INPUT_VIDEO" "$TITLE_VIDEO"
if [ $? -ne 0 ]; then
    echo "Error: render-title.sh failed. Aborting."
    exit 1
fi

# --- 2. Run Credits Screen Rendering ---
echo "Running render-credits.sh..."
bash render-credits.sh "$INPUT_VIDEO" "$CREDITS_VIDEO"
if [ $? -ne 0 ]; then
    echo "Error: render-credits.sh failed. Aborting."
    exit 1
fi

# --- 3. Run Video Combination ---
echo "Running combine-video.sh..."
bash combine-video.sh "$TITLE_VIDEO" "$INPUT_VIDEO" "$CREDITS_VIDEO" "$OUTPUT_VIDEO"
if [ $? -ne 0 ]; then
    echo "Error: combine-video.sh failed. Aborting."
    exit 1
fi

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$TITLE_VIDEO" "$CREDITS_VIDEO"
echo "Temporary files removed."

echo "--- Master Video Rendering Process Finished Successfully ---"
