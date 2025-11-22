//
//  WebSearchTool.swift
//  Cloe
//
//  Web search integration using DuckDuckGo HTML
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

        print("[WebSearch] Searching: \(query)")

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
        // Use DuckDuckGo HTML search (no API key required)
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw WebSearchError.invalidQuery
        }

        let urlString = "https://html.duckduckgo.com/html/?q=\(encodedQuery)"
        guard let url = URL(string: urlString) else {
            throw WebSearchError.invalidQuery
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WebSearchError.apiError("Failed to fetch search results")
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.apiError("Failed to decode response")
        }

        // Parse DuckDuckGo HTML results
        let results = parseSearchResults(from: html, limit: limit)

        if results.isEmpty {
            // Fallback: try to get at least something useful
            return [SearchResult(
                title: "Search for: \(query)",
                url: "https://duckduckgo.com/?q=\(encodedQuery)",
                snippet: "View search results on DuckDuckGo"
            )]
        }

        return results
    }

    private func parseSearchResults(from html: String, limit: Int) -> [SearchResult] {
        var results: [SearchResult] = []

        // DuckDuckGo HTML uses class="result__a" for links and class="result__snippet" for snippets
        // Parse using regex patterns

        // Find all result blocks
        let resultPattern = #"<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([^<]*)</a>"#
        let snippetPattern = #"<a[^>]*class="result__snippet"[^>]*>([^<]*(?:<[^>]*>[^<]*)*)</a>"#

        // Extract links and titles
        var links: [(url: String, title: String)] = []
        if let regex = try? NSRegularExpression(pattern: resultPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches.prefix(limit * 2) {
                if let urlRange = Range(match.range(at: 1), in: html),
                   let titleRange = Range(match.range(at: 2), in: html) {
                    var url = String(html[urlRange])
                    let title = String(html[titleRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "&amp;", with: "&")
                        .replacingOccurrences(of: "&quot;", with: "\"")
                        .replacingOccurrences(of: "&#x27;", with: "'")

                    // DuckDuckGo wraps URLs in redirect, extract actual URL
                    if let uddgRange = url.range(of: "uddg=") {
                        let afterUddg = url[uddgRange.upperBound...]
                        if let ampRange = afterUddg.range(of: "&") {
                            url = String(afterUddg[..<ampRange.lowerBound])
                        } else {
                            url = String(afterUddg)
                        }
                        url = url.removingPercentEncoding ?? url
                    }

                    if !title.isEmpty && url.hasPrefix("http") {
                        links.append((url: url, title: title))
                    }
                }
            }
        }

        // Extract snippets
        var snippets: [String] = []
        if let regex = try? NSRegularExpression(pattern: snippetPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)

            for match in matches.prefix(limit * 2) {
                if let snippetRange = Range(match.range(at: 1), in: html) {
                    var snippet = String(html[snippetRange])
                    // Clean HTML tags
                    snippet = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    snippet = snippet.replacingOccurrences(of: "&amp;", with: "&")
                    snippet = snippet.replacingOccurrences(of: "&quot;", with: "\"")
                    snippet = snippet.replacingOccurrences(of: "&#x27;", with: "'")
                    snippet = snippet.replacingOccurrences(of: "&nbsp;", with: " ")
                    snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !snippet.isEmpty {
                        snippets.append(snippet)
                    }
                }
            }
        }

        // Combine links with snippets
        for (index, link) in links.prefix(limit).enumerated() {
            let snippet = index < snippets.count ? snippets[index] : ""
            results.append(SearchResult(
                title: link.title,
                url: link.url,
                snippet: snippet
            ))
        }

        return results
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
