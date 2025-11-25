//
//  HotKeyMonitor.swift
//  Cloe
//
//  Global hotkey monitoring and registration
//

import Foundation
import AppKit
import Carbon

class HotKeyMonitor {
    typealias HotKeyHandler = () -> Void

    private var hotKeys: [Int32: HotKeyHandler] = [:]
    private var nextHotKeyID: Int32 = 1
    private var eventHandler: EventHandlerRef?

    init() {
        setupEventHandler()
    }

    deinit {
        unregisterAllHotKeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    // MARK: - Hot Key Registration

    func registerHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, handler: @escaping HotKeyHandler) {
        let hotKeyID = nextHotKeyID
        nextHotKeyID += 1

        let carbonModifiers = convertToCarbonModifiers(modifiers)

        // Register the hot key with the system
        var hotKeyRef: EventHotKeyRef?
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            EventHotKeyID(signature: OSType(0x436C6F65), id: UInt32(hotKeyID)), // 'Cloe'
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            hotKeys[hotKeyID] = handler
            print("[OK] Registered hotkey with ID: \(hotKeyID)")
        } else {
            print("[ERROR] Failed to register hotkey: \(status)")
        }
    }

    func unregisterAllHotKeys() {
        hotKeys.removeAll()
        // Note: In a full implementation, we'd need to store EventHotKeyRef to unregister
    }

    // MARK: - Event Handling

    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                return monitor.handleHotKeyEvent(event!)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return status }

        let id = Int32(hotKeyID.id)
        if let handler = hotKeys[id] {
            DispatchQueue.main.async {
                handler()
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    // MARK: - Utilities

    private func convertToCarbonModifiers(_ modifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonModifiers: UInt32 = 0

        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        return carbonModifiers
    }
}

// MARK: - Common Key Codes

extension HotKeyMonitor {
    enum KeyCode: UInt16 {
        case space = 49
        case returnKey = 36
        case escape = 53
        case delete = 51
        case tab = 48

        // Letters
        case a = 0
        case s = 1
        case d = 2
        case f = 3
        case h = 4
        case g = 5
        case z = 6
        case x = 7
        case c = 8
        case v = 9
        case b = 11
        case q = 12
        case w = 13
        case e = 14
        case r = 15
        case y = 16
        case t = 17
        case o = 31
        case u = 32
        case i = 34
        case p = 35
        case l = 37
        case j = 38
        case k = 40
        case n = 45
        case m = 46

        // Numbers
        case one = 18
        case two = 19
        case three = 20
        case four = 21
        case six = 22
        case five = 23
        case equal = 24
        case nine = 25
        case seven = 26
        case minus = 27
        case eight = 28
        case zero = 29
    }
}
