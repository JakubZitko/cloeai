//
//  AgentRuntime.swift
//  Cloe
//
//  Core AI agent runtime - orchestrates LLM, tools, and task execution
//

import Foundation

// MARK: - Agent Response Models

struct AgentCommandResponse {
    let message: String
    let actions: [ExecutableAction]?
    let requiresConfirmation: Bool
}

struct ExecutableAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let requiresConfirmation: Bool
    let tool: String
    let parameters: [String: Any]
}

// MARK: - Agent Runtime

class AgentRuntime {
    static let shared = AgentRuntime()

    // MARK: - Properties

    private let llmClient: LLMClient
    private let toolRegistry: ToolRegistry
    private let spatialMemory: SpatialMemory
    private let taskScheduler: TaskScheduler

    private var isInitialized = false

    // MARK: - Initialization

    private init() {
        self.llmClient = LLMClient()
        self.toolRegistry = ToolRegistry()
        self.spatialMemory = SpatialMemory.shared
        self.taskScheduler = TaskScheduler.shared

        registerTools()
    }

    func initialize() {
        guard !isInitialized else { return }

        print("🤖 Agent Runtime initializing...")

        // Load API keys from config
        loadConfiguration()

        // Initialize components
        spatialMemory.load()
        taskScheduler.start()

        isInitialized = true
        print("✅ Agent Runtime ready")
    }

    // MARK: - Command Processing

    func processCommand(_ command: String, context: ScreenContext) async throws -> AgentCommandResponse {
        print("🧠 Processing command: \(command)")

        // 1. Parse and understand command
        let intent = try await parseIntent(command, context: context)

        // 2. Retrieve relevant memory/context
        let relevantMemory = spatialMemory.search(query: command, limit: 5)

        // 3. Plan execution
        let plan = try await planExecution(intent: intent, context: context, memory: relevantMemory)

        // 4. Generate response with actions
        return AgentCommandResponse(
            message: plan.responseMessage,
            actions: plan.actions,
            requiresConfirmation: plan.requiresConfirmation
        )
    }

    func executeAction(_ action: ExecutableAction) async {
        print("⚡ Executing action: \(action.title)")

        do {
            // Get the tool
            guard let tool = toolRegistry.getTool(named: action.tool) else {
                print("❌ Tool not found: \(action.tool)")
                return
            }

            // Execute tool
            let result = try await tool.execute(parameters: action.parameters)

            // Store in memory
            spatialMemory.recordAction(
                tool: action.tool,
                parameters: action.parameters,
                result: result
            )

            print("✅ Action completed: \(action.title)")
        } catch {
            print("❌ Action failed: \(error)")
        }
    }

    // MARK: - Intent Parsing

    private func parseIntent(_ command: String, context: ScreenContext) async throws -> Intent {
        let systemPrompt = """
        You are Cloe, a proactive AI assistant for macOS.

        Analyze the user's command and current context to determine their intent.

        CURRENT CONTEXT:
        - Active App: \(context.appName)
        - Window: \(context.windowTitle)
        - Screen Content: \(context.screenContent ?? "N/A")

        USER COMMAND: \(command)

        Respond with a JSON object containing:
        {
          "intent_type": "send_email" | "find_file" | "create_event" | "search_web" | "create_document" | "general_query",
          "entities": {
            "recipient": "...",
            "file_name": "...",
            "topic": "...",
            etc.
          },
          "confidence": 0.0 to 1.0
        }
        """

        let response = try await llmClient.chat(messages: [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: command)
        ])

        return try parseIntentFromResponse(response)
    }

    // MARK: - Execution Planning

    private func planExecution(intent: Intent, context: ScreenContext, memory: [MemoryEntry]) async throws -> ExecutionPlan {
        let systemPrompt = """
        You are Cloe, a proactive AI assistant for macOS.

        Plan how to execute the user's intent using available tools.

        AVAILABLE TOOLS:
        \(toolRegistry.getToolDescriptions())

        CURRENT CONTEXT:
        - Active App: \(context.appName)
        - Window: \(context.windowTitle)

        RELEVANT MEMORY:
        \(formatMemory(memory))

        USER INTENT:
        - Type: \(intent.type)
        - Entities: \(intent.entities)

        Respond with a JSON object containing:
        {
          "response_message": "Human-readable explanation of what you'll do",
          "actions": [
            {
              "title": "Action name",
              "tool": "tool_name",
              "parameters": {...}
            }
          ],
          "requires_confirmation": true/false
        }
        """

        let response = try await llmClient.chat(messages: [
            LLMMessage(role: "system", content: systemPrompt),
            LLMMessage(role: "user", content: "Plan execution")
        ])

        return try parseExecutionPlanFromResponse(response)
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        // Load API keys from environment or config file
        if let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            llmClient.setAPIKey(openAIKey, provider: .openai)
        }

        if let claudeKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] {
            llmClient.setAPIKey(claudeKey, provider: .claude)
        }

        // TODO: Load from config file if not in environment
    }

    // MARK: - Tool Registration

    private func registerTools() {
        // Register all available tools
        toolRegistry.register(FileSystemTool())
        toolRegistry.register(CalendarTool())
        toolRegistry.register(EmailTool())
        toolRegistry.register(WebSearchTool())
        toolRegistry.register(ScreenCaptureTool())

        print("🔧 Registered \(toolRegistry.toolCount) tools")
    }

    // MARK: - Utilities

    private func formatMemory(_ entries: [MemoryEntry]) -> String {
        return entries.map { entry in
            "- \(entry.description)"
        }.joined(separator: "\n")
    }

    private func parseIntentFromResponse(_ response: String) throws -> Intent {
        // TODO: Parse JSON response into Intent struct
        // For now, return a mock intent
        return Intent(
            type: .generalQuery,
            entities: [:],
            confidence: 0.8
        )
    }

    private func parseExecutionPlanFromResponse(_ response: String) throws -> ExecutionPlan {
        // TODO: Parse JSON response into ExecutionPlan
        // For now, return a mock plan
        return ExecutionPlan(
            responseMessage: "I'll help you with that.",
            actions: [],
            requiresConfirmation: false
        )
    }
}

// MARK: - Supporting Types

struct Intent {
    let type: IntentType
    let entities: [String: Any]
    let confidence: Double

    enum IntentType: String {
        case sendEmail = "send_email"
        case findFile = "find_file"
        case createEvent = "create_event"
        case searchWeb = "search_web"
        case createDocument = "create_document"
        case generalQuery = "general_query"
    }
}

struct ExecutionPlan {
    let responseMessage: String
    let actions: [ExecutableAction]
    let requiresConfirmation: Bool
}

struct MemoryEntry {
    let description: String
    let timestamp: Date
    let relevance: Double
}
