//
//  MenuController.swift
//  DisplayModeMenu
//
//  Manages the menu bar status item and display mode menus.
//

import AppKit
import CoreGraphics

class MenuController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let displayService = DisplayService.shared
    private var showLowResolution = false  // Toggle for showing non-HiDPI modes
    private var isMenuOpen = false
    
    // Favorite resolutions to always display at the top
    private let favoriteResolutions: [(width: Int, height: Int, refreshRate: Double, hiDPI: Bool)] = [
        (3840, 2160, 60, false),   // 4K@60 HiDPI
        (3200, 1800, 60, true),   // 3200x1800@60 HiDPI
        (2560, 1440, 60, true),   // 2560x1440@60 HiDPI
        (1920, 1080, 60, true),   // 1920x1080@60 HiDPI
    ]
    
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
        
        // Restore persisted display modes from previous session
        restorePersistedDisplayModes()
        
        // Build initial menu
        refreshMenu()
    }
    
    func refreshMenu() {
        // If menu is open, update in place to avoid closing when submenus open
        if isMenuOpen, statusItem?.menu != nil {
            rebuildMenuInPlace()
            return
        }

        let menu = NSMenu()
        menu.delegate = self
        
        // Utility items
        let showLowResItem = NSMenuItem(
            title: "Show Low Resolution",
            action: #selector(toggleShowLowResolution),
            keyEquivalent: "l"
        )
        showLowResItem.target = self
        showLowResItem.state = showLowResolution ? .on : .off
        menu.addItem(showLowResItem)
        
        let refreshItem = NSMenuItem(
            title: "Refresh Displays",
            action: #selector(refreshMenuAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let displays = displayService.getDisplays()
        
        if displays.isEmpty {
            let item = NSMenuItem(title: "No Displays Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Favorites section
            let favoritesHeader = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
            favoritesHeader.isEnabled = false
            menu.addItem(favoritesHeader)
            
            var favoriteAdded = false
            for display in displays {
                var displayHasFavorite = false
                var seenFavorites = Set<String>()
                
                for favorite in favoriteResolutions {
                    let displayModes = displayService.getModes(for: display.id)
                    
                    if let matchingMode = displayModes.first(where: { mode in
                        mode.width == favorite.width &&
                        mode.height == favorite.height &&
                        Int(mode.refreshRate) == Int(favorite.refreshRate) &&
                        mode.isHiDPI == favorite.hiDPI
                    }) {
                        let key = "\(matchingMode.width)x\(matchingMode.height)@\(Int(matchingMode.refreshRate))_\(matchingMode.isHiDPI)"
                        guard !seenFavorites.contains(key) else { continue }
                        seenFavorites.insert(key)
                        
                        if !displayHasFavorite {
                            // Add display header
                            let displayHeader = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                            displayHeader.isEnabled = false
                            menu.addItem(displayHeader)
                            displayHasFavorite = true
                            favoriteAdded = true
                        }
                        
                        let modeLabel = matchingMode.isHiDPI ? "\(matchingMode.label) [HiDPI]" : matchingMode.label
                        let title = "  ☆ \(modeLabel)"
                        
                        let item = NSMenuItem(title: title, action: #selector(modeSelected(_:)), keyEquivalent: "")
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: matchingMode)
                        if matchingMode.isCurrent {
                            item.state = .on
                        }
                        menu.addItem(item)
                    }
                }
            }
            
            if !favoriteAdded {
                let noFav = NSMenuItem(title: "  None available", action: nil, keyEquivalent: "")
                noFav.isEnabled = false
                menu.addItem(noFav)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // All Modes section
            let allModesHeader = NSMenuItem(title: "All Modes", action: nil, keyEquivalent: "")
            allModesHeader.isEnabled = false
            menu.addItem(allModesHeader)
            
            for display in displays {
                let displaySubmenu = NSMenu()
                let allModes = displayService.getModes(for: display.id)
                
                // Filter modes: show all 60Hz+; include non-HiDPI only when low-res toggle is on
                let modes: [DisplayModeInfo]
                let filteredModes = allModes.filter { mode in
                    mode.refreshRate >= 60 && (mode.isCurrent || mode.isHiDPI || showLowResolution)
                }
                
                // Deduplicate modes
                var seenModes = Set<String>()
                modes = filteredModes.filter { mode in
                    let key = "\(mode.width)x\(mode.height)@\(Int(mode.refreshRate))_\(mode.isHiDPI)"
                    let isNew = !seenModes.contains(key)
                    seenModes.insert(key)
                    return isNew
                }
                
                if modes.isEmpty {
                    let emptyItem = NSMenuItem(title: "No modes available", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    displaySubmenu.addItem(emptyItem)
                } else {
                    for mode in modes {
                        let modeLabel = mode.isHiDPI ? "\(mode.label) [HiDPI]" : mode.label
                        let item = NSMenuItem(
                            title: modeLabel,
                            action: #selector(modeSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                        if mode.isCurrent {
                            item.state = .on
                        }
                        displaySubmenu.addItem(item)
                    }
                }
                
                let displayItem = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                displayItem.submenu = displaySubmenu
                menu.addItem(displayItem)
            }
        }
        
        // Quit at the bottom
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
            // Persist the mode selection so it survives app termination
            saveDisplayModePersistence(displayID: selection.displayID, mode: selection.mode)
            
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
    

    @objc private func toggleShowLowResolution(_ sender: NSMenuItem) {
        showLowResolution.toggle()
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
        menu.delegate = self
        
        // Remove all items
        menu.removeAllItems()
        
        // Utility items
        let showLowResItem = NSMenuItem(
            title: "Show Low Resolution",
            action: #selector(toggleShowLowResolution),
            keyEquivalent: "l"
        )
        showLowResItem.target = self
        showLowResItem.state = showLowResolution ? .on : .off
        menu.addItem(showLowResItem)
        
        let refreshItem = NSMenuItem(
            title: "Refresh Displays",
            action: #selector(refreshMenuAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let displays = displayService.getDisplays()
        
        if displays.isEmpty {
            let item = NSMenuItem(title: "No Displays Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Favorites section
            let favoritesHeader = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
            favoritesHeader.isEnabled = false
            menu.addItem(favoritesHeader)
            
            var favoriteAdded = false
            for display in displays {
                var displayHasFavorite = false
                var seenFavorites = Set<String>()
                
                for favorite in favoriteResolutions {
                    let displayModes = displayService.getModes(for: display.id)
                    
                    if let matchingMode = displayModes.first(where: { mode in
                        mode.width == favorite.width &&
                        mode.height == favorite.height &&
                        Int(mode.refreshRate) == Int(favorite.refreshRate) &&
                        mode.isHiDPI == favorite.hiDPI
                    }) {
                        let key = "\(matchingMode.width)x\(matchingMode.height)@\(Int(matchingMode.refreshRate))_\(matchingMode.isHiDPI)"
                        guard !seenFavorites.contains(key) else { continue }
                        seenFavorites.insert(key)
                        
                        if !displayHasFavorite {
                            // Add display header
                            let displayHeader = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                            displayHeader.isEnabled = false
                            menu.addItem(displayHeader)
                            displayHasFavorite = true
                            favoriteAdded = true
                        }
                        
                        let modeLabel = matchingMode.isHiDPI ? "\(matchingMode.label) [HiDPI]" : matchingMode.label
                        let title = "  ☆ \(modeLabel)"
                        
                        let item = NSMenuItem(title: title, action: #selector(modeSelected(_:)), keyEquivalent: "")
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: matchingMode)
                        if matchingMode.isCurrent {
                            item.state = .on
                        }
                        menu.addItem(item)
                    }
                }
            }
            
            if !favoriteAdded {
                let noFav = NSMenuItem(title: "  None available", action: nil, keyEquivalent: "")
                noFav.isEnabled = false
                menu.addItem(noFav)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // All Modes section
            let allModesHeader = NSMenuItem(title: "All Modes", action: nil, keyEquivalent: "")
            allModesHeader.isEnabled = false
            menu.addItem(allModesHeader)
            
            for display in displays {
                let displaySubmenu = NSMenu()
                let allModes = displayService.getModes(for: display.id)
                
                // Filter modes: show all 60Hz+; include non-HiDPI only when low-res toggle is on
                let modes: [DisplayModeInfo]
                let filteredModes = allModes.filter { mode in
                    mode.refreshRate >= 60 && (mode.isCurrent || mode.isHiDPI || showLowResolution)
                }
                
                // Deduplicate modes
                var seenModes = Set<String>()
                modes = filteredModes.filter { mode in
                    let key = "\(mode.width)x\(mode.height)@\(Int(mode.refreshRate))_\(mode.isHiDPI)"
                    let isNew = !seenModes.contains(key)
                    seenModes.insert(key)
                    return isNew
                }
                
                if modes.isEmpty {
                    let emptyItem = NSMenuItem(title: "No modes available", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    displaySubmenu.addItem(emptyItem)
                } else {
                    for mode in modes {
                        let modeLabel = mode.isHiDPI ? "\(mode.label) [HiDPI]" : mode.label
                        let item = NSMenuItem(
                            title: modeLabel,
                            action: #selector(modeSelected(_:)),
                            keyEquivalent: ""
                        )
                        item.target = self
                        item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                        if mode.isCurrent {
                            item.state = .on
                        }
                        displaySubmenu.addItem(item)
                    }
                }
                
                let displayItem = NSMenuItem(title: display.name, action: nil, keyEquivalent: "")
                displayItem.submenu = displaySubmenu
                menu.addItem(displayItem)
            }
        }
        
        // Quit at the bottom
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
        // Quit app while keeping the current display resolution
        // (no reset to previous resolution)
        NSApplication.shared.terminate(nil)
    }
    
    private func saveDisplayModePersistence(displayID: CGDirectDisplayID, mode: DisplayModeInfo) {
        let key = "DisplayMode_\(displayID)"
        let modeData: [String: Any] = [
            "width": mode.width,
            "height": mode.height,
            "refreshRate": mode.refreshRate,
            "isHiDPI": mode.isHiDPI,
            "timestamp": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(modeData, forKey: key)
        NSLog("[MenuController] Saved display mode for display \(displayID): \(mode.label)")
    }
    
    private func restorePersistedDisplayModes() {
        let displays = displayService.getDisplays()
        
        for display in displays {
            let key = "DisplayMode_\(display.id)"
            guard let modeData = UserDefaults.standard.dictionary(forKey: key) as? [String: Any],
                  let width = modeData["width"] as? Int,
                  let height = modeData["height"] as? Int,
                  let refreshRate = modeData["refreshRate"] as? Double else {
                continue
            }
            
            let allModes = displayService.getModes(for: display.id)
            
            // Find matching mode
            if let matchingMode = allModes.first(where: { mode in
                mode.width == width && mode.height == height && abs(mode.refreshRate - refreshRate) < 0.5
            }) {
                let success = displayService.setMode(matchingMode, for: display.id)
                if success {
                    NSLog("[MenuController] Restored display mode for \(display.name): \(matchingMode.label)")
                } else {
                    NSLog("[MenuController] Failed to restore display mode for \(display.name)")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }
}

// Helper struct to pass mode selection data
private struct ModeSelection {
    let displayID: CGDirectDisplayID
    let mode: DisplayModeInfo
}
