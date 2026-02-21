#!/usr/bin/env bash

################################################################################
# Groq Voice Transcription
# Linux voice-to-text transcription
################################################################################

set -euo pipefail

# ============================================================================
# Paths
# ============================================================================
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# ============================================================================
# Configuration
# ============================================================================
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

GROQ_API_KEY="${GROQ_API_KEY:-}"
AI_ENHANCE="${AI_ENHANCE:-off}"
AI_PROMPT_STYLE="${AI_PROMPT_STYLE:-strict}"
AI_MODEL="${AI_MODEL:-auto}"
TRANSCRIPTION_LANG="${TRANSCRIPTION_LANG:-}"
SOUND_FILE="${SOUND_FILE:-$PROJECT_ROOT/assets/Staplebops.oga}"
HISTORY_FILE="${HISTORY_FILE:-$PROJECT_ROOT/history.md}"
ENABLE_OVERLAY="${ENABLE_OVERLAY:-auto}"   # auto/on/off

# Runtime files
LOCK_FILE="/tmp/groq_recording.lock"
PID_FILE="/tmp/groq_recording.pid"
AUDIO_FILE="/tmp/groq_recording.wav"
AUDIO_OPTIMIZED="/tmp/groq_recording.ogg"
PRIMARY_MODEL="whisper-large-v3-turbo"
FALLBACK_MODEL="whisper-large-v3"

# ============================================================================
# Utility Functions
# ============================================================================
notify_user() {
    local title="$1"
    local message="$2"
    local timeout_ms="${3:-2000}"
    notify-send "$title" "$message" -t "$timeout_ms" 2>/dev/null || true
}

play_sound() {
    local sound_file="$1"

    if [ -z "$sound_file" ] || [ ! -f "$sound_file" ]; then
        return
    fi

    if command -v ffplay >/dev/null 2>&1; then
        ffplay -nodisp -autoexit -v quiet "$sound_file" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then
        paplay "$sound_file" >/dev/null 2>&1 &
    fi
}

get_filesize() {
    local file="$1"
    stat -c%s "$file" 2>/dev/null || echo "0"
}

copy_to_clipboard() {
    local text="$1"

    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$text" | xclip -selection clipboard
    else
        echo "Warning: no clipboard tool found (wl-copy/xclip)" >&2
        return 1
    fi
}

paste_at_cursor() {
    if command -v pgrep >/dev/null 2>&1 && pgrep ydotoold >/dev/null 2>&1 && command -v ydotool >/dev/null 2>&1; then
        ydotool key 29:1 47:1 47:0 29:0
        return 0
    fi

    if command -v wtype >/dev/null 2>&1; then
        wtype -M ctrl -k v -m ctrl
        return 0
    fi

    if command -v xdotool >/dev/null 2>&1; then
        xdotool key --clearmodifiers ctrl+v
        return 0
    fi

    echo "Warning: no paste automation tool found" >&2
    return 1
}

overlay_supported() {
    if [ "$ENABLE_OVERLAY" = "off" ]; then
        return 1
    fi

    if [ ! -f "$PROJECT_ROOT/src/overlay/main.py" ]; then
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi

    return 0
}

# ============================================================================
# Overlay Functions
# ============================================================================
start_waveform_overlay() {
    if ! overlay_supported; then
        return
    fi

    GDK_BACKEND=x11 python3 "$PROJECT_ROOT/src/overlay/main.py" >> /tmp/groq_overlay_debug.log 2>&1 &
    echo "$!" > "/tmp/groq_waveform.pid"
}

show_recording() {
    start_waveform_overlay &
}

show_processing() {
    if [ -f "/tmp/groq_waveform.pid" ]; then
        touch /tmp/groq_processing_mode
    fi
}

show_success() {
    play_sound "$SOUND_FILE"

    if [ -f "/tmp/groq_waveform.pid" ]; then
        touch /tmp/groq_close_animation
        sleep 0.8
        kill "$(cat "/tmp/groq_waveform.pid")" 2>/dev/null || true
        rm -f "/tmp/groq_waveform.pid" /tmp/groq_close_animation
    fi
}

show_error() {
    local message="$1"
    notify_user "Groq Voice" "$message" 2500

    if [ -f "/tmp/groq_waveform.pid" ]; then
        touch /tmp/groq_close_animation
        sleep 0.8
        kill "$(cat "/tmp/groq_waveform.pid")" 2>/dev/null || true
        rm -f "/tmp/groq_waveform.pid" /tmp/groq_close_animation
    fi
}

