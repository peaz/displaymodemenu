//
//  DisplayModeMenuApp.swift
//  DisplayModeMenu
//
//  Main application delegate for the menu bar app.
//

import Cocoa

// Critical: borderless windows cannot become key by default
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var menuController: MenuController?
    @MainActor private var displayObserver: DisplayChangeObserver?
    private var helperWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // For LSUIElement apps, we must ensure the event loop runs
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Initialize window server to fix submenu auto-close bug
        initializeWindowServer()
        
        // Setup main menu with Edit menu for copy/paste support
        setupMainMenu()
        
        // Initialize menu controller on main thread
        Task { @MainActor in
            self.menuController = MenuController()
            self.menuController?.setup()
            
            // Initialize display change observer
            if let menuController = self.menuController {
                self.displayObserver = DisplayChangeObserver(menuController: menuController)
                self.displayObserver?.startObserving()
            }
        }
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = NSMenu(title: "Edit")
        
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenuItem.submenu?.addItem(NSMenuItem.separator())
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenuItem.submenu?.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        mainMenu.addItem(editMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }
    
    private func initializeWindowServer() {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Make completely invisible BEFORE showing
        window.alphaValue = 0
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        // Activate the app first (critical for LSUIElement)
        NSApp.activate(ignoringOtherApps: true)
        
        // Make key to trigger window server initialization
        window.makeKeyAndOrderFront(nil)
        
        // Hide on next run loop iteration to ensure init completes
        DispatchQueue.main.async { [weak window] in
            window?.orderOut(nil)
        }
        
        // Keep reference to prevent deallocation
        self.helperWindow = window
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        displayObserver?.stopObserving()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
