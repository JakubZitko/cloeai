//
//  CloudSync.swift
//  Cloe
//
//  Syncs local data to the Cloe web dashboard
//

import Foundation

/// Handles syncing local data to the Cloe cloud dashboard
class CloudSync {
    static let shared = CloudSync()

    private let baseURL: String
    private var authToken: String?
    private var syncTimer: Timer?
    private var lastSyncTime: Date?
    private let syncInterval: TimeInterval = 60 // Sync every 60 seconds

    private init() {
        // Load from environment or config
        self.baseURL = ProcessInfo.processInfo.environment["CLOE_API_URL"] ?? "http://localhost:3000"
        loadAuthToken()
    }

    // MARK: - Authentication

    /// Check if user is logged in
    var isLoggedIn: Bool {
        return authToken != nil
    }

    /// Store auth token after web login
    func setAuthToken(_ token: String) {
        self.authToken = token
        UserDefaults.standard.set(token, forKey: "cloe_auth_token")
        print("[CLOUD] Auth token saved")
    }

    /// Clear auth token on logout
    func logout() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "cloe_auth_token")
        stopSync()
        print("[CLOUD] Logged out")
    }

    private func loadAuthToken() {
        self.authToken = UserDefaults.standard.string(forKey: "cloe_auth_token")
        if authToken != nil {
            print("[CLOUD] Auth token loaded")
        }
    }

    // MARK: - Sync Control

    /// Start periodic sync
    func startSync() {
        guard isLoggedIn else {
            print("[CLOUD] Not logged in, skipping sync")
            return
        }

        guard syncTimer == nil else { return }

        // Initial sync
        Task {
            await performSync()
        }

        // Periodic sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }

        // Periodic ping
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.sendPing()
            }
        }

        print("[CLOUD] Sync started (interval: \(syncInterval)s)")
    }

    /// Stop periodic sync
    func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("[CLOUD] Sync stopped")
    }

    // MARK: - Sync Operations

    /// Perform full sync to cloud
    func performSync() async {
        guard let token = authToken else { return }

        let learning = LearningEngine.shared

        // Get data to sync
        let actions = learning.getRecentActions().map { action in
            [
                "type": action.type.rawValue,
                "app": action.app,
                "target": action.target ?? "",
                "value": action.value ?? "",
                "timestamp": ISO8601DateFormatter().string(from: action.timestamp)
            ]
        }

        let contacts = learning.getLearnedContacts().map { contact in
            [
                "name": contact.name,
                "email": contact.email ?? "",
                "phone": contact.phone ?? "",
                "relationship": contact.relationship ?? "",
                "aliases": contact.aliases,
                "locations": contact.locations.map { ["app": $0.app, "url": $0.url ?? ""] },
                "lastContact": contact.lastContact.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            ] as [String : Any]
        }

        let workflows = learning.getLearnedWorkflows().map { workflow in
            [
                "name": workflow.name,
                "steps": workflow.steps.map { ["app": $0.app, "action": $0.action, "details": $0.details ?? ""] },
                "triggerPatterns": workflow.triggerPatterns,
                "frequency": workflow.frequency,
                "lastUsed": ISO8601DateFormatter().string(from: workflow.lastUsed)
            ] as [String : Any]
        }

        let payload: [String: Any] = [
            "actions": actions,
            "contacts": contacts,
            "workflows": workflows
        ]

        do {
            _ = try await makeRequest(endpoint: "/api/cloe/sync", method: "POST", body: payload)
            lastSyncTime = Date()
            print("[CLOUD] Sync complete - \(actions.count) actions, \(contacts.count) contacts, \(workflows.count) workflows")
        } catch {
            print("[CLOUD] Sync failed: \(error.localizedDescription)")
        }
    }

    /// Send ping to indicate app is connected
    private func sendPing() async {
        guard authToken != nil else { return }

        do {
            _ = try await makeRequest(endpoint: "/api/cloe/ping", method: "POST", body: [:])
        } catch {
            // Silent fail for ping
        }
    }

    /// Record a single action immediately
    func recordAction(type: String, app: String, target: String?, value: String?) async {
        guard authToken != nil else { return }

        let payload: [String: Any] = [
            "type": type,
            "app": app,
            "target": target ?? "",
            "value": value ?? ""
        ]

        do {
            _ = try await makeRequest(endpoint: "/api/cloe/activity", method: "POST", body: payload)
        } catch {
            // Silent fail - will be synced in batch later
        }
    }

    // MARK: - Settings Sync

    /// Fetch settings from cloud
    func fetchSettings() async -> [String: Any]? {
        guard authToken != nil else { return nil }

        do {
            let response = try await makeRequest(endpoint: "/api/cloe/settings", method: "GET", body: nil)
            if let data = response,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["settings"] as? [String: Any] {
                return settings
            }
        } catch {
            print("[CLOUD] Failed to fetch settings: \(error)")
        }

        return nil
    }

    /// Save settings to cloud
    func saveSettings(_ settings: [String: Any]) async {
        guard authToken != nil else { return }

        do {
            _ = try await makeRequest(endpoint: "/api/cloe/settings", method: "PUT", body: settings)
            print("[CLOUD] Settings saved")
        } catch {
            print("[CLOUD] Failed to save settings: \(error)")
        }
    }

    // MARK: - HTTP Client

    private func makeRequest(endpoint: String, method: String, body: [String: Any]?) async throws -> Data? {
        guard let url = URL(string: baseURL + endpoint) else {
            throw CloudError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Token expired - logout
            logout()
            throw CloudError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            throw CloudError.serverError(httpResponse.statusCode)
        }

        return data
    }

    enum CloudError: Error {
        case invalidURL
        case invalidResponse
        case unauthorized
        case serverError(Int)
    }
}
