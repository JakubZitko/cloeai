//
//  NightWorker.swift
//  Cloe
//
//  Autonomous task completion during off-hours
//  Knows when it's appropriate to do things (won't text mom at 3am)
//

import Foundation
import AppKit
import UserNotifications

/// Handles autonomous overnight task completion
class NightWorker {
    static let shared = NightWorker()

    private var isActive = false
    private var nightTimer: Timer?
    private var pendingTasks: [CloeTask] = []
    private let learning = LearningEngine.shared

    private init() {
        loadPendingTasks()
        setupNotifications()
    }

    // MARK: - Task Model

    struct CloeTask: Codable, Identifiable {
        let id: UUID
        var description: String
        var type: TaskType
        var priority: Priority
        var createdAt: Date
        var scheduledFor: Date?
        var status: TaskStatus
        var contactName: String?
        var details: [String: String]

        enum TaskType: String, Codable {
            case sendMessage
            case sendEmail
            case completeWork
            case research
            case organize
            case reminder
            case download
            case backup
        }

        enum Priority: String, Codable {
            case urgent
            case high
            case normal
            case low
        }

        enum TaskStatus: String, Codable {
            case pending
            case scheduled
            case inProgress
            case completed
            case skipped
            case failed
        }
    }

    // MARK: - Social Awareness

    struct SocialRules {
        // Time windows when certain actions are appropriate
        static let messageHours = 8...22 // 8am to 10pm
        static let workHours = 9...18 // 9am to 6pm
        static let quietHours = 22...8 // 10pm to 8am (next day)

        // Special relationships
        static let closeRelationships = ["mom", "dad", "wife", "husband", "partner", "family"]
        static let workRelationships = ["boss", "colleague", "client", "coworker"]
    }

    /// Check if it's appropriate to perform an action right now
    func isAppropriateTime(for task: CloeTask) -> (appropriate: Bool, reason: String?) {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7

        switch task.type {
        case .sendMessage, .sendEmail:
            // Check who we're contacting
            if let contact = task.contactName?.lowercased() {
                // Close family - be more flexible but still respectful
                if SocialRules.closeRelationships.contains(where: { contact.contains($0) }) {
                    if hour < 7 || hour > 23 {
                        return (false, "It's too early/late to message \(task.contactName ?? "them"). I'll wait until morning.")
                    }
                }

                // Work contacts - only during business hours
                if SocialRules.workRelationships.contains(where: { contact.contains($0) }) {
                    if !SocialRules.workHours.contains(hour) || isWeekend {
                        return (false, "It's outside work hours. I'll send this on the next business day.")
                    }
                }
            }

            // General messages - respect quiet hours
            if !SocialRules.messageHours.contains(hour) {
                return (false, "It's late. I'll send this tomorrow morning at 8am.")
            }

            return (true, nil)

        case .completeWork, .research, .organize:
            // These are fine anytime - they don't disturb anyone
            return (true, nil)

        case .reminder:
            // Only remind during waking hours
            if hour < 7 || hour > 22 {
                return (false, "I'll remind you tomorrow morning.")
            }
            return (true, nil)

        case .download, .backup:
            // Actually better at night (less network usage)
            return (true, nil)
        }
    }

    /// Get the next appropriate time for a task
    func nextAppropriateTime(for task: CloeTask) -> Date {
        var calendar = Calendar.current
        var date = Date()

        switch task.type {
        case .sendMessage, .sendEmail:
            // Next 8am
            if let contact = task.contactName?.lowercased(),
               SocialRules.workRelationships.contains(where: { contact.contains($0) }) {
                // Next 9am on a weekday
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = 9
                components.minute = 0

                if let nextDate = calendar.date(from: components) {
                    date = nextDate

                    // If it's already past 9am, go to tomorrow
                    if date <= Date() {
                        date = calendar.date(byAdding: .day, value: 1, to: date)!
                    }

                    // Skip weekends
                    let dayOfWeek = calendar.component(.weekday, from: date)
                    if dayOfWeek == 1 { // Sunday
                        date = calendar.date(byAdding: .day, value: 1, to: date)!
                    } else if dayOfWeek == 7 { // Saturday
                        date = calendar.date(byAdding: .day, value: 2, to: date)!
                    }
                }
            } else {
                // Next 8am
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = 8
                components.minute = 0

                if let nextDate = calendar.date(from: components) {
                    date = nextDate
                    if date <= Date() {
                        date = calendar.date(byAdding: .day, value: 1, to: date)!
                    }
                }
            }

        case .reminder:
            // Next 8am
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = 8
            components.minute = 0

            if let nextDate = calendar.date(from: components) {
                date = nextDate
                if date <= Date() {
                    date = calendar.date(byAdding: .day, value: 1, to: date)!
                }
            }

        default:
            // Can be done now
            break
        }

        return date
    }