# ============================================================================
# Dependency Checks
# ============================================================================
check_dependencies() {
    local missing=()
    local sudo_cmd=""
    command -v sudo &>/dev/null && sudo_cmd="sudo"

    # Detect package manager
    local install_cmd=""
    if command -v apt-get &>/dev/null; then
        install_cmd="$sudo_cmd apt-get install -y"
    elif command -v dnf &>/dev/null; then
        install_cmd="$sudo_cmd dnf install -y"
    elif command -v pacman &>/dev/null; then
        install_cmd="$sudo_cmd pacman -S --noconfirm"
    elif command -v brew &>/dev/null; then
        install_cmd="brew install"
    fi

    # Map command → package name
    get_pkg() {
        local cmd="$1"
        if command -v apt-get &>/dev/null; then
            case "$cmd" in
                curl) echo "curl" ;; jq) echo "jq" ;; ffmpeg) echo "ffmpeg" ;;
                arecord) echo "alsa-utils" ;; notify-send) echo "libnotify-bin" ;;
                xclip) echo "xclip" ;; xdotool) echo "xdotool" ;;
                wl-copy) echo "wl-clipboard" ;; *) echo "$cmd" ;;
            esac
        elif command -v pacman &>/dev/null; then
            case "$cmd" in
                notify-send) echo "libnotify" ;; *) echo "$cmd" ;;
            esac
        else
            echo "$cmd"
        fi
    }

    # Auto-install a missing command
    try_install() {
        local cmd="$1"
        local pkg
        pkg="$(get_pkg "$cmd")"
        if [ -n "$install_cmd" ]; then
            echo "Installing $pkg..." >&2
            # shellcheck disable=SC2086
            $install_cmd $pkg >/dev/null 2>&1 && return 0
        fi
        return 1
    }

    # Check & install required commands
    for cmd in curl jq; do
        if ! command -v "$cmd" &>/dev/null; then
            try_install "$cmd" || missing+=("$cmd")
        fi
    done

    # Check for audio recorder
    if ! command -v arecord &>/dev/null && ! command -v ffmpeg &>/dev/null; then
        try_install "ffmpeg" || missing+=("arecord or ffmpeg")
    fi

    # Check for ffmpeg (needed for audio optimization)
    if ! command -v ffmpeg &>/dev/null; then
        try_install "ffmpeg" || missing+=("ffmpeg")
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Missing dependencies: ${missing[*]}" >&2
        echo "Run: ./scripts/setup.sh --install" >&2
        exit 1
    fi

    # Auto-install optional but important deps (non-blocking)
    if ! command -v wl-copy &>/dev/null && ! command -v xclip &>/dev/null; then
        if [ -n "${WAYLAND_DISPLAY:-}" ]; then
            try_install "wl-copy" 2>/dev/null || true
        else
            try_install "xclip" 2>/dev/null || true
        fi
        if ! command -v wl-copy &>/dev/null && ! command -v xclip &>/dev/null; then
            echo "Warning: no clipboard command found (wl-copy/xclip). Text won't be copied." >&2
        fi
    fi
}

# ============================================================================
# Recording Functions
# ============================================================================
start_audio_capture() {
    if command -v arecord >/dev/null 2>&1; then
        arecord -f S16_LE -r 16000 -c 1 -t wav "$AUDIO_FILE" >/dev/null 2>&1 &
        echo "$!" > "$PID_FILE"
        return 0
    fi

    ffmpeg -nostdin -hide_banner -loglevel error -y \
        -f alsa -i default -ac 1 -ar 16000 -c:a pcm_s16le "$AUDIO_FILE" \
        >/tmp/groq_recording_ffmpeg.log 2>&1 &
    echo "$!" > "$PID_FILE"
    return 0
}

start_recording() {
    touch "$LOCK_FILE"
    play_sound "$SOUND_FILE" &
    show_recording

    if ! start_audio_capture; then
        cleanup_files
        show_error "Unable to start audio capture"
        return 1
    fi
}

stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        cleanup_files
        return 0
    fi

    local pid
    pid="$(cat "$PID_FILE")"
    if [ -n "$pid" ]; then
        kill -INT "$pid" 2>/dev/null || true
    fi

    sleep 0.25
    show_processing

    if [ -f "$AUDIO_FILE" ]; then
        local filesize
        filesize="$(get_filesize "$AUDIO_FILE")"
        if [ "$filesize" -lt 8000 ]; then
            show_error "Recording too short"
            cleanup_files
            return 1
        fi
    else
        show_error "No audio file generated"
        cleanup_files
        return 1
    fi

    AUDIO_OPTIMIZED="$AUDIO_FILE"
    transcribe_and_type
    cleanup_files
}

cleanup_files() {
    if [ -f "/tmp/groq_waveform.pid" ]; then
        kill "$(cat "/tmp/groq_waveform.pid")" 2>/dev/null || true
        rm -f "/tmp/groq_waveform.pid"
    fi

    pkill -f "src/overlay/main.py" 2>/dev/null || true
    rm -f "$LOCK_FILE" "$PID_FILE" "$AUDIO_FILE" "$AUDIO_OPTIMIZED" /tmp/groq_recording.ogg
}

