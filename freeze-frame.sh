#!/bin/bash

# =============================================================================
# freeze-frame.sh (Modular Version)
# This script extracts the last non-black frame from an input video, and
# creates a new video file containing only that freeze frame for a specified duration.
# The input video is used only for probing encoding attributes.
# Usage: ./freeze-frame.sh <input-video-file> <output-video-file> <freeze-frame-duration-seconds>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-video-file> <output-video-file> <freeze-frame-duration-seconds>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"
FREEZE_FRAME_DURATION_SEC="$3"

# --- Validate Binaries ---
if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

if ! command -v "$FFPROBE_BIN" &> /dev/null; then
    echo "Error: $FFPROBE_BIN command not found. Please install FFmpeg (ffprobe is usually included)."
    exit 1
fi

# --- Validate Input Video ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file not found: '$INPUT_VIDEO'"
    exit 1
fi

echo "--- Creating Freeze Frame Video from Last Non-Black Frame ---"

# --- Query Video and Audio Parameters ---
echo "Querying parameters from '$INPUT_VIDEO'..."

VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel_layout -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters using ffprobe."
    exit 1
fi

FFMPEG_SIZE=$(echo "$VIDEO_SIZE" | sed 's/,/x/')

# Temporary files (created in the current working directory, which will be tmp/)
TEMP_LAST_CONTENT_FRAME_PNG="temp_last_content_frame_${RANDOM}.png"

# --- Detect Trailing Black to find the actual end of content ---
echo "Detecting trailing black frames to find the last content frame..."

DURATION=$("$FFPROBE_BIN" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO")

BLACK_DETECT_OUTPUT=$("$FFMPEG_BIN" -i "$INPUT_VIDEO" -vf "blackdetect=d=0.1:pix_th=0.20" -an -f null - 2>&1 | grep 'black_start')

LAST_CONTENT_END_TIME="$DURATION"
if [ -n "$BLACK_DETECT_OUTPUT" ]; then
    LAST_BLACK_START=$(echo "$BLACK_DETECT_OUTPUT" | tail -n1 | sed -n 's/.*black_start:\([0-9.]*\).*/\1/p')
    LAST_BLACK_END=$(echo "$BLACK_DETECT_OUTPUT" | tail -n1 | sed -n 's/.*black_end:\([0-9.]*\).*/\1/p')

    if [ -n "$LAST_BLACK_START" ] && [ -n "$LAST_BLACK_END" ]; then
        if (( $(echo "$LAST_BLACK_START == 0" | bc -l) )) && (( $(echo "$LAST_BLACK_END < $DURATION" | bc -l) )); then
            echo "Detected leading black segment, ignoring for end-of-content frame extraction."
        else
            LAST_CONTENT_END_TIME="$LAST_BLACK_START"
        fi
    fi
fi

echo "Last non-black content frame is at approximately: ${LAST_CONTENT_END_TIME}s"

# --- Extract Last Content Frame ---
echo "Extracting last content frame to '$TEMP_LAST_CONTENT_FRAME_PNG'..."
# Seek to 0.1 seconds before the detected LAST_CONTENT_END_TIME from the *original* video
SEEK_TIME=$(echo "$LAST_CONTENT_END_TIME - 0.1" | bc)
if (( $(echo "$SEEK_TIME < 0" | bc -l) )); then
    SEEK_TIME=0
fi

"$FFMPEG_BIN" -y -ss "$SEEK_TIME" -i "$INPUT_VIDEO" -frames:v 1 "$TEMP_LAST_CONTENT_FRAME_PNG"

if [ $? -ne 0 ]; then
    echo "Error: Failed to extract last content frame. FFmpeg command exited with an error."
    rm -f "$TEMP_LAST_CONTENT_FRAME_PNG"
    exit 1
fi

# --- Create Freeze Frame Video from Last Content Frame ---
echo "Creating freeze frame video ('$OUTPUT_VIDEO') from last content frame for ${FREEZE_FRAME_DURATION_SEC} seconds..."

FREEZE_FRAME_AUDIO_OPTIONS=""
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    FREEZE_FRAME_AUDIO_OPTIONS="-f lavfi -i anullsrc=channel_layout=$AUDIO_CH_LAYOUT:sample_rate=$AUDIO_SAMPLE_RATE -c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
fi

"$FFMPEG_BIN" -y \
              -loop 1 -i "$TEMP_LAST_CONTENT_FRAME_PNG" \
              ${FREEZE_FRAME_AUDIO_OPTIONS} \
              -c:v libx264 -b:v ${YOUTUBE_VIDEO_BITRATE} \
              -t "$FREEZE_FRAME_DURATION_SEC" \
              -pix_fmt "$VIDEO_PIX_FMT" \
              -r $VIDEO_FPS \
              -shortest \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create freeze frame video. FFmpeg command exited with an error."
    rm -f "$TEMP_LAST_CONTENT_FRAME_PNG"
    exit 1
fi

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$TEMP_LAST_CONTENT_FRAME_PNG"

echo "✅ Freeze frame video created successfully. Output saved to '$OUTPUT_VIDEO'"