    // MARK: - Task Management

    /// Add a task to be completed
    func addTask(_ task: CloeTask) {
        var mutableTask = task

        // Check if it's already done
        if checkIfAlreadyDone(task) {
            mutableTask.status = .completed
            print("OK Task '\(task.description)' was already completed by user")
            return
        }

        // Check timing
        let timing = isAppropriateTime(for: task)
        if !timing.appropriate {
            mutableTask.scheduledFor = nextAppropriateTime(for: task)
            mutableTask.status = .scheduled
            print("[TIME] Task '\(task.description)' scheduled for \(mutableTask.scheduledFor!)")
        }

        pendingTasks.append(mutableTask)
        savePendingTasks()
    }

    /// Check if user already completed this task
    private func checkIfAlreadyDone(_ task: CloeTask) -> Bool {
        // Check recent actions from LearningEngine
        // This is a simplified check - real implementation would be more sophisticated

        switch task.type {
        case .sendMessage, .sendEmail:
            // Check if message was sent to this contact recently
            if let contact = task.contactName,
               let learnedContact = learning.findContact(query: contact) {
                // If contacted in last hour, assume done
                if let lastContact = learnedContact.lastContact,
                   Date().timeIntervalSince(lastContact) < 3600 {
                    return true
                }
            }

        default:
            break
        }

        return false
    }

    /// Get today's pending tasks
    func getTodaysTasks() -> [CloeTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return pendingTasks.filter { task in
            task.status == .pending ||
            (task.status == .scheduled &&
             task.scheduledFor.map { calendar.isDate($0, inSameDayAs: today) } ?? false)
        }
    }

    /// Get unfinished tasks from today
    func getUnfinishedTasks() -> [CloeTask] {
        return pendingTasks.filter { $0.status == .pending || $0.status == .scheduled }
    }

    // MARK: - Night Mode

    /// Start night mode - autonomous completion
    func startNightMode() {
        guard !isActive else { return }
        isActive = true

        print("[NIGHT] NightWorker: Starting night mode")

        // Check every 30 minutes for tasks to complete
        nightTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.processNightTasks()
        }

