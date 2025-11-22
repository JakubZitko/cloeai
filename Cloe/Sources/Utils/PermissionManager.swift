//
//  PermissionManager.swift
//  Cloe
//
//  Manages macOS permissions (Screen Recording, Accessibility, etc.)
//

import Foundation
import AppKit
import AVFoundation
import EventKit

class PermissionManager {
    static let shared = PermissionManager()

    enum PermissionType {
        case screenRecording
        case accessibility
        case microphone
        case calendar
        case automation

        var displayName: String {
            switch self {
            case .screenRecording: return "Screen Recording"
            case .accessibility: return "Accessibility"
            case .microphone: return "Microphone"
            case .calendar: return "Calendar"
            case .automation: return "Automation"
            }
        }
    }

    enum PermissionStatus {
        case granted
        case denied
        case notDetermined
        case restricted
    }

    private init() {}

    // MARK: - Permission Checking

    func checkAllPermissions() {
        print("[LOCK] Checking all permissions...")

        let screenRecording = checkScreenRecordingPermission()
        let accessibility = checkAccessibilityPermission()
        let microphone = checkMicrophonePermission()
        let calendar = checkCalendarPermission()

        print("  Screen Recording: \(screenRecording)")
        print("  Accessibility: \(accessibility)")
        print("  Microphone: \(microphone)")
        print("  Calendar: \(calendar)")
    }

    func checkScreenRecordingPermission() -> PermissionStatus {
        // macOS 10.15+ screen recording permission
        if #available(macOS 10.15, *) {
            // Try to get screen content to test permission
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]

            if let windows = windows, !windows.isEmpty {
                // Check if we can actually read window titles
                let hasAccess = windows.contains { window in
                    if let ownerName = window[kCGWindowOwnerName as String] as? String,
                       !ownerName.isEmpty {
                        return true
                    }
                    return false
                }
                return hasAccess ? .granted : .denied
            }
            return .denied
        }
        return .granted
    }

    func checkAccessibilityPermission() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return trusted ? .granted : .denied
    }

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    func checkCalendarPermission() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    // MARK: - Permission Requesting

    func requestAllPermissions() {
        print("[LIST] Requesting all permissions...")

        requestScreenRecordingPermission()
        requestAccessibilityPermission()
        requestMicrophonePermission()
        requestCalendarPermission()
    }

    func requestScreenRecordingPermission() {
        let status = checkScreenRecordingPermission()

        if status != .granted {
            showPermissionAlert(
                title: "Screen Recording Permission Required",
                message: """
                Cloe needs permission to view your screen to:
                • Understand context from active windows
                • Extract text and information
                • Provide intelligent assistance

                Please grant Screen Recording permission in System Settings.
                """,
                settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            )
        }
    }

    func requestAccessibilityPermission() {
        let status = checkAccessibilityPermission()

        if status != .granted {
            showPermissionAlert(
                title: "Accessibility Permission Required",
                message: """
                Cloe needs Accessibility permission to:
                • Control other applications
                • Automate tasks
                • Interact with UI elements

                Please grant Accessibility permission in System Settings.
                """,
                settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )

            // Also trigger the system prompt
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }

    func requestMicrophonePermission() {
        let status = checkMicrophonePermission()

        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("[MIC] Microphone permission: \(granted ? "granted" : "denied")")
                }
            }
        } else if status == .denied {
            showPermissionAlert(
                title: "Microphone Permission Required",
                message: """
                Cloe needs Microphone permission to:
                • Accept voice commands
                • Transcribe meetings
                • Provide voice-based assistance

                Please grant Microphone permission in System Settings.
                """,
                settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
        }
    }

    func requestCalendarPermission() {
        let status = checkCalendarPermission()

        if status == .notDetermined {
            let eventStore = EKEventStore()
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("[ERROR] Calendar permission error: \(error)")
                    } else {
                        print("[CAL] Calendar permission: \(granted ? "granted" : "denied")")
                    }
                }
            }
        } else if status == .denied {
            showPermissionAlert(
                title: "Calendar Permission Required",
                message: """
                Cloe needs Calendar permission to:
                • Create and manage events
                • Check your schedule
                • Send meeting reminders

                Please grant Calendar permission in System Settings.
                """,
                settingsPath: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
            )
        }
    }

    // MARK: - Permission Alerts

    private func showPermissionAlert(title: String, message: String, settingsPath: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if let url = URL(string: settingsPath) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Permission Utilities

    func hasAllRequiredPermissions() -> Bool {
        let required: [PermissionType] = [
            .screenRecording,
            .accessibility,
            .microphone
        ]

        return required.allSatisfy { type in
            switch type {
            case .screenRecording:
                return checkScreenRecordingPermission() == .granted
            case .accessibility:
                return checkAccessibilityPermission() == .granted
            case .microphone:
                return checkMicrophonePermission() == .granted
            case .calendar:
                return checkCalendarPermission() == .granted
            case .automation:
                return true // Handled differently
            }
        }
    }

    func getMissingPermissions() -> [PermissionType] {
        var missing: [PermissionType] = []

        if checkScreenRecordingPermission() != .granted {
            missing.append(.screenRecording)
        }
        if checkAccessibilityPermission() != .granted {
            missing.append(.accessibility)
        }
        if checkMicrophonePermission() != .granted {
            missing.append(.microphone)
        }

        return missing
    }
}
