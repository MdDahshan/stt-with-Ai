#!/usr/bin/env bash

################################################################################
# Groq Voice — Dependency Setup
# Automatically detects and installs all required dependencies
################################################################################

set -euo pipefail

# ============================================================================
# Colors & Formatting
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
info() { echo -e "  ${BLUE}→${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

# ============================================================================
# Paths
# ============================================================================
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd -P)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

# ============================================================================
# OS & Package Manager Detection
# ============================================================================
OS="unknown"
PKG_MANAGER="unknown"
INSTALL_CMD=""
SUDO=""

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        OS="linux"
    else
        echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
        exit 1
    fi
}

detect_package_manager() {
    if [ "$OS" = "macos" ]; then
        if command -v brew &>/dev/null; then
            PKG_MANAGER="brew"
            INSTALL_CMD="brew install"
        else
            echo -e "${RED}Homebrew is required on macOS.${NC}"
            echo "Install it with:"
            echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
            exit 1
        fi
    elif [ "$OS" = "linux" ]; then
        # Check for sudo
        if command -v sudo &>/dev/null; then
            SUDO="sudo"
        fi

        if command -v apt-get &>/dev/null; then
            PKG_MANAGER="apt"
            INSTALL_CMD="$SUDO apt-get install -y"
        elif command -v dnf &>/dev/null; then
            PKG_MANAGER="dnf"
            INSTALL_CMD="$SUDO dnf install -y"
        elif command -v pacman &>/dev/null; then
            PKG_MANAGER="pacman"
            INSTALL_CMD="$SUDO pacman -S --noconfirm"
        elif command -v zypper &>/dev/null; then
            PKG_MANAGER="zypper"
            INSTALL_CMD="$SUDO zypper install -y"
        elif command -v apk &>/dev/null; then
            PKG_MANAGER="apk"
            INSTALL_CMD="$SUDO apk add"
        else
            echo -e "${RED}No supported package manager found.${NC}"
            echo "Supported: apt, dnf, pacman, zypper, apk"
            exit 1
        fi
    fi
}

# ============================================================================
# Package Name Mapping (command → package name per manager)
# ============================================================================
get_package_name() {
    local cmd="$1"

    case "$PKG_MANAGER" in
        apt)
            case "$cmd" in
                curl)        echo "curl" ;;
                jq)          echo "jq" ;;
                ffmpeg)      echo "ffmpeg" ;;
                ffplay)      echo "ffmpeg" ;;
                arecord)     echo "alsa-utils" ;;
                notify-send) echo "libnotify-bin" ;;
                rofi)        echo "rofi" ;;
                zenity)      echo "zenity" ;;
                xclip)       echo "xclip" ;;
                xdotool)     echo "xdotool" ;;
                wl-copy)     echo "wl-clipboard" ;;
                wtype)       echo "wtype" ;;
                ydotool)     echo "ydotool" ;;
                python3)     echo "python3" ;;
                pip3)        echo "python3-pip" ;;
                python3-gi)  echo "python3-gi python3-gi-cairo gir1.2-gtk-3.0" ;;
                bash)        echo "bash" ;;
                *)           echo "$cmd" ;;
            esac
            ;;
        dnf)
            case "$cmd" in
                curl)        echo "curl" ;;
                jq)          echo "jq" ;;
                ffmpeg)      echo "ffmpeg" ;;
                ffplay)      echo "ffmpeg" ;;
                arecord)     echo "alsa-utils" ;;
                notify-send) echo "libnotify" ;;
                rofi)        echo "rofi" ;;
                zenity)      echo "zenity" ;;
                xclip)       echo "xclip" ;;
                xdotool)     echo "xdotool" ;;
                wl-copy)     echo "wl-clipboard" ;;
                wtype)       echo "wtype" ;;
                ydotool)     echo "ydotool" ;;
                python3)     echo "python3" ;;
                pip3)        echo "python3-pip" ;;
                python3-gi)  echo "python3-gobject python3-cairo gtk3" ;;
                bash)        echo "bash" ;;
                *)           echo "$cmd" ;;
            esac
            ;;
        pacman)
            case "$cmd" in
                curl)        echo "curl" ;;
                jq)          echo "jq" ;;
                ffmpeg)      echo "ffmpeg" ;;
                ffplay)      echo "ffmpeg" ;;
                arecord)     echo "alsa-utils" ;;
                notify-send) echo "libnotify" ;;
                rofi)        echo "rofi" ;;
                zenity)      echo "zenity" ;;
                xclip)       echo "xclip" ;;
                xdotool)     echo "xdotool" ;;
                wl-copy)     echo "wl-clipboard" ;;
                wtype)       echo "wtype" ;;
                ydotool)     echo "ydotool" ;;
                python3)     echo "python3" ;;
                pip3)        echo "python-pip" ;;
                python3-gi)  echo "python-gobject python-cairo gtk3" ;;
                bash)        echo "bash" ;;
                *)           echo "$cmd" ;;
            esac
            ;;
        brew)
            case "$cmd" in
                curl)    echo "curl" ;;
                jq)      echo "jq" ;;
                ffmpeg)  echo "ffmpeg" ;;
                ffplay)  echo "ffmpeg" ;;
                bash)    echo "bash" ;;
                zenity)  echo "zenity" ;;
                python3) echo "python3" ;;
                *)       echo "$cmd" ;;
            esac
            ;;
        *)
            echo "$cmd"
            ;;
    esac
}

