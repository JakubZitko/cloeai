//
//  ActionExecutor.swift
//  Cloe
//
//  Executes learned actions on the Mac
//  Can navigate menus, click buttons, type text based on AI instructions
//

import Foundation
import AppKit

/// Executes actions learned from tutorials or AI instructions
class ActionExecutor {
    static let shared = ActionExecutor()

    private let screenController = ScreenController.shared
    private let uiNavigator = UINavigator.shared
    private let tutorialFinder = TutorialFinder.shared

    private init() {}

    // MARK: - Action Types

    enum ActionType {
        case clickMenu(path: [String])
        case clickButton(title: String)
        case typeText(text: String)
        case pressShortcut(keys: String)
        case moveMouse(x: Double, y: Double)
        case click
        case doubleClick
        case wait(milliseconds: Int)
        case scroll(direction: ScrollDirection, amount: Int)
    }

    enum ScrollDirection {
        case up, down, left, right
    }

    struct Action {
        let type: ActionType
        let description: String
    }

    struct ExecutionResult {
        let success: Bool
        let message: String
        let completedSteps: Int
        let totalSteps: Int
    }

    // MARK: - Process User Query

    /// Main entry point: Process a user query and execute if appropriate
    func processQuery(
        query: String,
        currentApp: String,
        onStepUpdate: @escaping (Int, String, Bool) -> Void
    ) async -> ExecutionResult {

        // Step 1: Check if we know how to do this already
        if let knownActions = getKnownActions(for: query, in: currentApp) {
            return await executeActions(knownActions, onStepUpdate: onStepUpdate)
        }

        // Step 2: Search for tutorial
        onStepUpdate(0, "Searching for tutorial...", true)

        do {
            let tutorials = try await tutorialFinder.findTutorial(query: query, app: currentApp)

            guard let tutorial = tutorials.first else {
                return ExecutionResult(
                    success: false,
                    message: "I couldn't find how to do '\(query)' in \(currentApp). Try rephrasing or ask for specific steps.",
                    completedSteps: 0,
                    totalSteps: 1
                )
            }

            onStepUpdate(1, "Found tutorial: \(tutorial.title)", true)

            // Step 3: Extract steps from tutorial
            let steps = try await tutorialFinder.extractSteps(from: tutorial.url)

            if steps.isEmpty {
                return ExecutionResult(
                    success: false,
                    message: "Found a tutorial but couldn't extract clear steps. Here's the link: \(tutorial.url)",
                    completedSteps: 1,
                    totalSteps: 2
                )
            }

            // Step 4: Convert steps to actions
            let actions = convertStepsToActions(steps, app: currentApp)

            // Step 5: Execute actions
            return await executeActions(actions, onStepUpdate: onStepUpdate)

        } catch {
            return ExecutionResult(
                success: false,
                message: "Error searching for tutorial: \(error.localizedDescription)",
                completedSteps: 0,
                totalSteps: 1
            )
        }
    }

    // MARK: - Known Actions (Built-in knowledge)

    private func getKnownActions(for query: String, in app: String) -> [Action]? {
        let lowerQuery = query.lowercased()
        let lowerApp = app.lowercased()

        // Figma actions
        if lowerApp.contains("figma") {
            if lowerQuery.contains("glass") || lowerQuery.contains("blur") || lowerQuery.contains("frosted") {
                return glassEffectActions(for: "figma")
            }
            if lowerQuery.contains("shadow") {
                return shadowEffectActions(for: "figma")
            }
            if lowerQuery.contains("auto layout") {
                return [Action(type: .pressShortcut(keys: "⇧A"), description: "Add Auto Layout")]
            }
            if lowerQuery.contains("component") {
                return [Action(type: .pressShortcut(keys: "⌥⌘K"), description: "Create Component")]
            }
            if lowerQuery.contains("group") {
                return [Action(type: .pressShortcut(keys: "⌘G"), description: "Group Selection")]
            }
        }

        // Photoshop actions
        if lowerApp.contains("photoshop") {
            if lowerQuery.contains("blur") {
                return [
                    Action(type: .clickMenu(path: ["Filter", "Blur", "Gaussian Blur"]), description: "Open Gaussian Blur"),
                    Action(type: .wait(milliseconds: 500), description: "Wait for dialog"),
                ]
            }
        }

        return nil
    }

