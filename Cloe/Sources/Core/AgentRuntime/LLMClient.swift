//
//  LLMClient.swift
//  Cloe
//
//  LLM API client for OpenAI and Claude
//

import Foundation

// MARK: - LLM Message

struct LLMMessage: Codable {
    let role: String
    let content: String
}

// MARK: - LLM Provider

enum LLMProvider {
    case openai
    case claude
    case local

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4-turbo-preview"
        case .claude: return "claude-3-5-sonnet-20241022"
        case .local: return "llama3"
        }
    }
}

// MARK: - LLM Client

class LLMClient {
    // MARK: - Properties

    private var apiKeys: [LLMProvider: String] = [:]
    private var currentProvider: LLMProvider = .openai

    private let openAIBaseURL = "https://api.openai.com/v1"
    private let claudeBaseURL = "https://api.anthropic.com/v1"

    // MARK: - Configuration

    func setAPIKey(_ key: String, provider: LLMProvider) {
        apiKeys[provider] = key
        print("[KEY] API key set for \(provider)")
    }

    func setProvider(_ provider: LLMProvider) {
        currentProvider = provider
        print("[BOT] Using LLM provider: \(provider)")
    }

    // MARK: - Chat Completion

    func chat(
        messages: [LLMMessage],
        model: String? = nil,
        temperature: Double = 0.7,
        maxTokens: Int = 2000
    ) async throws -> String {
        let selectedModel = model ?? currentProvider.defaultModel

        print("[CHAT] LLM Chat - Provider: \(currentProvider), Model: \(selectedModel)")

        switch currentProvider {
        case .openai:
            return try await chatWithOpenAI(messages: messages, model: selectedModel, temperature: temperature, maxTokens: maxTokens)
        case .claude:
            return try await chatWithClaude(messages: messages, model: selectedModel, temperature: temperature, maxTokens: maxTokens)
        case .local:
            return try await chatWithLocal(messages: messages, model: selectedModel)
        }
    }

    // MARK: - OpenAI Implementation

    private func chatWithOpenAI(
        messages: [LLMMessage],
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = apiKeys[.openai] else {
            throw LLMError.missingAPIKey(provider: .openai)
        }

        let url = URL(string: "\(openAIBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content
    }

    // MARK: - Claude Implementation

    private func chatWithClaude(
        messages: [LLMMessage],
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = apiKeys[.claude] else {
            throw LLMError.missingAPIKey(provider: .claude)
        }

        let url = URL(string: "\(claudeBaseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Claude requires system message separate
        var systemMessage = ""
        var conversationMessages: [[String: String]] = []

        for msg in messages {
            if msg.role == "system" {
                systemMessage += msg.content + "\n"
            } else {
                conversationMessages.append([
                    "role": msg.role,
                    "content": msg.content
                ])
            }
        }

        var body: [String: Any] = [
            "model": model,
            "messages": conversationMessages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]

        if !systemMessage.isEmpty {
            body["system"] = systemMessage
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text
    }

    // MARK: - Local Implementation

    private func chatWithLocal(messages: [LLMMessage], model: String) async throws -> String {
        // TODO: Implement local LLM via Ollama or llama.cpp
        throw LLMError.notImplemented
    }
}

// MARK: - Errors

enum LLMError: Error {
    case missingAPIKey(provider: LLMProvider)
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case notImplemented
}

extension LLMError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider)"
        case .invalidResponse:
            return "Invalid response from LLM API"
        case .apiError(let code, let message):
            return "LLM API error (\(code)): \(message)"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}