# ============================================================================
# Install Functions
# ============================================================================
install_package() {
    local cmd="$1"
    local pkg
    pkg="$(get_package_name "$cmd")"

    if [ -z "$pkg" ] || [ "$pkg" = "$cmd" ] && [ "$PKG_MANAGER" = "brew" ]; then
        # Skip packages not available on this platform
        return 1
    fi

    info "Installing: $pkg"
    # shellcheck disable=SC2086
    $INSTALL_CMD $pkg 2>&1 | tail -1 || {
        fail "Failed to install $pkg"
        return 1
    }
    ok "Installed: $pkg"
    return 0
}

check_and_install() {
    local cmd="$1"
    local label="${2:-$cmd}"
    local required="${3:-true}"

    if command -v "$cmd" &>/dev/null; then
        ok "$label"
        return 0
    fi

    if [ "$AUTO_INSTALL" = "true" ]; then
        install_package "$cmd" && return 0
    fi

    if [ "$required" = "true" ]; then
        fail "$label — ${RED}MISSING (required)${NC}"
        MISSING_REQUIRED+=("$cmd")
    else
        warn "$label — ${YELLOW}not found (optional)${NC}"
        MISSING_OPTIONAL+=("$cmd")
    fi
    return 1
}

check_python_module() {
    local module="$1"
    local label="${2:-$module}"
    local pip_name="${3:-$module}"
    local required="${4:-true}"

    if python3 -c "import $module" &>/dev/null 2>&1; then
        ok "$label"
        return 0
    fi

    if [ "$AUTO_INSTALL" = "true" ]; then
        info "Installing Python package: $pip_name"
        pip3 install --user "$pip_name" 2>&1 | tail -1 || {
            # Try without --user (some systems don't support it)
            pip3 install "$pip_name" 2>&1 | tail -1 || {
                fail "Failed to install $pip_name"
                return 1
            }
        }
        ok "Installed: $pip_name"
        return 0
    fi

    if [ "$required" = "true" ]; then
        fail "$label — ${RED}MISSING${NC} (pip3 install $pip_name)"
        MISSING_REQUIRED+=("pip:$pip_name")
    else
        warn "$label — ${YELLOW}not found${NC} (pip3 install $pip_name)"
        MISSING_OPTIONAL+=("pip:$pip_name")
    fi
    return 1
}

check_python_gi() {
    if python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" &>/dev/null 2>&1; then
        ok "Python GTK3 bindings (gi)"
        return 0
    fi

    if [ "$AUTO_INSTALL" = "true" ] && [ "$OS" = "linux" ]; then
        local pkg
        pkg="$(get_package_name "python3-gi")"
        info "Installing: $pkg"
        # shellcheck disable=SC2086
        $INSTALL_CMD $pkg 2>&1 | tail -1 || {
            fail "Failed to install GTK3 Python bindings"
            return 1
        }
        ok "Installed: GTK3 Python bindings"
        return 0
    fi

    warn "Python GTK3 bindings — ${YELLOW}not found (overlay won't work)${NC}"
    MISSING_OPTIONAL+=("python3-gi")
    return 1
}

