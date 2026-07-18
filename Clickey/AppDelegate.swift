import SwiftUI
import AppKit
import ServiceManagement

@main
struct ClickeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        _ = AudioManager.shared
        KeystrokeMonitor.shared.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanUpAndExit()
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Clickey")
        }

        let menu = NSMenu()
        // this is the volume slider lol
        menu.addItem(createVolumeSliderItem())
        menu.addItem(NSMenuItem.separator())
        
        // pause and resume toggle.
        let pauseTitle = AudioManager.shared.isPaused ? "Resume Sound" : "Pause Sound"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause(_:)), keyEquivalent: "p")
        menu.addItem(pauseItem)
        
        // lunch at login thing
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // quit app
        menu.addItem(NSMenuItem(title: "Quit Clickey", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    private func createVolumeSliderItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 30))
        
        let label = NSTextField(labelWithString: "Volume")
        label.frame = NSRect(x: 12, y: 6, width: 50, height: 18)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .labelColor
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.isBordered = false
        
        let slider = NSSlider(
            value: Double(AudioManager.shared.volume),
            minValue: 0.0,
            maxValue: 1.0,
            target: self,
            action: #selector(volumeSliderChanged(_:))
        )
        slider.frame = NSRect(x: 65, y: 4, width: 103, height: 20)
        slider.isContinuous = true
        
        containerView.addSubview(label)
        containerView.addSubview(slider)
        menuItem.view = containerView
        return menuItem
    }

    @objc private func volumeSliderChanged(_ sender: NSSlider) {
        AudioManager.shared.volume = Float(sender.doubleValue)
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        AudioManager.shared.isPaused.toggle()
        sender.title = AudioManager.shared.isPaused ? "Resume Sound" : "Pause Sound"
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            print("failed: \(error.localizedDescription)")
        }
    }

    @objc private func quitApp() {
        cleanUpAndExit()
    }
    
    private func cleanUpAndExit() {
        KeystrokeMonitor.shared.stopMonitoring()
        AudioManager.shared.stopAudio()
        
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        
        exit(0)
    }
}
