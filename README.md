# 🎙️ Groq Voice — Speech-to-Text Transcription System

> A professional, keyboard-driven voice transcription tool powered by [Groq's Whisper API](https://groq.com/). Record your voice with a single hotkey press, get instant transcription with optional AI enhancement, and have the text automatically typed at your cursor. Supports 30+ languages, multiple AI models, and features a beautiful real-time waveform overlay on Linux.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Bash](https://img.shields.io/badge/bash-4.0+-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [How It Works](#-how-it-works)
- [Demo](#-demo)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Configuration](#%EF%B8%8F-configuration)
- [Usage](#-usage)
- [AI Enhancement Styles](#-ai-enhancement-styles)
- [Supported AI Models](#-supported-ai-models)
- [Overlay UI (Linux)](#-overlay-ui-linux)
- [Project Architecture](#-project-architecture)
- [Transcription History](#-transcription-history)
- [Troubleshooting](#-troubleshooting)
- [FAQ](#-faq)
- [Contributing](#-contributing)
- [License](#-license)
- [Acknowledgments](#-acknowledgments)

---

## 🌟 Overview

**Groq Voice** turns your microphone into a powerful text input device. Instead of typing, just speak — your words are transcribed in real-time using Groq's ultra-fast Whisper API and optionally refined by AI before being pasted directly at your cursor position.

Whether you're writing emails, coding, taking notes, or drafting documents, Groq Voice integrates seamlessly into your workflow through a simple hotkey-based interface. No browser tabs, no copy-pasting — just press, speak, and your text appears.

### Why Groq Voice?

| Feature | Groq Voice | Other Tools |
|---------|-----------|-------------|
| **Speed** | ~1-2 seconds total latency | 5-10+ seconds |
| **Integration** | Types directly at cursor | Copy-paste required |
| **AI Enhancement** | 6 built-in styles, 8+ models | Manual post-processing |
| **Cost** | Free (Groq free tier) | Paid subscriptions |
| **Privacy** | Runs locally, audio deleted after use | Cloud-stored recordings |
| **Customization** | Full control over prompts & models | Limited or none |

---

## ✨ Key Features

### 🎤 Core Transcription
- **Instant Voice-to-Text** — Record with a hotkey, get text in seconds
- **Dual Whisper Models** — Uses `whisper-large-v3-turbo` (fast) with automatic fallback to `whisper-large-v3` (accurate) on rate limits
- **30+ Languages** — Arabic, English, Spanish, Chinese, Japanese, Korean, French, German, Hindi, and many more with automatic language detection
- **Smart Audio Processing** — Records in WAV, converts to optimized OGG for faster API upload

### 🤖 AI Enhancement Engine
- **6 Enhancement Styles** — From minimal cleanup to full AI assistant mode
- **8+ AI Models** — Including Llama 4, GPT-OSS, Qwen3, and Kimi K2
- **Auto Model Selection** — Smart fallback chain tries the fastest model first, automatically switches on rate limits
- **Web Search Integration** — GPT-OSS models can search the web in assistant mode
- **Custom Prompt Templates** — Each style has a dedicated, editable prompt file

### 🖥️ Visual Feedback (Linux)
- **Animated Waveform Overlay** — Real-time audio visualization with smooth bars
- **Recording Timer** — Live MM:SS counter during recording
- **Processing Spinner** — Animated indicator while transcription is in progress
- **Network Error Display** — Red-tinted overlay with error message on connection issues
- **Smooth Animations** — Entrance/exit morphing animation (circle → pill shape)
- **Non-intrusive Design** — Transparent, always-on-top, never steals focus

### 🔧 System Integration
- **Clipboard + Auto-Type** — Copies text to clipboard AND types it at cursor position
- **Multiple Clipboard Backends** — xclip, wl-clipboard, xdotool, ydotool, pbcopy (macOS)
- **Desktop Notifications** — Visual feedback via system notifications
- **Sound Effects** — Audio cue when recording starts/stops
- **History Logging** — All transcriptions saved to a Markdown table with timestamps

### ⚙️ Settings Menu
- **Interactive UI** — Beautiful Rofi-based menu (falls back to Zenity or osascript on macOS)
- **Quick Toggles** — Enable/disable AI, switch styles, change models, select languages
- **Persistent Settings** — All preferences saved to `.env` file

---

## 🔄 How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                        WORKFLOW                              │
│                                                              │
│  ① Press Hotkey ──► ② Record Audio ──► ③ Stop (Hotkey)      │
│                         │                     │              │
│                    ┌────▼────┐          ┌─────▼─────┐       │
│                    │ Overlay │          │ Optimize   │       │
│                    │ Shows   │          │ WAV → OGG  │       │
│                    │ Waveform│          └─────┬─────┘       │
│                    └─────────┘                │              │
│                                         ┌─────▼──────┐      │
│                                         │ Groq API   │      │
│                                         │ (Whisper)  │      │
│                                         └─────┬──────┘      │
│                                               │              │
│                              ┌────────────────┼───────┐     │
│                              │ AI Enhancement │       │     │
│                              │ (if enabled)   │       │     │
│                              └────────┬───────┘       │     │
│                                       │               │     │
│                                 ┌─────▼─────┐  ┌─────▼──┐  │
│                                 │ Clipboard  │  │ History│  │
│                                 │ + Auto-type│  │  Log   │  │
│                                 └───────────┘  └────────┘  │
└─────────────────────────────────────────────────────────────┘
```

1. **Press your hotkey** to start recording (a waveform overlay appears on Linux)
2. **Speak naturally** — the system captures high-quality audio via `arecord` (Linux) or `ffmpeg` (macOS)
3. **Press the hotkey again** to stop recording
4. **Audio is optimized** — WAV is converted to OGG for smaller file size and faster upload
5. **Groq Whisper transcribes** your speech to text (with automatic model fallback)
6. **AI Enhancement** (optional) — the transcription is refined using your chosen style and model
7. **Text is delivered** — automatically typed at your cursor AND copied to clipboard
8. **History is logged** — a timestamped entry is added to `history.md`

---

## 🎬 Demo

### Quick Start Flow
```
Press hotkey  →  Speak  →  Press hotkey  →  Text appears at cursor
```

### Overlay States (Linux)

| State | Visual |
|-------|--------|
| **Recording** | Animated waveform bars + timer (MM:SS) |
| **Processing** | Spinning loader + "Processing..." text |
| **Error** | Red-tinted background + error message |

---

## 📋 Requirements

### API Key (Required)

You'll need a free API key from [Groq Console](https://console.groq.com/). Groq offers a generous free tier that's more than enough for personal use.

### Linux Dependencies

```bash
# Core (required)
sudo apt install ffmpeg curl jq

# Audio recording
sudo apt install alsa-utils              # provides arecord

# Desktop notifications
sudo apt install libnotify-bin           # provides notify-send

# Sound playback (one of these)
sudo apt install ffmpeg                  # provides ffplay (recommended)
sudo apt install pulseaudio-utils        # provides paplay (alternative)

# Settings menu UI (one of these)
sudo apt install rofi                    # Recommended — modern, beautiful menu
sudo apt install zenity                  # Alternative — GTK dialog boxes

# Clipboard & auto-typing (based on your display server)
# For X11:
sudo apt install xclip xdotool

# For Wayland:
sudo apt install wl-clipboard wtype

# Universal (works on both X11 and Wayland):
sudo apt install ydotool
sudo systemctl enable --now ydotool      # start the ydotool daemon

# Python overlay dependencies
sudo apt install python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0
pip3 install pyaudio
```

### macOS Dependencies

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core dependencies
brew install bash ffmpeg curl jq

# Optional: settings menu (built-in osascript dialogs work without this)
brew install zenity
```

**macOS Notes:**
- macOS ships with Bash 3.2 — this project requires **Bash 4+** for associative arrays. The `brew install bash` step is essential.
- Clipboard (`pbcopy`/`pbpaste`) and notifications (`osascript`) are built-in on macOS.
- The waveform overlay UI is **Linux-only** for now (GTK3/Cairo dependency).
- Audio recording uses `ffmpeg` with AVFoundation on macOS.

---

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/groq-voice.git
cd groq-voice
```

### 2. Run Setup (auto-installs dependencies)

```bash
./scripts/setup.sh --install
```

This will:
- ✅ Detect your OS and package manager (apt, dnf, pacman, brew)
- ✅ Install all missing dependencies automatically
- ✅ Create your `.env` config file from the template
- ✅ Make all scripts executable

> **💡 Note:** You can also run `./scripts/setup.sh --check` to just see what's missing without installing anything.

### 3. Add Your API Key

```bash
nano .env   # or use any editor
```

Get your free API key from [console.groq.com](https://console.groq.com/) and paste it into the `GROQ_API_KEY` field.

### 4. Set Up Your Keyboard Shortcut

#### Linux (GNOME)
1. Open **Settings → Keyboard → Custom Shortcuts**
2. Add a new shortcut:
   - **Name:** `Voice Transcription`
   - **Command:** `/full/path/to/groq-voice/scripts/groq-voice-to-text.sh`
   - **Shortcut:** Choose your preferred key combo (e.g., `Super+Space`)
3. Press the shortcut once to start recording, press again to stop and transcribe

#### Linux (KDE / Other DEs)
- Use your DE's shortcut settings to bind `scripts/groq-voice-to-text.sh` to a hotkey

#### macOS
1. Run the settings menu and select **Setup macOS Shortcuts**:
   ```bash
   ./scripts/select-language.sh
   ```
2. This copies the necessary commands and opens the Shortcuts app
3. Create a Quick Action that runs the script and assign a keyboard shortcut

### 5. Test It

```bash
# Run a quick test
./scripts/groq-voice-to-text.sh
# Speak for a few seconds, then run again to stop and transcribe
```

---

## ⚙️ Configuration

### Interactive Settings Menu

The easiest way to configure everything:

```bash
./scripts/select-language.sh
```

This opens a beautiful interactive menu where you can:
- 🌐 Select your transcription language (30+ options)
- 🤖 Toggle AI enhancement on/off
- 🎨 Choose an AI enhancement style
- 🧠 Select your preferred AI model
- 📊 View current settings at a glance

### Manual Configuration (`.env` file)

All settings are stored in the `.env` file at the project root:

```bash
# ─── Required ────────────────────────────────────────────
GROQ_API_KEY="gsk_xxxxx"              # Your Groq API key

# ─── Transcription ──────────────────────────────────────
TRANSCRIPTION_LANG="en"                # Language code (e.g., "en", "ar", "es")
                                       # Leave empty or set to "auto" for auto-detection

# ─── AI Enhancement ─────────────────────────────────────
AI_ENHANCE="off"                       # "on" or "off"
AI_PROMPT_STYLE="clarify"             # strict | professional | minimal | formal_arabic | assistant | clarify
AI_MODEL="auto"                        # "auto" for smart fallback, or a specific model ID

# ─── Audio & Feedback ───────────────────────────────────
SOUND_FILE="/path/to/assets/Staplebops.oga"   # Notification sound file
ENABLE_OVERLAY="auto"                          # "auto" | "on" | "off"
                                               # auto = enabled on Linux, disabled on macOS
AUDIO_INPUT_DEVICE="0"                         # macOS only: ffmpeg avfoundation input index

# ─── Logging ────────────────────────────────────────────
HISTORY_FILE="/path/to/history.md"    # Where to save transcription history
```

---

## 📖 Usage

### Basic Transcription

```bash
# Start/stop recording (toggle)
./scripts/groq-voice-to-text.sh

# Open settings menu
./scripts/select-language.sh
# Or use the shortcut:
./scripts/groq-voice-to-text.sh lang
```

### AI Enhancement Commands

```bash
# Toggle AI enhancement
./scripts/ai-enhance.sh on
./scripts/ai-enhance.sh off

# Check current status
./scripts/ai-enhance.sh status

# Change enhancement style
./scripts/ai-enhance.sh set-style professional

# Change AI model
./scripts/ai-enhance.sh set-model "llama-3.3-70b-versatile"

# List all available models
./scripts/ai-enhance.sh list-models

# Enhance text directly via stdin
echo "um so like I went to the store and uh bought stuff" | ./scripts/ai-enhance.sh enhance
# Output: "I went to the store and bought some items."
```

### Typical Workflow

1. **Set your language** — Run `./scripts/select-language.sh` and pick your language
2. **Enable AI** (optional) — Toggle AI enhancement and choose a style
3. **Bind to hotkey** — Set up your keyboard shortcut (see [Installation](#-installation))
4. **Press → Speak → Press** — That's it! Text appears at your cursor

---

## 🎨 AI Enhancement Styles

Each style uses a carefully crafted prompt template stored in `data/prompts/`. You can edit these files to customize the behavior.

| Style | File | Description | Best For |
|-------|------|-------------|----------|
| **`strict`** | `strict.txt` | Minimal changes — fixes grammar and punctuation while preserving your exact dialect and word choices | Keeping your authentic voice |
| **`professional`** | `professional.txt` | Polished, publication-ready text with proper formatting. Restructures sentences for clarity | Formal documents, emails, reports |
| **`minimal`** | `minimal.txt` | Light-touch cleanup — removes filler words ("um", "uh", "like") and adds punctuation | Quick notes, casual writing |
| **`formal_arabic`** | `formal_arabic.txt` | Converts Egyptian/Gulf/Levantine colloquial Arabic (عامية) to Modern Standard Arabic (فصحى) | Arabic academic/formal writing |
| **`assistant`** | `assistant.txt` | AI responds to your voice as a conversational assistant — answers questions, provides information | Voice commands, Q&A |
| **`clarify`** | `clarify.txt` | Transforms rough speech into well-structured, optimized prompts ready to send to AI agents | Prompt engineering, AI workflows |

### Custom Prompts

To create your own style:

1. Create a new file in `data/prompts/` (e.g., `my_style.txt`)
2. Write your system prompt following the existing templates as reference
3. The prompt will be automatically available in the settings menu

---

## 🧠 Supported AI Models

The system uses Groq's hosted models for AI enhancement. When set to `auto`, it tries models in order of speed, automatically falling back on rate limits.

| Model | ID | Speed | Quality | Web Search |
|-------|----|-------|---------|------------|
| **Llama 3.1 8B Instant** | `llama-3.1-8b-instant` | ⚡⚡⚡ ~0.3s | Good | ❌ |
| **Llama 4 Scout 17B** | `meta-llama/llama-4-scout-17b-16e-instruct` | ⚡⚡ ~0.5s | Great | ❌ |
| **Llama 4 Maverick 17B** | `meta-llama/llama-4-maverick-17b-128e-instruct` | ⚡⚡ ~0.6s | Great | ❌ |
| **Qwen3 32B** | `qwen/qwen3-32b` | ⚡ ~0.8s | Excellent | ❌ |
| **Llama 3.3 70B** | `llama-3.3-70b-versatile` | ⚡ ~1.5s | Excellent | ❌ |
| **GPT-OSS 20B** | `openai/gpt-oss-20b` | ⚡ ~0.5s | Great | ✅ (assistant mode) |
| **GPT-OSS 120B** | `openai/gpt-oss-120b` | 🐢 ~2s | Best | ✅ (assistant mode) |
| **Kimi K2** | `moonshotai/kimi-k2-instruct-0905` | ⚡ ~0.8s | Great | ❌ |

### Auto Fallback Chain

When `AI_MODEL="auto"`, the system tries models in this order:
1. Llama 3.1 8B Instant (fastest)
2. Llama 4 Scout 17B
3. Llama 4 Maverick 17B
4. Kimi K2
5. GPT-OSS 20B
6. Qwen3 32B
7. Llama 3.3 70B (most reliable)
8. GPT-OSS 120B (highest quality)

If a model hits a rate limit, the system instantly switches to the next one — no manual intervention needed.

---

## 🖥️ Overlay UI (Linux)

The overlay is a GTK3/Cairo-based transparent window that provides visual feedback during recording. It sits at the bottom center of your screen, never steals focus, and features smooth animations.

### Architecture

```
src/overlay/
├── main.py          # GTK window management, animation loops, signal handling
├── audio.py         # PyAudio real-time audio input with error recovery
├── renderers.py     # Cairo drawing: background, timer, waveform bars
├── visuals.py       # Shape primitives (pill path drawing)
└── errors.py        # Centralized error handling with circuit breaker pattern
```

### Visual States

| State | Description |
|-------|-------------|
| **🟢 Recording** | Animated waveform bars react to your voice in real-time. Timer counts up in MM:SS format. Smooth entrance animation morphs from circle to pill shape. |
| **🔵 Processing** | Waveform bars replaced by a spinning loader animation. "Processing..." text displayed. Audio input paused. |
| **🔴 Error** | Background tints red. "Check your network" message appears. Triggered by `/tmp/groq_connection_error` flag file. |
| **✨ Entrance** | Circle morphs into pill shape with opacity fade-in. Width gradually expands to full size. |
| **💨 Exit** | Reverse animation — pill shrinks back to circle and fades out. |

### Error Handling

The overlay uses a comprehensive error handling framework (`errors.py`) with:

- **Error Categories** — UI rendering, audio input, file I/O, signal checking, animation, window management
- **Circuit Breaker Pattern** — Stops retrying after too many consecutive failures to prevent cascading errors
- **Safe Callbacks** — All GTK callbacks are wrapped in error-catching decorators that prevent crashes
- **Graceful Degradation** — If audio input fails, the overlay continues working with idle animation
- **Debug Logging** — All errors logged to `/tmp/groq_overlay_errors.log`

---

## 🏗️ Project Architecture

```
groq-voice/
│
├── scripts/                          # Bash scripts (main entry points)
│   ├── groq-voice-to-text.sh        # 🎯 Main transcription engine
│   │                                 #    - Audio recording (arecord/ffmpeg)
│   │                                 #    - Groq Whisper API calls
│   │                                 #    - Clipboard/auto-type integration
│   │                                 #    - Overlay lifecycle management
│   │                                 #    - History logging
│   │
│   ├── ai-enhance.sh                # 🤖 AI post-processing module
│   │                                 #    - Model management & fallback chain
│   │                                 #    - Prompt loading from data/prompts/
│   │                                 #    - Groq Chat API calls
│   │                                 #    - Web search support (GPT-OSS models)
│   │
│   ├── select-language.sh           # ⚙️ Interactive settings menu
│   │                                 #    - Rofi/Zenity/osascript UI
│   │                                 #    - Language, model, style selection
│   │                                 #    - .env file management
│   │
│   ├── setup.sh                     # 📦 Dependency installer
│   │                                 #    - Auto-detects OS & package manager
│   │                                 #    - Installs missing dependencies
│   │                                 #    - Creates .env from template
│   │
│   └── test-history-dialog.sh       # 🧪 History dialog test utility
│
├── src/overlay/                      # Python overlay (Linux only)
│   ├── main.py                      # GTK3 window + animation loops
│   ├── audio.py                     # PyAudio input with error recovery
│   ├── renderers.py                 # Cairo rendering (background, timer, bars)
│   ├── visuals.py                   # Shape drawing utilities
│   └── errors.py                    # Error handling framework
│
├── data/prompts/                     # AI enhancement prompt templates
│   ├── strict.txt                   # Preserve original voice
│   ├── professional.txt             # Publication-ready polish
│   ├── minimal.txt                  # Light cleanup
│   ├── formal_arabic.txt            # عامية → فصحى conversion
│   ├── assistant.txt                # Conversational AI responses
│   └── clarify.txt                  # Speech → optimized AI prompt
│
├── assets/                           # Static resources
│   └── Staplebops.oga              # Notification sound effect
│
├── .env                              # User configuration (not tracked in git)
├── history.md                        # Transcription log (auto-generated)
└── README.md                         # This file
```

### Script Communication

The scripts communicate through files and signals:

| Mechanism | Path | Purpose |
|-----------|------|---------|
| Lock file | `/tmp/groq_recording.lock` | Prevents multiple simultaneous recordings |
| PID file | `/tmp/groq_recording.pid` | Tracks recording process for stop signal |
| Audio file | `/tmp/groq_recording.wav` | Raw audio capture |
| Optimized audio | `/tmp/groq_recording.ogg` | Compressed audio for API upload |
| Processing signal | `/tmp/groq_processing` | Tells overlay to show spinner |
| Close signal | `/tmp/groq_overlay_close` | Tells overlay to animate exit |
| Connection error | `/tmp/groq_connection_error` | Tells overlay to show error state |
| Error log | `/tmp/groq_overlay_errors.log` | Overlay debug/error log |
| Debug log | `/tmp/groq_overlay_debug.log` | Overlay verbose debug log |

---

## 📝 Transcription History

All transcriptions are automatically logged to `history.md` as a Markdown table:

```markdown
# Voice Transcription History
| Date | Time | Model | Style | Text |
|---|---|---|---|---|
| 2026-02-01 | 08:15:14 | auto | Raw | Hello, how are you today? |
| 2026-02-01 | 08:16:13 | auto | professional | I would like to schedule a meeting for tomorrow. |
| 2026-02-01 | 08:17:45 | llama-3.3-70b-versatile | clarify | Please help me debug this Python function that raises a TypeError. |
```

Each entry records:
- **Date & Time** — When the transcription was made
- **Model** — Which AI model was used (or "Raw" if AI enhancement was off)
- **Style** — Which enhancement style was applied
- **Text** — The final transcribed (and optionally enhanced) text

---

## 🔧 Troubleshooting

### Common Issues

<details>
<summary><strong>❌ No audio visualization in the overlay</strong></summary>

1. **Check microphone permissions:**
   ```bash
   arecord -d 3 test.wav && aplay test.wav
   ```
2. **Verify PyAudio installation:**
   ```bash
   python3 -c "import pyaudio; print('PyAudio OK')"
   ```
3. **Check the overlay error log:**
   ```bash
   cat /tmp/groq_overlay_errors.log
   ```
4. **Note:** On macOS, the overlay is disabled by default (`ENABLE_OVERLAY=auto`)
</details>

<details>
<summary><strong>❌ Text not appearing at cursor</strong></summary>

1. **Install clipboard tools:**
   ```bash
   # X11
   sudo apt install xclip xdotool

   # Wayland
   sudo apt install wl-clipboard wtype

   # Universal
   sudo apt install ydotool
   sudo systemctl enable --now ydotool
   ```
2. **Verify ydotool daemon is running:**
   ```bash
   pgrep ydotoold || sudo systemctl start ydotool
   ```
3. **On macOS:** Grant **Accessibility** permission to your Terminal app in System Settings → Privacy & Security
</details>

<details>
<summary><strong>❌ Settings menu not showing</strong></summary>

1. **Install Rofi (recommended):**
   ```bash
   sudo apt install rofi
   ```
2. **Or install Zenity as alternative:**
   ```bash
   sudo apt install zenity
   ```
3. **On macOS:** The menu uses built-in `osascript` — no additional installation needed
</details>

<details>
<summary><strong>❌ No notification sound</strong></summary>

1. **Install ffplay (comes with ffmpeg):**
   ```bash
   sudo apt install ffmpeg
   ```
2. **Or install paplay:**
   ```bash
   sudo apt install pulseaudio-utils
   ```
3. **On macOS:** `afplay` is used automatically (built-in)
4. **Verify the sound file exists:**
   ```bash
   ls -la assets/Staplebops.oga
   ```
</details>

<details>
<summary><strong>❌ API errors or rate limits</strong></summary>

1. **Verify your API key:**
   ```bash
   grep GROQ_API_KEY .env
   ```
2. **Check Groq console** for rate limit status: [console.groq.com](https://console.groq.com/)
3. **Use `auto` model** — the system automatically switches models on rate limits:
   ```bash
   ./scripts/ai-enhance.sh set-model auto
   ```
4. **Check error logs:**
   ```bash
   tail -f /tmp/groq_overlay_errors.log
   ```
</details>

<details>
<summary><strong>❌ Overlay not showing on Linux</strong></summary>

1. **Check GTK3 installation:**
   ```bash
   python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk; print('GTK3 OK')"
   ```
2. **Check Cairo installation:**
   ```bash
   python3 -c "import cairo; print('Cairo OK')"
   ```
3. **View debug log:**
   ```bash
   cat /tmp/groq_overlay_debug.log
   ```
4. **XWayland note:** The overlay requires X11 or XWayland. Pure Wayland compositors may not support transparent overlays via GTK3.
</details>

<details>
<summary><strong>❌ macOS recording device issues</strong></summary>

1. **List available audio devices:**
   ```bash
   ffmpeg -f avfoundation -list_devices true -i ""
   ```
2. **Set the correct input index in `.env`:**
   ```bash
   AUDIO_INPUT_DEVICE="0"   # Change to match your microphone's index
   ```
</details>

### Whisper Model Details

The transcription engine uses two Whisper models with automatic fallback:

| Model | Speed | Accuracy | Usage |
|-------|-------|----------|-------|
| `whisper-large-v3-turbo` | ⚡ 8x faster | Very Good | Primary (used first) |
| `whisper-large-v3` | 🐢 Standard | Excellent | Fallback (on rate limits) |

---

## ❓ FAQ

**Q: Is this free to use?**
> Yes! Groq offers a generous free tier. For most personal use, you'll never hit the limits. The `auto` model setting ensures you maximize your free quota by distributing requests across models.

**Q: Does it work offline?**
> No, it requires an internet connection to reach the Groq API. The overlay will display a network error indicator if the connection is lost.

**Q: Can I use it with any text editor/application?**
> Yes! It types text at your cursor position using system-level keyboard simulation (xdotool/ydotool/wtype on Linux, osascript on macOS). It works with any application that accepts keyboard input.

**Q: Is my audio data stored anywhere?**
> No. Audio files are recorded to `/tmp/` and deleted immediately after transcription. Nothing is stored permanently. Groq's API also doesn't retain audio data.

**Q: Can I add my own AI models?**
> Currently, the supported models are those available on the Groq platform. You can modify `scripts/ai-enhance.sh` to add new models as Groq makes them available.

**Q: Does the overlay work on Wayland?**
> The overlay works on XWayland (which most Wayland compositors support). Pure Wayland support (using layer-shell protocol) is planned for a future release.

**Q: Can I use this for languages other than English?**
> Absolutely! Whisper supports 30+ languages. Use the settings menu or set `TRANSCRIPTION_LANG` in your `.env` file. You can also set it to `auto` for automatic language detection.

---

## 🤝 Contributing

Contributions are welcome! Here are some areas where help is appreciated:

### Good First Issues
- [ ] Add more languages to the selection menu
- [ ] Create new AI enhancement prompt styles
- [ ] Improve error messages and user feedback

### Feature Requests
- [ ] Pure Wayland overlay support (layer-shell protocol)
- [ ] Additional menu backends (dmenu, wofi, bemenu)
- [ ] Windows support
- [ ] Audio input device selection menu
- [ ] Custom theme support for the overlay
- [ ] Offline mode with local Whisper models
- [ ] Plugin system for custom post-processing

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Make** your changes and test them
4. **Commit** with descriptive messages: `git commit -m "Add: new prompt style for technical writing"`
5. **Push** to your fork: `git push origin feature/my-feature`
6. **Open** a Pull Request with a clear description of your changes

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

You are free to use, modify, and distribute this software for personal and commercial purposes.

---

## 🙏 Acknowledgments

- **[Groq](https://groq.com/)** — Ultra-fast AI inference platform powering both transcription and enhancement
- **[OpenAI Whisper](https://openai.com/research/whisper)** — The speech recognition model that makes accurate transcription possible
- **[GTK3](https://www.gtk.org/) & [Cairo](https://www.cairographics.org/)** — The UI framework and graphics library behind the overlay
- **[PyAudio](https://people.csail.mit.edu/hubert/pyaudio/)** — Real-time audio input for the waveform visualization
- **[Rofi](https://github.com/davatorium/rofi)** — The beautiful application launcher used for the settings menu

---

<div align="center">

**Made with ❤️ for seamless voice transcription**

[⬆ Back to Top](#️-groq-voice--speech-to-text-transcription-system)

</div>
