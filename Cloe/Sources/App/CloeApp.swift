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
    var activityLogWindow: NSWindow?
    var learnedPatternsWindow: NSWindow?

    // Core systems
    var permissionManager: PermissionManager?
    var contextEngine: ContextEngine?
    var agentRuntime: AgentRuntime?
    var learningEngine: LearningEngine?
    var nightWorker: NightWorker?
    var screenController: ScreenController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("""

        ============================================
                       CLOE AI
              Your Personal AI Assistant
        ============================================

        """)

        // Hide from dock (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core components in order
        setupPermissionManager()
        setupCoreEngines()
        setupMenuBar()
        setupHotKey()
        setupAutonomousMode()

        print("[OK] Cloe is ready!")
        print("   Press Cmd+Shift+Space to activate")
        print("   Or click the menu bar icon")
        print("")

        // Show welcome notification if first launch
        if isFirstLaunch() {
            showWelcomeFlow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("[INFO] Cloe is shutting down...")
        cleanupResources()
    }

    // MARK: - Setup Methods

    private func setupPermissionManager() {
        permissionManager = PermissionManager.shared

        // Check all required permissions
        permissionManager?.checkAllPermissions()

        // These are critical for Cloe to work
        print("[PERMISSIONS] Status:")
        print("   - Screen Recording: \(permissionManager?.hasScreenRecordingPermission ?? false ? "OK" : "MISSING")")
        print("   - Accessibility: \(permissionManager?.hasAccessibilityPermission ?? false ? "OK" : "MISSING")")
    }

    private func setupCoreEngines() {
        // Context Engine - watches what's on screen
        contextEngine = ContextEngine.shared
        contextEngine?.startMonitoring()
        print("[CONTEXT] Context Engine: Active")

        // Learning Engine - learns from user behavior
        learningEngine = LearningEngine.shared
        learningEngine?.startObserving()
        print("[LEARNING] Learning Engine: Active")

        // Screen Controller - for executing actions
        screenController = ScreenController.shared
        print("[SCREEN] Screen Controller: Ready")

        // Agent Runtime - AI brain
        agentRuntime = AgentRuntime.shared
        agentRuntime?.initialize()
        print("[AGENT] Agent Runtime: Ready")

        // Night Worker - autonomous task completion
        nightWorker = NightWorker.shared
        print("[NIGHT] Night Worker: Ready")
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
        print("[HOTKEY] Registered: Cmd+Shift+Space")
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
        let headerItem = NSMenuItem(title: "Cloe AI Assistant", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // Today's summary
        let tasks = nightWorker?.getTodaysTasks() ?? []
        let completed = tasks.filter { $0.status == .completed }.count
        let pending = tasks.filter { $0.status == .pending || $0.status == .scheduled }.count

        let statsItem = NSMenuItem(title: "Today: \(completed) done, \(pending) pending", action: nil, keyEquivalent: "")
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        // Learning status
        let learningItem = NSMenuItem(title: "Learning from your workflow...", action: nil, keyEquivalent: "")
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
        if activityLogWindow == nil {
            let activityLogView = ActivityLogView()
            let hostingView = NSHostingView(rootView: activityLogView)

            activityLogWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            activityLogWindow?.title = "Cloe Activity Log"
            activityLogWindow?.contentView = hostingView
            activityLogWindow?.center()
            activityLogWindow?.isReleasedWhenClosed = false
        }

        activityLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showLearned() {
        if learnedPatternsWindow == nil {
            let learnedView = LearnedPatternsView()
            let hostingView = NSHostingView(rootView: learnedView)

            learnedPatternsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 550, height: 650),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            learnedPatternsWindow?.title = "What Cloe Has Learned"
            learnedPatternsWindow?.contentView = hostingView
            learnedPatternsWindow?.center()
            learnedPatternsWindow?.isReleasedWhenClosed = false
        }

        learnedPatternsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
            print("[AUTONOMOUS] Mode: ENABLED")
            print("   Cloe will complete unfinished tasks overnight")
        } else {
            print("[AUTONOMOUS] Mode: DISABLED")
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
            title = " Cloe [Night]"
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

        Welcome to Cloe!

        Cloe needs a few permissions to work:
        - Screen Recording - to see what you're working on
        - Accessibility - to help you navigate and execute tasks

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
                        Text(PermissionManager.shared.hasScreenRecordingPermission ? "OK Granted" : "FAIL Required")
                            .foregroundColor(PermissionManager.shared.hasScreenRecordingPermission ? .green : .red)
                    }

                    HStack {
                        Text("Accessibility")
                        Spacer()
                        Text(PermissionManager.shared.hasAccessibilityPermission ? "OK Granted" : "FAIL Required")
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

// MARK: - Activity Log View

struct ActivityLogView: View {
    @State private var actions: [LearningEngine.UserAction] = []
    @State private var selectedFilter: ActionFilter = .all

    enum ActionFilter: String, CaseIterable {
        case all = "All"
        case apps = "Apps"
        case files = "Files"
        case communication = "Communication"
    }

    var filteredActions: [LearningEngine.UserAction] {
        switch selectedFilter {
        case .all:
            return actions
        case .apps:
            return actions.filter { $0.type == .openApp || $0.type == .switchApp || $0.type == .closeApp }
        case .files:
            return actions.filter { $0.type == .openFile || $0.type == .saveFile }
        case .communication:
            return actions.filter { $0.type == .sendEmail || $0.type == .openURL }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
                Text("\(actions.count) actions recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Filter bar
            Picker("Filter", selection: $selectedFilter) {
                ForEach(ActionFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Action list
            if filteredActions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No activity recorded yet")
                        .font(.headline)
                    Text("Cloe learns from your actions over time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredActions, id: \.id) { action in
                    HStack(spacing: 12) {
                        Image(systemName: iconForAction(action.type))
                            .font(.system(size: 16))
                            .foregroundColor(colorForAction(action.type))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(descriptionForAction(action))
                                .font(.system(size: 13))
                            Text(action.app)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatTime(action.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            actions = LearningEngine.shared.getRecentActions()
        }
    }

    private func iconForAction(_ type: LearningEngine.UserAction.ActionType) -> String {
        switch type {
        case .openApp: return "app.badge.checkmark"
        case .closeApp: return "xmark.app"
        case .switchApp: return "arrow.left.arrow.right"
        case .openFile: return "doc"
        case .saveFile: return "doc.badge.arrow.up"
        case .copyText: return "doc.on.doc"
        case .pasteText: return "doc.on.clipboard"
        case .sendEmail: return "envelope"
        case .openURL: return "globe"
        case .search: return "magnifyingglass"
        }
    }

    private func colorForAction(_ type: LearningEngine.UserAction.ActionType) -> Color {
        switch type {
        case .openApp, .closeApp, .switchApp: return .blue
        case .openFile, .saveFile: return .orange
        case .copyText, .pasteText: return .purple
        case .sendEmail: return .green
        case .openURL: return .cyan
        case .search: return .gray
        }
    }

    private func descriptionForAction(_ action: LearningEngine.UserAction) -> String {
        switch action.type {
        case .openApp: return "Opened \(action.app)"
        case .closeApp: return "Closed \(action.app)"
        case .switchApp: return "Switched to \(action.target ?? action.app)"
        case .openFile: return "Opened \(action.target ?? "file")"
        case .saveFile: return "Saved \(action.target ?? "file")"
        case .copyText: return "Copied text"
        case .pasteText: return "Pasted text"
        case .sendEmail: return "Sent email to \(action.target ?? "recipient")"
        case .openURL: return "Visited \(action.target ?? "URL")"
        case .search: return "Searched: \(action.value ?? "...")"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Learned Patterns View

struct LearnedPatternsView: View {
    @State private var workflows: [LearningEngine.Workflow] = []
    @State private var contacts: [LearningEngine.Contact] = []
    @State private var stats: (actions: Int, contacts: Int, workflows: Int, apps: Int) = (0, 0, 0, 0)
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Stats header
            HStack(spacing: 20) {
                StatCard(title: "Actions", value: "\(stats.actions)", icon: "bolt.fill", color: .blue)
                StatCard(title: "Contacts", value: "\(stats.contacts)", icon: "person.2.fill", color: .green)
                StatCard(title: "Workflows", value: "\(stats.workflows)", icon: "arrow.triangle.branch", color: .orange)
                StatCard(title: "Apps", value: "\(stats.apps)", icon: "app.fill", color: .purple)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tab view
            Picker("", selection: $selectedTab) {
                Text("Workflows").tag(0)
                Text("Contacts").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if selectedTab == 0 {
                workflowsView
            } else {
                contactsView
            }
        }
        .onAppear {
            loadData()
        }
    }

    private var workflowsView: some View {
        Group {
            if workflows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No workflows learned yet")
                        .font(.headline)
                    Text("Cloe detects repeated patterns in your work")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(workflows) { workflow in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(workflow.name)
                                .font(.headline)
                            Spacer()
                            Text("Used \(workflow.frequency)x")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 4) {
                            ForEach(Array(workflow.steps.enumerated()), id: \.offset) { index, step in
                                if index > 0 {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(step.app)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        if !workflow.triggerPatterns.isEmpty {
                            Text("Triggers: \(workflow.triggerPatterns.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var contactsView: some View {
        Group {
            if contacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No contacts learned yet")
                        .font(.headline)
                    Text("Cloe remembers people you communicate with")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(contacts) { contact in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(contact.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.headline)

                            if let email = contact.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let relationship = contact.relationship {
                                Text(relationship)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        Spacer()

                        if let lastContact = contact.lastContact {
                            VStack(alignment: .trailing) {
                                Text("Last contact")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(formatDate(lastContact))
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func loadData() {
        workflows = LearningEngine.shared.getLearnedWorkflows()
        contacts = LearningEngine.shared.getLearnedContacts()
        stats = LearningEngine.shared.getStatistics()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
