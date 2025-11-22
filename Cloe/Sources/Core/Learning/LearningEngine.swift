//
//  LearningEngine.swift
//  Cloe
//
//  Watches and learns from user behavior
//  Remembers workflows, contacts, preferences, patterns
//

import Foundation
import AppKit

/// Learns from user behavior over time
class LearningEngine {
    static let shared = LearningEngine()

    private let memory: SpatialMemory
    private var isObserving = false
    private var observationTimer: Timer?

    // Recent observations
    private var recentApps: [AppUsage] = []
    private var recentActions: [UserAction] = []
    private var learnedWorkflows: [Workflow] = []

    private init() {
        self.memory = SpatialMemory.shared
        loadLearnedData()
    }

    // MARK: - Data Models

    struct AppUsage: Codable {
        let appName: String
        let bundleId: String
        let timestamp: Date
        let duration: TimeInterval
        let windowTitle: String?
    }

    struct UserAction: Codable {
        let id: UUID
        let type: ActionType
        let app: String
        let target: String?
        let value: String?
        let timestamp: Date

        enum ActionType: String, Codable {
            case openApp
            case closeApp
            case switchApp
            case openFile
            case saveFile
            case copyText
            case pasteText
            case sendEmail
            case openURL
            case search
        }
    }

    struct Workflow: Codable, Identifiable {
        let id: UUID
        var name: String
        var steps: [WorkflowStep]
        var triggerPatterns: [String] // Natural language triggers
        var frequency: Int
        var lastUsed: Date
    }

    struct WorkflowStep: Codable {
        let app: String
        let action: String
        let details: String?
    }

    struct Contact: Codable, Identifiable {
        let id: UUID
        var name: String
        var aliases: [String] // "Mr Johnson", "lawyer", "John"
        var email: String?
        var phone: String?
        var locations: [ContactLocation] // Where you've contacted them
        var relationship: String? // "lawyer", "mom", "boss"
        var lastContact: Date?
        var conversationHistory: [String]?
    }

    struct ContactLocation: Codable {
        let app: String // "Safari", "Mail", "Messages"
        let url: String? // For web-based contacts
        let identifier: String? // Email thread ID, message ID
    }

