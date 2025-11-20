//
//  ScreenCaptureTool.swift
//  Cloe
//
//  Screen capture and OCR
//

import Foundation
import AppKit

class ScreenCaptureTool: Tool {
    let name = "screen_capture"
    let description = "Capture screen content and extract text"

    let parameters = [
        ToolParameter(name: "action", type: "string", description: "Action: capture, ocr", required: true),
        ToolParameter(name: "save_path", type: "string", description: "Path to save screenshot", required: false)
    ]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let action = parameters["action"] as? String else {
            throw ToolError.missingParameter("action")
        }

        switch action {
        case "capture":
            return try await captureScreen(savePath: parameters["save_path"] as? String)
        case "ocr":
            return try await performOCR()
        default:
            throw ToolError.invalidParameter("action", value: action)
        }
    }

    // MARK: - Screen Capture

    private func captureScreen(savePath: String?) async throws -> ToolResult {
        // Check permission
        guard PermissionManager.shared.checkScreenRecordingPermission() == .granted else {
            throw ScreenCaptureError.permissionDenied
        }

        // Capture main screen
        guard let screen = NSScreen.main,
              let image = CGWindowListCreateImage(
                  screen.frame,
                  .optionOnScreenOnly,
                  kCGNullWindowID,
                  [.bestResolution, .boundsIgnoreFraming]
              ) else {
            throw ScreenCaptureError.captureFailed
        }

        let nsImage = NSImage(cgImage: image, size: screen.frame.size)

        // Save if path provided
        if let savePath = savePath {
            try saveImage(nsImage, to: savePath)
        }

        return ToolResult(
            success: true,
            message: "Screen captured successfully",
            data: savePath != nil ? ["path": savePath!] : nil
        )
    }

    private func performOCR() async throws -> ToolResult {
        // Capture screen and perform OCR
        guard PermissionManager.shared.checkScreenRecordingPermission() == .granted else {
            throw ScreenCaptureError.permissionDenied
        }

        let context = try await ContextEngine.shared.getCurrentContext()

        guard let screenContent = context.screenContent else {
            throw ScreenCaptureError.ocrFailed
        }

        return ToolResult(
            success: true,
            message: "Extracted text from screen",
            data: [
                "text": screenContent,
                "app": context.appName,
                "window": context.windowTitle
            ]
        )
    }

    // MARK: - Utilities

    private func saveImage(_ image: NSImage, to path: String) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.saveFailed
        }

        let url = URL(fileURLWithPath: path)
        try pngData.write(to: url)
    }
}

// MARK: - Errors

enum ScreenCaptureError: Error {
    case permissionDenied
    case captureFailed
    case ocrFailed
    case saveFailed
}

extension ScreenCaptureError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied"
        case .captureFailed:
            return "Failed to capture screen"
        case .ocrFailed:
            return "Failed to extract text from screen"
        case .saveFailed:
            return "Failed to save screenshot"
        }
    }
}
