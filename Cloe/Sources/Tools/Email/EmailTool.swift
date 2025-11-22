//
//  EmailTool.swift
//  Cloe
//
//  Email automation (send, search, draft)
//

import Foundation
import AppKit

class EmailTool: Tool {
    let name = "email"
    let description = "Send emails, search emails, draft messages"

    let parameters = [
        ToolParameter(name: "action", type: "string", description: "Action: send, draft, search", required: true),
        ToolParameter(name: "to", type: "string", description: "Recipient email address", required: false),
        ToolParameter(name: "subject", type: "string", description: "Email subject", required: false),
        ToolParameter(name: "body", type: "string", description: "Email body", required: false),
        ToolParameter(name: "query", type: "string", description: "Search query for emails", required: false)
    ]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let action = parameters["action"] as? String else {
            throw ToolError.missingParameter("action")
        }

        switch action {
        case "send":
            return try sendEmail(parameters: parameters)
        case "draft":
            return try draftEmail(parameters: parameters)
        case "search":
            return try searchEmails(parameters: parameters)
        default:
            throw ToolError.invalidParameter("action", value: action)
        }
    }

    // MARK: - Email Operations

    private func sendEmail(parameters: [String: Any]) throws -> ToolResult {
        guard let to = parameters["to"] as? String else {
            throw ToolError.missingParameter("to")
        }
        guard let subject = parameters["subject"] as? String else {
            throw ToolError.missingParameter("subject")
        }
        guard let body = parameters["body"] as? String else {
            throw ToolError.missingParameter("body")
        }

        // Use AppleScript to send via Mail.app
        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
            tell newMessage
                make new to recipient with properties {address:"\(to)"}
            end tell
            send newMessage
        end tell
        """

        try executeAppleScript(script)

        return ToolResult(
            success: true,
            message: "Sent email to \(to)",
            data: [
                "to": to,
                "subject": subject
            ]
        )
    }

    private func draftEmail(parameters: [String: Any]) throws -> ToolResult {
        guard let to = parameters["to"] as? String else {
            throw ToolError.missingParameter("to")
        }
        let subject = parameters["subject"] as? String ?? ""
        let body = parameters["body"] as? String ?? ""

        // Create draft in Mail.app
        let script = """
        tell application "Mail"
            activate
            set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
            tell newMessage
                make new to recipient with properties {address:"\(to)"}
            end tell
        end tell
        """

        try executeAppleScript(script)

        return ToolResult(
            success: true,
            message: "Created email draft to \(to)",
            data: [
                "to": to,
                "subject": subject
            ]
        )
    }

    private func searchEmails(parameters: [String: Any]) throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            throw ToolError.missingParameter("query")
        }

        let limit = parameters["limit"] as? Int ?? 10

        // Search emails using AppleScript with Mail.app
        let script = """
        tell application "Mail"
            set foundMessages to {}
            set searchQuery to "\(query.replacingOccurrences(of: "\"", with: "\\\""))"

            -- Search in all mailboxes
            repeat with acc in accounts
                repeat with mbox in mailboxes of acc
                    try
                        set msgs to (messages of mbox whose subject contains searchQuery or sender contains searchQuery or content contains searchQuery)
                        repeat with msg in msgs
                            if (count of foundMessages) < \(limit) then
                                set msgInfo to {subject of msg, sender of msg, date received of msg as string, id of msg}
                                set end of foundMessages to msgInfo
                            end if
                        end repeat
                    end try
                end repeat
            end repeat

            return foundMessages
        end tell
        """

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            throw EmailError.scriptCreationFailed
        }

        let result = scriptObject.executeAndReturnError(&error)

        if let error = error {
            // If Mail.app isn't available or permission denied, use Spotlight fallback
            return try searchEmailsViaSpotlight(query: query, limit: limit)
        }

        // Parse AppleScript result
        var emailResults: [[String: String]] = []

        if let resultList = result.coerce(toDescriptorType: typeAEList) {
            let count = resultList.numberOfItems
            for i in 1...count {
                if let item = resultList.atIndex(i),
                   let itemList = item.coerce(toDescriptorType: typeAEList) {
                    let subject = itemList.atIndex(1)?.stringValue ?? "No Subject"
                    let sender = itemList.atIndex(2)?.stringValue ?? "Unknown"
                    let date = itemList.atIndex(3)?.stringValue ?? ""
                    let id = itemList.atIndex(4)?.stringValue ?? ""

                    emailResults.append([
                        "subject": subject,
                        "sender": sender,
                        "date": date,
                        "id": id
                    ])
                }
            }
        }

        return ToolResult(
            success: true,
            message: "Found \(emailResults.count) emails matching '\(query)'",
            data: [
                "query": query,
                "results": emailResults
            ]
        )
    }

    private func searchEmailsViaSpotlight(query: String, limit: Int) throws -> ToolResult {
        // Use Spotlight (mdfind) for email search as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "-limit", String(limit),
            "kMDItemContentType == 'com.apple.mail.emlx' && (kMDItemSubject == '*\(query)*'cd || kMDItemAuthors == '*\(query)*'cd)"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            var results: [[String: String]] = []
            for path in paths.prefix(limit) {
                // Extract basic info from path
                let filename = (path as NSString).lastPathComponent
                results.append([
                    "path": path,
                    "filename": filename
                ])
            }

            return ToolResult(
                success: true,
                message: "Found \(results.count) emails via Spotlight for '\(query)'",
                data: [
                    "query": query,
                    "results": results
                ]
            )
        } catch {
            return ToolResult(
                success: false,
                message: "Email search failed: \(error.localizedDescription)",
                data: ["query": query, "results": []]
            )
        }
    }

    // MARK: - AppleScript Execution

    private func executeAppleScript(_ script: String) throws {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            throw EmailError.scriptCreationFailed
        }

        scriptObject.executeAndReturnError(&error)

        if let error = error {
            throw EmailError.scriptExecutionFailed(error.description)
        }
    }
}

// MARK: - Email Errors

enum EmailError: Error {
    case scriptCreationFailed
    case scriptExecutionFailed(String)
}

extension EmailError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .scriptCreationFailed:
            return "Failed to create AppleScript"
        case .scriptExecutionFailed(let message):
            return "AppleScript execution failed: \(message)"
        }
    }
}
