#!/usr/bin/env bash

################################################################################
# AI Text Enhancement Module
# Cleans and formats transcribed text using AI models
################################################################################

set -euo pipefail

# ============================================================================
# Load Configuration from .env
# ============================================================================
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load .env file
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Defaults if not set
GROQ_API_KEY="${GROQ_API_KEY:-}"
AI_ENHANCE="${AI_ENHANCE:-off}"
AI_PROMPT_STYLE="${AI_PROMPT_STYLE:-strict}"
AI_MODEL="${AI_MODEL:-auto}"  # auto = use fallback chain

# ============================================================================
# Available Models
# ============================================================================
declare -A MODEL_INFO
# Format: [model_id]="display_name|supports_browser_search"
MODEL_INFO["openai/gpt-oss-120b"]="GPT-OSS 120B|yes"
MODEL_INFO["openai/gpt-oss-20b"]="GPT-OSS 20B|yes"
MODEL_INFO["llama-3.3-70b-versatile"]="Llama 3.3 70B|no"
MODEL_INFO["qwen/qwen3-32b"]="Qwen3 32B|no"
MODEL_INFO["meta-llama/llama-4-maverick-17b-128e-instruct"]="Llama 4 Maverick|no"
MODEL_INFO["meta-llama/llama-4-scout-17b-16e-instruct"]="Llama 4 Scout|no"
MODEL_INFO["moonshotai/kimi-k2-instruct-0905"]="Kimi K2|no"
MODEL_INFO["llama-3.1-8b-instant"]="Llama 3.1 8B (Fast)|no"

# Fallback chain (used when AI_MODEL=auto)
# Ordered by SPEED: fastest models first!
FALLBACK_MODELS=(
    "llama-3.1-8b-instant"                           # Fastest! ~0.3s
    "meta-llama/llama-4-scout-17b-16e-instruct"      # Fast ~0.5s
    "qwen/qwen3-32b"                                 # Medium ~0.8s
    "llama-3.3-70b-versatile"                        # Slower ~1.5s
    "openai/gpt-oss-20b"                             # Has browser search
    "openai/gpt-oss-120b"                            # Slowest but best
)

# ============================================================================
# System Prompts (loaded from external files)
# ============================================================================
declare -A PROMPTS

