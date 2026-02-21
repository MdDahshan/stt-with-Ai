#!/usr/bin/env bash

# ============================================================================
# Language & Settings Selector
# ============================================================================

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load .env
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

AI_ENHANCE="${AI_ENHANCE:-off}"
AI_PROMPT_STYLE="${AI_PROMPT_STYLE:-strict}"
AI_MODEL="${AI_MODEL:-auto}"
TRANSCRIPTION_LANG="${TRANSCRIPTION_LANG:-}"

# Helper to update .env
update_env() {
    local key="$1"
    local value="$2"
    local tmp_file

    [ -f "$ENV_FILE" ] || touch "$ENV_FILE"
    tmp_file="$(mktemp)"

    awk -v k="$key" -v v="$value" '
        BEGIN { updated=0 }
        $0 ~ ("^" k "=") {
            print k "=\"" v "\""
            updated=1
            next
        }
        { print }
        END {
            if (!updated) {
                print k "=\"" v "\""
            }
        }
    ' "$ENV_FILE" > "$tmp_file"

    mv "$tmp_file" "$ENV_FILE"
}

notify_user() {
    local title="$1"
    local message="$2"
    local timeout_ms="${3:-2000}"
    notify-send "$title" "$message" -t "$timeout_ms" 2>/dev/null || true
}

choose_option() {
    local prompt="$1"
    local options="$2"
    local selected=""

    if command -v rofi >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        if selected="$(printf '%s\n' "$options" | rofi -dmenu -i -theme-str "$ROFI_THEME" -p "$prompt" -font "Sans 10" 2>/dev/null)"; then
            printf '%s' "$selected"
            return 0
        fi
    fi

    if command -v zenity >/dev/null 2>&1 && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
        if selected="$(printf '%s\n' "$options" | zenity --list --column="$prompt" --title="$prompt" --height=420 --width=420 2>/dev/null)"; then
            printf '%s' "$selected"
            return 0
        fi
    fi

    echo "Error: no working menu backend found. Install rofi or zenity." >&2
    return 1
}

# Available Models (🌐 = supports browser search)
declare -A MODELS_DISPLAY
MODELS_DISPLAY["auto"]="🔄 Auto (Fallback Chain)"
MODELS_DISPLAY["openai/gpt-oss-120b"]="🏆 GPT-OSS 120B 🌐"
MODELS_DISPLAY["openai/gpt-oss-20b"]="⚡ GPT-OSS 20B 🌐"
MODELS_DISPLAY["llama-3.3-70b-versatile"]="🦙 Llama 3.3 70B"
MODELS_DISPLAY["qwen/qwen3-32b"]="🧠 Qwen3 32B"
MODELS_DISPLAY["meta-llama/llama-4-maverick-17b-128e-instruct"]="🦙 Llama 4 Maverick"
MODELS_DISPLAY["meta-llama/llama-4-scout-17b-16e-instruct"]="🦙 Llama 4 Scout"
MODELS_DISPLAY["moonshotai/kimi-k2-instruct-0905"]="🌙 Kimi K2"
MODELS_DISPLAY["llama-3.1-8b-instant"]="💨 Llama 3.1 8B (Fast)"

# ============================================================================
# Language Options
# ============================================================================
declare -A LANGUAGES
LANGUAGES=(
    ["Auto Detection"]="auto"
    ["Arabic (العربية)"]="ar"
    ["English"]="en"
    ["Spanish (Español)"]="es"
    ["Chinese (中文)"]="zh"
    ["Japanese (日本語)"]="ja"
    ["Korean (한국어)"]="ko"
    ["French (Français)"]="fr"
    ["German (Deutsch)"]="de"
    ["Russian (Русский)"]="ru"
    ["Portuguese (Português)"]="pt"
    ["Italian (Italiano)"]="it"
    ["Turkish (Türkçe)"]="tr"
    ["Hindi (हिन्दी)"]="hi"
    ["Dutch (Nederlands)"]="nl"
    ["Polish (Polski)"]="pl"
    ["Vietnamese (Tiếng Việt)"]="vi"
    ["Indonesian (Indonesia)"]="id"
    ["Thai (ไทย)"]="th"
    ["Hebrew (עברית)"]="he"
    ["Greek (Ελληνικά)"]="el"
    ["Czech (Čeština)"]="cs"
    ["Romanian (Română)"]="ro"
    ["Swedish (Svenska)"]="sv"
    ["Danish (Dansk)"]="da"
    ["Finnish (Suomi)"]="fi"
    ["Norwegian (Norsk)"]="no"
    ["Hungarian (Magyar)"]="hu"
    ["Ukrainian (Українська)"]="uk"
    ["Persian (فارسی)"]="fa"
    ["Urdu (اردو)"]="ur"
    ["Bengali (বাংলা)"]="bn"
    ["Tamil (தமிழ்)"]="ta"
    ["Malay (Bahasa Melayu)"]="ms"
)

