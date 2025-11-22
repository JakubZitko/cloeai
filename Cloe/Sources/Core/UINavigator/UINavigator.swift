//
//  UINavigator.swift
//  Cloe
//
//  Navigates UI elements using Accessibility APIs
//  Can find and interact with menus, buttons, text fields in any app
//

import Foundation
import AppKit
import ApplicationServices

/// Navigates app UI elements using Accessibility APIs
class UINavigator {
    static let shared = UINavigator()

    private init() {}

    // MARK: - UI Element Types

    struct UIElement {
        let role: String
        let title: String?
        let value: Any?
        let frame: CGRect
        let axElement: AXUIElement

        var description: String {
            return "\(role): \(title ?? "untitled") at \(frame)"
        }
    }

    // MARK: - Get Active App

    /// Get the frontmost application
    func getFrontmostApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    /// Get AXUIElement for an app
    func getAppElement(_ app: NSRunningApplication) -> AXUIElement {
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    // MARK: - Find Elements

    /// Find all UI elements in the frontmost app
    func getAllElements() -> [UIElement] {
        guard let app = getFrontmostApp() else { return [] }
        let appElement = getAppElement(app)
        return findAllElements(in: appElement, depth: 0, maxDepth: 10)
    }

    /// Find elements matching a criteria
    func findElements(role: String? = nil, title: String? = nil) -> [UIElement] {
        return getAllElements().filter { element in
            var matches = true

            if let role = role {
                matches = matches && element.role == role
            }

            if let title = title {
                matches = matches && (element.title?.localizedCaseInsensitiveContains(title) ?? false)
            }

            return matches
        }
    }

    /// Find the focused/selected element
    func getFocusedElement() -> UIElement? {
        guard let app = getFrontmostApp() else { return nil }
        let appElement = getAppElement(app)

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        if result == .success, let axElement = focusedElement as! AXUIElement? {
            return createUIElement(from: axElement)
        }

        return nil
    }

    /// Find menu bar items
    func getMenuBar() -> [UIElement] {
        guard let app = getFrontmostApp() else { return [] }
        let appElement = getAppElement(app)

        var menuBar: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar)

        if result == .success, let menuBarElement = menuBar as! AXUIElement? {
            return getChildren(of: menuBarElement)
        }

        return []
    }

    // MARK: - Navigate Menus

    /// Navigate to a menu item by path (e.g., ["Edit", "Copy"])
    func navigateMenu(path: [String]) async -> Bool {
        let menuItems = getMenuBar()

        guard let firstMenu = menuItems.first(where: { $0.title == path.first }) else {
            print("Menu '\(path.first ?? "")' not found")
            return false
        }

        // Click the top-level menu
        performAction(on: firstMenu.axElement, action: kAXPressAction as CFString)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Navigate through submenus
        var currentElement = firstMenu.axElement
        for (index, menuName) in path.dropFirst().enumerated() {
            let children = getChildren(of: currentElement)

            guard let submenu = children.first(where: {
                $0.title?.localizedCaseInsensitiveContains(menuName) ?? false
            }) else {
                print("Submenu '\(menuName)' not found")
                return false
            }

            if index < path.count - 2 {
                // Hover to open submenu
                performAction(on: submenu.axElement, action: kAXPressAction as CFString)
                try? await Task.sleep(nanoseconds: 200_000_000)
                currentElement = submenu.axElement
            } else {
                // Click final item
                performAction(on: submenu.axElement, action: kAXPressAction as CFString)
                return true
            }
        }

        return true
    }

    /// Find and click a button by title
    func clickButton(titled: String) async -> Bool {
        let buttons = findElements(role: "AXButton", title: titled)

        guard let button = buttons.first else {
            print("Button '\(titled)' not found")
            return false
        }

        performAction(on: button.axElement, action: kAXPressAction as CFString)
        return true
    }

    /// Type into the focused text field
    func typeInFocusedField(_ text: String) {
        ScreenController.shared.typeText(text)
    }

    // MARK: - Private Helpers

    private func findAllElements(in element: AXUIElement, depth: Int, maxDepth: Int) -> [UIElement] {
        guard depth < maxDepth else { return [] }

        var results: [UIElement] = []

        if let uiElement = createUIElement(from: element) {
            results.append(uiElement)
        }

        let children = getChildren(of: element)
        for child in children {
            results.append(contentsOf: findAllElements(in: child.axElement, depth: depth + 1, maxDepth: maxDepth))
        }

        return results
    }

