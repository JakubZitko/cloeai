//
//  ScreenController.swift
//  Cloe
//
//  Controls mouse and keyboard to execute actions on the Mac
//

import Foundation
import AppKit
import CoreGraphics

/// Controls the screen - clicks, types, navigates through UI elements
class ScreenController {
    static let shared = ScreenController()

    private init() {}

    // MARK: - Mouse Control

    /// Move mouse to a screen position
    func moveMouse(to point: CGPoint) {
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    /// Click at current position or specified point
    func click(at point: CGPoint? = nil, button: CGMouseButton = .left) {
        let location = point ?? currentMouseLocation()

        // Mouse down
        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: location, mouseButton: button)
        downEvent?.post(tap: .cghidEventTap)

        // Small delay
        usleep(50000) // 50ms

        // Mouse up
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: location, mouseButton: button)
        upEvent?.post(tap: .cghidEventTap)
    }

    /// Double click at a point
    func doubleClick(at point: CGPoint? = nil) {
        let location = point ?? currentMouseLocation()

        for _ in 0..<2 {
            let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left)
            downEvent?.setIntegerValueField(.mouseEventClickState, value: 2)
            downEvent?.post(tap: .cghidEventTap)

            let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left)
            upEvent?.setIntegerValueField(.mouseEventClickState, value: 2)
            upEvent?.post(tap: .cghidEventTap)

            usleep(50000)
        }
    }

    /// Drag from one point to another
    func drag(from start: CGPoint, to end: CGPoint) {
        // Move to start
        moveMouse(to: start)
        usleep(100000)

        // Mouse down
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)
        downEvent?.post(tap: .cghidEventTap)
        usleep(100000)

        // Drag
        let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: end, mouseButton: .left)
        dragEvent?.post(tap: .cghidEventTap)
        usleep(100000)

        // Mouse up
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)
        upEvent?.post(tap: .cghidEventTap)
    }

    /// Scroll at current position
    func scroll(deltaY: Int32, deltaX: Int32 = 0) {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard Control

    /// Type a string of text
    func typeText(_ text: String, delayBetweenChars: UInt32 = 30000) {
        for char in text {
            typeCharacter(char)
            usleep(delayBetweenChars)
        }
    }

    /// Type a single character
    private func typeCharacter(_ char: Character) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Create key down event
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            var buffer = [UniChar](String(char).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: &buffer)
            keyDown.post(tap: .cghidEventTap)
        }

        // Create key up event
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Press a keyboard shortcut
    func pressShortcut(key: CGKeyCode, modifiers: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }

        usleep(50000)

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            keyUp.flags = modifiers
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Common shortcuts
    func pressEnter() { pressShortcut(key: 0x24) }
    func pressTab() { pressShortcut(key: 0x30) }
    func pressEscape() { pressShortcut(key: 0x35) }
    func pressDelete() { pressShortcut(key: 0x33) }
    func pressSpace() { pressShortcut(key: 0x31) }

    func pressCmdC() { pressShortcut(key: 0x08, modifiers: .maskCommand) }
    func pressCmdV() { pressShortcut(key: 0x09, modifiers: .maskCommand) }
    func pressCmdA() { pressShortcut(key: 0x00, modifiers: .maskCommand) }
    func pressCmdZ() { pressShortcut(key: 0x06, modifiers: .maskCommand) }
    func pressCmdS() { pressShortcut(key: 0x01, modifiers: .maskCommand) }
    func pressCmdF() { pressShortcut(key: 0x03, modifiers: .maskCommand) }

    // MARK: - Utilities

    func currentMouseLocation() -> CGPoint {
        return NSEvent.mouseLocation
    }

    /// Wait for a duration
    func wait(_ milliseconds: UInt32) {
        usleep(milliseconds * 1000)
    }
}

// MARK: - Action Sequence Builder

/// Fluent API to build action sequences
class ActionSequence {
    private var actions: [() -> Void] = []
    private let controller = ScreenController.shared

    @discardableResult
    func moveTo(_ point: CGPoint) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.moveMouse(to: point)
        }
        return self
    }

    @discardableResult
    func click() -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.click()
        }
        return self
    }

    @discardableResult
    func clickAt(_ point: CGPoint) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.click(at: point)
        }
        return self
    }

    @discardableResult
    func doubleClick() -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.doubleClick()
        }
        return self
    }

    @discardableResult
    func type(_ text: String) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.typeText(text)
        }
        return self
    }

    @discardableResult
    func shortcut(key: CGKeyCode, modifiers: CGEventFlags = []) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.pressShortcut(key: key, modifiers: modifiers)
        }
        return self
    }

    @discardableResult
    func wait(_ ms: UInt32) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.wait(ms)
        }
        return self
    }

    @discardableResult
    func scroll(y: Int32, x: Int32 = 0) -> ActionSequence {
        actions.append { [weak self] in
            self?.controller.scroll(deltaY: y, deltaX: x)
        }
        return self
    }

    /// Execute all actions in sequence
    func execute() async {
        for action in actions {
            action()
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms between actions
        }
    }
}
