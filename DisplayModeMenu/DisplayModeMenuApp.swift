//
//  DisplayModeMenuApp.swift
//  DisplayModeMenu
//
//  Main application delegate for the menu bar app.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var menuController: MenuController?
    @MainActor private var displayObserver: DisplayChangeObserver?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // For LSUIElement apps, we must ensure the event loop runs
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
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
    
    func applicationWillTerminate(_ aNotification: Notification) {
        displayObserver?.stopObserving()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
