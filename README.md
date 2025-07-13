# Video Processing Scripts, or How to be your own Vibe Cutter

This repository contains a suite of modular shell scripts designed for various video processing tasks using FFmpeg. The scripts are designed to be flexible and configurable via a single `.env` file.

## Table of Contents
- [Dependencies](#dependencies)
- [Configuration](#configuration)
- [Scripts](#scripts)
  - [master-render.sh](#master-render.sh)
  - [render-title.sh](#render-title.sh)
  - [render-credits.sh](#render-credits.sh)
  - [combine-video.sh](#combine-video.sh)
  - [logo-stamp.sh](#logo-stamp.sh)
  - [trim-to-first-cut.sh](#trim-to-first-cut.sh)
  - [shift-audio.sh](#shift-audio.sh)
  - [freeze-frame.sh](#freeze-frame.sh)
- [Usage Examples](#usage-examples)

## Dependencies

These scripts require `FFmpeg` and `FFprobe` to be installed and accessible in your system's PATH. You can usually install them via your system's package manager (e.g., `brew install ffmpeg` on macOS, `sudo apt-get install ffmpeg` on Debian/Ubuntu).

## Configuration

All configurable variables for the scripts are managed in a single `.env` file located in the root directory of this project. This approach allows for easy customization without modifying the scripts directly.

An example configuration file, `.env.example`, is provided. To get started, copy this file to `.env` and modify the values as needed:

```bash
cp .env.example .env
```

Variables are organized into sections. You can override any default value by setting the corresponding environment variable in your shell before running a script (e.g., `export TITLE_DURATION_SEC=10`).

**`.env` file structure (from `.env.example`):**

```ini
# Consolidated Environment Variables for Video Scripts

# --- General Configuration ---
# These variables are common across multiple scripts.

YOUTUBE_VIDEO_BITRATE="10M"
YOUTUBE_AUDIO_BITRATE="384k"
BACKGROUND_COLOR="white"
FFMPEG_BIN="ffmpeg"
FFPROBE_BIN="ffprobe"
FONT_ROBOTO_MONO="${HOME}/Library/Fonts/RobotoMono-VariableFont_wght.ttf"

# --- render-title.sh Specific Configuration ---

TITLE_DURATION_SEC=5
TITLE_TEXT="Digitale Geburtsanzeige mit der Stadt Kiel"
TITLE_FONT_SIZE=48
TITLE_COLOR="black"
TITLE_TEXT_LINE2="Präsentation Vertama DiGG vom 4. Juli 2025"
TITLE_FONT_SIZE_LINE2=28
TITLE_COLOR_LINE2="darkgray"

# --- render-credits.sh Specific Configuration ---

CREDITS_DURATION_SEC=10
CREDITS_LINE1="Digitale Geburtsanzeige mit Vertama DiGG"
CREDITS_LINE2="entwickelt und präsentiert mit der Stadt Kiel"
CREDITS_LINE3="info@vertama.com"
CREDITS_LINE4=""
CREDITS_FONT_SIZE_LINE1=48
CREDITS_FONT_COLOR_LINE1="black"
CREDITS_FONT_SIZE_LINE2=28
CREDITS_FONT_COLOR_LINE2="darkgray"
CREDITS_FONT_SIZE_LINE3=24
CREDITS_FONT_COLOR_LINE3="darkgray"
CREDITS_FONT_SIZE_LINE4=28
CREDITS_FONT_COLOR_LINE4="darkgray"
LINE_SPACING=50
```

## Scripts

### `master-render.sh`

Orchestrates the entire video rendering workflow, combining title, main video, and credits.

**Usage:** `./master-render.sh <input-video> <output-video>`

### `render-title.sh`

Generates a standalone title video based on the input video's properties and configured text/style settings.

**Usage:** `./render-title.sh <original-input-video> <title-output-file>`

### `render-credits.sh`

Generates a standalone credits video based on the input video's properties and configured text/style settings.

**Usage:** `./render-credits.sh <original-input-video> <credits-output-file>`

### `combine-video.sh`

Concatenates multiple video files into a single output video.

**Usage:** `./combine-video.sh <title-video> <main-video> <credits-video> <output-video>`

### `logo-stamp.sh`

Overlays a logo onto a video. The logo is cropped and resized as configured.

**Usage:** `./logo-stamp.sh <input-video> <logo-png> <output-video>`

### `trim-to-first-cut.sh`

Trims an input video to start at its first detected scene change (after any initial black frames).

**Usage:** `./trim-to-first-cut.sh <input-video-file> <output-video-file>`

### `shift-audio.sh`

Shifts the audio track of an input video by a specified amount (audio starts later) and extends the video duration with black frames.

**Usage:** `./shift-audio.sh <input-video-file> <output-video-file> <shift-amount-seconds>`

### `freeze-frame.sh`

Takes the last non-black frame of an input video, creates a still frame video from it, and appends it to the original video (trimmed to remove any trailing black frames).

**Usage:** `./freeze-frame.sh <input-video-file> <output-video-file> <freeze-frame-duration-seconds>`

## Usage Examples

To run the full master rendering process:

```bash
./master-render.sh "./original.mp4" "./final_presentation.mp4"
```

To generate a title video with custom duration:

```bash
TITLE_DURATION_SEC=10 ./render-title.sh "./original.mp4" "./my_custom_title.mp4"
```

To apply a logo stamp:

```bash
./logo-stamp.sh "./input_video.mp4" "./my_logo.png" "./output_with_logo.mp4"
```
