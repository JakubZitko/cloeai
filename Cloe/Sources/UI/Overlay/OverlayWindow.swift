//
//  OverlayWindow.swift
//  Cloe
//
//  Floating overlay window for Cloe interaction
//

import SwiftUI
import AppKit

class OverlayWindow: NSPanel {
    private var hostingView: NSHostingView<OverlayView>?

    init() {
        // Create window with proper styling
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        // Window properties
        self.level = .floating
        self.isFloatingPanel = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Title bar
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        // Position in top-right corner
        positionWindow()

        // Setup content view
        setupContentView()
    }

    private func setupContentView() {
        let overlayView = OverlayView(window: self)
        hostingView = NSHostingView(rootView: overlayView)
        self.contentView = hostingView
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Position in top-right corner with padding
        let padding: CGFloat = 20
        let x = screenFrame.maxX - self.frame.width - padding
        let y = screenFrame.maxY - self.frame.height - padding

        self.setFrameOrigin(NSPoint(x: x, y: y))

        // Restore saved position if exists
        if let savedOrigin = UserDefaults.standard.string(forKey: "overlayWindowOrigin") {
            self.setFrameOrigin(NSPointFromString(savedOrigin))
        }
    }

    func show() {
        self.orderFrontRegardless()
        self.makeKey()
    }

    func hide() {
        // Save position
        let origin = NSStringFromPoint(self.frame.origin)
        UserDefaults.standard.set(origin, forKey: "overlayWindowOrigin")

        self.orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        // Don't hide when clicking away - stay visible
    }
}

// MARK: - Overlay SwiftUI View

struct OverlayView: View {
    @StateObject private var viewModel = OverlayViewModel()
    weak var window: OverlayWindow?

    var body: some View {
        ZStack {
            // Background with blur effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(16)

            VStack(spacing: 0) {
                // Header
                headerView

                Divider()

                // Context indicator
                if let context = viewModel.currentContext {
                    contextView(context)
                    Divider()
                }

                // Main content area
                contentArea

                Divider()

                // Input area
                inputArea
            }
            .padding(0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.loadContext()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 12))

            Text("Cloe")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { window?.hide() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close (Cmd+Shift+Space)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
    }

    private func contextView(_ context: ContextInfo) -> some View {
        HStack(spacing: 8) {
            Image(systemName: context.icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.appName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)

                Text(context.details)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
    }

    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isListening {
                    listeningView
                } else if viewModel.isProcessing {
                    processingView
                } else if let response = viewModel.currentResponse {
                    responseView(response)
                } else {
                    idleView
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.blue.opacity(0.3))

            Text("Ready to assist")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("Press the microphone or start typing")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var listeningView: some View {
        VStack(spacing: 16) {
            // Animated waveform
            WaveformView(isAnimating: true)
                .frame(height: 60)

            Text("Listening...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)

            if !viewModel.voiceTranscript.isEmpty {
                Text(viewModel.voiceTranscript)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Thinking...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func responseView(_ response: AgentResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI Response
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text(response.message)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)

            // Action buttons if needed
            if let actions = response.actions, !actions.isEmpty {
                Divider()

                Text("Actions")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                ForEach(actions, id: \.id) { action in
                    actionButton(action)
                }
            }
        }
    }

    private func actionButton(_ action: AgentAction) -> some View {
        Button(action: {
            viewModel.executeAction(action)
        }) {
            HStack {
                Image(systemName: action.icon)
                    .font(.system(size: 12))

                Text(action.title)
                    .font(.system(size: 12, weight: .medium))

                Spacer()

                if action.requiresConfirmation {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var inputArea: some View {
        HStack(spacing: 12) {
            // Microphone button
            Button(action: { viewModel.toggleVoiceInput() }) {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.isListening ? .red : .blue)
                    .frame(width: 32, height: 32)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Voice input (Space to hold)")

            // Text input
            TextField("Type message...", text: $viewModel.textInput, onCommit: {
                viewModel.submitTextInput()
            })
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)

            // Settings button
            Button(action: { viewModel.openSettings() }) {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
    }
}

// MARK: - Visual Effect View for blur

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Waveform Animation View

struct WaveformView: View {
    let isAnimating: Bool
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .frame(height: barHeight(for: index))
                    .animation(
                        isAnimating ? .easeInOut(duration: 0.5).repeatForever() : .default,
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            if isAnimating {
                withAnimation {
                    animationPhase = 1
                }
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 50
        let wave = sin(animationPhase * .pi * 2 + CGFloat(index) * 0.3)
        return baseHeight + (maxHeight - baseHeight) * (wave + 1) / 2
    }
}

// MARK: - Data Models

struct ContextInfo {
    let appName: String
    let details: String
    let icon: String
}

struct AgentResponse {
    let message: String
    let actions: [AgentAction]?
}

struct AgentAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let requiresConfirmation: Bool
    let handler: () -> Void
}
