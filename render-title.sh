#!/bin/bash

# =============================================================================
# render-title.sh
# This script generates a standalone title video based on an input video's
# properties (resolution, frame rate) and predefined text/style settings.
# Usage: ./render-title.sh <original-input-video> <title-output-file>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <original-input-video> <title-output-file>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"

# --- Validate Inputs ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file not found: '$INPUT_VIDEO'"
    exit 1
fi

if [ ! -f "$FONT_ROBOTO_MONO" ]; then
    echo "Error: Font file for title not found: '$FONT_ROBOTO_MONO'"
    echo "Please update the FONT_ROBOTO_MONO variable in .env."
    exit 1
fi

if [ -n "$TITLE_TEXT_LINE2" ] && [ ! -f "$FONT_ROBOTO_MONO" ]; then
    echo "Error: Font file for subtitle not found: '$FONT_ROBOTO_MONO'"
    echo "Please update the FONT_ROBOTO_MONO variable in .env."
    exit 1
fi

FFMPEG_BIN="ffmpeg"
FFPROBE_BIN="ffprobe"

if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

if ! command -v "$FFPROBE_BIN" &> /dev/null; then
    echo "Error: $FFPROBE_BIN command not found. Please install FFmpeg (ffprobe is usually included)."
    exit 1
fi

# --- Query Main Video Parameters using ffprobe ---
VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CODEC=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel_layout -of csv=p=0 "$INPUT_VIDEO" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters using ffprobe."
    exit 1
fi

FFMPEG_SIZE=$(echo "$VIDEO_SIZE" | sed 's/,/x/')

# --- Create the Title Screen Video (with silent audio) ---
if [ -z "$TITLE_TEXT_LINE2" ]; then
    DRAWTEXT_FILTER="drawtext=text='$TITLE_TEXT':fontcolor=$TITLE_COLOR:fontsize=$TITLE_FONT_SIZE:x=(w-tw)/2:y=(h-th)/2:fontfile='$FONT_ROBOTO_MONO'"
else
    DRAWTEXT_FILTER="drawtext=text='$TITLE_TEXT':fontcolor=$TITLE_COLOR:fontsize=$TITLE_FONT_SIZE:x=(w-tw)/2:y=(h-th)/2-th*0.8:fontfile='$FONT_ROBOTO_MONO', drawtext=text='$TITLE_TEXT_LINE2':fontcolor=$TITLE_COLOR_LINE2:fontsize=$TITLE_FONT_SIZE_LINE2:x=(w-tw)/2:y=(h+th)/2+th*0.2:fontfile='$FONT_ROBOTO_MONO'"
fi

AUDIO_INPUT=""
AUDIO_OUTPUT_CODEC=""
if [ -n "$AUDIO_CODEC" ]; then
    AUDIO_INPUT="-f lavfi -i anullsrc=channel_layout=$AUDIO_CH_LAYOUT:sample_rate=$AUDIO_SAMPLE_RATE"
    AUDIO_OUTPUT_CODEC="-c:a $AUDIO_CODEC"
fi

"$FFMPEG_BIN" -y \
              -f lavfi -i "color=size=$FFMPEG_SIZE:c=$BACKGROUND_COLOR:duration=$TITLE_DURATION_SEC:rate=$VIDEO_FPS" \
              $AUDIO_INPUT \
              -vf "$DRAWTEXT_FILTER" \
              -c:v libx264 -b:v $YOUTUBE_VIDEO_BITRATE \
              $AUDIO_OUTPUT_CODEC -b:a $YOUTUBE_AUDIO_BITRATE -ar $AUDIO_SAMPLE_RATE \
              -pix_fmt "$VIDEO_PIX_FMT" \
              -r $VIDEO_FPS \
              -t "$TITLE_DURATION_SEC" \
              -shortest \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error creating title screen video. FFmpeg command failed."
    exit 1
fi

echo "Title screen video created successfully: '$OUTPUT_VIDEO'"