    private func getChildren(of element: AXUIElement) -> [UIElement] {
        var children: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)

        guard result == .success, let childArray = children as? [AXUIElement] else {
            return []
        }

        return childArray.compactMap { createUIElement(from: $0) }
    }

    private func createUIElement(from axElement: AXUIElement) -> UIElement? {
        // Get role
        var role: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        let roleString = role as? String ?? "Unknown"

        // Get title
        var title: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &title)
        let titleString = title as? String

        // Get value
        var value: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &value)

        // Get position and size
        var position: AnyObject?
        var size: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &size)

        var frame = CGRect.zero
        if let positionValue = position {
            var point = CGPoint.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point)
            frame.origin = point
        }
        if let sizeValue = size {
            var sizeRect = CGSize.zero
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &sizeRect)
            frame.size = sizeRect
        }

        return UIElement(
            role: roleString,
            title: titleString,
            value: value,
            frame: frame,
            axElement: axElement
        )
    }

    private func performAction(on element: AXUIElement, action: CFString) {
        AXUIElementPerformAction(element, action)
    }

    // MARK: - App-Specific Knowledge

    /// Get common actions for specific apps
    func getAppActions(appName: String) -> [AppAction] {
        switch appName.lowercased() {
        case "figma":
            return figmaActions
        case "photoshop", "adobe photoshop":
            return photoshopActions
        case "safari", "google chrome", "arc":
            return browserActions
        case "finder":
            return finderActions
        default:
            return []
        }
    }

    private var figmaActions: [AppAction] {
        return [
            AppAction(name: "Add Fill", menuPath: ["Object", "Fill"], shortcut: nil),
            AppAction(name: "Add Stroke", menuPath: ["Object", "Stroke"], shortcut: nil),
            AppAction(name: "Add Effect", menuPath: ["Object", "Effects"], shortcut: nil),
            AppAction(name: "Group", menuPath: ["Object", "Group Selection"], shortcut: "⌘G"),
            AppAction(name: "Ungroup", menuPath: ["Object", "Ungroup"], shortcut: "⇧⌘G"),
            AppAction(name: "Create Component", menuPath: ["Object", "Create Component"], shortcut: "⌥⌘K"),
            AppAction(name: "Flatten", menuPath: ["Object", "Flatten"], shortcut: "⌘E"),
            AppAction(name: "Boolean Union", menuPath: ["Object", "Boolean Groups", "Union"], shortcut: nil),
            AppAction(name: "Auto Layout", menuPath: ["Object", "Add Auto Layout"], shortcut: "⇧A"),
        ]
    }

    private var photoshopActions: [AppAction] {
        return [
            AppAction(name: "New Layer", menuPath: ["Layer", "New", "Layer"], shortcut: "⇧⌘N"),
            AppAction(name: "Duplicate Layer", menuPath: ["Layer", "Duplicate Layer"], shortcut: "⌘J"),
            AppAction(name: "Merge Layers", menuPath: ["Layer", "Merge Layers"], shortcut: "⌘E"),
            AppAction(name: "Free Transform", menuPath: ["Edit", "Free Transform"], shortcut: "⌘T"),
            AppAction(name: "Gaussian Blur", menuPath: ["Filter", "Blur", "Gaussian Blur"], shortcut: nil),
        ]
    }

    private var browserActions: [AppAction] {
        return [
            AppAction(name: "New Tab", menuPath: ["File", "New Tab"], shortcut: "⌘T"),
            AppAction(name: "Close Tab", menuPath: ["File", "Close Tab"], shortcut: "⌘W"),
            AppAction(name: "Reload", menuPath: ["View", "Reload Page"], shortcut: "⌘R"),
            AppAction(name: "Find", menuPath: ["Edit", "Find", "Find"], shortcut: "⌘F"),
        ]
    }

    private var finderActions: [AppAction] {
        return [
            AppAction(name: "New Folder", menuPath: ["File", "New Folder"], shortcut: "⇧⌘N"),
            AppAction(name: "Get Info", menuPath: ["File", "Get Info"], shortcut: "⌘I"),
            AppAction(name: "Duplicate", menuPath: ["File", "Duplicate"], shortcut: "⌘D"),
        ]
    }
}

// MARK: - App Action Model

struct AppAction {
    let name: String
    let menuPath: [String]
    let shortcut: String?
}