# ============================================================================
# Rofi Theme
# ============================================================================
ROFI_THEME='
* {
    background-color: #000000;
    text-color: #ffffff;
    font: "Segoe UI, Roboto, Helvetica, Arial, sans-serif 11";
}
window {
    background-color: #000000;
    border: 2px;
    border-color: #ffffff;
    border-radius: 12px;
    padding: 15px;
    width: 650px;
}
mainbox {
    background-color: transparent;
    children: [ inputbar, message, listview ];
    spacing: 10px;
}
inputbar {
    background-color: #000000;
    border-radius: 6px;
    padding: 8px;
    children: [ prompt, entry ];
    border: 1px;
    border-color: #ffffff;
}
prompt {
    background-color: transparent;
    text-color: #ffffff;
    margin: 0px 8px 0px 0px;
    font: "Sans Bold 11";
}
entry {
    background-color: transparent;
    text-color: #ffffff;
    placeholder: "Search languages...";
    placeholder-color: #666666;
}
listview {
    background-color: transparent;
    lines: 10;
    columns: 2;
    spacing: 4px;
    scrollbar: true;
    scrollbar-width: 4px;
}
element {
    padding: 6px 10px;
    border-radius: 6px;
    background-color: transparent;
    text-color: #ffffff;
}
element normal.normal, element alternate.normal {
    background-color: transparent;
    text-color: #ffffff;
}
element selected {
    background-color: #ffffff;
    text-color: #000000;
    border: 0px;
}
element-text {
    background-color: transparent;
    text-color: inherit;
    highlight: bold underline;
    vertical-align: 0.5;
}
element-icon {
    size: 1.0em;
    background-color: transparent;
    vertical-align: 0.5;
}
scrollbar {
    handle-width: 4px;
    handle-color: #333333;
    background-color: transparent;
}
'

# ============================================================================
# Build Menu
# ============================================================================

# Get display status
get_ai_display() {
    if [ "$AI_ENHANCE" = "on" ]; then
        echo "🟢 ON"
    else
        echo "🔴 OFF"
    fi
}

get_style_display() {
    case "$AI_PROMPT_STYLE" in
        "strict") echo "🔒 Strict" ;;
        "professional") echo "💼 Professional" ;;
        "minimal") echo "✨ Minimal" ;;
        "formal_arabic") echo "📜 فصحى" ;;
        "assistant") echo "💬 Assistant" ;;
        "clarify") echo "🔍 Clarify" ;;
        *) echo "🔒 Strict" ;;
    esac
}

get_model_display() {
    echo "${MODELS_DISPLAY[$AI_MODEL]:-🔄 Auto}"
}

AI_DISPLAY=$(get_ai_display)
STYLE_DISPLAY=$(get_style_display)
MODEL_DISPLAY=$(get_model_display)

# Main Menu Loop
main_menu() {
    # Get status for display
    AI_DISPLAY=$(get_ai_display)
    STYLE_DISPLAY=$(get_style_display)
    MODEL_DISPLAY=$(get_model_display)

    # Build options list
    OPTIONS="━━━━━ 🌍 Languages ━━━━━
Auto Detection
Arabic (العربية)
English
Spanish (Español)
Chinese (中文)
Japanese (日本語)
Korean (한국어)
French (Français)
German (Deutsch)
━━━━━ ⚙ AI Settings ━━━━━
🤖 AI Enhancement [$AI_DISPLAY]
$(get_style_display)
$(get_model_display)
━━━━━ ⚙ AI Settings ━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━
Russian (Русский)
Portuguese (Português)
Italian (Italiano)
Turkish (Türkçe)
Hindi (हिन्दी)
Dutch (Nederlands)
Polish (Polski)
Vietnamese (Tiếng Việt)
Indonesian (Indonesia)
Thai (ไทย)
Hebrew (עברית)
Greek (Ελληνικά)
Czech (Čeština)
Romanian (Română)
Swedish (Svenska)
Persian (فارسی)
Ukrainian (Українська)
Bengali (বাংলা)"

    # Show Menu
    SELECTED="$(choose_option "Settings" "$OPTIONS")" || exit 1

    # Handle empty selection
    [ -z "$SELECTED" ] && exit 0

    # Separator
    if [[ "$SELECTED" == *"━━━━━"* ]]; then
        exit 0
    fi

    # AI Enhancement Toggle
    if [[ "$SELECTED" == *"AI Enhancement"* ]]; then
        if [ "$AI_ENHANCE" = "on" ]; then
            update_env "AI_ENHANCE" "off"
            notify_user "AI Enhancement" "Disabled" 2000
        else
            update_env "AI_ENHANCE" "on"
            notify_user "AI Enhancement" "Enabled" 2000
        fi
        exit 0
    fi

    # AI Style Selection
    if [[ "$SELECTED" == *"Strict"* ]] || [[ "$SELECTED" == *"Professional"* ]] || [[ "$SELECTED" == *"Minimal"* ]] || [[ "$SELECTED" == *"فصحى"* ]] || [[ "$SELECTED" == *"Assistant"* ]] || [[ "$SELECTED" == *"Clarify"* ]]; then
        STYLE_OPTIONS="⬅ Back
🔒 Strict (Preserve Dialect)
💼 Professional (Polished)
✨ Minimal (Light Touch)
📜 Formal Arabic (فصحى)
💬 Assistant (AI Replies)
🔍 Clarify (Make Speech Clear)"

        STYLE_SELECTED="$(choose_option "AI Style" "$STYLE_OPTIONS")"

        if [ "$STYLE_SELECTED" = "⬅ Back" ]; then
            main_menu
            return
        fi

        if [ -n "$STYLE_SELECTED" ]; then
            case "$STYLE_SELECTED" in
                *"Strict"*) update_env "AI_PROMPT_STYLE" "strict" ; notify_user "AI Style" "Strict" 2000 ;;
                *"Professional"*) update_env "AI_PROMPT_STYLE" "professional" ; notify_user "AI Style" "Professional" 2000 ;;
                *"Minimal"*) update_env "AI_PROMPT_STYLE" "minimal" ; notify_user "AI Style" "Minimal" 2000 ;;
                *"فصحى"* | *"Formal"*) update_env "AI_PROMPT_STYLE" "formal_arabic" ; notify_user "AI Style" "Formal Arabic" 2000 ;;
                *"Assistant"*) update_env "AI_PROMPT_STYLE" "assistant" ; notify_user "AI Style" "Assistant" 2000 ;;
                *"Clarify"*) update_env "AI_PROMPT_STYLE" "clarify" ; notify_user "AI Style" "Clarify" 2000 ;;
            esac
        fi
        exit 0
    fi

    # Model Selection
    if [[ "$SELECTED" == *"Auto"* ]] || [[ "$SELECTED" == *"GPT-OSS"* ]] || [[ "$SELECTED" == *"Llama"* ]] || [[ "$SELECTED" == *"Qwen"* ]] || [[ "$SELECTED" == *"Kimi"* ]]; then
        MODEL_OPTIONS="⬅ Back
