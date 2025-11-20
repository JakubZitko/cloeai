//
//  CalendarTool.swift
//  Cloe
//
//  Calendar integration (create events, check schedule, reminders)
//

import Foundation
import EventKit

class CalendarTool: Tool {
    let name = "calendar"
    let description = "Create calendar events, check schedule, manage reminders"

    let parameters = [
        ToolParameter(name: "action", type: "string", description: "Action: create_event, list_events, delete_event, check_availability", required: true),
        ToolParameter(name: "title", type: "string", description: "Event title", required: false),
        ToolParameter(name: "start_time", type: "string", description: "Event start time (ISO 8601 or natural language)", required: false),
        ToolParameter(name: "end_time", type: "string", description: "Event end time (ISO 8601 or natural language)", required: false),
        ToolParameter(name: "duration", type: "number", description: "Event duration in minutes", required: false),
        ToolParameter(name: "notes", type: "string", description: "Event notes/description", required: false)
    ]

    private let eventStore = EKEventStore()

    func execute(parameters: [String: Any]) async throws -> ToolResult {
        // Request calendar access if needed
        try await requestCalendarAccess()

        guard let action = parameters["action"] as? String else {
            throw ToolError.missingParameter("action")
        }

        switch action {
        case "create_event":
            return try await createEvent(parameters: parameters)
        case "list_events":
            return try await listEvents(parameters: parameters)
        case "delete_event":
            return try deleteEvent(parameters: parameters)
        case "check_availability":
            return try await checkAvailability(parameters: parameters)
        default:
            throw ToolError.invalidParameter("action", value: action)
        }
    }

    // MARK: - Calendar Access

    private func requestCalendarAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            return
        case .notDetermined:
            let granted = try await eventStore.requestAccess(to: .event)
            if !granted {
                throw CalendarError.permissionDenied
            }
        case .denied, .restricted:
            throw CalendarError.permissionDenied
        @unknown default:
            throw CalendarError.permissionDenied
        }
    }

    // MARK: - Calendar Operations

    private func createEvent(parameters: [String: Any]) async throws -> ToolResult {
        guard let title = parameters["title"] as? String else {
            throw ToolError.missingParameter("title")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Parse start time
        if let startTimeStr = parameters["start_time"] as? String {
            event.startDate = try parseDateTime(startTimeStr)
        } else {
            event.startDate = Date()
        }

        // Parse end time or duration
        if let endTimeStr = parameters["end_time"] as? String {
            event.endDate = try parseDateTime(endTimeStr)
        } else if let duration = parameters["duration"] as? Int {
            event.endDate = event.startDate.addingTimeInterval(TimeInterval(duration * 60))
        } else {
            // Default 1 hour
            event.endDate = event.startDate.addingTimeInterval(3600)
        }

        // Notes
        if let notes = parameters["notes"] as? String {
            event.notes = notes
        }

        // Save event
        try eventStore.save(event, span: .thisEvent)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return ToolResult(
            success: true,
            message: "Created event '\(title)' on \(formatter.string(from: event.startDate))",
            data: [
                "event_id": event.eventIdentifier as Any,
                "title": title,
                "start": formatter.string(from: event.startDate),
                "end": formatter.string(from: event.endDate)
            ]
        )
    }

    private func listEvents(parameters: [String: Any]) async throws -> ToolResult {
        // Default: list events for today
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let eventList = events.map { event in
            [
                "title": event.title ?? "Untitled",
                "start": formatter.string(from: event.startDate),
                "end": formatter.string(from: event.endDate),
                "location": event.location ?? ""
            ]
        }

        return ToolResult(
            success: true,
            message: "Found \(events.count) events today",
            data: ["events": eventList]
        )
    }

    private func deleteEvent(parameters: [String: Any]) throws -> ToolResult {
        guard let eventID = parameters["event_id"] as? String else {
            throw ToolError.missingParameter("event_id")
        }

        guard let event = eventStore.event(withIdentifier: eventID) else {
            throw CalendarError.eventNotFound
        }

        try eventStore.remove(event, span: .thisEvent)

        return ToolResult(
            success: true,
            message: "Deleted event '\(event.title ?? "Untitled")'",
            data: nil
        )
    }

    private func checkAvailability(parameters: [String: Any]) async throws -> ToolResult {
        // Check if user is free at a given time
        guard let startTimeStr = parameters["start_time"] as? String else {
            throw ToolError.missingParameter("start_time")
        }

        let startTime = try parseDateTime(startTimeStr)
        let duration = parameters["duration"] as? Int ?? 60
        let endTime = startTime.addingTimeInterval(TimeInterval(duration * 60))

        let predicate = eventStore.predicateForEvents(
            withStart: startTime,
            end: endTime,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
        let isFree = events.isEmpty

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return ToolResult(
            success: true,
            message: isFree ? "You're free at that time" : "You have \(events.count) event(s) during that time",
            data: [
                "is_free": isFree,
                "conflicting_events": events.count,
                "time_slot": "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
            ]
        )
    }

    // MARK: - Utilities

    private func parseDateTime(_ string: String) throws -> Date {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // Try common formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy HH:mm"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .short
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // TODO: Implement natural language parsing ("tomorrow at 3pm", "next Monday at 10am")

        throw CalendarError.invalidDateFormat(string)
    }
}

// MARK: - Calendar Errors

enum CalendarError: Error {
    case permissionDenied
    case eventNotFound
    case invalidDateFormat(String)
}

extension CalendarError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar permission denied"
        case .eventNotFound:
            return "Event not found"
        case .invalidDateFormat(let format):
            return "Invalid date format: \(format)"
        }
    }
}
