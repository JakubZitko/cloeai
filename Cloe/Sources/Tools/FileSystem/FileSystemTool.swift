//
//  FileSystemTool.swift
//  Cloe
//
//  File system operations (search, open, organize)
//

import Foundation
import AppKit

class FileSystemTool: Tool {
    let name = "file_system"
    let description = "Search for files, open files, organize files and folders"

    let parameters = [
        ToolParameter(name: "action", type: "string", description: "Action to perform: search, open, move, copy, delete", required: true),
        ToolParameter(name: "query", type: "string", description: "Search query or file name", required: false),
        ToolParameter(name: "path", type: "string", description: "File or folder path", required: false),
        ToolParameter(name: "destination", type: "string", description: "Destination path for move/copy operations", required: false)
    ]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let action = parameters["action"] as? String else {
            throw ToolError.missingParameter("action")
        }

        switch action {
        case "search":
            return try await searchFiles(query: parameters["query"] as? String)
        case "open":
            return try openFile(path: parameters["path"] as? String)
        case "move":
            return try moveFile(from: parameters["path"] as? String, to: parameters["destination"] as? String)
        case "copy":
            return try copyFile(from: parameters["path"] as? String, to: parameters["destination"] as? String)
        case "delete":
            return try deleteFile(path: parameters["path"] as? String)
        default:
            throw ToolError.invalidParameter("action", value: action)
        }
    }

    // MARK: - File Operations

    private func searchFiles(query: String?) async throws -> ToolResult {
        guard let query = query else {
            throw ToolError.missingParameter("query")
        }

        print("🔍 Searching for files: \(query)")

        // Use Spotlight (NSMetadataQuery) for search
        let searchResults = try await performSpotlightSearch(query: query)

        return ToolResult(
            success: true,
            message: "Found \(searchResults.count) files matching '\(query)'",
            data: [
                "files": searchResults.map { [
                    "path": $0.path,
                    "name": $0.lastPathComponent,
                    "type": $0.pathExtension
                ]}
            ]
        )
    }

    private func openFile(path: String?) throws -> ToolResult {
        guard let path = path else {
            throw ToolError.missingParameter("path")
        }

        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw ToolError.fileNotFound(path)
        }

        NSWorkspace.shared.open(url)

        return ToolResult(
            success: true,
            message: "Opened file: \(url.lastPathComponent)",
            data: ["path": path]
        )
    }

    private func moveFile(from sourcePath: String?, to destinationPath: String?) throws -> ToolResult {
        guard let sourcePath = sourcePath else {
            throw ToolError.missingParameter("path")
        }
        guard let destinationPath = destinationPath else {
            throw ToolError.missingParameter("destination")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = URL(fileURLWithPath: destinationPath)

        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

        return ToolResult(
            success: true,
            message: "Moved file to: \(destinationURL.lastPathComponent)",
            data: ["from": sourcePath, "to": destinationPath]
        )
    }

    private func copyFile(from sourcePath: String?, to destinationPath: String?) throws -> ToolResult {
        guard let sourcePath = sourcePath else {
            throw ToolError.missingParameter("path")
        }
        guard let destinationPath = destinationPath else {
            throw ToolError.missingParameter("destination")
        }

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = URL(fileURLWithPath: destinationPath)

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        return ToolResult(
            success: true,
            message: "Copied file to: \(destinationURL.lastPathComponent)",
            data: ["from": sourcePath, "to": destinationPath]
        )
    }

    private func deleteFile(path: String?) throws -> ToolResult {
        guard let path = path else {
            throw ToolError.missingParameter("path")
        }

        let url = URL(fileURLWithPath: path)

        try FileManager.default.trashItem(at: url, resultingItemURL: nil)

        return ToolResult(
            success: true,
            message: "Moved file to trash: \(url.lastPathComponent)",
            data: ["path": path]
        )
    }

    // MARK: - Spotlight Search

    private func performSpotlightSearch(query: String) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            let metadataQuery = NSMetadataQuery()

            // Search scope: user's home directory
            metadataQuery.searchScopes = [
                NSMetadataQueryUserHomeScope,
                NSMetadataQueryLocalComputerScope
            ]

            // Predicate for file name search
            metadataQuery.predicate = NSPredicate(
                format: "kMDItemFSName LIKE[cd] %@",
                "*\(query)*"
            )

            // Notification observer
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: .main
            ) { notification in
                metadataQuery.stop()

                if let observer = observer {
                    NotificationCenter.default.removeObserver(observer)
                }

                let results = metadataQuery.results.compactMap { item -> URL? in
                    guard let metadataItem = item as? NSMetadataItem,
                          let path = metadataItem.value(forAttribute: NSMetadataItemPathKey) as? String else {
                        return nil
                    }
                    return URL(fileURLWithPath: path)
                }

                continuation.resume(returning: results)
            }

            // Start query
            metadataQuery.start()

            // Timeout after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if metadataQuery.isGathering {
                    metadataQuery.stop()
                    if let observer = observer {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    continuation.resume(throwing: ToolError.timeout("Spotlight search timed out"))
                }
            }
        }
    }
}

// MARK: - Tool Errors

enum ToolError: Error {
    case missingParameter(String)
    case invalidParameter(String, value: String)
    case fileNotFound(String)
    case timeout(String)
}

extension ToolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameter(let param, let value):
            return "Invalid value '\(value)' for parameter: \(param)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .timeout(let message):
            return message
        }
    }
}