# ============================================================================
# Transcription
# ============================================================================
transcribe_and_type() {
    local temp_response="/tmp/groq_response_$(date +%s).txt"
    local model="$PRIMARY_MODEL"
    local http_code
    local curl_exit=0
    local body

    local -a lang_args=()
    if [ -n "$TRANSCRIPTION_LANG" ]; then
        lang_args=(-F "language=$TRANSCRIPTION_LANG")
    fi

    http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
        --http2 \
        --connect-timeout 3 \
        --max-time 20 \
        "https://api.groq.com/openai/v1/audio/transcriptions" \
        -H "Authorization: Bearer ${GROQ_API_KEY}" \
        -F "model=$model" \
        "${lang_args[@]}" \
        -F "file=@$AUDIO_OPTIMIZED" \
        -F "temperature=0" \
        -F "response_format=json" \
        -X POST) || curl_exit=$?

    if [ "$curl_exit" -eq 6 ] || [ "$curl_exit" -eq 7 ]; then
        touch "/tmp/groq_connection_error"
        sleep 0.5
        if [ -f "/tmp/groq_waveform.pid" ]; then
            touch /tmp/groq_close_animation
            sleep 0.5
        fi
        cleanup_files
        return 1
    fi

    body="$(cat "$temp_response" 2>/dev/null || true)"

    if [ "$http_code" = "429" ] || echo "$body" | grep -q "rate_limit\|quota"; then
        model="$FALLBACK_MODEL"
        http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
            --http2 \
            --connect-timeout 3 \
            --max-time 20 \
            "https://api.groq.com/openai/v1/audio/transcriptions" \
            -H "Authorization: Bearer ${GROQ_API_KEY}" \
            -F "model=$model" \
            "${lang_args[@]}" \
            -F "file=@$AUDIO_OPTIMIZED" \
            -F "temperature=0" \
            -F "response_format=json" \
            -X POST)
        body="$(cat "$temp_response" 2>/dev/null || true)"
    fi

    rm -f "$temp_response"

    if [ "$http_code" = "200" ]; then
        local transcribed_text
        transcribed_text="$(echo "$body" | jq -r '.text // empty' 2>/dev/null)"

        echo "$body" > /tmp/groq_last_response.json
        echo "Transcribed: $transcribed_text" > /tmp/groq_debug.log

        if [ -n "$transcribed_text" ] && [ "$transcribed_text" != "null" ]; then
            if [ "$AI_ENHANCE" = "on" ] && [ -x "$SCRIPT_DIR/ai-enhance.sh" ]; then
                local enhanced_text
                enhanced_text="$("$SCRIPT_DIR/ai-enhance.sh" enhance "$transcribed_text" 2>/dev/null || true)"
                if [ -n "$enhanced_text" ]; then
                    transcribed_text="$enhanced_text"
                fi
                echo "Enhanced: $transcribed_text" >> /tmp/groq_debug.log
            fi

            copy_to_clipboard "$transcribed_text" || true
            paste_at_cursor || true

            {
                if [ -n "$transcribed_text" ]; then
                    if [ ! -s "$HISTORY_FILE" ]; then
                        echo "# Voice Transcription History" > "$HISTORY_FILE"
                        echo "| Date | Time | Model | Style | Text |" >> "$HISTORY_FILE"
                        echo "|---|---|---|---|---|" >> "$HISTORY_FILE"
                    fi

                    local timestamp_date timestamp_time style_name safe_text
                    timestamp_date="$(date "+%Y-%m-%d")"
                    timestamp_time="$(date "+%H:%M:%S")"
                    style_name="Raw"
                    if [ "$AI_ENHANCE" = "on" ]; then
                        style_name="${AI_PROMPT_STYLE:-Unknown}"
                    fi

                    safe_text="$(echo "$transcribed_text" | tr '|' '¦' | tr '\n' ' ')"
                    echo "| $timestamp_date | $timestamp_time | ${AI_MODEL:-$model} | $style_name | $safe_text |" >> "$HISTORY_FILE"
                fi
            } &

            show_success
        else
            show_error "No speech detected"
        fi
    else
        local error_msg
        error_msg="$(echo "$body" | jq -r '.error.message // "Unknown error"' 2>/dev/null)"
        show_error "$error_msg"
    fi
}

change_language() {
    if [ -x "$SCRIPT_DIR/select-language.sh" ]; then
        "$SCRIPT_DIR/select-language.sh"
    else
        echo "Error: select-language.sh not found or not executable" >&2
        exit 1
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    if [ "${1:-}" = "--select-lang" ] || [ "${1:-}" = "lang" ]; then
        change_language
        exit 0
    fi

    check_dependencies

    if [ -z "$GROQ_API_KEY" ]; then
        echo "Configuration error: GROQ_API_KEY is not set in .env" >&2
        exit 1
    fi

    if [ -f "$LOCK_FILE" ]; then
        stop_recording
    else
        start_recording
    fi
}

main "$@"
