//
//  TutorialFinder.swift
//  Cloe
//
//  Searches for tutorials online and extracts actionable steps
//

import Foundation

/// Searches web/YouTube for tutorials and extracts steps
class TutorialFinder {
    static let shared = TutorialFinder()

    private let googleAPIKey: String
    private let youtubeAPIKey: String

    private init() {
        self.googleAPIKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? ""
        self.youtubeAPIKey = ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? ""
    }

    // MARK: - Search for Tutorial

    struct TutorialResult {
        let title: String
        let url: String
        let source: TutorialSource
        let steps: [String]?
        let summary: String?
    }

    enum TutorialSource {
        case web
        case youtube
        case documentation
    }

    /// Search for a tutorial on how to do something in an app
    func findTutorial(query: String, app: String) async throws -> [TutorialResult] {
        let searchQuery = "\(query) in \(app) tutorial"

        async let webResults = searchWeb(query: searchQuery)
        async let youtubeResults = searchYouTube(query: searchQuery)

        let web = try await webResults
        let youtube = try await youtubeResults

        return web + youtube
    }

    // MARK: - Web Search

    private func searchWeb(query: String) async throws -> [TutorialResult] {
        // Use Google Custom Search API or DuckDuckGo
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://www.googleapis.com/customsearch/v1?key=\(googleAPIKey)&cx=YOUR_SEARCH_ENGINE_ID&q=\(encodedQuery)")!

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)

            return response.items?.prefix(5).map { item in
                TutorialResult(
                    title: item.title,
                    url: item.link,
                    source: .web,
                    steps: nil,
                    summary: item.snippet
                )
            } ?? []
        } catch {
            // Fallback: Use DuckDuckGo (no API key needed)
            return try await searchDuckDuckGo(query: query)
        }
    }

    private func searchDuckDuckGo(query: String) async throws -> [TutorialResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(DuckDuckGoResponse.self, from: data)

        var results: [TutorialResult] = []

        // Abstract
        if let abstract = response.Abstract, !abstract.isEmpty {
            results.append(TutorialResult(
                title: response.Heading ?? query,
                url: response.AbstractURL ?? "",
                source: .web,
                steps: nil,
                summary: abstract
            ))
        }

        // Related topics
        for topic in response.RelatedTopics?.prefix(4) ?? [] {
            if let text = topic.Text, let url = topic.FirstURL {
                results.append(TutorialResult(
                    title: text.prefix(100).description,
                    url: url,
                    source: .web,
                    steps: nil,
                    summary: text
                ))
            }
        }

        return results
    }

    // MARK: - YouTube Search

    private func searchYouTube(query: String) async throws -> [TutorialResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=5&q=\(encodedQuery)&type=video&key=\(youtubeAPIKey)")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(YouTubeSearchResponse.self, from: data)

        return response.items?.map { item in
            TutorialResult(
                title: item.snippet.title,
                url: "https://www.youtube.com/watch?v=\(item.id.videoId)",
                source: .youtube,
                steps: nil,
                summary: item.snippet.description
            )
        } ?? []
    }

    // MARK: - Extract Steps from Tutorial

    /// Uses AI to extract actionable steps from a tutorial page
    func extractSteps(from url: String) async throws -> [String] {
        // Fetch page content
        let pageURL = URL(string: url)!
        let (data, _) = try await URLSession.shared.data(from: pageURL)
        let html = String(data: data, encoding: .utf8) ?? ""

        // Strip HTML to plain text
        let plainText = stripHTML(html)

        // Use LLM to extract steps
        let steps = try await extractStepsWithAI(content: plainText)
        return steps
    }

    private func stripHTML(_ html: String) -> String {
        var result = html

        // Remove script and style tags with content
        result = result.replacingOccurrences(of: "<script[^>]*>.*?</script>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "<style[^>]*>.*?</style>", with: "", options: .regularExpression)

        // Remove all HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")

        // Clean up whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractStepsWithAI(content: String) async throws -> [String] {
        let truncatedContent = String(content.prefix(10000))

        let prompt = """
        Extract the step-by-step instructions from this tutorial content.
        Return ONLY a JSON array of strings, each string being one step.
        Focus on actionable steps the user needs to take.

        Content:
        \(truncatedContent)

        Response format: ["Step 1...", "Step 2...", ...]
        """

        // Use LLMClient to get steps
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        if let content = response.choices.first?.message.content {
            // Parse JSON array
            if let jsonData = content.data(using: .utf8),
               let steps = try? JSONDecoder().decode([String].self, from: jsonData) {
                return steps
            }
        }

        return []
    }
}

// MARK: - API Response Models

struct GoogleSearchResponse: Codable {
    let items: [GoogleSearchItem]?
}

struct GoogleSearchItem: Codable {
    let title: String
    let link: String
    let snippet: String
}

struct DuckDuckGoResponse: Codable {
    let Abstract: String?
    let AbstractURL: String?
    let Heading: String?
    let RelatedTopics: [DuckDuckGoTopic]?
}

struct DuckDuckGoTopic: Codable {
    let Text: String?
    let FirstURL: String?
}

struct YouTubeSearchResponse: Codable {
    let items: [YouTubeItem]?
}

struct YouTubeItem: Codable {
    let id: YouTubeVideoID
    let snippet: YouTubeSnippet
}

struct YouTubeVideoID: Codable {
    let videoId: String
}

struct YouTubeSnippet: Codable {
    let title: String
    let description: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}
