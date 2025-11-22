//
//  TaskScheduler.swift
//  Cloe
//
//  Autonomous task scheduler - executes tasks while user is away
//

import Foundation
import AppKit

// MARK: - Task Models

struct ScheduledTask: Codable, Identifiable {
    let id: UUID
    var title: String
    var description: String
    var command: String
    var scheduledTime: Date?
    var priority: TaskPriority
    var status: TaskStatus
    var requiresUserInput: Bool
    var canRunAutonomously: Bool
    var result: TaskResult?
    var createdAt: Date
    var updatedAt: Date

    enum TaskPriority: String, Codable {
        case low, medium, high, urgent
    }

    enum TaskStatus: String, Codable {
        case pending, scheduled, running, completed, failed, blocked
    }
}

struct TaskResult: Codable {
    let success: Bool
    let message: String
    let completedAt: Date
}

// MARK: - Task Scheduler

class TaskScheduler {
    static let shared = TaskScheduler()

    // MARK: - Properties

    private var taskQueue: [ScheduledTask] = []
    private var isAutonomousModeActive = false
    private var autonomousTimer: Timer?

    private let taskQueuePath: String

    // User activity monitoring
    private var lastActivityTime = Date()
    private var activityMonitorTimer: Timer?

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cloeDir = appSupport.appendingPathComponent("Cloe", isDirectory: true)
        try? FileManager.default.createDirectory(at: cloeDir, withIntermediateDirectories: true)

        taskQueuePath = cloeDir.appendingPathComponent("task_queue.json").path

