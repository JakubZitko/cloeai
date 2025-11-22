//
//  CloeApp.swift
//  Cloe - Your AI Assistant
//
//  Main application entry point
//  Integrates all systems: UI, Learning, Night Worker, Screen Control
//

import SwiftUI
import AppKit

@main
struct CloeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - we use programmatic windows
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var notchWindow: NotchWindow?
    var hotKeyMonitor: HotKeyMonitor?

    // Core systems
    var permissionManager: PermissionManager?
    var contextEngine: ContextEngine?
    var agentRuntime: AgentRuntime?
    var learningEngine: LearningEngine?
    var nightWorker: NightWorker?
    var screenController: ScreenController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("""

        ╔═══════════════════════════════════════╗
        ║           🧠 CLOE AI                  ║
        ║      Your Personal AI Assistant       ║
        ╚═══════════════════════════════════════╝

        """)

        // Hide from dock (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core components in order
        setupPermissionManager()
        setupCoreEngines()
        setupMenuBar()
        setupHotKey()
        setupAutonomousMode()

        print("✅ Cloe is ready!")
        print("   Press Cmd+Shift+Space to activate")
        print("   Or click the menu bar icon")
        print("")

        // Show welcome notification if first launch
        if isFirstLaunch() {
            showWelcomeFlow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Cloe is shutting down...")
        cleanupResources()
    }

    // MARK: - Setup Methods

    private func setupPermissionManager() {
        permissionManager = PermissionManager.shared

        // Check all required permissions
        permissionManager?.checkAllPermissions()

        // These are critical for Cloe to work
        print("📋 Permission Status:")
        print("   • Screen Recording: \(permissionManager?.hasScreenRecordingPermission ?? false ? "✓" : "✗")")
        print("   • Accessibility: \(permissionManager?.hasAccessibilityPermission ?? false ? "✓" : "✗")")
    }

    private func setupCoreEngines() {
        // Context Engine - watches what's on screen
        contextEngine = ContextEngine.shared
        contextEngine?.startMonitoring()
        print("👁 Context Engine: Active")

        // Learning Engine - learns from user behavior
        learningEngine = LearningEngine.shared
        learningEngine?.startObserving()
        print("🧠 Learning Engine: Active")

        // Screen Controller - for executing actions
        screenController = ScreenController.shared
        print("🖱 Screen Controller: Ready")

        // Agent Runtime - AI brain
        agentRuntime = AgentRuntime.shared
        agentRuntime?.initialize()
        print("🤖 Agent Runtime: Ready")

        // Night Worker - autonomous task completion
        nightWorker = NightWorker.shared
        print("🌙 Night Worker: Ready")
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Custom Cloe icon
            let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "Cloe")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(menuBarClicked)
            button.target = self

            // Add "Cloe" text
            button.title = " Cloe"
            button.imagePosition = .imageLeft
        }

        updateMenuBarIcon(state: .idle)
    }

    private func setupHotKey() {
        hotKeyMonitor = HotKeyMonitor()

        // Cmd+Shift+Space to toggle Cloe
        hotKeyMonitor?.registerHotKey(keyCode: 49, modifiers: [.command, .shift]) { [weak self] in
            self?.toggleNotch()
        }
        print("⌨️ Hotkey registered: Cmd+Shift+Space")
    }

    private func setupAutonomousMode() {
        // Check if autonomous mode is enabled
        let autonomousEnabled = UserDefaults.standard.bool(forKey: "autonomousModeEnabled")

        if autonomousEnabled {
            // Check if it's night time (10pm - 6am)
            let hour = Calendar.current.component(.hour, from: Date())
            if hour >= 22 || hour < 6 {
                nightWorker?.startNightMode()
                updateMenuBarIcon(state: .autonomous)
            }
        }

        // Schedule night mode check
        scheduleNightModeCheck()
    }

    private func scheduleNightModeCheck() {
        // Check every hour if we should enter/exit night mode
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let autonomousEnabled = UserDefaults.standard.bool(forKey: "autonomousModeEnabled")
            let hour = Calendar.current.component(.hour, from: Date())

            if autonomousEnabled && (hour >= 22 || hour < 6) {
                self.nightWorker?.startNightMode()
                self.updateMenuBarIcon(state: .autonomous)
            } else {
                self.nightWorker?.stopNightMode()
                self.updateMenuBarIcon(state: .idle)
            }
        }
    }

    // MARK: - Actions

    @objc private func menuBarClicked() {
        showMenuBarMenu()
    }

    private func toggleNotch() {
        if notchWindow == nil || !notchWindow!.isVisible {
            showNotch()
        } else {
            hideNotch()
        }
    }

    private func showNotch() {
        if notchWindow == nil {
            notchWindow = NotchWindow()
        }

        notchWindow?.show()
        updateMenuBarIcon(state: .active)
    }

    private func hideNotch() {
        notchWindow?.collapse()
        notchWindow?.hide()
        updateMenuBarIcon(state: .idle)
    }

    private func showMenuBarMenu() {
        let menu = NSMenu()

        // Status header
        let headerItem = NSMenuItem(title: "🧠 Cloe AI Assistant", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Today's summary
        let tasks = nightWorker?.getTodaysTasks() ?? []
        let completed = tasks.filter { $0.status == .completed }.count
        let pending = tasks.filter { $0.status == .pending || $0.status == .scheduled }.count

        let statsItem = NSMenuItem(title: "📊 Today: \(completed) done, \(pending) pending", action: nil, keyEquivalent: "")
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        // Learning status
        let learningItem = NSMenuItem(title: "🧠 Learning from your workflow...", action: nil, keyEquivalent: "")
        learningItem.isEnabled = false
        menu.addItem(learningItem)

        menu.addItem(NSMenuItem.separator())

        // Actions
        let openItem = NSMenuItem(title: "Open Cloe", action: #selector(openCloeAction), keyEquivalent: " ")
        openItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(openItem)

        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Activity Log", action: #selector(openActivityLog), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "What I've Learned", action: #selector(showLearned), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Position submenu
        let positionMenu = NSMenu()
        for position in NotchPosition.allCases {
            let item = NSMenuItem(title: position.displayName, action: #selector(setNotchPosition(_:)), keyEquivalent: "")
            item.representedObject = position
            item.state = notchWindow?.position == position ? .on : .off
            positionMenu.addItem(item)
        }
        let positionItem = NSMenuItem(title: "Notch Position", action: nil, keyEquivalent: "")
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(NSMenuItem.separator())

        // Autonomous mode toggle
        let autonomousItem = NSMenuItem(title: "Night Mode (Autonomous)", action: #selector(toggleAutonomousMode), keyEquivalent: "")
        autonomousItem.state = UserDefaults.standard.bool(forKey: "autonomousModeEnabled") ? .on : .off
        menu.addItem(autonomousItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit Cloe", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)

        // Remove menu after it's shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.statusItem?.menu = nil
        }
    }

    @objc private func openCloeAction() {
        toggleNotch()
    }

    @objc private func openSettings() {
        // Open settings window
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func openActivityLog() {
        // TODO: Implement activity log window
        print("Opening activity log...")
    }

    @objc private func showLearned() {
        // TODO: Show what Cloe has learned
        print("Showing learned patterns...")
    }

    @objc private func setNotchPosition(_ sender: NSMenuItem) {
        if let position = sender.representedObject as? NotchPosition {
            notchWindow?.position = position
        }
    }

    @objc private func toggleAutonomousMode() {
        let currentState = UserDefaults.standard.bool(forKey: "autonomousModeEnabled")
        UserDefaults.standard.set(!currentState, forKey: "autonomousModeEnabled")

        if !currentState {
            print("🌙 Autonomous mode: ENABLED")
            print("   Cloe will complete unfinished tasks overnight")
        } else {
            print("☀️ Autonomous mode: DISABLED")
            nightWorker?.stopNightMode()
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Menu Bar Icon States

    enum MenuBarState {
        case idle, active, processing, error, autonomous
    }

    private func updateMenuBarIcon(state: MenuBarState) {
        guard let button = statusItem?.button else { return }

        let iconName: String
        let title: String

        switch state {
        case .idle:
            iconName = "brain.head.profile"
            title = " Cloe"
        case .active:
            iconName = "brain.head.profile.fill"
            title = " Cloe"
        case .processing:
            iconName = "brain"
            title = " Thinking..."
        case .error:
            iconName = "exclamationmark.triangle.fill"
            title = " Error"
        case .autonomous:
            iconName = "moon.fill"
            title = " Cloe 🌙"
        }

        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Cloe")
        image?.isTemplate = true
        button.image = image
        button.title = title
    }

    // MARK: - Utilities

    private func isFirstLaunch() -> Bool {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            return true
        }
        return false
    }

    private func showWelcomeFlow() {
        print("""

        👋 Welcome to Cloe!

        Cloe needs a few permissions to work:
        • Screen Recording - to see what you're working on
        • Accessibility - to help you navigate and execute tasks

        These permissions are used ONLY on your device.
        Nothing is sent to any server without your action.

        """)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.permissionManager?.requestAllPermissions()
        }
    }

    private func cleanupResources() {
        contextEngine?.stopMonitoring()
        learningEngine?.stopObserving()
        nightWorker?.stopNightMode()
        hotKeyMonitor?.unregisterAllHotKeys()
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("autonomousModeEnabled") private var autonomousMode = false
    @AppStorage("notchPosition") private var notchPosition = "top"
    @AppStorage("openaiApiKey") private var openaiKey = ""

    var body: some View {
        TabView {
            // General Settings
            Form {
                Section("Appearance") {
                    Picker("Notch Position", selection: $notchPosition) {
                        Text("Top").tag("top")
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                    }
                }

                Section("Behavior") {
                    Toggle("Enable Night Mode (Autonomous)", isOn: $autonomousMode)
                    Text("When enabled, Cloe will complete unfinished tasks overnight while respecting social boundaries (won't message people at inappropriate times).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // API Keys
            Form {
                Section("AI Provider") {
                    SecureField("OpenAI API Key", text: $openaiKey)
                    Text("Get your API key from platform.openai.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .tabItem {
                Label("API Keys", systemImage: "key")
            }

            // Permissions
            Form {
                Section("Required Permissions") {
                    HStack {
                        Text("Screen Recording")
                        Spacer()
                        Text(PermissionManager.shared.hasScreenRecordingPermission ? "✓ Granted" : "✗ Required")
                            .foregroundColor(PermissionManager.shared.hasScreenRecordingPermission ? .green : .red)
                    }

                    HStack {
                        Text("Accessibility")
                        Spacer()
                        Text(PermissionManager.shared.hasAccessibilityPermission ? "✓ Granted" : "✗ Required")
                            .foregroundColor(PermissionManager.shared.hasAccessibilityPermission ? .green : .red)
                    }

                    Button("Open System Preferences") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
                    }
                }
            }
            .padding()
            .tabItem {
                Label("Permissions", systemImage: "lock.shield")
            }
        }
        .frame(width: 450, height: 300)
    }
}
