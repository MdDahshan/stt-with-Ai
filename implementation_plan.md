# 🏗️ Groq Voice Desktop — Full Implementation Plan

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Phase 1 — Project Scaffolding & Foundation](#2-phase-1--project-scaffolding--foundation)
3. [Phase 2 — Rust Core Engine](#3-phase-2--rust-core-engine)
4. [Phase 3 — Frontend UI](#4-phase-3--frontend-ui)
5. [Phase 4 — Overlay Window](#5-phase-4--overlay-window)
6. [Phase 5 — Integration & Polish](#6-phase-5--integration--polish)
7. [Phase 6 — Cross-Platform Build & Release](#7-phase-6--cross-platform-build--release)
8. [Data Models](#8-data-models)
9. [Rust ↔ Frontend Commands (IPC)](#9-rust--frontend-commands-ipc)
10. [File-by-File Breakdown](#10-file-by-file-breakdown)

---

## 1. Project Overview

### What We're Building
A cross-platform desktop app that replaces all bash scripts with a single native binary. The app lives in the system tray, responds to a global hotkey, records audio, transcribes via Groq Whisper API, optionally enhances via AI, and pastes the result at the user's cursor.

### Functional Requirements

| Feature | Details |
|---|---|
| **Global Hotkey** | Single configurable hotkey toggles record/stop (works even when app is minimized/hidden) |
| **Audio Recording** | Cross-platform mic capture at 16kHz mono |
| **Audio Compression** | Encode WAV → OGG/Opus before API upload (reduce ~10x bandwidth) |
| **Transcription** | Groq Whisper API with model fallback (turbo → full) |
| **AI Enhancement** | 6 prompt styles via Groq Chat API with 8-model fallback chain |
| **Auto-Paste** | Copy to clipboard + simulate Ctrl+V (or Cmd+V on macOS) |
| **Overlay** | Floating pill-shaped widget: waveform bars + timer (recording) / spinner (processing) |
| **System Tray** | Persistent tray icon with status (idle/recording/processing) + quick menu |
| **Settings** | Language, AI toggle, prompt style, model selection, hotkey config |
| **History** | SQLite-backed searchable transcription log |
| **Network Resilience** | Retry with exponential backoff, offline detection, connection error UI |
| **Sound Effects** | Play start/success sounds |

### Non-Functional Requirements

| Requirement | Target |
|---|---|
| App bundle size | < 15 MB |
| Memory usage (idle) | < 40 MB |
| Memory usage (recording) | < 80 MB |
| Hotkey-to-paste latency | < 3 seconds (short recordings) |
| Startup time | < 1 second |
| Platforms | Linux (X11 + Wayland), macOS (Intel + ARM), Windows 10/11 |

---

## 2. Phase 1 — Project Scaffolding & Foundation

### Step 1.1: Initialize Tauri v2 + React + TypeScript

```bash
# Inside stt/
mkdir app && cd app
npm create tauri-app@latest . -- --template react-ts
```

### Step 1.2: Project Structure

```
app/
├── src-tauri/
│   ├── Cargo.toml                # Rust dependencies
│   ├── tauri.conf.json           # Tauri configuration
│   ├── capabilities/             # Tauri v2 permissions
│   │   └── default.json
│   ├── icons/                    # App icons (all sizes)
│   └── src/
│       ├── lib.rs                # Tauri command registrations
│       ├── main.rs               # Entry point
│       ├── audio/
│       │   ├── mod.rs
│       │   ├── recorder.rs       # Mic capture via cpal
│       │   ├── encoder.rs        # WAV → OGG/Opus compression
│       │   └── levels.rs         # Real-time audio level extraction
│       ├── api/
│       │   ├── mod.rs
│       │   ├── transcription.rs  # Groq Whisper API
│       │   ├── enhancement.rs    # Groq Chat API (AI enhance)
│       │   ├── models.rs         # Model definitions + fallback
│       │   └── client.rs         # HTTP client with retry logic
│       ├── input/
│       │   ├── mod.rs
│       │   ├── clipboard.rs      # Copy text to clipboard
│       │   └── autotype.rs       # Simulate paste keystroke
│       ├── config/
│       │   ├── mod.rs
│       │   ├── settings.rs       # App settings struct + persistence
│       │   └── prompts.rs        # Load AI prompt files
│       ├── history/
│       │   ├── mod.rs
│       │   └── store.rs          # SQLite CRUD for transcription history
│       ├── state.rs              # AppState (shared across commands)
│       ├── tray.rs               # System tray setup + menu
│       └── errors.rs             # Custom error types
│
├── src/                          # React frontend
│   ├── main.tsx                  # React entry
│   ├── App.tsx                   # Root component + router
│   ├── styles/
│   │   ├── global.css            # CSS variables, fonts, base styles
│   │   ├── settings.css
│   │   ├── history.css
│   │   └── overlay.css
│   ├── pages/
│   │   ├── SettingsPage.tsx      # Main settings window
│   │   └── HistoryPage.tsx       # Transcription history viewer
│   ├── components/
│   │   ├── settings/
│   │   │   ├── LanguageSelect.tsx
│   │   │   ├── AIConfig.tsx
│   │   │   ├── ModelPicker.tsx
│   │   │   ├── HotkeyConfig.tsx
│   │   │   └── AboutSection.tsx
│   │   ├── history/
│   │   │   ├── HistoryList.tsx
│   │   │   ├── HistoryItem.tsx
│   │   │   └── SearchBar.tsx
│   │   ├── overlay/
│   │   │   ├── OverlayWindow.tsx # Floating overlay root
│   │   │   ├── Waveform.tsx      # Animated waveform bars (Canvas)
│   │   │   ├── Timer.tsx         # MM:SS timer
│   │   │   └── Spinner.tsx       # Processing spinner
│   │   └── common/
│   │       ├── Toggle.tsx
│   │       ├── Select.tsx
│   │       └── StatusBadge.tsx
│   ├── hooks/
│   │   ├── useRecording.ts       # Recording state machine
│   │   ├── useSettings.ts       # Settings read/write
│   │   ├── useHistory.ts         # History CRUD
│   │   └── useAudioLevels.ts     # Real-time waveform data
│   ├── lib/
│   │   ├── commands.ts           # Typed Tauri invoke wrappers
│   │   └── types.ts              # Shared TypeScript types
│   └── assets/
│       └── sounds/
│           └── notification.oga  # Sound effect (copied from current project)
│
├── package.json
├── tsconfig.json
├── vite.config.ts
└── index.html
```

### Step 1.3: Rust Dependencies (`Cargo.toml`)

```toml
[dependencies]
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-global-shortcut = "2"
tauri-plugin-clipboard-manager = "2"
tauri-plugin-notification = "2"
tauri-plugin-store = "2"
tauri-plugin-shell = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
reqwest = { version = "0.12", features = ["json", "multipart", "rustls-tls"] }
cpal = "0.15"                     # Cross-platform audio recording
opus = "0.3"                      # Opus audio encoding
ogg = "0.9"                       # OGG container
hound = "3.5"                     # WAV reading/writing
enigo = "0.2"                     # Cross-platform keyboard simulation
rusqlite = { version = "0.31", features = ["bundled"] }
rodio = "0.19"                    # Audio playback (sound effects)
chrono = "0.4"                    # Timestamps
uuid = { version = "1", features = ["v4"] }
thiserror = "2"                   # Error handling
log = "0.4"
env_logger = "0.11"
parking_lot = "0.12"              # Fast mutexes
```

### Step 1.4: Frontend Dependencies (`package.json`)

```json
{
  "dependencies": {
    "@tauri-apps/api": "^2",
    "@tauri-apps/plugin-global-shortcut": "^2",
    "@tauri-apps/plugin-clipboard-manager": "^2",
    "@tauri-apps/plugin-notification": "^2",
    "@tauri-apps/plugin-store": "^2",
    "react": "^19",
    "react-dom": "^19",
    "react-router-dom": "^7"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^2",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "typescript": "^5.6",
    "vite": "^6",
    "@vitejs/plugin-react": "^4"
  }
}
```

### Step 1.5: Tauri Configuration (`tauri.conf.json` key sections)

```jsonc
{
  "productName": "Groq Voice",
  "version": "1.0.0",
  "identifier": "com.groqvoice.app",
  "build": {
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "Groq Voice — Settings",
        "width": 520,
        "height": 680,
        "resizable": true,
        "visible": false,       // Starts hidden (tray-only)
        "center": true
      },
      {
        "label": "overlay",
        "title": "",
        "width": 220,
        "height": 48,
        "decorations": false,
        "transparent": true,
        "alwaysOnTop": true,
        "resizable": false,
        "visible": false,       // Shown during recording
        "skipTaskbar": true,
        "focus": false
      }
    ],
    "trayIcon": {
      "iconPath": "icons/tray-idle.png",
      "tooltip": "Groq Voice"
    }
  },
  "plugins": {
    "global-shortcut": {},
    "clipboard-manager": {},
    "notification": {},
    "store": {}
  }
}
```

---

## 3. Phase 2 — Rust Core Engine

### Step 2.1: App State (`state.rs`)

A shared state struct managed by Tauri, accessible from all commands:

```
AppState {
    recording: AtomicBool,          // Is currently recording?
    processing: AtomicBool,         // Is API call in progress?
    audio_buffer: Mutex<Vec<f32>>,  // Live audio samples
    audio_levels: Mutex<Vec<f32>>,  // Smoothed levels for UI (16 bars)
    settings: Mutex<Settings>,      // Current settings
    db: Mutex<Connection>,          // SQLite connection
    http_client: reqwest::Client,   // Reusable HTTP client
}
```

### Step 2.2: Audio Recorder (`audio/recorder.rs`)

```
Functions:
  - start_recording(state) → Result<()>
      Opens default input device via cpal
      Spawns stream callback that pushes samples to audio_buffer
      
  - stop_recording(state) → Result<Vec<u8>>
      Stops cpal stream
      Returns raw PCM samples from audio_buffer
      Clears buffer
      
  - get_audio_levels(state) → Vec<f32>
      Returns current 16-bar audio levels (for waveform UI)
      Computed from recent samples using RMS
      
Configuration:
  - Sample rate: 16000 Hz (what Whisper expects)
  - Channels: 1 (mono)
  - Format: f32
```

### Step 2.3: Audio Encoder (`audio/encoder.rs`)

```
Functions:
  - encode_to_ogg(pcm_samples: &[f32], sample_rate: u32) → Result<Vec<u8>>
      Converts f32 PCM → i16
      Creates Opus encoder (mono, 16kHz)
      Wraps in OGG container
      Returns compressed bytes
      
  - encode_to_wav(pcm_samples: &[f32], sample_rate: u32) → Result<Vec<u8>>
      Fallback: creates WAV in memory using hound
      Returns WAV bytes

Expected compression: ~10x (1MB WAV → ~100KB OGG)
```

### Step 2.4: API Client (`api/client.rs`)

```
HttpClient {
    client: reqwest::Client,    // Connection pooling, keep-alive
    base_url: String,
    api_key: String,
}

Functions:
  - new(api_key) → HttpClient
      Creates client with:
        - 30s timeout
        - Connection pool
        - rustls TLS (no OpenSSL dependency)
        
  - transcribe(audio_bytes, format, language, model) → Result<TranscriptionResult>
      POST /openai/v1/audio/transcriptions
      Multipart form upload
      Retries: 3 attempts with exponential backoff (1s, 2s, 4s)
      Handles 429 (rate limit) → try fallback model
      Handles network errors → offline state
      
  - enhance(text, system_prompt, model) → Result<String>
      POST /openai/v1/chat/completions
      JSON body
      Strips <think> tags from response
      Retries: 2 attempts
      Fallback chain: tries models in speed order
```

### Step 2.5: Transcription Flow (`api/transcription.rs`)

```
Full pipeline:
  1. Receive raw PCM samples
  2. Encode → OGG/Opus (or WAV fallback)
  3. POST to Groq Whisper (whisper-large-v3-turbo)
  4. If 429 → retry with whisper-large-v3
  5. If AI enhance enabled:
     a. Load prompt for current style
     b. Try models in fallback order
     c. Strip <think> tags
  6. Return TranscriptionResult { raw_text, enhanced_text, model_used, duration }
```

### Step 2.6: Enhancement Module (`api/enhancement.rs`)

```
Fallback chain (speed-ordered):
  1. llama-3.1-8b-instant        (~0.3s)
  2. llama-4-scout-17b           (~0.5s)
  3. qwen3-32b                   (~0.8s)
  4. llama-3.3-70b-versatile     (~1.5s)
  5. gpt-oss-20b (+ web search)  (~2s)
  6. gpt-oss-120b (+ web search) (~3s)

Browser search: enabled only for "assistant" style + GPT-OSS models
Temperature: 0.1 (strict/professional/minimal) or 0.7 (assistant)
```

### Step 2.7: Input Simulation (`input/`)

```
clipboard.rs:
  - copy_to_clipboard(text: &str) → Result<()>
      Uses tauri-plugin-clipboard-manager
      
autotype.rs:
  - paste_at_cursor() → Result<()>
      Uses enigo crate
      Linux: Ctrl+V
      macOS: Cmd+V
      Windows: Ctrl+V
      Includes 50ms delay after clipboard write (race condition prevention)
```

### Step 2.8: Settings (`config/settings.rs`)

```rust
struct Settings {
    // API
    api_key: String,
    
    // Transcription
    language: String,           // "en", "ar", "" (auto)
    
    // AI Enhancement
    ai_enabled: bool,
    ai_style: AiStyle,         // Enum: Strict, Professional, Minimal, FormalArabic, Assistant, Clarify
    ai_model: String,          // "auto" or specific model ID
    
    // Hotkey
    hotkey: String,             // e.g., "CmdOrCtrl+Shift+Z"
    
    // UI
    overlay_enabled: bool,
    sound_enabled: bool,
    
    // Network
    timeout_seconds: u32,       // Default: 20
    max_retries: u32,           // Default: 3
}

Persistence: tauri-plugin-store (JSON file in app data dir)
```

### Step 2.9: History Store (`history/store.rs`)

```sql
CREATE TABLE IF NOT EXISTS transcriptions (
    id TEXT PRIMARY KEY,           -- UUID
    created_at TEXT NOT NULL,      -- ISO 8601
    language TEXT,
    raw_text TEXT NOT NULL,
    enhanced_text TEXT,
    ai_style TEXT,
    ai_model TEXT,
    whisper_model TEXT,
    duration_ms INTEGER,           -- Recording duration
    audio_size_bytes INTEGER       -- Compressed audio size
);

CREATE INDEX idx_created_at ON transcriptions(created_at DESC);
CREATE INDEX idx_language ON transcriptions(language);
```

```
Functions:
  - init_db(app_data_dir) → Result<Connection>
  - insert(entry: TranscriptionEntry) → Result<()>
  - list(limit, offset, search_query) → Result<Vec<TranscriptionEntry>>
  - delete(id) → Result<()>
  - clear_all() → Result<()>
  - get_stats() → Result<Stats>   // Total count, word count, time saved
```

### Step 2.10: System Tray (`tray.rs`)

```
Tray States:
  🟢 Idle    → tray-idle.png
  🔴 Recording → tray-recording.png  (or animated)
  🟡 Processing → tray-processing.png

Tray Menu:
  ┌──────────────────────┐
  │ Groq Voice           │
  │ ─────────────────    │
  │ Status: Idle         │
  │ ─────────────────    │
  │ Start Recording      │
  │ Settings...          │
  │ History...           │
  │ ─────────────────    │
  │ Quit                 │
  └──────────────────────┘
  
Clicking tray icon: toggles recording (same as hotkey)
```

### Step 2.11: Prompts (`config/prompts.rs`)

```
- Reads .txt files from bundled resources (included at compile time)
- Supports 6 styles: strict, professional, minimal, formal_arabic, assistant, clarify
- Files embedded via include_str! macro or Tauri resource system
- Function: get_prompt(style: AiStyle) → &str
```

---

## 4. Phase 3 — Frontend UI

### Step 3.1: Design System

```css
/* Theme: Dark mode, modern, glassmorphism hints */
:root {
    --bg-primary: #0a0a0a;
    --bg-secondary: #141414;
    --bg-card: #1a1a1a;
    --bg-hover: #222222;
    --border: #2a2a2a;
    --border-active: #3a3a3a;
    --text-primary: #ffffff;
    --text-secondary: #888888;
    --text-muted: #555555;
    --accent: #10b981;          /* Emerald green */
    --accent-hover: #059669;
    --danger: #ef4444;
    --warning: #f59e0b;
    --radius-sm: 6px;
    --radius-md: 10px;
    --radius-lg: 16px;
    --font: 'Inter', -apple-system, sans-serif;
}
```

### Step 3.2: Settings Page Layout

```
┌─────────────────────────────────────────┐
│  ⚙️  Groq Voice Settings               │
├─────────────────────────────────────────┤
│                                         │
│  🔑 API Key                             │
│  ┌─────────────────────────────┐        │
│  │ gsk_••••••••••••••••••••••  │  👁    │
│  └─────────────────────────────┘        │
│                                         │
│  ─────────────────────────────────      │
│                                         │
│  🌍 Language                            │
│  ┌─────────────────────────────┐        │
│  │ English                    ▼ │        │
│  └─────────────────────────────┘        │
│                                         │
│  ─────────────────────────────────      │
│                                         │
│  🤖 AI Enhancement           [  ON  ]   │
│                                         │
│  Style                                  │
│  ┌────┐┌─────────┐┌────────┐           │
│  │Strict│Professional│Minimal│ ...       │
│  └────┘└─────────┘└────────┘           │
│                                         │
│  Model                                  │
│  ┌─────────────────────────────┐        │
│  │ 🔄 Auto (Fallback Chain)  ▼ │        │
│  └─────────────────────────────┘        │
│                                         │
│  ─────────────────────────────────      │
│                                         │
│  ⌨️  Hotkey                              │
│  ┌─────────────────────────────┐        │
│  │ Ctrl+Shift+Alt+Z    [Edit]  │        │
│  └─────────────────────────────┘        │
│                                         │
│  ─────────────────────────────────      │
│                                         │
│  🔊 Sound Effects            [  ON  ]   │
│  🖥  Overlay                  [  ON  ]   │
│                                         │
│  ─────────────────────────────────      │
│                                         │
│  📜 History              [View All →]   │
│  Last: "Hello world..." — 2 min ago     │
│                                         │
│  ─────────────────────────────────      │
│  v1.0.0          Groq Voice ❤️           │
└─────────────────────────────────────────┘
```

### Step 3.3: History Page Layout

```
┌─────────────────────────────────────────┐
│  ← Back    📜 History                   │
├─────────────────────────────────────────┤
│  🔍 Search transcriptions...            │
│  ─────────────────────────────────      │
│                                         │
│  Today                                  │
│  ┌─────────────────────────────────┐    │
│  │ 14:32  "The meeting is at 3pm"  │    │
│  │ 🦙 Llama 4 • Strict • en       │    │
│  │                        📋  🗑   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 13:15  "أهلاً بالعالم"          │    │
│  │ 🧠 Qwen3 • فصحى • ar           │    │
│  │                        📋  🗑   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Yesterday                              │
│  ┌─────────────────────────────────┐    │
│  │ 09:45  "Send the report..."     │    │
│  │ ⚡ GPT-OSS • Professional • en  │    │
│  │                        📋  🗑   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ─────────────────────────────────      │
│  📊 Total: 142 transcriptions           │
│  🗑  Clear All                          │
└─────────────────────────────────────────┘
```

### Step 3.4: Component Details

| Component | Props / State | Behavior |
|---|---|---|
| `LanguageSelect` | `value`, `onChange` | Dropdown with 32+ languages + "Auto" |
| `AIConfig` | `enabled`, `style`, `model` | Toggle + style chips + model dropdown |
| `ModelPicker` | `value`, `onChange` | Dropdown showing model name + emoji + features |
| `HotkeyConfig` | `hotkey`, `onRecord` | Click to record new hotkey combination |
| `HistoryList` | `entries[]`, `onCopy`, `onDelete` | Virtualized list grouped by date |
| `SearchBar` | `query`, `onChange` | Debounced search input |
| `Toggle` | `value`, `onChange`, `label` | iOS-style toggle switch |
| `StatusBadge` | `status` | Colored dot (green/red/yellow) |

---

## 5. Phase 4 — Overlay Window

### Step 4.1: Overlay Design

```
Recording Mode:
┌─────────────────────────────────────┐
│  ▍▎▌▊█▊▌▎▍▏ ▍▎▌▊█    0:05         │
│     [waveform bars]      [timer]    │
└─────────────────────────────────────┘

Processing Mode:
┌─────────────────────────────────────┐
│  ▍▎▌▊█▊▌▎▍▏ ▍▎▌▊█    ⟳            │
│     [bars freeze]      [spinner]    │
└─────────────────────────────────────┘

Error Mode:
┌─────────────────────────────────────┐
│     ⚠ Check your network           │
└─────────────────────────────────────┘

Visual specs:   
  - Shape: Pill (rounded rectangle with semicircle ends)
  - Background: #0a0a0a at 85% opacity
  - Border: 2px white, subtle glow
  - Bars: 16 vertical bars, white, 3px wide, rounded caps
  - Position: Bottom-center, 150px from bottom
  - Animation: morph from circle → pill on appear, reverse on dismiss
```

### Step 4.2: Overlay Implementation Strategy

- **Separate Tauri window** (`label: "overlay"`) with `transparent: true`, `decorations: false`, `alwaysOnTop: true`, `skipTaskbar: true`, `focus: false`
- **Canvas-based rendering** in React for smooth waveform animation (requestAnimationFrame)
- **Audio levels** streamed from Rust backend via Tauri events (not polling)
- **State transitions** communicated via Tauri events:
  - `recording-started` → show overlay with waveform + timer
  - `processing-started` → switch to spinner
  - `transcription-complete` → success animation → hide
  - `transcription-error` → error state → hide after 2s

### Step 4.3: Overlay Communication (Events)

```typescript
// Rust → Frontend events
"audio-levels"        → { levels: number[] }       // 16 floats, ~20fps
"recording-started"   → {}
"processing-started"  → {}
"transcription-done"  → { text: string, enhanced: boolean }
"transcription-error" → { message: string, is_offline: boolean }
"overlay-show"        → {}
"overlay-hide"        → {}
```

---

## 6. Phase 5 — Integration & Polish

### Step 5.1: Full Recording Flow (State Machine)

```
        ┌──────────┐
        │   IDLE   │ ← Tray: 🟢
        └────┬─────┘
             │ hotkey pressed
             ▼
        ┌──────────┐
        │RECORDING │ ← Tray: 🔴, Overlay: waveform+timer, sound plays
        └────┬─────┘
             │ hotkey pressed again
             ▼
    ┌────────────────┐
    │   PROCESSING   │ ← Tray: 🟡, Overlay: spinner
    └────┬───────┬───┘
         │       │
    success    error
         │       │
         ▼       ▼
    ┌────────┐ ┌───────┐
    │ PASTING│ │ ERROR │ ← Overlay: error message, notification
    └────┬───┘ └───┬───┘
         │         │
         ▼         ▼
        ┌──────────┐
        │   IDLE   │ ← Sound plays (success), overlay dismisses
        └──────────┘
```

### Step 5.2: Network Resilience

```
Retry Strategy:
  Attempt 1: immediate
  Attempt 2: wait 1s
  Attempt 3: wait 2s
  
429 (Rate Limit):
  → Switch to fallback model (turbo → full)
  → If AI enhance also 429'd → try next model in chain
  
Connection Error:
  → Set offline state
  → Show error overlay ("Check your network")
  → Notification: "Groq Voice: Connection failed"
  → Don't retry (user can re-trigger manually)
  
Timeout:
  → 20s for transcription
  → 15s for AI enhancement
  → 3s connect timeout
```

### Step 5.3: Sound Effects

```
Events that play sounds:
  - Recording start → short blip
  - Transcription success → confirmation tone
  
Implementation: rodio crate playing bundled .oga/.ogg files
```

### Step 5.4: Error Handling Strategy

```rust
#[derive(thiserror::Error, Debug)]
enum AppError {
    #[error("API key not configured")]
    NoApiKey,
    
    #[error("Audio device not available: {0}")]
    AudioDevice(String),
    
    #[error("Recording too short (minimum 0.5s)")]
    RecordingTooShort,
    
    #[error("Transcription failed: {0}")]
    TranscriptionFailed(String),
    
    #[error("Rate limited on all models")]
    AllModelsRateLimited,
    
    #[error("Network error: {0}")]
    NetworkError(String),
    
    #[error("No speech detected")]
    NoSpeechDetected,
    
    #[error("Database error: {0}")]
    DatabaseError(String),
}

// All errors are serialized and sent to frontend for UI display
impl serde::Serialize for AppError { ... }
```

### Step 5.5: Migrate AI Prompts

```
Current: data/prompts/*.txt (6 files)
Target:  Embedded in Rust binary via include_str!()

prompts.rs:
  const PROMPT_STRICT: &str = include_str!("../../data/prompts/strict.txt");
  const PROMPT_PROFESSIONAL: &str = include_str!("../../data/prompts/professional.txt");
  // ... etc
  
  pub fn get_prompt(style: AiStyle) -> &'static str {
      match style {
          AiStyle::Strict => PROMPT_STRICT,
          AiStyle::Professional => PROMPT_PROFESSIONAL,
          // ...
      }
  }
```

---

## 7. Phase 6 — Cross-Platform Build & Release

### Step 6.1: Build Configuration

```bash
# Development
cd app
npm run tauri dev

# Production builds
npm run tauri build           # Current platform
npm run tauri build -- --target x86_64-unknown-linux-gnu       # Linux
npm run tauri build -- --target x86_64-apple-darwin             # macOS Intel  
npm run tauri build -- --target aarch64-apple-darwin            # macOS ARM
npm run tauri build -- --target x86_64-pc-windows-msvc          # Windows
```

### Step 6.2: Platform-Specific Output

| Platform | Format | Expected Size |
|---|---|---|
| Linux | `.deb`, `.AppImage`, `.rpm` | ~8-12 MB |
| macOS | `.dmg`, `.app` | ~8-12 MB |
| Windows | `.msi`, `.exe` (NSIS) | ~8-12 MB |

### Step 6.3: Platform-Specific Considerations

```
Linux:
  - Test on GNOME (X11 + Wayland), KDE, Cinnamon
  - Global hotkeys via X11 (XGrabKey) or portal (Wayland)
  - System tray may need AppIndicator on some DEs
  
macOS:
  - App needs microphone permission (Info.plist)
  - Accessibility permission for auto-type (enigo)
  - Notarization for distribution
  - Handle Gatekeeper
  
Windows:
  - Admin might be needed for global hotkeys in some contexts
  - Antivirus may flag keyboard simulation (enigo) — sign the binary
  - Sound playback via WASAPI
```

---

## 8. Data Models

### TranscriptionEntry (Rust + TypeScript)

```rust
// Rust
#[derive(Serialize, Deserialize, Clone)]
pub struct TranscriptionEntry {
    pub id: String,              // UUID
    pub created_at: String,      // ISO 8601
    pub language: Option<String>,
    pub raw_text: String,
    pub enhanced_text: Option<String>,
    pub ai_style: Option<String>,
    pub ai_model: Option<String>,
    pub whisper_model: String,
    pub duration_ms: u64,
    pub audio_size_bytes: u64,
}
```

```typescript
// TypeScript
interface TranscriptionEntry {
    id: string;
    created_at: string;
    language?: string;
    raw_text: string;
    enhanced_text?: string;
    ai_style?: string;
    ai_model?: string;
    whisper_model: string;
    duration_ms: number;
    audio_size_bytes: number;
}
```

### Settings (Rust + TypeScript)

```rust
#[derive(Serialize, Deserialize, Clone)]
pub struct Settings {
    pub api_key: String,
    pub language: String,        // "" = auto
    pub ai_enabled: bool,
    pub ai_style: AiStyle,
    pub ai_model: String,        // "auto" or model ID
    pub hotkey: String,
    pub overlay_enabled: bool,
    pub sound_enabled: bool,
    pub timeout_seconds: u32,
    pub max_retries: u32,
}

#[derive(Serialize, Deserialize, Clone)]
pub enum AiStyle {
    Strict,
    Professional,
    Minimal,
    FormalArabic,
    Assistant,
    Clarify,
}
```

---

## 9. Rust ↔ Frontend Commands (IPC)

### Tauri Commands (Frontend → Rust)

| Command | Parameters | Returns | Description |
|---|---|---|---|
| `get_settings` | — | `Settings` | Load current settings |
| `save_settings` | `Settings` | `()` | Save settings to store |
| `start_recording` | — | `()` | Begin mic capture |
| `stop_recording` | — | `TranscriptionResult` | Stop, transcribe, enhance, paste |
| `toggle_recording` | — | `bool` | Toggle; returns `is_recording` |
| `get_audio_levels` | — | `Vec<f32>` | Current 16-bar waveform levels |
| `get_history` | `limit, offset, query` | `Vec<TranscriptionEntry>` | Search/list history |
| `delete_history` | `id` | `()` | Delete one entry |
| `clear_history` | — | `()` | Delete all entries |
| `copy_text` | `text` | `()` | Copy text to clipboard |
| `get_app_info` | — | `AppInfo` | Version, platform, etc. |

### Tauri Events (Rust → Frontend)

| Event | Payload | Description |
|---|---|---|
| `audio-levels` | `{ levels: f32[] }` | Real-time waveform data (~20fps) |
| `recording-state-changed` | `{ state: "idle" | "recording" | "processing" }` | State machine transition |
| `transcription-complete` | `TranscriptionEntry` | Success result |
| `transcription-error` | `{ message: string, is_offline: bool }` | Error details |
| `settings-changed` | `Settings` | Settings were updated |

---

## 10. File-by-File Breakdown

### Implementation Order (most critical path first)

```
Batch 1 — Skeleton (Everything compiles/runs)
  1.  src-tauri/src/main.rs          — Entry point
  2.  src-tauri/src/lib.rs           — Plugin registration + command list
  3.  src-tauri/src/state.rs         — AppState struct
  4.  src-tauri/src/errors.rs        — Error types
  5.  src-tauri/tauri.conf.json      — Window + plugin config
  6.  src/App.tsx                    — Basic router (settings / history)
  7.  src/styles/global.css          — Design system tokens

Batch 2 — Settings (Config works end-to-end)
  8.  src-tauri/src/config/settings.rs  — Settings struct + load/save
  9.  src-tauri/src/config/prompts.rs   — Prompt embedding
  10. src/pages/SettingsPage.tsx         — Settings UI
  11. src/components/settings/*          — All settings components
  12. src/hooks/useSettings.ts           — Settings hook
  13. src/lib/commands.ts                — Typed invoke wrappers

Batch 3 — Audio (Recording works)
  14. src-tauri/src/audio/recorder.rs    — cpal recording
  15. src-tauri/src/audio/encoder.rs     — OGG/Opus encoding
  16. src-tauri/src/audio/levels.rs      — RMS level computation

Batch 4 — API (Transcription works)
  17. src-tauri/src/api/client.rs        — HTTP client + retry
  18. src-tauri/src/api/models.rs        — Model definitions
  19. src-tauri/src/api/transcription.rs — Whisper API call
  20. src-tauri/src/api/enhancement.rs   — Chat API call

Batch 5 — Input (Auto-paste works)
  21. src-tauri/src/input/clipboard.rs   — Clipboard write
  22. src-tauri/src/input/autotype.rs    — Ctrl+V simulation

Batch 6 — Overlay (Visual feedback works)
  23. src/components/overlay/*           — Overlay components
  24. src/hooks/useAudioLevels.ts        — Audio level streaming
  25. src/hooks/useRecording.ts          — Recording state machine

Batch 7 — System integration
  26. src-tauri/src/tray.rs              — System tray
  27. src-tauri/src/history/store.rs     — SQLite CRUD
  28. src/pages/HistoryPage.tsx          — History UI
  29. src/components/history/*           — History components
  30. src/hooks/useHistory.ts            — History hook

Batch 8 — Polish
  31. Sound effects integration
  32. Hotkey configuration UI
  33. Import from legacy history.md
  34. App icons for all platforms
  35. Final CSS polish + animations
```

---

## Quick Reference: Current Bash → Tauri Mapping

| Current File | → Tauri Replacement |
|---|---|
| `groq-voice-to-text.sh` (recording) | `audio/recorder.rs` + `audio/encoder.rs` |
| `groq-voice-to-text.sh` (API call) | `api/transcription.rs` + `api/client.rs` |
| `groq-voice-to-text.sh` (clipboard/paste) | `input/clipboard.rs` + `input/autotype.rs` |
| `groq-voice-to-text.sh` (overlay IPC) | Tauri events (no tmp files) |
| `ai-enhance.sh` | `api/enhancement.rs` + `config/prompts.rs` |
| `select-language.sh` | `pages/SettingsPage.tsx` + `config/settings.rs` |
| `setup.sh` | Not needed (dependencies bundled in binary) |
| `src/overlay/*.py` | `components/overlay/*` (React + Canvas) |
| `data/prompts/*.txt` | `include_str!()` in `config/prompts.rs` |
| `.env` file | `tauri-plugin-store` (JSON in app data dir) |
| `history.md` | SQLite via `history/store.rs` |

---

> [!IMPORTANT]  
> **Legacy scripts stay untouched.** The Tauri app lives in `app/` alongside the existing code. Both can coexist until the desktop app is fully ready.
