//
//  ToolRegistry.swift
//  Cloe
//
//  Tool registration and management
//

import Foundation

// MARK: - Tool Protocol

protocol Tool {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }

    func execute(parameters: [String: Any]) async throws -> ToolResult
}

struct ToolParameter {
    let name: String
    let type: String
    let description: String
    let required: Bool
}

struct ToolResult {
    let success: Bool
    let message: String
    let data: [String: Any]?
}

// MARK: - Tool Registry

class ToolRegistry {
    private var tools: [String: Tool] = [:]

    var toolCount: Int {
        tools.count
    }

    func register(_ tool: Tool) {
        tools[tool.name] = tool
        print("🔧 Registered tool: \(tool.name)")
    }

    func getTool(named name: String) -> Tool? {
        return tools[name]
    }

    func getToolDescriptions() -> String {
        return tools.values.map { tool in
            """
            - \(tool.name): \(tool.description)
              Parameters: \(tool.parameters.map { $0.name }.joined(separator: ", "))
            """
        }.joined(separator: "\n")
    }

    func getAllTools() -> [Tool] {
        return Array(tools.values)
    }
}
