# 🎙️ Groq Voice (STT with AI)

> A fast, keyboard-driven voice transcription tool powered by [Groq's Whisper API](https://groq.com/). Record your voice with a hotkey, get instant transcription with optional AI enhancement, and have the text automatically typed at your cursor.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

## ✨ Features

- **Instant Voice-to-Text** — Record with a hotkey, get text in 1-2 seconds.
- **Auto-Typing** — Transcribed text is automatically typed at your cursor.
- **AI Enhancement** — 6 processing styles (e.g., professional, strictly correct, clarify).
- **Multiple AI Models** — Supports Llama 3/4, Qwen3, GPT-OSS, and more.
- **Multi-language** — 30+ languages supported via Whisper-Large-v3.
- **Desktop Overlay** — Real-time waveform and timer overlay (Linux only).

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/MdDahshan/stt-with-Ai.git
cd stt-with-Ai
```

### 2. Auto-Install Dependencies
We provide a smart setup script that detects your OS/Package manager and handles everything.
```bash
./scripts/setup.sh --install
```

### 3. Add Your API Key
The setup script creates a `.env` file for you. Open it and add your Groq API key:
```bash
nano .env
```
*(Get a free API key from [console.groq.com](https://console.groq.com/))*

### 4. Set Up Your Hotkey
- **Linux:** Go to your system Keyboard Shortcuts and bind `/path/to/stt-with-Ai/scripts/groq-voice-to-text.sh` to a key combination (e.g., `Super+Space`).
- **macOS:** Use the interactive menu (`./scripts/select-language.sh`) and select "Setup macOS Shortcuts".

## 📖 Usage

### Basic Workflow
1. **Press** your hotkey to start recording.
2. **Speak** normally.
3. **Press** your hotkey again to stop.
4. The text will magically appear wherever your cursor currently is!

### Settings Menu
Open the beautiful interactive settings menu to change language, toggle AI, or switch models:
```bash
./scripts/select-language.sh
```

### AI Enhancement Styles

- `strict`: Minimal changes, fixes grammar while keeping original voice.
- `professional`: Polished, publication-ready formatting.
- `minimal`: Removes filler words (um, uh).
- `formal_arabic`: Converts colloquial Arabic (عامية) to MSA (فصحى).
- `assistant`: Acts as an AI assistant answering your voice queries.
- `clarify`: Optimizes rough speech into a clear prompt for AI workflows.

## 📁 Architecture
- `scripts/groq-voice-to-text.sh`: Main recording & API engine.
- `scripts/ai-enhance.sh`: AI post-processing using Groq Chat API.
- `scripts/select-language.sh`: Interactive Rofi/Zenity UI.
- `src/overlay/`: Python GTK3 visual overlay for Linux.

## 📝 License
MIT License - see LICENSE file for details.