        // Process immediately
        processNightTasks()
    }

    func stopNightMode() {
        isActive = false
        nightTimer?.invalidate()
        nightTimer = nil

        print("[DAY] NightWorker: Night mode ended")
    }

    private func processNightTasks() {
        let unfinished = getUnfinishedTasks()

        for (index, task) in unfinished.enumerated() {
            // Check if user already did it
            if checkIfAlreadyDone(task) {
                pendingTasks[index].status = .completed
                continue
            }

            // Check timing
            let timing = isAppropriateTime(for: task)

            if timing.appropriate {
                // Execute the task
                Task {
                    await executeTask(task, at: index)
                }
            } else if let reason = timing.reason {
                print("[PAUSE] Skipping '\(task.description)': \(reason)")

                // Reschedule
                pendingTasks[index].scheduledFor = nextAppropriateTime(for: task)
                pendingTasks[index].status = .scheduled
            }
        }

        savePendingTasks()
    }

    private func executeTask(_ task: CloeTask, at index: Int) async {
        print("[SYNC] Executing: \(task.description)")
        pendingTasks[index].status = .inProgress

        var success = false

        switch task.type {
        case .research:
            // Search and compile information
            success = await performResearch(task)

        case .download:
            // Download files
            success = await performDownload(task)

        case .backup:
            // Backup files
            success = await performBackup(task)

        case .organize:
            // Organize files/folders
            success = await performOrganization(task)

        case .sendEmail:
            // Compose and send email
            success = await performSendEmail(task)

        case .sendMessage:
            // Send message
            success = await performSendMessage(task)

        case .completeWork:
            // Try to complete the work task
            success = await performWorkTask(task)

        case .reminder:
            // Show reminder notification
            success = await showReminder(task)
        }

        pendingTasks[index].status = success ? .completed : .failed
        savePendingTasks()

        if success {
            print("OK Completed: \(task.description)")
        } else {
            print("FAIL Failed: \(task.description)")
        }
    }

    // MARK: - Task Execution

    private func performResearch(_ task: CloeTask) async -> Bool {
        // Use TutorialFinder to search for information
        guard let topic = task.details["topic"] else { return false }

        do {
            let results = try await TutorialFinder.shared.findTutorial(query: topic, app: "")

            if !results.isEmpty {
                // Save results to a note or document
                let summary = results.prefix(5).map { "- \($0.title): \($0.url)" }.joined(separator: "\n")

                // Create a note file
                let notesPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop/Cloe Research")

                try? FileManager.default.createDirectory(at: notesPath, withIntermediateDirectories: true)

                let fileName = topic.replacingOccurrences(of: " ", with: "_") + ".txt"
                let filePath = notesPath.appendingPathComponent(fileName)

                let content = """
                Research: \(topic)
                Date: \(Date())

                Sources:
                \(summary)
                """

                try content.write(to: filePath, atomically: true, encoding: .utf8)

                return true
            }
        } catch {
            print("Research error: \(error)")
        }

        return false
    }

    private func performDownload(_ task: CloeTask) async -> Bool {
        guard let urlString = task.details["url"],
              let url = URL(string: urlString) else { return false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let downloadsPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads")

            let fileName = url.lastPathComponent
            let filePath = downloadsPath.appendingPathComponent(fileName)

            try data.write(to: filePath)
            return true
        } catch {
            print("Download error: \(error)")
            return false
        }
    }

    private func performBackup(_ task: CloeTask) async -> Bool {
        guard let sourcePath = task.details["source"] else { return false }

        let source = URL(fileURLWithPath: sourcePath)
        let backupPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Backups/Cloe")
            .appendingPathComponent(Date().ISO8601Format())

        do {
            try FileManager.default.createDirectory(at: backupPath, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: backupPath.appendingPathComponent(source.lastPathComponent))
            return true
        } catch {
            print("Backup error: \(error)")
            return false
        }
    }

    private func performOrganization(_ task: CloeTask) async -> Bool {
        guard let targetPath = task.details["path"] else {
            print("[NightWorker] Organization task missing path")
            return false
        }

        let url = URL(fileURLWithPath: targetPath)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: targetPath) else {
            print("[NightWorker] Path does not exist: \(targetPath)")
            return false
        }

        do {
            // Get directory contents
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentTypeKey, .creationDateKey])

            // Create organized folders
            let categories: [String: [String]] = [
                "Documents": ["pdf", "doc", "docx", "txt", "rtf", "pages", "odt"],
                "Images": ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"],
                "Videos": ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"],
                "Audio": ["mp3", "wav", "aac", "flac", "m4a", "ogg"],
                "Archives": ["zip", "rar", "7z", "tar", "gz", "dmg"],
                "Code": ["swift", "js", "py", "java", "cpp", "c", "h", "html", "css", "json", "xml"]
            ]

            var movedCount = 0

            for file in contents {
                let ext = file.pathExtension.lowercased()
                var targetFolder: String?

                for (folder, extensions) in categories {
                    if extensions.contains(ext) {
                        targetFolder = folder
                        break
                    }
                }

                if let folder = targetFolder {
                    let destinationFolder = url.appendingPathComponent(folder)

                    // Create folder if needed
                    if !fileManager.fileExists(atPath: destinationFolder.path) {
                        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
                    }

                    // Move file
                    let destination = destinationFolder.appendingPathComponent(file.lastPathComponent)
                    if !fileManager.fileExists(atPath: destination.path) {
                        try fileManager.moveItem(at: file, to: destination)
                        movedCount += 1
                    }
                }
            }

            print("[NightWorker] Organized \(movedCount) files in \(targetPath)")
            return movedCount > 0

        } catch {
            print("[NightWorker] Organization error: \(error)")
            return false
        }
    }

    private func performSendEmail(_ task: CloeTask) async -> Bool {
        guard let to = task.details["to"],
              let subject = task.details["subject"],
              let body = task.details["body"] else { return false }

        // Open Mail.app with compose window
        let mailtoString = "mailto:\(to)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: mailtoString) {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
            return true
        }

        return false
    }

    private func performSendMessage(_ task: CloeTask) async -> Bool {
        guard let recipient = task.contactName ?? task.details["to"],
              let message = task.details["message"] else {
            print("[NightWorker] Message task missing recipient or message")
            return false
        }

        // Use AppleScript to send via Messages.app
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedRecipient = recipient.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to participant "\(escapedRecipient)" of targetService
            send "\(escapedMessage)" to targetBuddy
        end tell
        """

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            print("[NightWorker] Failed to create AppleScript for message")
            return false
        }

        scriptObject.executeAndReturnError(&error)

        if let error = error {
            // Try alternative method using buddy by phone/email
            let altScript = """
            tell application "Messages"
                send "\(escapedMessage)" to buddy "\(escapedRecipient)" of (service 1 whose service type is iMessage)
            end tell
            """

            guard let altScriptObject = NSAppleScript(source: altScript) else {
                print("[NightWorker] Message send failed: \(error)")
                return false
            }

            var altError: NSDictionary?
            altScriptObject.executeAndReturnError(&altError)

            if let altError = altError {
                print("[NightWorker] Message send failed: \(altError)")
                return false
            }
        }

        print("[NightWorker] Sent message to \(recipient)")
        return true
    }

    private func performWorkTask(_ task: CloeTask) async -> Bool {
        // Use ActionExecutor to complete work tasks
        guard let workType = task.details["type"] else {
            print("[NightWorker] Work task missing type")
            return false
        }

        let executor = ActionExecutor.shared

        switch workType {
        case "open_app":
            if let appName = task.details["app"] {
                return await executor.openApplication(named: appName)
            }

        case "open_file":
            if let filePath = task.details["path"] {
                return await executor.openFile(at: filePath)
            }

        case "run_script":
            if let scriptPath = task.details["script"] {
                return await executor.runScript(at: scriptPath)
            }

        case "create_document":
            if let docType = task.details["doc_type"],
               let title = task.details["title"] {
                return await executor.createDocument(type: docType, title: title)
            }

        case "compile_report":
            if let topic = task.details["topic"] {
                // Research and compile into a document
                let researchTask = CloeTask(
                    id: UUID(),
                    description: "Research for: \(topic)",
                    type: .research,
                    priority: .normal,
                    createdAt: Date(),
                    scheduledFor: nil,
                    status: .pending,
                    contactName: nil,
                    details: ["topic": topic]
                )
                return await performResearch(researchTask)
            }

        default:
            print("[NightWorker] Unknown work task type: \(workType)")
        }

        return false
    }

    private func showReminder(_ task: CloeTask) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "Cloe Reminder"
        content.body = task.description
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil // Immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("Notification error: \(error)")
            return false
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("OK Notification permission granted")
            }
        }
    }

    // MARK: - Persistence

    private func loadPendingTasks() {
        if let data = UserDefaults.standard.data(forKey: "cloe_pending_tasks"),
           let tasks = try? JSONDecoder().decode([CloeTask].self, from: data) {
            pendingTasks = tasks
        }
    }

    private func savePendingTasks() {
        if let data = try? JSONEncoder().encode(pendingTasks) {
            UserDefaults.standard.set(data, forKey: "cloe_pending_tasks")
        }
    }
}