    private func glassEffectActions(for app: String) -> [Action] {
        switch app.lowercased() {
        case "figma":
            return [
                Action(type: .wait(milliseconds: 200), description: "Prepare to add effect"),
                Action(type: .clickButton(title: "Effects"), description: "Open Effects panel"),
                Action(type: .wait(milliseconds: 300), description: "Wait for panel"),
                Action(type: .clickButton(title: "+"), description: "Add new effect"),
                Action(type: .wait(milliseconds: 200), description: "Wait for effect menu"),
                Action(type: .clickButton(title: "Background blur"), description: "Select Background Blur"),
                Action(type: .wait(milliseconds: 200), description: "Apply blur"),
            ]
        default:
            return []
        }
    }

    private func shadowEffectActions(for app: String) -> [Action] {
        switch app.lowercased() {
        case "figma":
            return [
                Action(type: .clickButton(title: "Effects"), description: "Open Effects panel"),
                Action(type: .wait(milliseconds: 300), description: "Wait for panel"),
                Action(type: .clickButton(title: "+"), description: "Add new effect"),
                Action(type: .clickButton(title: "Drop shadow"), description: "Select Drop Shadow"),
            ]
        default:
            return []
        }
    }

    // MARK: - Convert Tutorial Steps to Actions

    private func convertStepsToActions(_ steps: [String], app: String) -> [Action] {
        var actions: [Action] = []

        for step in steps {
            let lowerStep = step.lowercased()

            // Parse common patterns
            if lowerStep.contains("click") {
                if let menuPath = extractMenuPath(from: step) {
                    actions.append(Action(type: .clickMenu(path: menuPath), description: step))
                } else if let buttonName = extractButtonName(from: step) {
                    actions.append(Action(type: .clickButton(title: buttonName), description: step))
                } else {
                    actions.append(Action(type: .click, description: step))
                }
            } else if lowerStep.contains("type") || lowerStep.contains("enter") {
                if let text = extractTextToType(from: step) {
                    actions.append(Action(type: .typeText(text: text), description: step))
                }
            } else if lowerStep.contains("press") || lowerStep.contains("shortcut") {
                if let shortcut = extractShortcut(from: step) {
                    actions.append(Action(type: .pressShortcut(keys: shortcut), description: step))
                }
            } else if lowerStep.contains("scroll") {
                let direction: ScrollDirection = lowerStep.contains("down") ? .down : .up
                actions.append(Action(type: .scroll(direction: direction, amount: 100), description: step))
            } else if lowerStep.contains("wait") {
                actions.append(Action(type: .wait(milliseconds: 500), description: step))
            } else {
                // Generic step - just wait a bit
                actions.append(Action(type: .wait(milliseconds: 300), description: step))
            }

            // Add small delay between actions
            actions.append(Action(type: .wait(milliseconds: 200), description: ""))
        }

        return actions.filter { !$0.description.isEmpty || $0.description.isEmpty }
    }

    private func extractMenuPath(from step: String) -> [String]? {
        // Pattern: "click on Edit > Copy" or "go to File > New > Document"
        let patterns = [
            "(?:click|go to|select|open)\\s+(?:on\\s+)?([A-Z][a-z]+(?:\\s*[>→]\\s*[A-Z][a-z]+)+)",
            "([A-Z][a-z]+)\\s*menu\\s*[>→]\\s*([A-Z][a-z]+)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: step, options: [], range: NSRange(step.startIndex..., in: step)) {
                if let range = Range(match.range(at: 1), in: step) {
                    let pathString = String(step[range])
                    let path = pathString.components(separatedBy: CharacterSet(charactersIn: ">→"))
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                    return path
                }
            }
        }

