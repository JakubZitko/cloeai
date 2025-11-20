//
//  ContextEngine.swift
//  Cloe
//
//  Screen context monitoring and analysis
//

import Foundation
import AppKit
import Vision
import Combine

struct ScreenContext {
    let appName: String
    let windowTitle: String
    let appIcon: String
    let timestamp: Date
    let screenContent: String?
    let uiElements: [UIElement]?

    struct UIElement {
        let type: String
        let label: String
        let position: CGRect
    }
}

class ContextEngine {
    static let shared = ContextEngine()

    // MARK: - Properties

    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private var lastContext: ScreenContext?
    private var contextHistory: [ScreenContext] = []

    private let maxHistorySize = 100
    private let monitoringInterval: TimeInterval = 5.0 // Check every 5 seconds

    // Publishers
    private let contextSubject = PassthroughSubject<ScreenContext, Never>()
    var contextPublisher: AnyPublisher<ScreenContext, Never> {
        contextSubject.eraseToAnyPublisher()
    }

    private init() {}

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        print("👁️ Context monitoring started")
        isMonitoring = true

        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: monitoringInterval,
            repeats: true
        ) { [weak self] _ in
            self?.captureContext()
        }

        // Capture immediately
        captureContext()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        print("🛑 Context monitoring stopped")
        isMonitoring = false

        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    // MARK: - Context Capture

    private func captureContext() {
        Task {
            do {
                let context = try await getCurrentContext()

                // Check if context has significantly changed
                if hasContextChanged(newContext: context) {
                    await MainActor.run {
                        self.lastContext = context
                        self.contextHistory.append(context)

                        // Trim history if needed
                        if self.contextHistory.count > self.maxHistorySize {
                            self.contextHistory.removeFirst()
                        }

                        // Notify subscribers
                        self.contextSubject.send(context)

                        print("📍 Context updated: \(context.appName) - \(context.windowTitle)")
                    }
                }
            } catch {
                print("❌ Context capture error: \(error)")
            }
        }
    }

    func getCurrentContext() async throws -> ScreenContext {
        // Get active application
        let activeApp = NSWorkspace.shared.frontmostApplication

        let appName = activeApp?.localizedName ?? "Unknown"
        let bundleID = activeApp?.bundleIdentifier ?? ""

        // Get active window info
        let windowInfo = getActiveWindowInfo()

        // Capture screen content (if permission granted)
        let screenContent = try? await captureScreenContent()

        return ScreenContext(
            appName: appName,
            windowTitle: windowInfo.title,
            appIcon: getAppIcon(for: bundleID),
            timestamp: Date(),
            screenContent: screenContent,
            uiElements: nil // TODO: Implement UI element detection
        )
    }

    // MARK: - Screen Capture

    private func captureScreenContent() async throws -> String? {
        // Check if we have screen recording permission
        guard PermissionManager.shared.checkScreenRecordingPermission() == .granted else {
            return nil
        }

        // Capture screen using ScreenCaptureKit (macOS 12.3+)
        if #available(macOS 12.3, *) {
            return try await captureWithScreenCaptureKit()
        } else {
            // Fallback to CGWindowListCreateImage
            return try await captureWithCGWindow()
        }
    }

    @available(macOS 12.3, *)
    private func captureWithScreenCaptureKit() async throws -> String? {
        // TODO: Implement ScreenCaptureKit capture
        // For now, use fallback
        return try await captureWithCGWindow()
    }

    private func captureWithCGWindow() async throws -> String? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        // Get window list for active app
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]

        guard let windows = windowList else { return nil }

        // Find active window
        for window in windows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == activeApp.processIdentifier,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  windowLayer == 0 else { // Normal window layer
                continue
            }

            // Get window ID
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            // Capture window image
            guard let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .bestResolution]
            ) else {
                continue
            }

            // Convert to NSImage and perform OCR
            let nsImage = NSImage(cgImage: image, size: .zero)
            return try await performOCR(on: nsImage)
        }

        return nil
    }

    // MARK: - OCR

    private func performOCR(on image: NSImage) async throws -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract text from observations
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: recognizedText.isEmpty ? nil : recognizedText)
            }

            // Configure OCR request
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Window Info

    private func getActiveWindowInfo() -> (title: String, bounds: CGRect) {
        var windowTitle = ""
        var windowBounds = CGRect.zero

        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]

            if let windows = windows {
                for window in windows {
                    guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                          ownerPID == activeApp.processIdentifier else {
                        continue
                    }

                    if let title = window[kCGWindowName as String] as? String {
                        windowTitle = title
                    }

                    if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                        windowBounds = CGRect(
                            x: bounds["X"] ?? 0,
                            y: bounds["Y"] ?? 0,
                            width: bounds["Width"] ?? 0,
                            height: bounds["Height"] ?? 0
                        )
                    }

                    break
                }
            }
        }

        return (windowTitle, windowBounds)
    }

    // MARK: - Utilities

    private func getAppIcon(for bundleID: String) -> String {
        // Map common apps to SF Symbols
        let iconMap: [String: String] = [
            "com.apple.Safari": "safari",
            "com.google.Chrome": "globe",
            "com.apple.mail": "envelope",
            "com.apple.iCal": "calendar",
            "com.apple.finder": "folder",
            "com.microsoft.VSCode": "chevron.left.forwardslash.chevron.right",
            "com.apple.Notes": "note.text",
            "com.apple.TextEdit": "doc.text"
        ]

        return iconMap[bundleID] ?? "app.fill"
    }

    private func hasContextChanged(newContext: ScreenContext) -> Bool {
        guard let last = lastContext else { return true }

        // Context has changed if app or window is different
        return last.appName != newContext.appName ||
               last.windowTitle != newContext.windowTitle
    }

    // MARK: - Context History

    func getRecentContexts(limit: Int = 10) -> [ScreenContext] {
        return Array(contextHistory.suffix(limit))
    }

    func findContext(appName: String) -> [ScreenContext] {
        return contextHistory.filter { $0.appName.lowercased().contains(appName.lowercased()) }
    }

    func clearHistory() {
        contextHistory.removeAll()
        lastContext = nil
    }
}

// MARK: - NSImage Extension

extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
