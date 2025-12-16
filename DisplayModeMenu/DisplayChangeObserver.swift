//
//  DisplayChangeObserver.swift
//  DisplayModeMenu
//
//  Observes display configuration changes and notifies the menu controller.
//

import AppKit
import CoreGraphics

class DisplayChangeObserver {
    private weak var menuController: MenuController?
    private var callbackInstalled = false
    
    init(menuController: MenuController) {
        self.menuController = menuController
    }
    
    func startObserving() {
        // Register for display reconfiguration callbacks
        let callback: CGDisplayReconfigurationCallBack = { (displayID, flags, userInfo) in
            guard let observer = unsafeBitCast(userInfo, to: DisplayChangeObserver?.self) else {
                return
            }
            
            // Check if this is a significant change
            if flags.contains(.addFlag) || flags.contains(.removeFlag) || flags.contains(.setModeFlag) {
                // Refresh menu on main thread
                DispatchQueue.main.async {
                    observer.menuController?.refreshMenu()
                }
            }
        }
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let error = CGDisplayRegisterReconfigurationCallback(callback, selfPointer)
        
        if error == .success {
            callbackInstalled = true
        } else {
            print("Failed to register display reconfiguration callback: \(error)")
        }
        
        // Also observe NSApplication screen parameter changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func stopObserving() {
        if callbackInstalled {
            // Note: CGDisplayRemoveReconfigurationCallback requires the same callback pointer
            // For simplicity, we'll rely on app termination to clean up
            callbackInstalled = false
        }
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func screenParametersChanged() {
        // Refresh menu when screen parameters change
        DispatchQueue.main.async {
            self.menuController?.refreshMenu()
        }
    }
    
    deinit {
        stopObserving()
    }
}
