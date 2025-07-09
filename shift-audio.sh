#!/bin/bash

# =============================================================================
# shift-audio.sh
# This script shifts the audio track of an input video by a specified amount
# (audio starts later) and extends the video duration with black frames.
# Usage: ./shift-audio.sh <input-video-file> <output-video-file> <shift-amount-seconds>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-video-file> <output-video-file> <shift-amount-seconds>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"
SHIFT_AMOUNT_SEC="$3"
SHIFT_AMOUNT_MS=$(echo "$SHIFT_AMOUNT_SEC * 1000" | bc)

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

echo "--- Shifting Audio and Extending Video ---"

# --- Query Video and Audio Parameters ---
echo "Querying parameters from '$INPUT_VIDEO'..."

VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel_layout -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CODEC=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$INPUT_VIDEO" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters using ffprobe."
    exit 1
fi

FFMPEG_SIZE=$(echo "$VIDEO_SIZE" | sed 's/,/x/')

# Temporary files
TEMP_VIDEO_EXTENDED="temp_video_extended_${RANDOM}.mp4"
TEMP_AUDIO_DELAYED="temp_audio_delayed_${RANDOM}.aac"

# --- Extend Video with black frames ---
echo "Extending video with ${SHIFT_AMOUNT_SEC} second(s) of black frames..."
"$FFMPEG_BIN" -y \
              -i "$INPUT_VIDEO" \
              -f lavfi -i "color=c=black:s=$FFMPEG_SIZE:d=${SHIFT_AMOUNT_SEC}:r=$VIDEO_FPS" \
              -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[v]" \
              -map "[v]" \
              -c:v libx264 -preset medium -crf 23 \
              -an \
              "$TEMP_VIDEO_EXTENDED"

if [ $? -ne 0 ]; then
    echo "Error: Video extension failed. FFmpeg command exited with an error."
    rm -f "$TEMP_VIDEO_EXTENDED" "$TEMP_AUDIO_DELAYED"
    exit 1
fi

# --- Process Audio (if exists) ---
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    echo "Processing audio stream..."
    # Determine adelay map based on audio channels
    ADELAY_MAP=""
    NUM_CHANNELS=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$INPUT_VIDEO" 2>&1)
    if [ -n "$NUM_CHANNELS" ]; then
        for (( i=1; i<=$NUM_CHANNELS; i++ )); do
            ADELAY_MAP+="${SHIFT_AMOUNT_MS}"
            if [ "$i" -lt "$NUM_CHANNELS" ]; then
                ADELAY_MAP+="|"
            fi
        done
    else
        # Fallback to a common stereo delay if channels cannot be determined
        ADELAY_MAP="${SHIFT_AMOUNT_MS}|${SHIFT_AMOUNT_MS}"
    fi

    "$FFMPEG_BIN" -y \
                  -i "$INPUT_VIDEO" \
                  -filter_complex "[0:a]adelay=${ADELAY_MAP}[a]" \
                  -map "[a]" \
                  -c:a ${AUDIO_CODEC} -ar ${AUDIO_SAMPLE_RATE} \
                  "$TEMP_AUDIO_DELAYED"

    if [ $? -ne 0 ]; then
        echo "Error: Audio delay processing failed. FFmpeg command exited with an error."
        rm -f "$TEMP_VIDEO_EXTENDED" "$TEMP_AUDIO_DELAYED"
        exit 1
    fi
fi

# --- Combine Video and Audio ---
echo "Combining extended video and delayed audio..."

COMBINE_COMMAND="$FFMPEG_BIN -y -i \"$TEMP_VIDEO_EXTENDED\""
MAP_AUDIO_OPTION=""

if [ -n "$AUDIO_CH_LAYOUT" ]; then
    COMBINE_COMMAND+=" -i \"$TEMP_AUDIO_DELAYED\""
    MAP_AUDIO_OPTION="-map 1:a"
fi

COMBINE_COMMAND+=" -map 0:v ${MAP_AUDIO_OPTION} -c:v copy -c:a copy \"$OUTPUT_VIDEO\""

eval $COMBINE_COMMAND

if [ $? -ne 0 ]; then
    echo "Error: Final video combination failed. FFmpeg command exited with an error."
    rm -f "$TEMP_VIDEO_EXTENDED" "$TEMP_AUDIO_DELAYED"
    exit 1
fi

# --- Clean Up Temporary Files ---
rm -f "$TEMP_VIDEO_EXTENDED" "$TEMP_AUDIO_DELAYED"

echo "✅ Audio shifted and video extended successfully. Output saved to '$OUTPUT_VIDEO'"