🔄 Auto (Fallback Chain)
🏆 GPT-OSS 120B (Best + 🌐 Web Search)
⚡ GPT-OSS 20B (Fast + 🌐 Web Search)
🦙 Llama 3.3 70B (Reliable)
🧠 Qwen3 32B (Best for Arabic)
🦙 Llama 4 Maverick (Latest)
🦙 Llama 4 Scout (Efficient)
🌙 Kimi K2 (Moonshot AI)
💨 Llama 3.1 8B (Fastest)"

        MODEL_SELECTED="$(choose_option "AI Model" "$MODEL_OPTIONS")"

        if [ "$MODEL_SELECTED" = "⬅ Back" ]; then
            main_menu
            return
        fi

        if [ -n "$MODEL_SELECTED" ]; then
            case "$MODEL_SELECTED" in
                *"Auto"*) update_env "AI_MODEL" "auto" ; notify_user "AI Model" "Auto" 2000 ;;
                *"GPT-OSS 120B"*) update_env "AI_MODEL" "openai/gpt-oss-120b" ; notify_user "AI Model" "GPT-OSS 120B" 2000 ;;
                *"GPT-OSS 20B"*) update_env "AI_MODEL" "openai/gpt-oss-20b" ; notify_user "AI Model" "GPT-OSS 20B" 2000 ;;
                *"Llama 3.3 70B"*) update_env "AI_MODEL" "llama-3.3-70b-versatile" ; notify_user "AI Model" "Llama 3.3 70B" 2000 ;;
                *"Qwen3 32B"*) update_env "AI_MODEL" "qwen/qwen3-32b" ; notify_user "AI Model" "Qwen3 32B" 2000 ;;
                *"Maverick"*) update_env "AI_MODEL" "meta-llama/llama-4-maverick-17b-128e-instruct" ; notify_user "AI Model" "Maverick" 2000 ;;
                *"Scout"*) update_env "AI_MODEL" "meta-llama/llama-4-scout-17b-16e-instruct" ; notify_user "AI Model" "Scout" 2000 ;;
                *"Kimi"*) update_env "AI_MODEL" "moonshotai/kimi-k2-instruct-0905" ; notify_user "AI Model" "Kimi K2" 2000 ;;
                *"8B"* | *"Fastest"*) update_env "AI_MODEL" "llama-3.1-8b-instant" ; notify_user "AI Model" "8B Instant" 2000 ;;
            esac
        fi
        exit 0
    fi

    # Language Selection
    LANG_CODE="${LANGUAGES[$SELECTED]:-}"
    if [ -n "$LANG_CODE" ]; then
        [ "$LANG_CODE" = "auto" ] && LANG_CODE=""
        update_env "TRANSCRIPTION_LANG" "$LANG_CODE"
        notify_user "Language" "Set to: $SELECTED" 2000
    fi
}

# Start
main_menu
