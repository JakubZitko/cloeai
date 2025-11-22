//
//  OverlayViewModel.swift
//  Cloe
//
//  View model for overlay window
//

import Foundation
import Combine
import AppKit

class OverlayViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var textInput: String = ""
    @Published var voiceTranscript: String = ""
    @Published var isListening: Bool = false
    @Published var isProcessing: Bool = false
    @Published var currentContext: ContextInfo?
    @Published var currentResponse: AgentResponse?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let contextEngine = ContextEngine.shared
    private let agentRuntime = AgentRuntime.shared
    private let voiceInput = VoiceInputManager.shared

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Listen to voice input updates
        voiceInput.transcriptPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$voiceTranscript)

        voiceInput.isListeningPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$isListening)
    }

    // MARK: - Public Methods

    func loadContext() {
        // Get current screen context
        Task {
            let context = await contextEngine.getCurrentContext()
            await MainActor.run {
                self.currentContext = ContextInfo(
                    appName: context.appName,
                    details: context.windowTitle,
                    icon: context.appIcon
                )
            }
        }
    }

    func toggleVoiceInput() {
        if isListening {
            stopVoiceInput()
        } else {
            startVoiceInput()
        }
    }

    func startVoiceInput() {
        voiceInput.startListening()
    }

    func stopVoiceInput() {
        voiceInput.stopListening()

        // Process the transcript
        if !voiceTranscript.isEmpty {
            processInput(voiceTranscript)
            voiceTranscript = ""
        }
    }

    func submitTextInput() {
        guard !textInput.isEmpty else { return }

        let input = textInput
        textInput = ""

        processInput(input)
    }

    private func processInput(_ input: String) {
        print("[NOTE] Processing input: \(input)")

        isProcessing = true
        currentResponse = nil

        Task {
            do {
                let response = try await agentRuntime.processCommand(
                    input,
                    context: await contextEngine.getCurrentContext()
                )

                await MainActor.run {
                    self.isProcessing = false
                    self.currentResponse = AgentResponse(
                        message: response.message,
                        actions: response.actions?.map { action in
                            AgentAction(
                                title: action.title,
                                icon: action.icon,
                                requiresConfirmation: action.requiresConfirmation,
                                handler: {
                                    Task {
                                        await self.agentRuntime.executeAction(action)
                                    }
                                }
                            )
                        }
                    )
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.currentResponse = AgentResponse(
                        message: "Sorry, I encountered an error: \(error.localizedDescription)",
                        actions: nil
                    )
                }
            }
        }
    }

    func executeAction(_ action: AgentAction) {
        print("[TARGET] Executing action: \(action.title)")
        action.handler()
    }

    func openSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