    // MARK: - Start/Stop Learning

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        // Observe workspace notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        // Periodic observation
        observationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.captureSnapshot()
        }

        print("[BRAIN] LearningEngine: Started observing")
    }

    func stopObserving() {
        isObserving = false
        observationTimer?.invalidate()
        observationTimer = nil

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        saveLearnedData()

        print("[BRAIN] LearningEngine: Stopped observing")
    }

    // MARK: - Observation Callbacks

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let usage = AppUsage(
            appName: app.localizedName ?? "Unknown",
            bundleId: app.bundleIdentifier ?? "",
            timestamp: Date(),
            duration: 0,
            windowTitle: getActiveWindowTitle()
        )

        recentApps.append(usage)

        // Keep only last 100
        if recentApps.count > 100 {
            recentApps.removeFirst()
        }

        recordAction(
            type: .switchApp,
            app: usage.appName,
            target: usage.windowTitle
        )
    }

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        recordAction(
            type: .openApp,
            app: app.localizedName ?? "Unknown",
            target: nil
        )
    }

    private func captureSnapshot() {
        // Capture current screen state for learning
        let contextEngine = ContextEngine.shared

        Task {
            if let context = await contextEngine.captureContext() {
                // Store interesting patterns
                analyzeContext(context)
            }
        }
    }

    private func getActiveWindowTitle() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        if let window = focusedWindow {
            var title: AnyObject?
            AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title)
            return title as? String
        }

        return nil
    }

    // MARK: - Recording Actions

    func recordAction(type: UserAction.ActionType, app: String, target: String?, value: String? = nil) {
        let action = UserAction(
            id: UUID(),
            type: type,
            app: app,
            target: target,
            value: value,
            timestamp: Date()
        )

        recentActions.append(action)

        // Keep only last 500
        if recentActions.count > 500 {
            recentActions.removeFirst()
        }

        // Check if this completes a workflow pattern
        detectWorkflowPattern()
    }

    // MARK: - Contact Learning

    private var learnedContacts: [Contact] = []

    /// Learn a new contact from user behavior
    func learnContact(name: String, from app: String, email: String? = nil, url: String? = nil) {
        // Check if we already know this contact
        if let existingIndex = learnedContacts.firstIndex(where: {
            $0.name.lowercased() == name.lowercased() ||
            $0.aliases.contains(where: { $0.lowercased() == name.lowercased() })
        }) {
            // Update existing contact
            var contact = learnedContacts[existingIndex]
            contact.lastContact = Date()

            let location = ContactLocation(app: app, url: url, identifier: nil)
            if !contact.locations.contains(where: { $0.app == app && $0.url == url }) {
                contact.locations.append(location)
            }

            if let email = email, contact.email == nil {
                contact.email = email
            }

            learnedContacts[existingIndex] = contact
        } else {
            // Create new contact
            let contact = Contact(
                id: UUID(),
                name: name,
                aliases: [],
                email: email,
                phone: nil,
                locations: [ContactLocation(app: app, url: url, identifier: nil)],
                relationship: nil,
                lastContact: Date(),
                conversationHistory: nil
            )
            learnedContacts.append(contact)
        }

        saveLearnedData()
    }

    /// Find a contact by name or alias
    func findContact(query: String) -> Contact? {
        let lowerQuery = query.lowercased()

        return learnedContacts.first { contact in
            contact.name.lowercased().contains(lowerQuery) ||
            contact.aliases.contains { $0.lowercased().contains(lowerQuery) } ||
            contact.relationship?.lowercased().contains(lowerQuery) ?? false
        }
    }

    /// Get where to contact someone
    func getContactLocation(for contact: Contact) -> ContactLocation? {
        // Prefer most recently used location
        return contact.locations.first
    }

    // MARK: - Workflow Learning

    private func detectWorkflowPattern() {
        // Look for repeated sequences in recent actions
        guard recentActions.count >= 3 else { return }

        let lastThree = Array(recentActions.suffix(3))

        // Check if this sequence repeats
        let pattern = lastThree.map { "\($0.app):\($0.type.rawValue)" }.joined(separator: "->")

        // Simple pattern detection: if we've seen this sequence before, it might be a workflow
        let existingWorkflow = learnedWorkflows.first { workflow in
            workflow.steps.count == 3 &&
            workflow.steps.enumerated().allSatisfy { index, step in
                step.app == lastThree[index].app
            }
        }

        if var workflow = existingWorkflow {
            workflow.frequency += 1
            workflow.lastUsed = Date()
        }
    }

    /// Learn a workflow from user description
    func learnWorkflow(name: String, steps: [WorkflowStep], triggers: [String]) {
        let workflow = Workflow(
            id: UUID(),
            name: name,
            steps: steps,
            triggerPatterns: triggers,
            frequency: 0,
            lastUsed: Date()
        )

        learnedWorkflows.append(workflow)
        saveLearnedData()
    }

    /// Find a workflow by trigger phrase
    func findWorkflow(query: String) -> Workflow? {
        let lowerQuery = query.lowercased()

        return learnedWorkflows.first { workflow in
            workflow.triggerPatterns.contains { trigger in
                lowerQuery.contains(trigger.lowercased())
            }
        }
    }

    // MARK: - Context Analysis

    private func analyzeContext(_ context: ScreenContext) {
        // Look for interesting patterns in the screen content
        let text = context.extractedText

        // Email patterns
        let emailPattern = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let email = String(text[range])
                    // Try to find associated name
                    learnEmailFromContext(email: email, context: text)
                }
            }
        }
    }

    private func learnEmailFromContext(email: String, context: String) {
        // Simple heuristic: look for names near the email
        // This is a simplified version - real implementation would use NLP

        let words = context.components(separatedBy: .whitespacesAndNewlines)
        if let emailIndex = words.firstIndex(of: email), emailIndex > 0 {
            // Look at words before email for a name
            let potentialName = words[max(0, emailIndex - 2)..<emailIndex].joined(separator: " ")
            if !potentialName.isEmpty && potentialName.count > 3 {
                learnContact(
                    name: potentialName,
                    from: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown",
                    email: email
                )
            }
        }
    }

    // MARK: - Query Knowledge

    /// Answer a question using learned knowledge
    func queryKnowledge(_ query: String) -> String? {
        let lowerQuery = query.lowercased()

        // Contact queries
        if lowerQuery.contains("email") || lowerQuery.contains("contact") || lowerQuery.contains("send") {
            // Extract who they're looking for
            let words = query.components(separatedBy: .whitespaces)
            for word in words {
                if let contact = findContact(query: word) {
                    if let email = contact.email {
                        return "I found \(contact.name)'s email: \(email). They're usually contacted via \(contact.locations.first?.app ?? "email")."
                    }
                    if let location = contact.locations.first {
                        return "I remember you contacted \(contact.name) in \(location.app). Should I open that?"
                    }
                }
            }
        }

        // Workflow queries
        if let workflow = findWorkflow(query: query) {
            return "I know how to do '\(workflow.name)'. It involves: \(workflow.steps.map { $0.action }.joined(separator: ", "))"
        }

        return nil
    }

    // MARK: - Public Accessors for UI

    /// Get all recent actions for Activity Log
    func getRecentActions() -> [UserAction] {
        return recentActions
    }

    /// Get all recent app usage
    func getRecentAppUsage() -> [AppUsage] {
        return recentApps
    }

    /// Get all learned workflows
    func getLearnedWorkflows() -> [Workflow] {
        return learnedWorkflows
    }

    /// Get all learned contacts
    func getLearnedContacts() -> [Contact] {
        return learnedContacts
    }

    /// Get learning statistics
    func getStatistics() -> (actions: Int, contacts: Int, workflows: Int, apps: Int) {
        return (
            actions: recentActions.count,
            contacts: learnedContacts.count,
            workflows: learnedWorkflows.count,
            apps: Set(recentApps.map { $0.appName }).count
        )
    }

    // MARK: - Persistence

    private func loadLearnedData() {
        let defaults = UserDefaults.standard

        if let contactsData = defaults.data(forKey: "cloe_contacts"),
           let contacts = try? JSONDecoder().decode([Contact].self, from: contactsData) {
            learnedContacts = contacts
        }

        if let workflowsData = defaults.data(forKey: "cloe_workflows"),
           let workflows = try? JSONDecoder().decode([Workflow].self, from: workflowsData) {
            learnedWorkflows = workflows
        }

        print("[BRAIN] LearningEngine: Loaded \(learnedContacts.count) contacts, \(learnedWorkflows.count) workflows")
    }

    private func saveLearnedData() {
        let defaults = UserDefaults.standard

        if let contactsData = try? JSONEncoder().encode(learnedContacts) {
            defaults.set(contactsData, forKey: "cloe_contacts")
        }

        if let workflowsData = try? JSONEncoder().encode(learnedWorkflows) {
            defaults.set(workflowsData, forKey: "cloe_workflows")
        }
    }
}

// MARK: - Screen Context (from ContextEngine)

struct ScreenContext {
    let activeApp: String
    let windowTitle: String
    let extractedText: String
    let timestamp: Date
}
