# 🎙️ Groq Voice (STT with AI)

> A fast, keyboard-driven voice transcription tool powered by [Groq's Whisper API](https://groq.com/). Record your voice with a hotkey, get instant transcription with optional AI enhancement, and have the text automatically typed at your cursor.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey.svg)

## 🎥 Quick Demo
<video src="https://github.com/MdDahshan/stt-with-Ai/raw/main/assets/demo.mp4" controls="controls" muted="muted" style="max-height:640px;"></video>

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

### 4. Set Up Your Hotkeys
To use the tool seamlessly, you need to assign keyboard shortcuts to the scripts. 

**Linux (GNOME, Mint, KDE, etc.):**
Open your System Settings → **Keyboard Shortcuts** → **Custom Shortcuts** and add the following:

1. **Transcription Hotkey (Main)**
   - **Name:** STT Record/Process
   - **Command:** `bash /path/to/stt-with-Ai/scripts/groq-voice-to-text.sh`
   - **Shortcut:** e.g., `Shift+Ctrl+Alt+Super+Z` (or any combo you prefer)
   
   <img src="https://github.com/user-attachments/assets/75c2e9b8-656b-4e1b-b467-f472f854feab" width="400" alt="Main STT Shortcut">

2. **Settings Menu Hotkey (Optional)**
   - **Name:** STT Settings
   - **Command:** `bash /path/to/stt-with-Ai/scripts/select-language.sh`
   - **Shortcut:** e.g., `Alt+R`

   <img src="https://github.com/user-attachments/assets/b82af4d0-4cb5-47e9-a477-96a84c8a29a0" width="400" alt="Settings Menu Shortcut">

**macOS:** 
Use the interactive menu (`./scripts/select-language.sh`) and select "Setup macOS Shortcuts".

## 📖 Usage

### How the Main Hotkey Works (The Toggle)
The script acts as a toggle switch. You only need **one hotkey**.

1. **Press once** 👉 Starts recording (A waveform overlay appears on Linux).
2. **Speak** your thoughts.
3. **Press again** 👉 Stops recording and starts processing the AI.
4. ✨ The text magically types itself out wherever your cursor is!

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
