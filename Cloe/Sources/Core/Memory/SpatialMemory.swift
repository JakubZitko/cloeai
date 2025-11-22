//
//  SpatialMemory.swift
//  Cloe
//
//  Spatial memory graph - remembers where things are and how to do tasks
//

import Foundation
import SQLite3

class SpatialMemory {
    static let shared = SpatialMemory()

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbPath: String

    private var entities: [String: Entity] = [:]
    private var workflows: [String: Workflow] = [:]
    private var preferences: UserPreferences = UserPreferences()

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cloeDir = appSupport.appendingPathComponent("Cloe", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: cloeDir, withIntermediateDirectories: true)

        dbPath = cloeDir.appendingPathComponent("memory.db").path

        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[ERROR] Failed to open database")
        } else {
            print("[OK] Memory database opened: \(dbPath)")
        }
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func createTables() {
        let createEntitiesTable = """
        CREATE TABLE IF NOT EXISTS entities (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            metadata TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """

        let createLocationsTable = """
        CREATE TABLE IF NOT EXISTS locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_id TEXT NOT NULL,
            app TEXT NOT NULL,
            context TEXT,
            path TEXT,
            last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (entity_id) REFERENCES entities(id)
        );
        """

        let createWorkflowsTable = """
        CREATE TABLE IF NOT EXISTS workflows (
            id TEXT PRIMARY KEY,
            pattern TEXT NOT NULL,
            steps TEXT NOT NULL,
            success_count INTEGER DEFAULT 0,
            failure_count INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """

        let createActionsTable = """
        CREATE TABLE IF NOT EXISTS actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tool TEXT NOT NULL,
            parameters TEXT,
            result TEXT,
            success BOOLEAN,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """

        executeSQLquiet(createEntitiesTable)
        executeSQLQuiet(createLocationsTable)
        executeSQLQuiet(createWorkflowsTable)
        executeSQLQuiet(createActionsTable)
    }

    private func executeSQLQuiet(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                // Success
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Public Methods

    func load() {
        print("[DATA] Loading spatial memory...")
        loadEntities()
        loadWorkflows()
        loadPreferences()
    }

    func save() {
        // Data is saved to SQLite in real-time
        savePreferences()
    }

    // MARK: - Entity Management

    func recordEntity(id: String, type: EntityType, name: String, location: EntityLocation) {
        entities[id] = Entity(id: id, type: type, name: name, locations: [location], metadata: [:])

        // Save to database
        let insertEntity = """
        INSERT OR REPLACE INTO entities (id, type, name, metadata, updated_at)
        VALUES (?, ?, ?, ?, datetime('now'));
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertEntity, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (type.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, "{}", -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("[OK] Entity saved: \(name)")
            }
        }
        sqlite3_finalize(statement)

        // Save location
        recordLocation(entityID: id, location: location)
    }

    private func recordLocation(entityID: String, location: EntityLocation) {
        let insertLocation = """
        INSERT INTO locations (entity_id, app, context, path, last_seen)
        VALUES (?, ?, ?, ?, datetime('now'));
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertLocation, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (entityID as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (location.app as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (location.context as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (location.path ?? "" as NSString).utf8String, -1, nil)

            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func findEntity(name: String) -> Entity? {
        return entities.values.first { $0.name.lowercased().contains(name.lowercased()) }
    }

    // MARK: - Workflow Management

    func recordWorkflow(pattern: String, steps: [WorkflowStep]) {
        let id = pattern.lowercased().replacingOccurrences(of: " ", with: "_")

        workflows[id] = Workflow(id: id, pattern: pattern, steps: steps, successCount: 0, failureCount: 0)

        // Save to database
        let stepsJSON = try? JSONEncoder().encode(steps)
        let stepsString = stepsJSON != nil ? String(data: stepsJSON!, encoding: .utf8) : "[]"

        let insertWorkflow = """
        INSERT OR REPLACE INTO workflows (id, pattern, steps, updated_at)
        VALUES (?, ?, ?, datetime('now'));
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertWorkflow, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (pattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (stepsString! as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("[OK] Workflow saved: \(pattern)")
            }
        }
        sqlite3_finalize(statement)
    }

    func findWorkflow(pattern: String) -> Workflow? {
        return workflows.values.first { $0.pattern.lowercased().contains(pattern.lowercased()) }
    }

    // MARK: - Action Recording

    func recordAction(tool: String, parameters: [String: Any], result: ToolResult) {
        let parametersJSON = try? JSONSerialization.data(withJSONObject: parameters)
        let parametersString = parametersJSON != nil ? String(data: parametersJSON!, encoding: .utf8) : "{}"

        let resultJSON = try? JSONSerialization.data(withJSONObject: [
            "success": result.success,
            "message": result.message
        ])
        let resultString = resultJSON != nil ? String(data: resultJSON!, encoding: .utf8) : "{}"

        let insertAction = """
        INSERT INTO actions (tool, parameters, result, success)
        VALUES (?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertAction, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (tool as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (parametersString! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (resultString! as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 4, result.success ? 1 : 0)

            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Search

    func search(query: String, limit: Int = 5) -> [MemoryEntry] {
        // TODO: Implement semantic search with vector embeddings
        // For now, simple keyword search

        var results: [MemoryEntry] = []

        // Search entities
        for entity in entities.values {
            if entity.name.lowercased().contains(query.lowercased()) {
                results.append(MemoryEntry(
                    description: "Entity: \(entity.name) (\(entity.type.rawValue))",
                    timestamp: Date(),
                    relevance: 0.8
                ))
            }
        }

        return Array(results.prefix(limit))
    }

    // MARK: - Private Loading Methods

    private func loadEntities() {
        // Load from database
        let query = "SELECT id, type, name FROM entities LIMIT 1000;"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let typeStr = String(cString: sqlite3_column_text(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))

                if let type = EntityType(rawValue: typeStr) {
                    entities[id] = Entity(id: id, type: type, name: name, locations: [], metadata: [:])
                }
            }
        }
        sqlite3_finalize(statement)

        print("[DATA] Loaded \(entities.count) entities")
    }

    private func loadWorkflows() {
        let query = "SELECT id, pattern, steps FROM workflows LIMIT 1000;"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let pattern = String(cString: sqlite3_column_text(statement, 1))
                // TODO: Parse steps JSON

                workflows[id] = Workflow(id: id, pattern: pattern, steps: [], successCount: 0, failureCount: 0)
            }
        }
        sqlite3_finalize(statement)

        print("[DATA] Loaded \(workflows.count) workflows")
    }

    private func loadPreferences() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "cloe_user_preferences"),
           let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = prefs
        }
    }

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "cloe_user_preferences")
        }
    }
}

// MARK: - Data Models

struct Entity {
    let id: String
    let type: EntityType
    let name: String
    var locations: [EntityLocation]
    var metadata: [String: Any]
}

enum EntityType: String, Codable {
    case contact
    case file
    case project
    case task
    case document
}

struct EntityLocation {
    let app: String
    let context: String
    let path: String?
    let lastSeen: Date
}

struct Workflow: Codable {
    let id: String
    let pattern: String
    let steps: [WorkflowStep]
    var successCount: Int
    var failureCount: Int
}

struct WorkflowStep: Codable {
    let action: String
    let tool: String
    let parameters: [String: String]
}

struct UserPreferences: Codable {
    var workHoursStart: Int = 9
    var workHoursEnd: Int = 18
    var noMessageHoursStart: Int = 22
    var noMessageHoursEnd: Int = 7
    var writingStyle: String = "professional"
}
