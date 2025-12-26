# Fixing NSMenu submenu auto-close bug in LSUIElement apps

**The solution is an invisible window trick**: creating a **1×1 pixel borderless window** with `alphaValue = 0`, briefly making it key, then immediately hiding it forces window server initialization without any visible UI. This resolves the submenu auto-closing bug where first submenu access fails but second access works.

The root cause is now confirmed: LSUIElement apps using `NSApplicationActivationPolicyAccessory` don't trigger the initial activation event macOS expects. The window server connection remains partially uninitialized until a window becomes key for the first time. This explains why your Settings window workaround worked—it forced the initialization.

## The invisible window solution

The most reliable fix creates an invisible window at app launch that triggers window server initialization without showing anything to the user:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var helperWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        initializeWindowServer()
        setupStatusItem()  // Continue with normal menu setup
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
}

// Critical: borderless windows cannot become key by default
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}
```

**Critical implementation details**: Borderless windows cannot become key by default—you **must** subclass NSWindow and override `canBecomeKey` to return `true`. The `alphaValue = 0` must be set before `makeKeyAndOrderFront`, and using `DispatchQueue.main.async` for `orderOut` ensures the window server initialization completes before hiding. Keeping a reference prevents premature deallocation.

## Why this bug exists

Research confirms this is a systemic issue with LSUIElement apps, documented in multiple contexts. The **wxWidgets framework bug #16156** explains that LSUIElement apps "get stuck before initialization until activated" because they rely on an initial activation event that never occurs. Apple DTS engineer Kevin Elliott clarified that `LSUIElement` "tells LaunchServices not to create a dock icon during early launch, then sets your app into `NSApplicationActivationPolicyAccessory` once running"—this partial initialization leaves AppKit's internal state machines incomplete.

Multiple documented NSMenu bugs exhibit similar "works on second try" patterns. Apple Radar **rdar://9277191** documents a related issue where `popUpMenuPositioningItem:atLocation:inView:` fails to return in LSUIElement apps under certain conditions. The **BonzaiThePenguin/Loading** menubar app documents that `[NSMenuItem setView:]` causes keyboard controls to stop working "after using the menu for the first time."

## Alternative approaches that work

**Activation policy dance**: Temporarily switching to `.regular` activation policy, then back to `.accessory`:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // Briefly become regular app to fully initialize
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.setActivationPolicy(.accessory)
        // Now set up your menu
    }
}
```

This approach leverages the fact that apps can "freely transition in/out of app types" as documented by Apple DTS. The brief `.regular` state triggers full initialization, and users may see a momentary dock icon flash.

**NSPopover instead of submenus**: Multiple developers recommend replacing complex NSMenu submenus with NSPopover, which doesn't suffer from these initialization issues:

```swift
let popover = NSPopover()
popover.contentViewController = SubMenuViewController()
popover.behavior = .transient

if let button = statusItem.button {
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
}
```

## Techniques that were investigated but aren't recommended

**CGS private APIs** like `_CGSDefaultConnection()` and `CGSSetConnectionProperty()` exist in Core Graphics Services, but using them results in App Store rejection. Apple scans binaries for private API usage including string-based selector calls and dlsym lookups.

**Zero-sized windows (0×0)** may not trigger proper window server initialization—the **1×1 pixel** size with `alphaValue = 0` is the reliable approach.

**Offscreen positioning** (placing a window at coordinates like -10000, -10000) works but is less reliable than `alphaValue = 0` because macOS may pull windows back to visible screen areas in some circumstances.

## Timing and order of operations

The correct sequence is:

1. Create the NSWindow with borderless style and 1×1 size
2. Set `alphaValue = 0`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`
3. Call `NSApp.activate(ignoringOtherApps: true)`
4. Call `window.makeKeyAndOrderFront(nil)`
5. On next main loop cycle via `DispatchQueue.main.async`, call `window.orderOut(nil)`
6. Store the window reference to prevent deallocation
7. Proceed with normal menu setup

The async pattern ensures one main loop cycle completes, which appears sufficient for window server initialization—no documented minimum time is required.

## Properties summary for invisible windows

| Property | Value | Purpose |
|----------|-------|---------|
| `styleMask` | `.borderless` | No window decoration |
| `alphaValue` | `0` | Completely invisible |
| `isOpaque` | `false` | Enable transparency |
| `backgroundColor` | `.clear` | Transparent background |
| `hasShadow` | `false` | Prevent shadow artifacts |
| `canBecomeKey` | `true` (override) | Allow window server init |
| `canBecomeMain` | `false` (override) | Don't steal main status |

## Conclusion

The invisible window technique is the cleanest solution for this undocumented LSUIElement initialization bug. Creating a **1×1 borderless window** with **alphaValue = 0**, briefly making it key, then hiding it via async dispatch resolves the submenu auto-closing issue using only public APIs. This works because it forces the window server connection to fully initialize, the same mechanism that made your Settings window workaround effective. File this bug with Apple referencing rdar://9277191 as a related issue—this pattern has persisted for over a decade with no official fix.