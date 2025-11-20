# Cloe AI Assistant

<div align="center">

**Your intelligent AI assistant for macOS - learns your workflow, automates tasks, and works while you sleep**

[Features](#features) • [Architecture](#architecture) • [Getting Started](#getting-started) • [Usage](#usage) • [Development](#development)

</div>

---

## Overview

Cloe is a native macOS AI assistant that goes beyond simple chatbots. It learns from your workflow, remembers where things are across your apps, and can autonomously complete tasks while you're away.

### Key Differentiators

- **Context-Aware Learning**: Watches your workflow patterns and remembers where files, emails, and conversations live across apps
- **Spatial Memory Graph**: Knows "Mr. Johnson" is in Gmail, not just Contacts
- **Autonomous Execution**: Works overnight to finish incomplete tasks with smart timing guardrails
- **Native macOS Integration**: Deep integration with ScreenCaptureKit, AppleScript, Accessibility APIs
- **Self-Aware**: Knows its limitations (e.g., "I'm not a designer" → searches for templates)

---

## Features

### Core Capabilities

#### 🎯 **Intelligent Automation**
- Send emails by voice or text
- Create calendar events with natural language
- Find and organize files across your system
- Search the web and extract information
- Create presentations and documents

#### 🧠 **Context & Memory**
- **Screen Analysis**: OCR and UI element detection to understand what you're doing
- **Workflow Learning**: Watches you perform tasks and automates them next time
- **Spatial Memory**: Remembers where people, files, and data live across apps
- **Long-term Learning**: Adapts to your preferences and communication style

#### 🌙 **Autonomous Mode**
- Works while you sleep or are away
- Smart timing rules (won't message mom at 3am)
- Morning summary of completed tasks
- Waits for approval on sensitive actions

#### 🎤 **Multi-Modal Input**
- Voice commands via Speech framework
- Text input with context awareness
- Global hotkey activation (Cmd+Shift+Space)
- Menu bar quick access

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     USER INTERFACE                           │
│  • Overlay Window (SwiftUI)                                 │
│  • Menu Bar Icon                                            │
│  • Settings Panel                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    CONTEXT ENGINE                            │
│  • Screen capture & OCR (Vision framework)                  │
│  • Active window tracking                                   │
│  • Continuous context monitoring                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    AI AGENT RUNTIME                          │
│  • LLM Orchestrator (OpenAI/Claude)                         │
│  • Task Planner & Executor                                  │
│  • Tool Registry                                            │
│  • Autonomous Scheduler                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    TOOL LAYER                                │
│  • File System (Spotlight integration)                      │
│  • Calendar (EventKit)                                      │
│  • Email (AppleScript → Mail.app)                           │
│  • Web Search                                               │
│  • Screen Capture                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY & STORAGE                          │
│  • Spatial Memory Graph (SQLite)                            │
│  • Vector Embeddings (future: ChromaDB)                     │
│  • Task Queue Persistence                                   │
└─────────────────────────────────────────────────────────────┘
```

### Tech Stack

**Frontend:**
- Swift 5.9+
- SwiftUI for native macOS UI
- AppKit for window management

**Backend:**
- Swift for core logic
- SQLite for persistent storage
- OpenAI GPT-4 / Anthropic Claude (primary LLMs)

**macOS Frameworks:**
- ScreenCaptureKit - Screen monitoring
- Vision - OCR & text extraction
- Speech - Voice recognition
- EventKit - Calendar integration
- AppleScript - App automation

---

## Getting Started

### Prerequisites

- macOS 12.0 (Monterey) or later
- Xcode 14.0+ (for building from source)
- OpenAI API key or Anthropic Claude API key

### Installation

#### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/cloeai.git
cd cloeai

# Set up API keys
export OPENAI_API_KEY="your-key-here"
# OR
export CLAUDE_API_KEY="your-key-here"

# Build with Swift Package Manager
swift build -c release

# Run
.build/release/Cloe
```

#### Option 2: Xcode

1. Open `Cloe.xcodeproj` in Xcode
2. Set your development team in Signing & Capabilities
3. Build and run (⌘R)

### Configuration

On first launch, Cloe will request necessary permissions:

1. **Screen Recording** - To understand context from your screen
2. **Accessibility** - To control other applications
3. **Microphone** - For voice commands
4. **Calendar** - To manage events
5. **Automation** - To run AppleScripts

Grant these permissions in System Settings > Privacy & Security.

---

## Usage

### Basic Commands

**Activate Cloe:**
- Press `Cmd+Shift+Space` (global hotkey)
- Click menu bar icon
- Say "Hey Cloe" (if enabled)

**Example Commands:**

```
🎤 "Send email to Mr. Johnson about the contract status"
→ Finds Mr. Johnson in Gmail, drafts contextual email

🎤 "Find my presentation about renewable energy"
→ Searches files via Spotlight, opens result

🎤 "Create a meeting with the team tomorrow at 2pm"
→ Creates calendar event with smart scheduling

🎤 "What's on my screen?"
→ Performs OCR and analyzes visible content

🎤 "Create a presentation about AI trends for next week"
→ Searches for templates, gathers data, creates slides
```

### Autonomous Mode

**How it works:**

1. Enable in Menu Bar → Autonomous Mode
2. Cloe monitors for idle time (2+ hours) or night hours (10pm-6am)
3. Processes pending tasks with smart guardrails
4. Presents morning summary when you return

**Smart Timing Rules:**
- Won't send messages between 10pm-7am
- Won't message family outside 8am-9pm
- Waits for approval on financial/destructive actions
- Schedules appropriate tasks for work hours

**Morning Summary Example:**

```
Good morning! 🌅

Overnight, I completed:
✅ Finished Q4 presentation (added 3 slides)
✅ Organized Downloads folder (archived 47 files)

Waiting for your approval:
⏳ Email to Mr. Johnson (draft ready, will send at 9am)
⏳ Calendar event for team meeting

[View Details] [Approve All]
```

---

## Architecture Details

### Context Engine

**Screen Monitoring:**
- Captures active window every 5 seconds (when significant change detected)
- OCR via Vision framework extracts text
- Builds timeline of user activities

**Spatial Memory:**
- Entity graph: People, files, projects, tasks
- Location tracking: "Mr. Johnson" → Gmail (Safari)
- Workflow patterns: Email sending, file organization

**Learning Mechanism:**
1. User performs action manually
2. Cloe observes: App → Action → Outcome
3. Stores workflow pattern
4. Next time: Recalls and executes automatically

### AI Agent Runtime

**LLM Integration:**
- Primary: OpenAI GPT-4 Turbo
- Fallback: Claude 3.5 Sonnet
- Future: Local LLM support (Llama 3 via Ollama)

**Prompt Engineering:**
```
System: You are Cloe, a proactive AI assistant...

Context:
- App: Safari
- Window: Gmail - Mr. Johnson
- Screen: [OCR text]

User: "Send email to Mr. Johnson"

Response:
{
  "reasoning": "User wants to email Mr. Johnson...",
  "plan": ["find_contact", "draft_email", "send"],
  "tool_calls": [...]
}
```

**Tool Execution:**
- Sequential or parallel execution
- Error handling with retries
- Confirmation for sensitive actions

### Task Scheduler

**Autonomous Processing:**

```swift
func canExecuteTask(_ task: ScheduledTask) -> Bool {
    // 1. Check if autonomous execution allowed
    guard task.canRunAutonomously else { return false }

    // 2. Check smart timing
    let hour = Calendar.current.component(.hour, from: Date())

    if task.involvesMessaging {
        if hour >= 22 || hour <= 7 {
            return false  // Quiet hours
        }
    }

    // 3. Check scheduled time
    if let scheduledTime = task.scheduledTime {
        guard Date() >= scheduledTime else { return false }
    }

    return true
}
```

---

## Development

### Project Structure

```
Cloe/
├── Sources/
│   ├── App/
│   │   └── CloeApp.swift                 # Main entry point
│   ├── UI/
│   │   ├── Overlay/                      # Overlay window
│   │   ├── MenuBar/                      # Menu bar UI
│   │   └── Settings/                     # Settings panel
│   ├── Core/
│   │   ├── ContextEngine/                # Screen analysis
│   │   ├── AgentRuntime/                 # AI orchestration
│   │   ├── Memory/                       # Spatial memory
│   │   └── VoiceInputManager.swift       # Speech recognition
│   ├── Tools/
│   │   ├── FileSystem/                   # File operations
│   │   ├── Calendar/                     # EventKit integration
│   │   ├── Email/                        # Email automation
│   │   ├── Browser/                      # Web search
│   │   └── ScreenCapture/                # Screen capture
│   └── Utils/
│       ├── HotKeyMonitor.swift           # Global hotkeys
│       └── PermissionManager.swift       # Permission handling
├── Resources/
│   ├── Info.plist
│   └── Cloe.entitlements
├── Tests/
└── Package.swift
```

### Adding New Tools

```swift
class MyCustomTool: Tool {
    let name = "my_tool"
    let description = "What this tool does"

    let parameters = [
        ToolParameter(name: "param1", type: "string", description: "...", required: true)
    ]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        // Implementation
        return ToolResult(success: true, message: "Done", data: nil)
    }
}

// Register in AgentRuntime:
toolRegistry.register(MyCustomTool())
```

### Testing

```bash
# Run tests
swift test

# Run specific test
swift test --filter CloeTests.testContextEngine

# Build and run
swift run Cloe
```

---

## Privacy & Security

**Data Storage:**
- All data stored locally in `~/Library/Application Support/Cloe/`
- SQLite database encrypted at rest (AES-256)
- Screenshots auto-deleted after 24 hours
- No cloud sync by default

**Permission Controls:**
- Explicit user consent for all permissions
- Pause learning button in menu bar
- Activity log shows all actions
- Clear memory option in settings

**Sensitive Data Protection:**
- Never captures password fields
- Skips private browsing windows
- Pattern detection for credit cards, SSNs
- Auto-redaction of sensitive content

---

## Roadmap

### Phase 1: MVP ✅
- [x] Basic overlay UI
- [x] Voice & text input
- [x] Screen context capture
- [x] File search & calendar integration
- [x] Permission management

### Phase 2: Intelligence 🚧
- [x] Spatial memory graph
- [x] Email automation
- [x] Web search integration
- [ ] Presentation creation (in progress)
- [ ] Multi-step task execution

### Phase 3: Autonomy 📅
- [x] Autonomous scheduler
- [x] Smart timing rules
- [ ] Morning summary notifications
- [ ] Learning from corrections
- [ ] Undo stack for actions

### Phase 4: Advanced Features 🔮
- [ ] Team workflows & sharing
- [ ] Visual workflow builder
- [ ] Enterprise security features
- [ ] iOS companion app
- [ ] Browser extension

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Inspired by:
- [Dimension.dev](https://dimension.dev) - AI agent architecture
- Cluely, Otter.ai, Granola - Meeting assistants
- Apple's Human Interface Guidelines

Built with:
- OpenAI GPT-4
- Anthropic Claude
- macOS native frameworks

---

## Contact

- GitHub: [@yourusername](https://github.com/yourusername)
- Email: hello@cloe.ai
- Twitter: [@cloeai](https://twitter.com/cloeai)

---

<div align="center">

**Made with ❤️ for productivity enthusiasts**

</div>