        loadTaskQueue()
    }

    // MARK: - Task Queue Management

    func addTask(_ task: ScheduledTask) {
        taskQueue.append(task)
        saveTaskQueue()

        print("[NOTE] Task added: \(task.title)")

        // If autonomous mode is active, process immediately
        if isAutonomousModeActive && task.canRunAutonomously {
            Task {
                await processTask(task)
            }
        }
    }

    func removeTask(id: UUID) {
        taskQueue.removeAll { $0.id == id }
        saveTaskQueue()
    }

    func updateTask(_ task: ScheduledTask) {
        if let index = taskQueue.firstIndex(where: { $0.id == task.id }) {
            taskQueue[index] = task
            saveTaskQueue()
        }
    }

    func getPendingTasks() -> [ScheduledTask] {
        return taskQueue.filter { $0.status == .pending || $0.status == .scheduled }
    }

    func getCompletedTasks() -> [ScheduledTask] {
        return taskQueue.filter { $0.status == .completed }
    }

    // MARK: - Autonomous Mode

    func start() {
        print("[BOT] Task Scheduler started")

        // Start activity monitoring
        startActivityMonitoring()

        // Check if autonomous mode should activate
        checkAutonomousMode()
    }

    func stop() {
        stopAutonomousMode()
        activityMonitorTimer?.invalidate()
    }

    private func startActivityMonitoring() {
        // Monitor user activity every minute
        activityMonitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkUserActivity()
        }
    }

    private func checkUserActivity() {
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .any)

        if idleTime > 120 { // 2 minutes idle
            lastActivityTime = Date().addingTimeInterval(-idleTime)
            checkAutonomousMode()
        } else {
            lastActivityTime = Date()

            // User is active, stop autonomous mode if running
            if isAutonomousModeActive {
                stopAutonomousMode()
            }
        }
    }

    private func checkAutonomousMode() {
        // Check if we should activate autonomous mode
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        // Autonomous mode conditions:
        // 1. User idle for 2+ hours OR
        // 2. It's night time (10pm - 6am)
        let userIdle = Date().timeIntervalSince(lastActivityTime) > 7200 // 2 hours
        let isNightTime = hour >= 22 || hour <= 6

        // Check if autonomous mode is enabled in settings
        let autonomousEnabled = UserDefaults.standard.bool(forKey: "autonomousModeEnabled")

        if autonomousEnabled && (userIdle || isNightTime) && !isAutonomousModeActive {
            startAutonomousMode()
        }
    }

    private func startAutonomousMode() {
        print("[NIGHT] Autonomous mode activated")
        isAutonomousModeActive = true

        // Notify via menu bar icon
        NotificationCenter.default.post(name: .autonomousModeChanged, object: true)

        // Process pending tasks
        Task {
            await processPendingTasks()
        }

        // Set up periodic processing
        autonomousTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.processPendingTasks()
            }
        }
    }

    private func stopAutonomousMode() {
        guard isAutonomousModeActive else { return }

        print("[DAY] Autonomous mode deactivated")
        isAutonomousModeActive = false

        autonomousTimer?.invalidate()
        autonomousTimer = nil

        // Notify
        NotificationCenter.default.post(name: .autonomousModeChanged, object: false)
    }

    // MARK: - Task Processing

    private func processPendingTasks() async {
        let pendingTasks = getPendingTasks()

        print("[SYNC] Processing \(pendingTasks.count) pending tasks")

        for task in pendingTasks {
            // Check if task can be executed
            if canExecuteTask(task) {
                await processTask(task)
            }
        }
    }

    private func canExecuteTask(_ task: ScheduledTask) -> Bool {
        // Check if task can run autonomously
        guard task.canRunAutonomously else {
            print("[PAUSE]️  Task requires user input: \(task.title)")
            return false
        }

        // Check smart timing rules
        if !checkSmartTiming(for: task) {
            print("[TIME] Task timing not appropriate: \(task.title)")
            return false
        }

        // Check if scheduled time has passed
        if let scheduledTime = task.scheduledTime {
            guard Date() >= scheduledTime else {
                print("[WAIT] Task not yet scheduled: \(task.title)")
                return false
            }
        }

        return true
    }

    private func checkSmartTiming(for task: ScheduledTask) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        let preferences = SpatialMemory.shared
        // Get from UserDefaults as fallback
        let noMessageStart = UserDefaults.standard.integer(forKey: "noMessageHoursStart") != 0 ?
            UserDefaults.standard.integer(forKey: "noMessageHoursStart") : 22
        let noMessageEnd = UserDefaults.standard.integer(forKey: "noMessageHoursEnd") != 0 ?
            UserDefaults.standard.integer(forKey: "noMessageHoursEnd") : 7

        // Check if task involves messaging/email
        if task.command.lowercased().contains("send") ||
           task.command.lowercased().contains("email") ||
           task.command.lowercased().contains("message") {

            // Don't send messages during no-message hours
            if hour >= noMessageStart || hour <= noMessageEnd {
                print("[QUIET] Not sending messages during quiet hours")
                return false
            }

            // Don't send to family late at night
            if task.command.lowercased().contains("mom") ||
               task.command.lowercased().contains("dad") ||
               task.command.lowercased().contains("family") {
                if hour >= 21 || hour <= 8 {
                    print("[QUIET] Not messaging family outside appropriate hours")
                    return false
                }
            }
        }

        return true
    }

    private func processTask(_ task: ScheduledTask) async {
        print("[EXEC] Processing task: \(task.title)")

        // Update task status
        var updatedTask = task
        updatedTask.status = .running
        updatedTask.updatedAt = Date()
        updateTask(updatedTask)

        do {
            // Execute task via AgentRuntime
            let context = try await ContextEngine.shared.getCurrentContext()
            let response = try await AgentRuntime.shared.processCommand(task.command, context: context)

            // Execute actions if any
            if let actions = response.actions {
                for action in actions {
                    await AgentRuntime.shared.executeAction(action)
                }
            }

            // Mark as completed
            updatedTask.status = .completed
            updatedTask.result = TaskResult(
                success: true,
                message: response.message,
                completedAt: Date()
            )

            print("[OK] Task completed: \(task.title)")

        } catch {
            // Mark as failed
            updatedTask.status = .failed
            updatedTask.result = TaskResult(
                success: false,
                message: "Error: \(error.localizedDescription)",
                completedAt: Date()
            )

            print("[ERROR] Task failed: \(task.title) - \(error)")
        }

        updatedTask.updatedAt = Date()
        updateTask(updatedTask)
    }

    // MARK: - Persistence

    private func loadTaskQueue() {
        guard FileManager.default.fileExists(atPath: taskQueuePath) else { return }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: taskQueuePath))
            taskQueue = try JSONDecoder().decode([ScheduledTask].self, from: data)
            print("[DATA] Loaded \(taskQueue.count) tasks from queue")
        } catch {
            print("[ERROR] Failed to load task queue: \(error)")
        }
    }

    private func saveTaskQueue() {
        do {
            let data = try JSONEncoder().encode(taskQueue)
            try data.write(to: URL(fileURLWithPath: taskQueuePath))
        } catch {
            print("[ERROR] Failed to save task queue: \(error)")
        }
    }

    // MARK: - Summary Generation

    func generateMorningSummary() -> String {
        let completed = getCompletedTasks().filter {
            Calendar.current.isDateInYesterday($0.updatedAt) ||
            Calendar.current.isDateInToday($0.updatedAt)
        }

        let pending = getPendingTasks()

        var summary = "Good morning! Morning\n\n"

        if !completed.isEmpty {
            summary += "Overnight, I completed:\n"
            for task in completed.prefix(5) {
                summary += "[OK] \(task.title)\n"
            }
            summary += "\n"
        }

        if !pending.isEmpty {
            summary += "Waiting for your approval:\n"
            for task in pending.prefix(3) {
                summary += "[WAIT] \(task.title)\n"
            }
        }

        return summary
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let autonomousModeChanged = Notification.Name("autonomousModeChanged")
}