        return nil
    }

    private func extractButtonName(from step: String) -> String? {
        // Pattern: "click the 'Submit' button" or "click on Add"
        let patterns = [
            "click\\s+(?:the\\s+)?['\"]([^'\"]+)['\"]",
            "click\\s+(?:on\\s+)?([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)?)",
            "press\\s+(?:the\\s+)?['\"]([^'\"]+)['\"]",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: step, options: [], range: NSRange(step.startIndex..., in: step)) {
                if let range = Range(match.range(at: 1), in: step) {
                    return String(step[range])
                }
            }
        }

        return nil
    }

    private func extractTextToType(from step: String) -> String? {
        // Pattern: "type 'hello'" or "enter the value 50"
        let patterns = [
            "(?:type|enter)\\s+['\"]([^'\"]+)['\"]",
            "(?:type|enter)\\s+(?:the\\s+)?(?:value\\s+)?([0-9]+)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: step, options: [], range: NSRange(step.startIndex..., in: step)) {
                if let range = Range(match.range(at: 1), in: step) {
                    return String(step[range])
                }
            }
        }

        return nil
    }

    private func extractShortcut(from step: String) -> String? {
        // Pattern: "Cmd+C" or "⌘C" or "Command+Shift+S"
        let shortcuts = [
            "⌘C": "⌘C", "cmd+c": "⌘C", "command+c": "⌘C",
            "⌘V": "⌘V", "cmd+v": "⌘V", "command+v": "⌘V",
            "⌘S": "⌘S", "cmd+s": "⌘S", "command+s": "⌘S",
            "⌘Z": "⌘Z", "cmd+z": "⌘Z", "command+z": "⌘Z",
            "⇧⌘S": "⇧⌘S", "shift+cmd+s": "⇧⌘S",
        ]

        let lowerStep = step.lowercased()
        for (pattern, shortcut) in shortcuts {
            if lowerStep.contains(pattern.lowercased()) {
                return shortcut
            }
        }

        return nil
    }

    // MARK: - Execute Actions

    private func executeActions(
        _ actions: [Action],
        onStepUpdate: @escaping (Int, String, Bool) -> Void
    ) async -> ExecutionResult {

        var completedSteps = 0
        let visibleActions = actions.filter { !$0.description.isEmpty }

        for (index, action) in actions.enumerated() {
            if !action.description.isEmpty {
                onStepUpdate(completedSteps, action.description, true)
            }

            let success = await executeAction(action)

            if !success && !action.description.isEmpty {
                return ExecutionResult(
                    success: false,
                    message: "Failed at step: \(action.description)",
                    completedSteps: completedSteps,
                    totalSteps: visibleActions.count
                )
            }

            if !action.description.isEmpty {
                completedSteps += 1
            }
        }

        return ExecutionResult(
            success: true,
            message: "Successfully completed all steps!",
            completedSteps: completedSteps,
            totalSteps: visibleActions.count
        )
    }

    private func executeAction(_ action: Action) async -> Bool {
        switch action.type {
        case .clickMenu(let path):
            return await uiNavigator.navigateMenu(path: path)

        case .clickButton(let title):
            return await uiNavigator.clickButton(titled: title)

        case .typeText(let text):
            screenController.typeText(text)
            return true

        case .pressShortcut(let keys):
            executeShortcut(keys)
            return true

        case .moveMouse(let x, let y):
            screenController.moveMouse(to: CGPoint(x: x, y: y))
            return true

        case .click:
            screenController.click()
            return true

        case .doubleClick:
            screenController.doubleClick()
            return true

        case .wait(let ms):
            try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
            return true

        case .scroll(let direction, let amount):
            let deltaY: Int32 = (direction == .down) ? Int32(-amount) : Int32(amount)
            let deltaX: Int32 = (direction == .left) ? Int32(-amount) : (direction == .right) ? Int32(amount) : 0
            screenController.scroll(deltaY: deltaY, deltaX: deltaX)
            return true
        }
    }

    private func executeShortcut(_ keys: String) {
        // Parse shortcut string like "⌘C" or "⇧⌘S"
        var modifiers: CGEventFlags = []
        var keyCode: CGKeyCode = 0

        for char in keys {
            switch char {
            case "⌘": modifiers.insert(.maskCommand)
            case "⇧": modifiers.insert(.maskShift)
            case "⌥": modifiers.insert(.maskAlternate)
            case "⌃": modifiers.insert(.maskControl)
            case "A", "a": keyCode = 0x00
            case "S", "s": keyCode = 0x01
            case "D", "d": keyCode = 0x02
            case "F", "f": keyCode = 0x03
            case "G", "g": keyCode = 0x05
            case "H", "h": keyCode = 0x04
            case "Z", "z": keyCode = 0x06
            case "X", "x": keyCode = 0x07
            case "C", "c": keyCode = 0x08
            case "V", "v": keyCode = 0x09
            case "N", "n": keyCode = 0x2D
            case "K", "k": keyCode = 0x28
            case "E", "e": keyCode = 0x0E
            default: break
            }
        }

        screenController.pressShortcut(key: keyCode, modifiers: modifiers)
    }
}
