//
//  MenuController.swift
//  DisplayModeMenu
//
//  Rebuilt menu controller with display mode caching and favorites with stars
//

import AppKit
import CoreGraphics
import UserNotifications

class MenuController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let displayService = DisplayService.shared
    private var isMenuOpen = false
    private var preferencesWindow: PreferencesWindowController?
    
    // Cache for display modes with favorite flags (loaded at startup)
    private struct CachedMode {
        let mode: DisplayModeInfo
        let isFavorite: Bool
    }
    private var modeCache: [CGDirectDisplayID: [CachedMode]] = [:]
    private var displaysCache: [DisplayInfo] = []
    
    // Cached SF Symbol images (pre-loaded to prevent menu closing on first access)
    private var displayIconImage: NSImage?
    private var starIconImage: NSImage?
    private var refreshIconImage: NSImage?
    private var quitIconImage: NSImage?
    private var supportIconimage: NSImage?
    
    // Public method to get all available mode keys for validation
    func getAllAvailableModeKeys() -> Set<String> {
        var modeKeys = Set<String>()
        for (_, cachedModes) in modeCache {
            for cached in cachedModes {
                let mode = cached.mode
                let key = "\(mode.width),\(mode.height),\(Int(mode.refreshRate)),\(mode.isHiDPI)"
                modeKeys.insert(key)
            }
        }
        return modeKeys
    }
    
    func setup() {
        // Pre-load SF Symbol images to prevent first-access menu closing
        displayIconImage = NSImage(systemSymbolName: "display", accessibilityDescription: "Display")
        starIconImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Favorite")
        refreshIconImage = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh")
        quitIconImage = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        supportIconimage = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: "Support")
        
        // Pre-warm the attributed string system by creating a dummy attributed string
        // This caches the font lookup and text rendering system
        let _ = NSAttributedString(string: "warmup", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 0),
            .foregroundColor: NSColor.systemBlue
        ])
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "Display Modes") {
                button.image = image
                button.image?.isTemplate = true
                #if DEBUG
                NSLog("[MenuController] Using SF Symbol icon")
                #endif
            } else {
                button.title = "🖥️"
                #if DEBUG
                NSLog("[MenuController] Using emoji icon")
                #endif
            }
        }
        
        // Cache display modes at startup
        cacheDisplayModes()
        
        // Restore last used resolutions
        restoreLastUsedResolutions()
        
        // Build initial menu
        refreshMenu()
    }
    
    // MARK: - Last Used Resolution Restore
    private func restoreLastUsedResolutions() {
        let lastUsed = Preferences.lastUsedResolutions
        guard !lastUsed.isEmpty else {
            #if DEBUG
            NSLog("[MenuController] No last used resolutions to restore")
            #endif
            return
        }
        
        #if DEBUG
        NSLog("[MenuController] Restoring last used resolutions...")
        #endif
        var restoredCount = 0
        
        for display in displaysCache {
            guard let savedMode = lastUsed[display.name] else { continue }
            
            // Find matching mode in available modes
            guard let cachedModes = modeCache[display.id] else { continue }
            
            if let matchingCached = cachedModes.first(where: { cached in
                let mode = cached.mode
                return mode.width == savedMode.width &&
                       mode.height == savedMode.height &&
                       Int(mode.refreshRate) == Int(savedMode.refreshRate) &&
                       mode.isHiDPI == savedMode.hiDPI
            }) {
                let mode = matchingCached.mode
                // Only restore if not already current
                if !mode.isCurrent {
                    #if DEBUG
                    NSLog("[MenuController] Restoring \(display.name) to \(mode.label)")
                    #endif
                    let success = displayService.setMode(mode, for: display.id)
                    if success {
                        #if DEBUG
                        NSLog("[MenuController] Successfully restored \(display.name)")
                        #endif
                        restoredCount += 1
                    } else {
                        #if DEBUG
                        NSLog("[MenuController] Failed to restore \(display.name)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    NSLog("[MenuController] \(display.name) already at saved resolution")
                    #endif
                }
            } else {
                #if DEBUG
                NSLog("[MenuController] Saved resolution for \(display.name) not available")
                #endif
            }
        }
        
        // Only recache if we actually restored at least one resolution
        if restoredCount > 0 {
            #if DEBUG
            NSLog("[MenuController] Recaching modes after restoring \(restoredCount) resolution(s)")
            #endif
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.cacheDisplayModes()
                self?.refreshMenu()
            }
        }
    }
    
    // MARK: - Display Mode Caching
    func cacheDisplayModes() {
        #if DEBUG
        NSLog("[MenuController] Caching display modes...")
        #endif
        displaysCache = displayService.getDisplays()
        modeCache.removeAll()
        
        let favorites = Preferences.favoriteResolutions
        
        for display in displaysCache {
            let modes = displayService.getModes(for: display.id)
            
            // Create cached modes with favorite flags
            let cachedModes = modes.map { mode in
                let isFavorite = favorites.contains { fav in
                    fav.width == mode.width &&
                    fav.height == mode.height &&
                    Int(fav.refreshRate) == Int(mode.refreshRate) &&
                    fav.hiDPI == mode.isHiDPI
                }
                return CachedMode(mode: mode, isFavorite: isFavorite)
            }
            
            modeCache[display.id] = cachedModes
            #if DEBUG
            NSLog("[MenuController] Cached \(cachedModes.count) modes for display: \(display.name)")
            #endif
        }
    }
    
    func refreshMenu() {
        // Rebuild menu from cache
        let menu = NSMenu()
        menu.delegate = self
        

        menu.addItem(NSMenuItem.separator())
        
        if displaysCache.isEmpty {
            let item = NSMenuItem(title: "No Displays Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            // Favorites section
            addFavoritesSection(to: menu)
            
            menu.addItem(NSMenuItem.separator())
            
            // All Modes section
            addAllModesSection(to: menu)
        }
        
        // Refresh, Settings and Quit at the bottom
        menu.addItem(NSMenuItem.separator())
        
        // Refresh Displays
        let refreshItem = NSMenuItem(
            title: "Refresh Displays",
            action: #selector(refreshDisplaysAction),
            keyEquivalent: "r"
        )
        refreshItem.image = refreshIconImage
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        //Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        //Support
        let supportItem = NSMenuItem(
            title: "Buy me a coffee ☕️ ",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        supportItem.image = supportIconimage
        supportItem.target = self
        menu.addItem(supportItem)
        
        //Quit
        let quitItem = NSMenuItem(
            title: "Quit DisplayMode",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.image = quitIconImage
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Favorites Section
    private func addFavoritesSection(to menu: NSMenu) {
        // let favoritesHeader = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        // favoritesHeader.isEnabled = false
        // menu.addItem(favoritesHeader)
        
        var favoriteAdded = false
        var displayCount = 0
        
        for display in displaysCache {
            var displayHasFavorite = false
            var seenFavorites = Set<String>()
            
            guard let cachedModes = modeCache[display.id] else { continue }
            
            for cached in cachedModes where cached.isFavorite {
                let mode = cached.mode
                let key = "\(mode.width)x\(mode.height)@\(Int(mode.refreshRate))_\(mode.isHiDPI)"
                guard !seenFavorites.contains(key) else { continue }
                seenFavorites.insert(key)
                
                if !displayHasFavorite {
                    // Add separator between displays (except before first display)
                    if displayCount > 0 {
                        menu.addItem(NSMenuItem.separator())
                    }
                    
                    // Add display header (clickable to copy name)
                    let displayHeader = NSMenuItem(title: "", action: #selector(copyDisplayName(_:)), keyEquivalent: "")
                    displayHeader.target = self
                    displayHeader.representedObject = display.name
                    displayHeader.image = displayIconImage
                    displayHeader.toolTip = "Click to copy display name"
                    
                    // Use attributed title for bold font
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: 13)
                    ]
                    displayHeader.attributedTitle = NSAttributedString(string: display.name, attributes: attrs)
                    
                    menu.addItem(displayHeader)
                    displayHasFavorite = true
                    favoriteAdded = true
                    displayCount += 1
                }
                
                // Add mode without star on the left
                let modeLabel = mode.isHiDPI ? "\(mode.label) [HiDPI]" : mode.label
                let title = "\(modeLabel)"
                
                let item = NSMenuItem(title: "", action: #selector(modeSelected(_:)), keyEquivalent: "")
                
                // Use bold text for current resolution instead of checkmark
                if mode.isCurrent {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.boldSystemFont(ofSize: 0),
                        .foregroundColor: NSColor.systemBlue
                    ]
                    item.attributedTitle = NSAttributedString(string: title, attributes: attrs)
                } else {
                    item.title = title
                }
                
                item.target = self
                item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                menu.addItem(item)
            }
        }
        
        if !favoriteAdded {
            let noFav = NSMenuItem(title: "  None available", action: nil, keyEquivalent: "")
            noFav.isEnabled = false
            menu.addItem(noFav)
        }
    }
    
    // MARK: - All Modes Section
    private func addAllModesSection(to menu: NSMenu) {
        let allModesHeader = NSMenuItem(title: "All Modes", action: nil, keyEquivalent: "")
        allModesHeader.isEnabled = false
        menu.addItem(allModesHeader)
        
        let minRefreshRate = Preferences.minRefreshRate
        let showLowRes = Preferences.showLowResolution
        
        for display in displaysCache {
            guard let cachedModes = modeCache[display.id] else { continue }
            
            // Filter modes based on preferences
            let filteredCached = cachedModes.filter { cached in
                let mode = cached.mode
                return mode.refreshRate >= minRefreshRate && (mode.isCurrent || mode.isHiDPI || showLowRes)
            }
            
            // Deduplicate modes
            var seenModes = Set<String>()
            let modes = filteredCached.filter { cached in
                let mode = cached.mode
                let key = "\(mode.width)x\(mode.height)@\(Int(mode.refreshRate))_\(mode.isHiDPI)"
                let isNew = !seenModes.contains(key)
                seenModes.insert(key)
                return isNew
            }
            
            // Create submenu for this display
            let displaySubmenu = NSMenu()
            
            if modes.isEmpty {
                let emptyItem = NSMenuItem(title: "No modes available", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                displaySubmenu.addItem(emptyItem)
            } else {
                for cached in modes {
                    let mode = cached.mode
                    let modeLabel = mode.isHiDPI ? "\(mode.label) [HiDPI]" : mode.label
                    let item = NSMenuItem(
                        title: "",
                        action: #selector(modeSelected(_:)),
                        keyEquivalent: ""
                    )
                    
                    // Use bold text for current resolution instead of checkmark
                    if mode.isCurrent {
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: NSFont.boldSystemFont(ofSize: 0),
                            .foregroundColor: NSColor.systemBlue
                        ]
                        item.attributedTitle = NSAttributedString(string: modeLabel, attributes: attrs)
                    } else {
                        item.title = modeLabel
                    }
                    
                    // Add star icon if it's a favorite
                    if cached.isFavorite {
                        item.image = starIconImage
                    }
                    
                    item.target = self
                    item.representedObject = ModeSelection(displayID: display.id, mode: mode)
                    displaySubmenu.addItem(item)
                }
            }
            
            let displayItem = NSMenuItem(title: "  \(display.name)", action: nil, keyEquivalent: "")
            displayItem.submenu = displaySubmenu
            displayItem.image = displayIconImage
            menu.addItem(displayItem)
        }
    }
    
    // MARK: - Actions
    @objc private func modeSelected(_ sender: NSMenuItem) {
        guard let selection = sender.representedObject as? ModeSelection else {
            #if DEBUG
            NSLog("[MenuController] ERROR: No ModeSelection in represented object")
            #endif
            return
        }
        
        #if DEBUG
        NSLog("[MenuController] Switching to mode: \(selection.mode.label) on display \(selection.displayID)")
        #endif
        
        let success = displayService.setMode(selection.mode, for: selection.displayID)
        
        if success {
            NSLog("[MenuController] Mode switch successful")
            
            // Save this resolution as last used for this display
            if let display = displaysCache.first(where: { $0.id == selection.displayID }) {
                var lastUsed = Preferences.lastUsedResolutions
                lastUsed[display.name] = FavoriteResolution(
                    width: selection.mode.width,
                    height: selection.mode.height,
                    refreshRate: selection.mode.refreshRate,
                    hiDPI: selection.mode.isHiDPI
                )
                Preferences.lastUsedResolutions = lastUsed
                NSLog("[MenuController] Saved last used resolution for \(display.name): \(selection.mode.label)")
            }
            
            // Refresh menu to update highlighted current mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.cacheDisplayModes()
                self?.refreshMenu()
            }
        } else {
            NSLog("[MenuController] Mode switch failed")
            let alert = NSAlert()
            alert.messageText = "Failed to change display mode"
            alert.informativeText = "The selected resolution may not be supported."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    @objc private func refreshDisplaysAction(_ sender: NSMenuItem) {
        NSLog("[MenuController] Refreshing displays...")
        cacheDisplayModes()
        refreshMenu()
    }
    
    @objc private func openSettings() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(menuController: self)
        }
        preferencesWindow?.show(selectedTab: 0)  // 0 = Settings tab, 1 = About tab
    }
    
    @objc private func openAbout() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(menuController: self)
        }
        preferencesWindow?.show(selectedTab: 1)  // 0 = Settings tab, 1 = About tab
    }
    
    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func copyDisplayName(_ sender: NSMenuItem) {
        guard let displayName = sender.representedObject as? String else { return }
        
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(displayName, forType: .string)
        
        // Show notification popup using modern UserNotifications
        let content = UNMutableNotificationContent()
        content.title = "Display Name Copied"
        content.body = "\"\(displayName)\" copied to clipboard"
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                NSLog("[MenuController] Notification error: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        NSLog("[MenuController] Copied display name to clipboard: \(displayName)")
        #endif
    }
    
    // MARK: - NSMenuDelegate
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }
}

// MARK: - Helper Structures
struct ModeSelection {
    let displayID: CGDirectDisplayID
    let mode: DisplayModeInfo
}
