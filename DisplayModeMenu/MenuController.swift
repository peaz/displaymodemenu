//
//  MenuController.swift
//  DisplayModeMenu
//
//  Manages the menu bar status item and display mode menus.
//

import AppKit
import CoreGraphics

class MenuController {
    private var statusItem: NSStatusItem?
    private let displayService = DisplayService.shared
    private var showAllModes = false  // Toggle for showing all modes
    
    func setup() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            NSLog("[MenuController] button found")
            // Try SF Symbol first, fall back to text
            if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display Modes") {
                button.image = image
                button.image?.isTemplate = true
                NSLog("[MenuController] Using SF Symbol icon")
            } else {
                // Fallback to text icon
                button.title = "🖥️"
                NSLog("[MenuController] Using emoji icon")
            }
        } else {
            NSLog("[MenuController] ERROR: button is nil!")
        }
        
        // Build initial menu
        refreshMenu()
    }
    
    func refreshMenu() {
        let menu = NSMenu()
        
        let displays = displayService.getDisplays()
        
        if displays.isEmpty {
            let item = NSMenuItem(title: "No Displays Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Add menu items for each display
            for (index, display) in displays.enumerated() {
                if index > 0 {
                    menu.addItem(NSMenuItem.separator())
                }
                
                // Display header
                let displayHeader = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                displayHeader.isEnabled = false
                menu.addItem(displayHeader)
                
                // Get modes for this display
                let allModes = displayService.getModes(for: display.id)
                
                // Filter to preferred resolutions unless showAllModes is enabled
                let modes: [DisplayModeInfo]
                if showAllModes {
                    // Filter out modes below 60Hz
                    modes = allModes.filter { $0.refreshRate >= 60 }
                } else {
                    // Only show HiDPI modes for 1920x1080 and 2560x1440, with refresh >= 60Hz
                    modes = allModes.filter { mode in
                        mode.refreshRate >= 60 && (
                            mode.isCurrent || (
                                mode.isHiDPI && (
                                    (mode.width == 1920 && mode.height == 1080) ||
                                    (mode.width == 2560 && mode.height == 1440)
                                )
                            )
                        )
                    }
                }
                
                if modes.isEmpty {
                    let item = NSMenuItem(title: "  No modes available", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    menu.addItem(item)
                } else {
                    // Group modes by resolution for cleaner menu
                    var lastResolution: String? = nil
                    
                    for mode in modes {
                        let resolution = "\(mode.width)×\(mode.height)"
                        
                        // Add separator between different resolutions
                        if let last = lastResolution, last != resolution {
                            // Just visual grouping, no separator needed for now
                        }
                        lastResolution = resolution
                        
                        let item = NSMenuItem(
                            title: "  \(mode.label)",
                            action: #selector(modeSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                        
                        // Mark current mode with checkmark
                        if mode.isCurrent {
                            item.state = .on
                        }
                        
                        menu.addItem(item)
                    }
                }
            }
        }
        
        // Add utility items
        menu.addItem(NSMenuItem.separator())
        
        let showAllItem = NSMenuItem(
            title: "Show All Modes",
            action: #selector(toggleShowAllModes),
            keyEquivalent: "a"
        )
        showAllItem.target = self
        showAllItem.state = showAllModes ? .on : .off
        menu.addItem(showAllItem)
        
        let refreshItem = NSMenuItem(
            title: "Refresh Displays",
            action: #selector(refreshMenuAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit DisplayMode",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func modeSelected(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? ModeSelection else {
            return
        }
        
        let success = displayService.setMode(selection.mode, for: selection.displayID)
        
        if !success {
            showAlert(
                title: "Failed to Change Display Mode",
                message: "Could not set display to \(selection.mode.label). The mode may not be supported."
            )
        } else {
            // Refresh menu after mode change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshMenu()
            }
        }
    }
    
    @objc private func refreshMenuAction(_ sender: NSMenuItem) {
        // Keep menu open by updating after a brief delay
        DispatchQueue.main.async {
            self.refreshMenu()
            // Re-open the menu
            self.statusItem?.button?.performClick(nil)
        }
    }
    
    @objc private func toggleShowAllModes(_ sender: NSMenuItem) {
        showAllModes.toggle()
        // Keep menu open by updating after a brief delay
        DispatchQueue.main.async {
            self.refreshMenu()
            // Re-open the menu
            self.statusItem?.button?.performClick(nil)
        }
    }
    
    /// Rebuild menu without closing it (updates in place)
    private func rebuildMenuInPlace() {
        guard let menu = statusItem?.menu else { return }
        
        // Remove all items
        menu.removeAllItems()
        
        let displays = displayService.getDisplays()
        
        if displays.isEmpty {
            let item = NSMenuItem(title: "No Displays Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Add menu items for each display
            for (index, display) in displays.enumerated() {
                if index > 0 {
                    menu.addItem(NSMenuItem.separator())
                }
                
                // Display header
                let displayHeader = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                displayHeader.isEnabled = false
                menu.addItem(displayHeader)
                
                // Get modes for this display
                let allModes = displayService.getModes(for: display.id)
                
                // Filter to preferred resolutions unless showAllModes is enabled
                let modes: [DisplayModeInfo]
                if showAllModes {
                    // Filter out modes below 60Hz
                    modes = allModes.filter { $0.refreshRate >= 60 }
                } else {
                    // Only show HiDPI modes for 1920x1080 and 2560x1440, with refresh >= 60Hz
                    modes = allModes.filter { mode in
                        mode.refreshRate >= 60 && (
                            mode.isCurrent || (
                                mode.isHiDPI && (
                                    (mode.width == 1920 && mode.height == 1080) ||
                                    (mode.width == 2560 && mode.height == 1440)
                                )
                            )
                        )
                    }
                }
                
                if modes.isEmpty {
                    let item = NSMenuItem(title: "  No modes available", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    menu.addItem(item)
                } else {
                    // Group modes by resolution for cleaner menu
                    var lastResolution: String? = nil
                    
                    for mode in modes {
                        let resolution = "\(mode.width)×\(mode.height)"
                        
                        // Add separator between different resolutions
                        if let last = lastResolution, last != resolution {
                            // Just visual grouping, no separator needed for now
                        }
                        lastResolution = resolution
                        
                        let item = NSMenuItem(
                            title: "  \(mode.label)",
                            action: #selector(modeSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                        
                        // Mark current mode with checkmark
                        if mode.isCurrent {
                            item.state = .on
                        }
                        
                        menu.addItem(item)
                    }
                }
            }
        }
        
        // Add utility items
        menu.addItem(NSMenuItem.separator())
        
        let showAllItem = NSMenuItem(
            title: "Show All Modes",
            action: #selector(toggleShowAllModes),
            keyEquivalent: "a"
        )
        showAllItem.target = self
        showAllItem.state = showAllModes ? .on : .off
        menu.addItem(showAllItem)
        
        let refreshItem = NSMenuItem(
            title: "Refresh Displays",
            action: #selector(refreshMenuAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit DisplayMode",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// Helper struct to pass mode selection data
private struct ModeSelection {
    let displayID: CGDirectDisplayID
    let mode: DisplayModeInfo
}
