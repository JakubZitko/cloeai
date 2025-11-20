# Building Cloe from Source

This guide will help you build and run Cloe AI Assistant on your macOS system.

## Prerequisites

### System Requirements
- **macOS**: 12.0 (Monterey) or later
- **Xcode**: 14.0 or later (includes Swift 5.9+)
- **Command Line Tools**: `xcode-select --install`

### API Keys
You'll need at least one of these:
- OpenAI API key ([get one here](https://platform.openai.com/api-keys))
- Anthropic Claude API key ([get one here](https://console.anthropic.com/))

## Quick Start

### Option 1: Build with Swift Package Manager (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/cloeai.git
cd cloeai

# 2. Set up environment variables
export OPENAI_API_KEY="sk-your-key-here"
# OR
export CLAUDE_API_KEY="sk-ant-your-key-here"

# 3. Build the project
swift build -c release

# 4. Run Cloe
./.build/release/Cloe
```

### Option 2: Build with Xcode

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/cloeai.git
cd cloeai

# 2. Generate Xcode project
swift package generate-xcodeproj

# 3. Open in Xcode
open Cloe.xcodeproj
```

Then in Xcode:
1. Select the "Cloe" scheme
2. Set your development team in **Signing & Capabilities**
3. Build and run (⌘R)

## Configuration

### API Keys

Cloe looks for API keys in this order:

1. **Environment variables** (recommended for development):
   ```bash
   export OPENAI_API_KEY="your-key"
   export CLAUDE_API_KEY="your-key"
   ```

2. **Config file** (create `~/.config/cloe/config.json`):
   ```json
   {
     "openai_api_key": "sk-...",
     "claude_api_key": "sk-ant-...",
     "default_provider": "openai"
   }
   ```

3. **Settings UI** (after first launch):
   - Open Cloe → Settings → AI Configuration
   - Enter your API key

### Permissions

On first launch, Cloe will request permissions. Grant these in **System Settings > Privacy & Security**:

#### Required Permissions:
- ✅ **Screen Recording** - Understand context from your screen
- ✅ **Accessibility** - Control other applications
- ✅ **Microphone** - Voice commands

#### Optional Permissions:
- 📅 **Calendar** - Create and manage events
- 📧 **Automation** - Send emails via AppleScript
- 📁 **Files & Folders** - Full file system access

**Important**: Some features won't work without these permissions.

## Development Setup

### 1. Install Dependencies

Cloe uses only native macOS frameworks, so no external dependencies are required. However, for development, you might want:

```bash
# Install SwiftLint (optional, for code quality)
brew install swiftlint

# Install SwiftFormat (optional)
brew install swiftformat
```

### 2. Project Structure

```
Cloe/
├── Sources/              # Swift source files
│   ├── App/             # Main app entry point
│   ├── UI/              # User interface
│   ├── Core/            # Core logic (Context, Agent, Memory)
│   ├── Tools/           # Tool implementations
│   └── Utils/           # Utilities
├── Resources/           # Resources (Info.plist, entitlements)
├── Tests/               # Unit tests
└── Package.swift        # Swift Package Manager manifest
```

### 3. Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter CloeTests.testContextEngine

# Run with coverage
swift test --enable-code-coverage
```

### 4. Debugging

#### Using Xcode Debugger:
1. Open `Cloe.xcodeproj`
2. Set breakpoints in source files
3. Run with ⌘R
4. Debug output appears in Console

#### Using Print Debugging:
Cloe includes extensive logging:
```swift
print("🚀 Cloe is starting...")     // App lifecycle
print("📝 Processing input: ...")   // User input
print("🧠 LLM Chat - ...")          // AI processing
print("⚡ Executing action: ...")   // Tool execution
```

#### Checking Logs:
```bash
# View app logs
log stream --predicate 'processImagePath contains "Cloe"' --info

# Or use Console.app
open -a Console.app
```

## Building for Distribution

### Option 1: Direct Distribution (Full Features)

Build a standalone app bundle:

```bash
# 1. Build release version
swift build -c release

# 2. Create app bundle
./scripts/create-app-bundle.sh

# 3. Sign the app (optional)
codesign --sign "Developer ID Application: Your Name" --deep Cloe.app

# 4. Create DMG
hdiutil create -volname "Cloe" -srcfolder Cloe.app -ov -format UDZO Cloe.dmg
```

### Option 2: Mac App Store Distribution (Sandboxed)

**Note**: Some features will be limited due to App Store sandboxing restrictions.

1. Enable sandboxing in `Cloe.entitlements`:
   ```xml
   <key>com.apple.security.app-sandbox</key>
   <true/>
   ```

2. Request specific entitlements for needed features

3. Build and archive in Xcode:
   - Product → Archive
   - Distribute App → App Store Connect

## Troubleshooting

### Build Errors

#### "Swift Package Manager failed to resolve dependencies"
```bash
# Clear package cache
rm -rf .build
swift package reset
swift build
```

#### "Code signing failed"
- Go to Xcode → Preferences → Accounts
- Add your Apple ID
- Select your team in project settings

#### "Missing OpenAI/Claude API key"
- Set environment variable: `export OPENAI_API_KEY="sk-..."`
- Or configure in Settings after first launch

### Runtime Issues

#### "Screen recording permission denied"
1. Go to System Settings → Privacy & Security → Screen Recording
2. Enable Cloe
3. Restart Cloe

#### "Microphone not working"
1. System Settings → Privacy & Security → Microphone
2. Enable Cloe
3. Restart Cloe

#### "AppleScript automation fails"
1. System Settings → Privacy & Security → Automation
2. Enable Cloe → System Events
3. Enable Cloe → Mail (for email features)

#### "LLM API errors"
- Check API key is valid
- Verify internet connection
- Check OpenAI/Anthropic status page

### Performance Issues

#### "High CPU usage"
- Screen monitoring interval can be adjusted in code
- Disable autonomous mode if not needed
- Check for runaway LLM requests in logs

#### "High memory usage"
- Clear spatial memory: Settings → Privacy → Clear All Memory
- Reduce context history limit in code

## Advanced Configuration

### Customizing Hotkeys

Edit `Cloe/Sources/App/CloeApp.swift`:

```swift
// Change from Cmd+Shift+Space to your preferred key
hotKeyMonitor?.registerHotKey(
    keyCode: 49,  // Space
    modifiers: [.command, .shift]
)
```

### Customizing Monitoring Interval

Edit `Cloe/Sources/Core/ContextEngine/ContextEngine.swift`:

```swift
// Change from 5 seconds to your preference
private let monitoringInterval: TimeInterval = 5.0
```

### Adding Custom Tools

Create a new tool in `Cloe/Sources/Tools/`:

```swift
class MyCustomTool: Tool {
    let name = "my_tool"
    let description = "What my tool does"
    let parameters = [...]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        // Implementation
    }
}
```

Register in `AgentRuntime.swift`:

```swift
private func registerTools() {
    toolRegistry.register(FileSystemTool())
    toolRegistry.register(MyCustomTool())  // Add your tool
}
```

## Environment Variables Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API key | Yes (or Claude) |
| `CLAUDE_API_KEY` | Anthropic Claude API key | Yes (or OpenAI) |
| `CLOE_LOG_LEVEL` | Logging level: debug, info, warn, error | No (default: info) |
| `CLOE_DB_PATH` | Custom database path | No |
| `CLOE_DISABLE_MONITORING` | Disable screen monitoring | No |

## Next Steps

After building successfully:

1. **Configure API Keys**: Settings → AI Configuration
2. **Grant Permissions**: Allow screen recording, accessibility, etc.
3. **Try Basic Commands**: "Find file presentation", "What's on my screen?"
4. **Enable Autonomous Mode**: Menu Bar → Autonomous Mode

## Need Help?

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/yourusername/cloeai/issues)
- 💬 [Discussions](https://github.com/yourusername/cloeai/discussions)
- 📧 Email: hello@cloe.ai

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

---

**Happy Building!** 🚀
