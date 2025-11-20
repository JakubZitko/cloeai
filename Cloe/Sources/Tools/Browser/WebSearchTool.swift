//
//  WebSearchTool.swift
//  Cloe
//
//  Web search integration
//

import Foundation

class WebSearchTool: Tool {
    let name = "web_search"
    let description = "Search the web for information"

    let parameters = [
        ToolParameter(name: "query", type: "string", description: "Search query", required: true),
        ToolParameter(name: "limit", type: "number", description: "Number of results (default: 5)", required: false)
    ]

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        guard let query = parameters["query"] as? String else {
            throw ToolError.missingParameter("query")
        }

        let limit = parameters["limit"] as? Int ?? 5

        print("🔍 Web search: \(query)")

        // Perform web search
        let results = try await search(query: query, limit: limit)

        return ToolResult(
            success: true,
            message: "Found \(results.count) results for '\(query)'",
            data: [
                "query": query,
                "results": results.map { [
                    "title": $0.title,
                    "url": $0.url,
                    "snippet": $0.snippet
                ]}
            ]
        )
    }

    // MARK: - Search Implementation

    private func search(query: String, limit: Int) async throws -> [SearchResult] {
        // TODO: Integrate with Brave Search API or SerpAPI
        // For now, return mock results

        // Encode query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw WebSearchError.invalidQuery
        }

        // Mock results
        return [
            SearchResult(
                title: "Search result for: \(query)",
                url: "https://example.com/1",
                snippet: "This is a mock search result."
            )
        ]
    }
}

// MARK: - Supporting Types

struct SearchResult {
    let title: String
    let url: String
    let snippet: String
}

// MARK: - Errors

enum WebSearchError: Error {
    case invalidQuery
    case apiError(String)
}

extension WebSearchError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .apiError(let message):
            return "Web search API error: \(message)"
        }
    }
}
