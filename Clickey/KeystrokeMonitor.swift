import Foundation
import CoreGraphics
import AppKit

class KeystrokeMonitor {
    static let shared = KeystrokeMonitor()
    
    private var runLoopSource: CFRunLoopSource?
    private var eventTap: CFMachPort?

    private init() {}

    func startMonitoring() {
        // Step 1: Check baseline status without forcing a system prompt
        if AXIsProcessTrusted() {
            setupEventTap()
        } else {
            print("⚠️ Permissions missing. Triggering system prompt exactly once...")
            
            // Step 2: Trigger prompt ONCE explicitly
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            
            // Step 3: Poll clean verification status in background
            pollForPermissions()
        }
    }

    private func pollForPermissions() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // AXIsProcessTrusted checks status passively without spawning duplicated system alerts
            if AXIsProcessTrusted() {
                print("✅ Accessibility authorized.")
                DispatchQueue.main.async {
                    self?.setupEventTap()
                }
            } else {
                self?.pollForPermissions()
            }
        }
    }

    private func setupEventTap() {
        guard eventTap == nil else { return }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("❌ Event tap failure. Ensure App Sandbox is disabled and TCC DB is cleared.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("⌨️ Global Keyboard Event Hook fully active.")
    }

    func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .keyDown {
        let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if !isAutorepeat {
            AudioManager.shared.play()
        }
    }
    return Unmanaged.passRetained(event)
}