# Load prompts from external files
load_prompts() {
    local prompt_dir="$PROJECT_ROOT/data/prompts"
    
    # Check if prompts directory exists
    if [ ! -d "$prompt_dir" ]; then
        echo "Error: Prompts directory not found at $prompt_dir" >&2
        exit 1
    fi
    
    # Load each prompt file
    for prompt_file in "$prompt_dir"/*.txt; do
        if [ -f "$prompt_file" ]; then
            local prompt_name=$(basename "$prompt_file" .txt)
            PROMPTS["$prompt_name"]=$(cat "$prompt_file")
        fi
    done
    
    # Verify required prompts are loaded
    local required_prompts=("strict" "professional" "minimal" "formal_arabic" "assistant" "clarify")
    for prompt in "${required_prompts[@]}"; do
        if [ -z "${PROMPTS[$prompt]:-}" ]; then
            echo "Error: Required prompt '$prompt' not found in $prompt_dir" >&2
            exit 1
        fi
    done
}

# Load prompts on script initialization
load_prompts

# Get current prompt
get_prompt() {
    echo "${PROMPTS[$AI_PROMPT_STYLE]:-${PROMPTS[strict]}}"
}

SYSTEM_PROMPT=$(get_prompt)

# ============================================================================
# Helper Functions
# ============================================================================

# Update .env file
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
    notify-send "$title" "$message" -t "$timeout_ms" -u normal 2>/dev/null || true
}

# Check if AI enhancement is enabled
is_enabled() {
    [ "$AI_ENHANCE" = "on" ]
}

# Show processing notification
show_processing() {
    notify_user "AI Enhancement" "Improving your text..." 1500
}

# ============================================================================
# Enhancement Function
# ============================================================================

# Check if model supports browser search
supports_browser_search() {
    local model="$1"
    local info="${MODEL_INFO[$model]:-}"
    [[ "$info" == *"|yes" ]]
}

# Get models to try
get_models_to_try() {
    if [ "$AI_MODEL" = "auto" ]; then
        echo "${FALLBACK_MODELS[@]}"
    else
        echo "$AI_MODEL"
    fi
}

# Build request payload
build_payload() {
    local model="$1"
    local escaped_text="$2"
    local escaped_system="$3"
    
    # Check if we should use browser search (only for assistant mode + GPT-OSS models)
    if [ "$AI_PROMPT_STYLE" = "assistant" ] && supports_browser_search "$model"; then
        # Payload with browser search enabled
        cat << EOF
{
    "model": "$model",
    "messages": [
        {"role": "system", "content": $escaped_system},
        {"role": "user", "content": $escaped_text}
    ],
    "temperature": 0.7,
    "max_completion_tokens": 4096,
    "stream": false,
    "tools": [{"type": "browser_search"}],
    "tool_choice": "auto"
}
EOF
    else
        # Base payload - optimized for speed
        cat << EOF
{
    "model": "$model",
    "messages": [
        {"role": "system", "content": $escaped_system},
        {"role": "user", "content": $escaped_text}
    ],
    "temperature": 0.1,
    "max_completion_tokens": 512,
    "stream": false
}
EOF
    fi
}

enhance_text() {
    local input_text="$1"
    local temp_response="/tmp/ai_enhance_response_$$.txt"
    
    # Skip if text is too short
    if [ ${#input_text} -lt 5 ]; then
        echo "$input_text"
        return 0
    fi
    
    show_processing
    
    # Reload prompt in case style changed
    SYSTEM_PROMPT=$(get_prompt)
    
    local escaped_text=$(echo "$input_text" | jq -Rs '.')
    local escaped_system=$(echo "$SYSTEM_PROMPT" | jq -Rs '.')
    
    # Get models to try
    local models_array
    if [ "$AI_MODEL" = "auto" ]; then
        models_array=("${FALLBACK_MODELS[@]}")
    else
        models_array=("$AI_MODEL")
    fi
    
    # Try each model
    for model in "${models_array[@]}"; do
        local payload=$(build_payload "$model" "$escaped_text" "$escaped_system")
        
        local http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
            --http2 \
            --connect-timeout 3 \
            --max-time 15 \
            "https://api.groq.com/openai/v1/chat/completions" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${GROQ_API_KEY}" \
            -d "$payload")
        
        local body=$(cat "$temp_response" 2>/dev/null)
        
        # Log for debugging
        echo "[$(date)] Model: $model, HTTP: $http_code" >> /tmp/ai_enhance_debug.log
        
        # Check for success
        if [ "$http_code" = "200" ]; then
            local enhanced=$(echo "$body" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
            
            # Remove thinking tags if present (multiline)
            enhanced=$(echo "$enhanced" | perl -0777 -pe 's/<think>.*?<\/think>//gs' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "$enhanced" ]; then
                rm -f "$temp_response"
                echo "$enhanced"
                return 0
            fi
        fi
        
        echo "[$(date)] Model $model failed, trying next..." >> /tmp/ai_enhance_debug.log
    done
    
    # All models failed
    rm -f "$temp_response"
    echo "$input_text"
    return 1
}

# ============================================================================
# Main
# ============================================================================

case "${1:-}" in
    "status")
        echo "AI_ENHANCE=$AI_ENHANCE"
        echo "AI_PROMPT_STYLE=$AI_PROMPT_STYLE"
        ;;
    "on")
        update_env "AI_ENHANCE" "on"
        echo "on"
        ;;
    "off")
        update_env "AI_ENHANCE" "off"
        echo "off"
        ;;
    "set-style")
        style="${2:-strict}"
        if [ -n "${PROMPTS[$style]+x}" ]; then
            update_env "AI_PROMPT_STYLE" "$style"
            echo "$style"
        else
            echo "Invalid style. Use: strict, professional, minimal, formal_arabic"
            exit 1
        fi
        ;;
    "enhance")
        if [ -n "${2:-}" ]; then
            enhance_text "$2"
        else
            input=$(cat)
            enhance_text "$input"
        fi
        ;;
    "check")
        is_enabled && exit 0 || exit 1
        ;;
    "set-model")
        model="${2:-auto}"
        if [ "$model" = "auto" ] || [ -n "${MODEL_INFO[$model]+x}" ]; then
            update_env "AI_MODEL" "$model"
            echo "$model"
        else
            echo "Invalid model. Use 'list-models' to see available models."
            exit 1
        fi
        ;;
    "list-models")
        echo "Available models (🌐 = Web Search in Assistant mode):"
        echo "  auto (use fallback chain)"
        for m in "${!MODEL_INFO[@]}"; do
            info="${MODEL_INFO[$m]}"
            name=$(echo "$info" | cut -d'|' -f1)
            browser_search=$(echo "$info" | cut -d'|' -f2)
            features=""
            [ "$browser_search" = "yes" ] && features+="🌐 "
            echo "  $m → $name $features"
        done
        ;;
    "get-model")
        echo "$AI_MODEL"
        ;;
    *)
        echo "Usage: $0 {status|on|off|set-style <style>|set-model <model>|list-models|enhance <text>|check}"
        echo ""
        echo "Styles: strict, professional, minimal, formal_arabic, assistant, clarify"
        echo "Models: auto, or use 'list-models' to see all"
        exit 1
        ;;
esac
