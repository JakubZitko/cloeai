//
//  NotchWindow.swift
//  Cloe
//
//  Notch-style floating window (like Dynamic Island)
//  Can be positioned at top, left, or right of screen
//

import SwiftUI
import AppKit

enum NotchPosition: String, CaseIterable {
    case top = "top"
    case left = "left"
    case right = "right"

    var displayName: String {
        switch self {
        case .top: return "Top"
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

class NotchWindow: NSPanel {
    private var hostingView: NSHostingView<NotchView>?
    private var viewModel: NotchViewModel

    var position: NotchPosition = .top {
        didSet {
            UserDefaults.standard.set(position.rawValue, forKey: "notchPosition")
            updateWindowFrame()
        }
    }

    init() {
        self.viewModel = NotchViewModel()

        // Load saved position
        let savedPosition = UserDefaults.standard.string(forKey: "notchPosition") ?? "top"
        let initialPosition = NotchPosition(rawValue: savedPosition) ?? .top

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 48),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.position = initialPosition

        // Window properties
        self.level = .statusBar
        self.isFloatingPanel = true
        self.isMovableByWindowBackground = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Hide title bar
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        setupContentView()
        updateWindowFrame()
    }

    private func setupContentView() {
        let notchView = NotchView(viewModel: viewModel, window: self)
        hostingView = NSHostingView(rootView: notchView)
        self.contentView = hostingView
    }

    private func updateWindowFrame() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let collapsedWidth: CGFloat = 380
        let collapsedHeight: CGFloat = 48
        let expandedWidth: CGFloat = 420
        let expandedHeight: CGFloat = 480

        let isExpanded = viewModel.isExpanded
        let width = isExpanded ? expandedWidth : collapsedWidth
        let height = isExpanded ? expandedHeight : collapsedHeight

        var origin: CGPoint

        switch position {
        case .top:
            // Center top, just below menu bar
            origin = CGPoint(
                x: screenFrame.midX - width / 2,
                y: visibleFrame.maxY - height - 8
            )

        case .left:
            // Left side, vertically centered
            origin = CGPoint(
                x: 8,
                y: screenFrame.midY - height / 2
            )

        case .right:
            // Right side, vertically centered
            origin = CGPoint(
                x: screenFrame.maxX - width - 8,
                y: screenFrame.midY - height / 2
            )
        }

        let newFrame = NSRect(origin: origin, size: CGSize(width: width, height: height))

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }

    func toggleExpanded() {
        viewModel.isExpanded.toggle()
        updateWindowFrame()
    }

    func expand() {
        if !viewModel.isExpanded {
            viewModel.isExpanded = true
            updateWindowFrame()
        }
    }

    func collapse() {
        if viewModel.isExpanded {
            viewModel.isExpanded = false
            updateWindowFrame()
        }
    }

    func show() {
        self.orderFrontRegardless()
    }

    func hide() {
        self.orderOut(nil)
    }
}

// MARK: - Notch ViewModel

class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isExecuting = false

    @Published var textInput = ""
    @Published var voiceTranscript = ""
    @Published var currentApp = ""
    @Published var selectedElement = ""

    @Published var response: String?
    @Published var steps: [ExecutionStep] = []
    @Published var currentStepIndex: Int = 0

    enum Mode {
        case idle
        case listening
        case thinking
        case responding
        case executing
    }

    @Published var mode: Mode = .idle

    struct ExecutionStep: Identifiable {
        let id = UUID()
        let description: String
        var status: StepStatus = .pending
    }

    enum StepStatus {
        case pending
        case running
        case completed
        case failed
    }

    func updateContext() {
        if let app = NSWorkspace.shared.frontmostApplication {
            currentApp = app.localizedName ?? "Unknown"
        }

        // Get focused element
        if let focused = UINavigator.shared.getFocusedElement() {
            selectedElement = focused.title ?? focused.role
        }
    }
}

