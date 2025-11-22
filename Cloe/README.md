# Cloe AI - Your Personal macOS Assistant

Cloe is an intelligent AI assistant that lives on your Mac. She watches how you work, learns your patterns, and helps you accomplish tasks faster.

## Features

### 🧠 Context Awareness
- Sees what app you're using (Figma, Safari, VS Code, etc.)
- Reads text on screen via OCR
- Understands what you're working on

### 📚 Learning & Memory
- **Learns your workflows** - Watches how you do things and remembers
- **Remembers contacts** - "Send email to Mr Johnson" → Knows he's your lawyer in Gmail
- **Spatial memory** - Remembers where things are on your Mac

### 🎯 Action Execution
- **Takes over when asked** - Can click, type, navigate menus
- **Finds tutorials** - Searches web/YouTube if Cloe doesn't know how
- **Executes learned steps** - Automates repetitive tasks

### 🌙 Autonomous Night Mode
- Completes unfinished tasks while you sleep
- **Social awareness** - Won't text mom at 3am, waits until morning
- **Respects work hours** - Won't email boss on weekends
- **Checks if done** - If you already sent that message, marks task complete

### 🎨 Notch UI
- Clean, minimal interface that stays out of your way
- Position on top, left, or right of screen
- Expands when you need it, collapses when you don't

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0+
- OpenAI API key (for AI capabilities)

## Installation

### Option 1: Build from Source

```bash
cd Cloe

# Build with Swift Package Manager
swift build -c release

# Run
.build/release/Cloe
```

### Option 2: Xcode

1. Open `Cloe` folder in Xcode
2. File → Swift Packages → Resolve Package Versions
3. Select your Mac as target
4. Press Cmd+R to build and run

## Setup

### 1. Grant Permissions

Cloe needs these permissions to work:

- **Screen Recording** - To see what you're working on
- **Accessibility** - To click, type, and navigate apps

Go to: System Settings → Privacy & Security → Screen Recording / Accessibility

### 2. Add API Key

1. Open Cloe Settings (Cmd+,)
2. Go to "API Keys" tab
3. Enter your OpenAI API key

Get your key at: https://platform.openai.com/api-keys

## Usage

### Activate Cloe
- **Hotkey:** `Cmd + Shift + Space`
- **Menu bar:** Click the brain icon

### Example Commands

**In Figma:**
```
"How do I add a glass effect to this?"
"Add drop shadow to selected element"
"Create an auto layout"
```

**General:**
```
"Send email to Mr Johnson about the contract"
"Find a presentation template for tomorrow's meeting"
"Remind me to call mom at 5pm"
```

**Night Tasks:**
```
"Finish this later tonight"
"Send this email first thing tomorrow"
"Research competitors while I sleep"
```

## Architecture

```
Cloe/
├── Sources/
│   ├── App/
│   │   └── CloeApp.swift          # Main entry point
│   ├── UI/
│   │   ├── Notch/
│   │   │   └── NotchWindow.swift  # Notch-style overlay
│   │   └── Overlay/
│   │       └── OverlayWindow.swift # Legacy overlay
│   ├── Core/
│   │   ├── ContextEngine/         # Screen monitoring & OCR
│   │   ├── Learning/              # Pattern learning
│   │   ├── Memory/                # Spatial memory (SQLite)
│   │   ├── AgentRuntime/          # AI brain
│   │   ├── ScreenController/      # Mouse/keyboard automation
│   │   ├── UINavigator/           # App UI navigation
│   │   ├── TutorialFinder/        # Web search for tutorials
│   │   ├── ActionExecutor/        # Execute learned actions
│   │   └── NightWorker/           # Autonomous night mode
│   ├── Tools/                     # Integrations (Calendar, Email, etc.)
│   └── Utils/                     # Hotkeys, permissions
└── Package.swift
```

## Core Components

| Component | Purpose |
|-----------|---------|
| **ContextEngine** | Captures screen, runs OCR, tracks active apps |
| **LearningEngine** | Observes user behavior, learns patterns and contacts |
| **ScreenController** | Mouse clicks, keyboard input via CGEvent |
| **UINavigator** | Navigates app menus using Accessibility APIs |
| **TutorialFinder** | Searches Google/YouTube for how-to guides |
| **ActionExecutor** | Converts tutorial steps to automated actions |
| **NightWorker** | Autonomous overnight task completion |
| **SpatialMemory** | SQLite-based memory for entities and workflows |

## Privacy

- **100% local** - Cloe runs entirely on your Mac
- **No data sent** - Screen captures never leave your device
- **You control AI calls** - Only sends to OpenAI when you ask something
- **Clear permissions** - Only requests what's needed

## Configuration

### Notch Position
Change where Cloe appears:
- Menu bar → Notch Position → Top/Left/Right

### Night Mode
Enable autonomous task completion:
- Menu bar → Night Mode (Autonomous)

Or: Settings → General → Enable Night Mode

### Social Rules
Night Mode respects:
- **Message hours:** 8am - 10pm
- **Work hours:** 9am - 6pm (weekdays)
- **Close contacts:** Slightly more flexible timing
- **Work contacts:** Strictly business hours

## Troubleshooting

### Cloe can't see my screen
1. Go to System Settings → Privacy & Security
2. Enable Screen Recording for Cloe
3. Restart Cloe

### Cloe can't click/type
1. Go to System Settings → Privacy & Security
2. Enable Accessibility for Cloe
3. Restart Cloe

### AI not responding
1. Check your API key in Settings
2. Ensure you have internet connection
3. Check OpenAI API status

## License

MIT License - see LICENSE file

## Credits

Built with:
- SwiftUI & AppKit
- Vision framework (OCR)
- ScreenCaptureKit
- OpenAI GPT-4
