//
//  VoiceInputManager.swift
//  Cloe
//
//  Voice input and speech recognition
//

import Foundation
import Speech
import AVFoundation
import Combine

class VoiceInputManager: NSObject, ObservableObject {
    static let shared = VoiceInputManager()

    // MARK: - Published Properties

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var permissionGranted = false

    // Publishers for external use
    var isListeningPublisher: Published<Bool>.Publisher { $isListening }
    var transcriptPublisher: Published<String>.Publisher { $transcript }

    // MARK: - Private Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Permission

    private func checkPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.permissionGranted = (status == .authorized)
                print("🎤 Speech recognition permission: \(status)")
            }
        }
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("✅ Speech recognition authorized")
                    self.permissionGranted = true
                case .denied:
                    print("❌ Speech recognition denied")
                    self.showPermissionDeniedAlert()
                case .restricted, .notDetermined:
                    print("⚠️ Speech recognition restricted or not determined")
                @unknown default:
                    print("❌ Unknown speech recognition status")
                }
            }
        }
    }

    // MARK: - Voice Input

    func startListening() {
        guard !isListening else { return }
        guard permissionGranted else {
            requestPermission()
            return
        }

        do {
            try startRecording()
            DispatchQueue.main.async {
                self.isListening = true
                self.transcript = ""
            }
            print("🎤 Started listening...")
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine.stop()
        recognitionRequest?.endAudio()

        DispatchQueue.main.async {
            self.isListening = false
        }

        print("🛑 Stopped listening")
    }

    // MARK: - Speech Recognition

    private func startRecording() throws {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceInputError.recognitionRequestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.recognizerNotAvailable
        }

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let transcribedText = result.bestTranscription.formattedString

                DispatchQueue.main.async {
                    self.transcript = transcribedText
                }

                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                if isFinal {
                    print("✅ Speech recognition completed: \(self.transcript)")
                }
            }
        }
    }

    // MARK: - Utilities

    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = """
        Cloe needs microphone access for voice commands.

        Please grant permission in System Settings > Privacy & Security > Microphone.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }
}

// MARK: - Errors

enum VoiceInputError: Error {
    case recognitionRequestCreationFailed
    case recognizerNotAvailable
    case audioEngineError
}

extension VoiceInputError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .recognitionRequestCreationFailed:
            return "Failed to create speech recognition request"
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}
