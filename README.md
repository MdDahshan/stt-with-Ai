# 🎙️ Groq Voice — STT & AI Enhancement Overlay

A high-performance, hands-free Linux desktop Voice-to-Text transcription tool powered by **Groq Whisper STT** (`whisper-large-v3-turbo`), featuring a real-time **Python GTK3 visual waveform overlay**, automatic clipboard copy & cursor auto-paste, and optional **Groq LLM text enhancement**.

---

## 🌟 Key Features

- 🔴 **One-Key Toggle Recording**: Press your configured desktop shortcut once to start recording; press again to stop, transcribe, format, and paste directly at your cursor.
- 🎨 **Real-Time GTK3 Visual Overlay**: A sleek, dark, floating pill widget showing live audio levels during recording and a scanning loading bar during transcription. Includes an interactive `×` cancel button.
- ⚡ **Ultra-Fast Transcription**: Uses Groq's high-speed Whisper API (`whisper-large-v3-turbo` with automatic fallback to `whisper-large-v3`).
- 🗜️ **On-the-Fly Audio Compression**: Automatically converts WAV audio into low-bitrate **Ogg Opus** using `ffmpeg` (~98% size reduction, e.g., 1.9 MB → 30 KB), enabling instant API uploads.
- 📋 **Automatic Copy & Cursor Paste**: Instantly copies transcribed text to clipboard (`wl-copy` / `xclip`) and types it into the active application (`ydotool` / `wtype` / `xdotool`).
- 🧠 **AI Post-Processing Enhancement**: Optional LLM text cleanup via Groq Chat Completions (`scripts/ai-enhance.sh`) supporting styles such as Strict, Professional, Minimal, Formal Arabic (فصحى), Assistant, and Clarify.
- ⚙️ **Interactive Settings GUI**: Launch a Rofi or Zenity popup menu (`scripts/select-language.sh`) to toggle AI enhancement, select target languages (30+ supported), choose prompt styles, and select LLM models.
- 📜 **Transcription History Log**: Automatically logs every transcription timestamp, model, style, and text to `history.md`.
- 🛡️ **Robust Error Handling**: Built with circuit-breaker error tracking, graceful audio device fallback, emergency process cleanup, and network error signaling.

---

## 📂 Project Architecture & File Structure

This directory structure serves as a map for developers and AI assistants working on this codebase:

```
stt/
├── .env                         # Active configuration & Groq API key (git-ignored)
├── .env.example                 # Template for configuration settings
├── history.md                   # Auto-generated markdown log of past transcriptions
├── assets/
│   └── Staplebops.oga           # Sound effect played on recording start & success
├── data/
│   └── prompts/                 # System prompt templates for AI text enhancement
│       ├── assistant.txt        # AI assistant mode (answers or responds to voice prompt)
│       ├── clarify.txt          # Rephrases & clarifies speech while fixing filler words
│       ├── formal_arabic.txt    # Translates/converts spoken Arabic dialect into Modern Standard Arabic (فصحى)
│       ├── minimal.txt          # Minimal touch-ups (punctuation & capitalization only)
│       ├── professional.txt     # Business professional polish
│       └── strict.txt           # Strict transcript cleanup (preserves original dialect & intent)
├── scripts/
│   ├── groq-voice-to-text.sh    # Main application entrypoint (toggle recording / transcribe / paste)
│   ├── setup.sh                 # Dependency detection & auto-installation script
│   ├── ai-enhance.sh            # Post-processing module calling Groq LLM API
│   ├── select-language.sh       # Rofi/Zenity GUI for language, AI style & model selection
│   └── test-history-dialog.sh   # Utility script to preview history log in GUI dialog
└── src/
    └── overlay/                 # Real-time GTK3 visual overlay application
        ├── main.py              # Application window, GTK event loop, animation timer & signal checks
        ├── audio.py             # PyAudio capture wrapper & real-time RMS audio level calculation
        ├── renderers.py         # Cairo graphics renderers for background pill & animated waveform bars
        ├── visuals.py           # Pill geometry path helpers
        └── errors.py            # Centralized error management, logging & circuit breaker
```

---

## 🚀 Quick Start

