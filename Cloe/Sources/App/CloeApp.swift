//
//  CloeApp.swift
//  Cloe - Your AI Assistant
//
//  Main application entry point
//

import SwiftUI
import AppKit

@main
struct CloeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene - we use programmatic windows
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var overlayWindow: OverlayWindow?
    var hotKeyMonitor: HotKeyMonitor?
    var permissionManager: PermissionManager?
    var contextEngine: ContextEngine?
    var agentRuntime: AgentRuntime?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Cloe is starting...")

        // Hide from dock (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Initialize core components
        setupPermissionManager()
        setupMenuBar()
        setupHotKey()
        setupContextEngine()
        setupAgentRuntime()

        print("✅ Cloe is ready!")

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
        permissionManager?.checkAllPermissions()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Cloe")
            button.action = #selector(menuBarClicked)
            button.target = self
        }

        updateMenuBarIcon(state: .idle)
    }

    private func setupHotKey() {
        hotKeyMonitor = HotKeyMonitor()
        hotKeyMonitor?.registerHotKey(keyCode: 49, modifiers: [.command, .shift]) { [weak self] in
            self?.toggleOverlay()
        }
    }

    private func setupContextEngine() {
        contextEngine = ContextEngine.shared
        contextEngine?.startMonitoring()
    }

    private func setupAgentRuntime() {
        agentRuntime = AgentRuntime.shared
        agentRuntime?.initialize()
    }

    // MARK: - Actions

    @objc private func menuBarClicked() {
        showMenuBarMenu()
    }

    private func toggleOverlay() {
        if overlayWindow == nil || !overlayWindow!.isVisible {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private func showOverlay() {
        if overlayWindow == nil {
            overlayWindow = OverlayWindow()
        }

        overlayWindow?.show()
        overlayWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        updateMenuBarIcon(state: .active)
    }

    private func hideOverlay() {
        overlayWindow?.hide()
        updateMenuBarIcon(state: .idle)
    }

    private func showMenuBarMenu() {
        let menu = NSMenu()

        // Status
        let statusItem = NSMenuItem(title: "Cloe AI Assistant", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Tasks summary
        let tasksItem = NSMenuItem(title: "✅ 3 tasks completed today", action: nil, keyEquivalent: "")
        tasksItem.isEnabled = false
        menu.addItem(tasksItem)

        let scheduledItem = NSMenuItem(title: "⏳ 2 tasks scheduled", action: nil, keyEquivalent: "")
        scheduledItem.isEnabled = false
        menu.addItem(scheduledItem)

        menu.addItem(NSMenuItem.separator())

        // Actions
        menu.addItem(NSMenuItem(title: "💬 Open Cloe", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "⚙️ Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "📊 Activity Log", action: #selector(openActivityLog), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // Autonomous mode toggle
        let autonomousItem = NSMenuItem(title: "🌙 Autonomous Mode", action: #selector(toggleAutonomousMode), keyEquivalent: "")
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

    @objc private func openSettings() {
        // TODO: Implement settings window
        print("Opening settings...")
    }

    @objc private func openActivityLog() {
        // TODO: Implement activity log window
        print("Opening activity log...")
    }

    @objc private func toggleAutonomousMode() {
        let currentState = UserDefaults.standard.bool(forKey: "autonomousModeEnabled")
        UserDefaults.standard.set(!currentState, forKey: "autonomousModeEnabled")
        print("Autonomous mode: \(!currentState ? "ON" : "OFF")")
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

        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Cloe")
        case .active:
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Cloe Active")
        case .processing:
            button.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Processing")
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Error")
        case .autonomous:
            button.image = NSImage(systemSymbolName: "moon.fill", accessibilityDescription: "Autonomous Mode")
        }
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
        // TODO: Implement welcome/onboarding flow
        print("👋 Welcome to Cloe! Let's set up your permissions...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.permissionManager?.requestAllPermissions()
        }
    }

    private func cleanupResources() {
        contextEngine?.stopMonitoring()
        hotKeyMonitor?.unregisterAllHotKeys()
    }
}