// MARK: - Notch SwiftUI View

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    weak var window: NotchWindow?

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: viewModel.isExpanded ? 24 : 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: viewModel.isExpanded ? 24 : 28)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            if viewModel.isExpanded {
                expandedView
            } else {
                collapsedView
            }
        }
        .onTapGesture {
            if !viewModel.isExpanded {
                window?.expand()
            }
        }
        .onAppear {
            viewModel.updateContext()
        }
    }

    // MARK: - Collapsed View (Notch bar)

    private var collapsedView: some View {
        HStack(spacing: 12) {
            // Cloe icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(viewModel.currentApp.isEmpty ? "Ready to help" : "Watching \(viewModel.currentApp)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Quick action indicators
            if viewModel.isListening {
                listeningIndicator
            } else if viewModel.isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
            }

            // Microphone button
            Button(action: { toggleListening() }) {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 14))
                    .foregroundColor(viewModel.isListening ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusText: String {
        switch viewModel.mode {
        case .idle: return "Cloe"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .responding: return "Here's what I found"
        case .executing: return "Working..."
        }
    }

    private var listeningIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: 3, height: 12)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever()
                        .delay(Double(i) * 0.1),
                        value: viewModel.isListening
                    )
            }
        }
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header
            expandedHeader

            Divider()
                .padding(.horizontal)

            // Context bar
            contextBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.isListening {
                        listeningView
                    } else if viewModel.isProcessing {
                        thinkingView
                    } else if viewModel.isExecuting {
                        executionView
                    } else if let response = viewModel.response {
                        responseView(response)
                    } else {
                        idleView
                    }
                }
                .padding(16)
            }

            Divider()
                .padding(.horizontal)

            // Input area
            inputArea
                .padding(12)
        }
    }

    private var expandedHeader: some View {
        HStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text("Cloe")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            // Position picker
            Menu {
                ForEach(NotchPosition.allCases, id: \.self) { pos in
                    Button(pos.displayName) {
                        window?.position = pos
                    }
                }
            } label: {
                Image(systemName: "rectangle.leadinghalf.inset.filled.arrow.leading")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)

            // Close button
            Button(action: { window?.collapse() }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var contextBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "app.badge")
                .font(.system(size: 11))
                .foregroundColor(.blue)

            Text(viewModel.currentApp)
                .font(.system(size: 11, weight: .medium))

            if !viewModel.selectedElement.isEmpty {
                Text("•")
                    .foregroundColor(.secondary)

                Text(viewModel.selectedElement)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("How can I help?")
                .font(.system(size: 16, weight: .medium))

            Text("Ask me anything about \(viewModel.currentApp.isEmpty ? "what you're working on" : viewModel.currentApp)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var listeningView: some View {
        VStack(spacing: 16) {
            // Animated waveform
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 4, height: CGFloat.random(in: 15...40))
                }
            }
            .frame(height: 50)

            Text("Listening...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)

            if !viewModel.voiceTranscript.isEmpty {
                Text(viewModel.voiceTranscript)
                    .font(.system(size: 13))
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var thinkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Thinking...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Text("Searching for how to do this...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func responseView(_ response: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)

                Text(response)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)

            // Action buttons
            if !viewModel.steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I can do this for you:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Button(action: { executeSteps() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Execute Steps")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: { /* Show steps */ }) {
                        HStack {
                            Image(systemName: "list.number")
                            Text("Show me the steps instead")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var executionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)

                Text("Executing...")
                    .font(.system(size: 14, weight: .medium))
            }

            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 10) {
                    stepStatusIcon(step.status)

                    Text(step.description)
                        .font(.system(size: 12))
                        .foregroundColor(step.status == .pending ? .secondary : .primary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }

    private func stepStatusIcon(_ status: NotchViewModel.StepStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Circle()
                    .stroke(Color.secondary, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            case .running:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 10) {
            // Microphone button
            Button(action: { toggleListening() }) {
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.isListening ? .red : .blue)
                    .frame(width: 36, height: 36)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Text input
            TextField("Ask anything...", text: $viewModel.textInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(20)
                .onSubmit {
                    submitQuery()
                }

            // Send button
            Button(action: { submitQuery() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.textInput.isEmpty)
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        viewModel.isListening.toggle()
        viewModel.mode = viewModel.isListening ? .listening : .idle
    }

    private func submitQuery() {
        guard !viewModel.textInput.isEmpty else { return }
        // Process query
        let query = viewModel.textInput
        viewModel.textInput = ""
        viewModel.mode = .thinking
        viewModel.isProcessing = true

        // TODO: Connect to AgentRuntime
        Task {
            await processQuery(query)
        }
    }

    private func processQuery(_ query: String) async {
        // Simulate processing
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            viewModel.isProcessing = false
            viewModel.mode = .responding
            viewModel.response = "I found how to add a glass effect in \(viewModel.currentApp). Would you like me to do it for you, or show you the steps?"
            viewModel.steps = [
                NotchViewModel.ExecutionStep(description: "Select the target layer"),
                NotchViewModel.ExecutionStep(description: "Open Effects panel"),
                NotchViewModel.ExecutionStep(description: "Add Background Blur effect"),
                NotchViewModel.ExecutionStep(description: "Set blur amount to 25"),
                NotchViewModel.ExecutionStep(description: "Adjust transparency to 60%"),
            ]
        }
    }

    private func executeSteps() {
        viewModel.mode = .executing
        viewModel.isExecuting = true

        Task {
            for i in 0..<viewModel.steps.count {
                await MainActor.run {
                    viewModel.steps[i].status = .running
                    viewModel.currentStepIndex = i
                }

                // Execute step
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                await MainActor.run {
                    viewModel.steps[i].status = .completed
                }
            }

            await MainActor.run {
                viewModel.isExecuting = false
                viewModel.mode = .responding
                viewModel.response = "Done! Glass effect has been applied to your element."
            }
        }
    }
}
