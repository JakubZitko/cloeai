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

        // Use Spotlight to search emails
        // TODO: Implement actual email search via Spotlight or Mail.app AppleScript

        return ToolResult(
            success: true,
            message: "Searched emails for: \(query)",
            data: [
                "query": query,
                "results": [] // Placeholder
            ]
        )
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
