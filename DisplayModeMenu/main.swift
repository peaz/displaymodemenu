import Cocoa

// For background apps (LSUIElement=true), we need explicit event loop management
func main() {
    let app = NSApplication.shared
    
    // Set activation policy for background app
    app.setActivationPolicy(.accessory)
    
    // Create and set delegate
    let delegate = AppDelegate()
    app.delegate = delegate
    
    // Activate the app to ensure it gets events
    app.activate(ignoringOtherApps: true)
    
    // Run the application event loop
    app.run()
}

main()