### 1. Prerequisites
- **Linux Desktop** (Wayland or X11)
- **Bash** 4.0+
- **Python 3** with `gi` (GTK3 bindings) & `pyaudio` (optional, for real-time waveform visualization)
- **Groq API Key**: Get a free API key at [console.groq.com](https://console.groq.com/)

### 2. Installation & Setup
Run the setup script to check and automatically install missing dependencies (supports `apt`, `dnf`, `pacman`, `brew`):

```bash
./scripts/setup.sh --install
```

### 3. Configure API Key
Copy `.env.example` to `.env` if not created automatically, and insert your Groq API key:

```env
GROQ_API_KEY="gsk_your_actual_groq_api_key_here"
TRANSCRIPTION_LANG="en"
AI_ENHANCE="off"
AI_PROMPT_STYLE="strict"
```

### 4. Test from Terminal
- Start recording:
  ```bash
  ./scripts/groq-voice-to-text.sh
  ```
- Speak into your microphone.
- Stop recording & transcribe:
  ```bash
  ./scripts/groq-voice-to-text.sh
  ```
- Open the settings GUI:
  ```bash
  ./scripts/groq-voice-to-text.sh --select-lang
  ```

---

## ⌨️ Setting Up Desktop Shortcuts

To make voice typing effortless, map a global keyboard shortcut in your Desktop Environment settings (GNOME, KDE, Sway, Hyprland, etc.):

### Main Voice Toggle Shortcut
- **Name**: Voice Typing
- **Command**: `/path/to/stt/scripts/groq-voice-to-text.sh`
- **Shortcut**: `Super + Space` or `Ctrl + Alt + R`

### Language & Settings Selector Shortcut
- **Name**: Voice Typing Settings
- **Command**: `/path/to/stt/scripts/groq-voice-to-text.sh --select-lang`
- **Shortcut**: `Super + Shift + Space` or `Ctrl + Alt + S`

---

## ⚙️ Configuration Reference (`.env`)

| Environment Variable | Allowed Values | Default | Description |
|---|---|---|---|
| `GROQ_API_KEY` | `gsk_...` | *(Required)* | Your API Key from Groq Console |
| `AI_ENHANCE` | `"on" \| "off"` | `"off"` | Enable LLM post-processing of transcribed text |
| `AI_PROMPT_STYLE` | `strict` \| `professional` \| `minimal` \| `formal_arabic` \| `assistant` \| `clarify` | `"strict"` | Prompt style used by `ai-enhance.sh` |
| `TRANSCRIPTION_LANG` | `en`, `ar`, `es`, `fr`, `de`, `""` | `""` (Auto) | ISO language code for Whisper STT |
| `INITIAL_PROMPT` | String | `""` | Technical/domain terms to bias Whisper accuracy |
| `AI_MODEL` | `auto`, model ID | `"auto"` | LLM model for enhancement (`auto` uses fallback chain) |
| `SOUND_FILE` | File Path | `assets/Staplebops.oga` | Audio cue on start & success |
| `HISTORY_FILE` | File Path | `history.md` | Path to transcription history file |
| `ENABLE_OVERLAY` | `"auto" \| "on" \| "off"` | `"auto"` | Python GTK overlay status (`auto` = Linux only) |

---

## 🤖 AI Post-Processing Styles (`data/prompts/`)

When `AI_ENHANCE="on"`, `ai-enhance.sh` passes the Whisper transcript through a Groq LLM model using one of the following prompt files:

- **`strict.txt`**: Fixes grammar and typos while strictly preserving spoken words and regional dialects.
- **`professional.txt`**: Polishes spoken words into well-structured, professional business language.
- **`minimal.txt`**: Applies minimal touch-ups (punctuation and capitalization only).
- **`formal_arabic.txt`**: Converts spoken colloquial Arabic (عامية) into Modern Standard Arabic (فصحى).
- **`clarify.txt`**: Rephrases disorganized thoughts into clear, concise statements.
- **`assistant.txt`**: Treats voice input as a prompt and returns an AI assistant response.

---

## 🛠️ Architecture Details for Developers & AI Assistants

### Inter-Process Communication & Signal Files
Communication between the main Bash controller (`scripts/groq-voice-to-text.sh`) and the Python GTK overlay (`src/overlay/main.py`) relies on lightweight `/tmp/` flag files:

- `/tmp/groq_recording.lock`: Indicates an active recording session. Its presence toggles `groq-voice-to-text.sh` from recording mode to stop/transcribe mode.
- `/tmp/groq_recording.pid`: Process ID of `arecord` or `ffmpeg` audio recording process.
- `/tmp/groq_waveform.pid`: Process ID of running `src/overlay/main.py`.
- `/tmp/groq_processing_mode`: Created by Bash after recording stops; signals GTK overlay to switch from live audio bars to the "Knight Rider" scanning animation.
- `/tmp/groq_close_animation`: Created by Bash upon completion; triggers smooth exit fade/morph of the overlay before process termination.
- `/tmp/groq_connection_error`: Created by Bash when Groq API network calls fail; causes overlay to display "Check your network" error state.
- `/tmp/groq_cancel_request`: Created by GTK overlay when the user clicks the `×` cancel button; instructs Bash to discard recorded audio without sending API calls.

### Audio Pipeline Flow
1. **Capture**: `arecord -f S16_LE -r 16000 -c 1` (or `ffmpeg` fallback) records raw mic output to `/tmp/groq_recording.wav`.
2. **Compression**: `ffmpeg` compresses WAV → Ogg Opus (`libopus`, mono, 16kHz, 32kbps) stored at `/tmp/groq_recording.ogg`.
3. **STT Request**: `curl` posts Ogg Opus audio to `https://api.groq.com/openai/v1/audio/transcriptions` with model `whisper-large-v3-turbo` (fallback: `whisper-large-v3`).
4. **Enhancement (Optional)**: If `AI_ENHANCE="on"`, passes raw text to `scripts/ai-enhance.sh` which executes a fallback chain of Groq LLM models (e.g. `llama-3.1-8b-instant` → `qwen/qwen3-32b` → `llama-3.3-70b-versatile`).
5. **Output**: Text is copied to system clipboard via `wl-copy`/`xclip` and pasted via `ydotool`/`wtype`/`xdotool`. Log entry appended to `history.md`.