# ============================================================================
# Main Setup
# ============================================================================
main() {
    echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     🎙️  Groq Voice — Setup              ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"

    # Parse arguments
    AUTO_INSTALL="false"
    CHECK_ONLY="false"
    for arg in "$@"; do
        case "$arg" in
            --install|-i) AUTO_INSTALL="true" ;;
            --check|-c)   CHECK_ONLY="true" ;;
            --help|-h)
                echo ""
                echo "Usage: ./scripts/setup.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --check,   -c    Check dependencies only (no install)"
                echo "  --install, -i    Auto-install missing dependencies"
                echo "  --help,    -h    Show this help"
                echo ""
                echo "Without flags: interactive mode (asks before installing)"
                exit 0
                ;;
        esac
    done

    detect_os
    detect_package_manager

    MISSING_REQUIRED=()
    MISSING_OPTIONAL=()

    echo ""
    info "OS: $OS | Package Manager: $PKG_MANAGER"

    # ── If interactive, ask before installing ──
    if [ "$AUTO_INSTALL" = "false" ] && [ "$CHECK_ONLY" = "false" ]; then
        echo ""
        echo -e "  ${BOLD}Would you like to auto-install missing dependencies?${NC}"
        echo -e "  ${CYAN}[y]${NC} Yes, install everything  ${CYAN}[n]${NC} No, just check"
        read -rp "  > " choice
        case "$choice" in
            [yY]*) AUTO_INSTALL="true" ;;
        esac
    fi

    # ── Update package lists ──
    if [ "$AUTO_INSTALL" = "true" ] && [ "$PKG_MANAGER" = "apt" ]; then
        info "Updating package lists..."
        $SUDO apt-get update -qq 2>&1 | tail -1 || true
    fi

    # ── Core (Required) ──
    header "Core Dependencies (Required)"
    check_and_install "curl"    "curl (HTTP client)"
    check_and_install "jq"      "jq (JSON parser)"
    check_and_install "ffmpeg"  "ffmpeg (audio processing)"

    if [ "$OS" = "macos" ]; then
        # Check bash version on macOS
        local bash_version
        bash_version="$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
        local bash_major="${bash_version%%.*}"
        if [ "$bash_major" -ge 4 ] 2>/dev/null; then
            ok "bash $bash_version (4+ required)"
        else
            fail "bash $bash_version — ${RED}version 4+ required${NC}"
            if [ "$AUTO_INSTALL" = "true" ]; then
                install_package "bash"
            else
                MISSING_REQUIRED+=("bash")
            fi
        fi
    fi

    # ── Audio Recording ──
    header "Audio Recording"
    if [ "$OS" = "linux" ]; then
        if command -v arecord &>/dev/null; then
            ok "arecord (ALSA recorder)"
        elif command -v ffmpeg &>/dev/null; then
            ok "ffmpeg (fallback recorder)"
        else
            check_and_install "arecord" "arecord (ALSA recorder)"
        fi
    else
        ok "ffmpeg (macOS recording via AVFoundation)"
    fi

    # ── Clipboard & Auto-Type ──
    header "Clipboard & Auto-Typing"
    if [ "$OS" = "linux" ]; then
        local has_clipboard=false
        local has_paste=false

        # Check clipboard
        if command -v wl-copy &>/dev/null; then
            ok "wl-copy (Wayland clipboard)"
            has_clipboard=true
        fi
        if command -v xclip &>/dev/null; then
            ok "xclip (X11 clipboard)"
            has_clipboard=true
        fi

        # Check auto-paste
        if command -v ydotool &>/dev/null; then
            ok "ydotool (universal key simulation)"
            has_paste=true
        fi
        if command -v wtype &>/dev/null; then
            ok "wtype (Wayland key simulation)"
            has_paste=true
        fi
        if command -v xdotool &>/dev/null; then
            ok "xdotool (X11 key simulation)"
            has_paste=true
        fi

        if [ "$has_clipboard" = "false" ]; then
            # Try to detect display server to install the right one
            if [ -n "${WAYLAND_DISPLAY:-}" ]; then
                check_and_install "wl-copy" "wl-copy (Wayland clipboard)"
            else
                check_and_install "xclip" "xclip (X11 clipboard)"
            fi
        fi

        if [ "$has_paste" = "false" ]; then
            if [ -n "${WAYLAND_DISPLAY:-}" ]; then
                check_and_install "wtype" "wtype (Wayland key simulation)" "false"
            else
                check_and_install "xdotool" "xdotool (X11 key simulation)"
            fi
        fi
    else
        ok "pbcopy/pbpaste (macOS built-in)"
        ok "osascript (macOS key simulation)"
    fi

    # ── Notifications ──
    header "Notifications"
    if [ "$OS" = "linux" ]; then
        check_and_install "notify-send" "notify-send (desktop notifications)" "false"
    else
        ok "osascript (macOS built-in)"
    fi

    # ── Sound Playback ──
    header "Sound Playback"
    if command -v ffplay &>/dev/null; then
        ok "ffplay (audio player)"
    elif command -v paplay &>/dev/null; then
        ok "paplay (PulseAudio player)"
    elif [ "$OS" = "macos" ] && command -v afplay &>/dev/null; then
        ok "afplay (macOS built-in)"
    else
        warn "No audio player found — install ffmpeg for sound notifications"
    fi

    # ── Settings Menu ──
    header "Settings Menu UI"
    if [ "$OS" = "linux" ]; then
        if command -v rofi &>/dev/null; then
            ok "rofi (modern menu)"
        elif command -v zenity &>/dev/null; then
            ok "zenity (GTK dialogs)"
        else
            check_and_install "rofi" "rofi (settings menu)" "false"
        fi
    else
        ok "osascript (macOS built-in dialogs)"
    fi

    # ── Python & Overlay (Linux only) ──
    if [ "$OS" = "linux" ]; then
        header "Python Overlay (Linux)"
        check_and_install "python3" "python3"
        
        if command -v python3 &>/dev/null; then
            check_python_gi
            check_python_module "pyaudio" "PyAudio (audio visualization)" "pyaudio" "false"
        fi
    fi

    # ── .env Configuration ──
    header "Configuration"
    if [ -f "$ENV_FILE" ]; then
        if grep -q "your_groq_api_key_here" "$ENV_FILE" 2>/dev/null; then
            warn ".env exists but API key is not set"
            info "Edit $ENV_FILE and add your Groq API key"
        else
            ok ".env configured"
        fi
    elif [ -f "$ENV_EXAMPLE" ]; then
        if [ "$AUTO_INSTALL" = "true" ] || [ "$CHECK_ONLY" = "false" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            ok ".env created from .env.example"
            warn "Edit $ENV_FILE and add your Groq API key"
            info "Get a free key at: https://console.groq.com/"
        else
            warn ".env not found — copy .env.example to .env and add your API key"
        fi
    else
        fail ".env and .env.example not found"
    fi

    # ── Make scripts executable ──
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    ok "Scripts are executable"

    # ── Summary ──
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ "${#MISSING_REQUIRED[@]}" -eq 0 ] && [ "${#MISSING_OPTIONAL[@]}" -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}✅ All dependencies are installed!${NC}"
        echo ""
        echo -e "  ${BOLD}Quick Start:${NC}"
        echo -e "  1. Set your API key in ${CYAN}.env${NC}"
        echo -e "  2. Run: ${CYAN}./scripts/groq-voice-to-text.sh${NC}"
        echo -e "  3. Speak, then run again to transcribe"
    elif [ "${#MISSING_REQUIRED[@]}" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}❌ Missing required dependencies:${NC}"
        for dep in "${MISSING_REQUIRED[@]}"; do
            echo -e "     ${RED}• $dep${NC}"
        done
        echo ""
        echo -e "  Run ${CYAN}./scripts/setup.sh --install${NC} to install them"
    else
        echo -e "  ${YELLOW}${BOLD}⚠ Some optional features unavailable:${NC}"
        for dep in "${MISSING_OPTIONAL[@]}"; do
            echo -e "     ${YELLOW}• $dep${NC}"
        done
        echo ""
        echo -e "  ${GREEN}Core functionality will work fine.${NC}"
        echo -e "  Run ${CYAN}./scripts/setup.sh --install${NC} to install optional deps"
    fi

    echo ""
}

main "$@"
