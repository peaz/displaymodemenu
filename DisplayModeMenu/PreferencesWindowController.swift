//
//  PreferencesWindowController.swift
//  DisplayModeMenu
//
//  Complete rebuilt preferences window with Settings and About tabs
//

import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController {
    private weak var menuController: MenuController?
    
    init(menuController: MenuController) {
        self.menuController = menuController
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.minSize = NSSize(width: 600, height: 550)
        window.center()
        super.init(window: window)
        
        let tabVC = NSTabViewController()
        let settingsTab = NSTabViewItem(viewController: SettingsTabViewController(menuController: menuController))
        settingsTab.label = "Settings"
        let aboutTab = NSTabViewItem(viewController: AboutTabViewController())
        aboutTab.label = "About"
        tabVC.addTabViewItem(settingsTab)
        tabVC.addTabViewItem(aboutTab)
        
        window.contentViewController = tabVC
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(selectedTab: Int = 0) {
        if let tabVC = window?.contentViewController as? NSTabViewController {
            tabVC.selectedTabViewItemIndex = selectedTab
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Display Mode Validation Utility
struct DisplayModeValidator {
    struct ValidationResult {
        let correctedLines: [NSAttributedString]
        let validResolutions: [FavoriteResolution]
        let hasWarnings: Bool
        let correctionsMade: Bool
        let statusMessage: String
        let statusColor: NSColor
    }
    
    static func validateAndCorrect(
        text: String,
        availableModes: Set<String>
    ) -> ValidationResult {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        
        var resolutions: [FavoriteResolution] = []
        var correctedLines: [NSAttributedString] = []
        var warnings: [String] = []
        var correctionsMade = false
        var hasContent = false
        var seenModes = Set<String>()  // Track duplicates
        
        for (lineNum, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip blank lines completely (don't add to output)
            if trimmedLine.isEmpty {
                continue
            }
            
            hasContent = true
            let parts = trimmedLine.split(separator: ",", omittingEmptySubsequences: true).map { String($0).trimmingCharacters(in: .whitespaces) }
            
            // Validate format and apply defaults
            if parts.count >= 2 {
                if let width = Int(parts[0]), let height = Int(parts[1]) {
                    // Parse refresh rate (default 30 if missing)
                    var refreshRate: Double = 30.0
                    if parts.count >= 3, let parsed = Double(parts[2]) {
                        refreshRate = parsed
                    } else if parts.count == 2 {
                        correctionsMade = true
                    }
                    
                    // Parse hiDPI (default true if missing)
                    var hiDPI: Bool = true
                    if parts.count >= 4, let parsed = Bool(parts[3].lowercased()) {
                        hiDPI = parsed
                    } else if parts.count <= 3 {
                        correctionsMade = true
                    }
                    
                    // Build the corrected line
                    let correctedLine = "\(width),\(height),\(Int(refreshRate)),\(hiDPI)"
                    
                    // Check for duplicates and skip if already seen
                    if seenModes.contains(correctedLine) {
                        correctionsMade = true
                        continue
                    }
                    seenModes.insert(correctedLine)
                    
                    // Check if mode is available
                    let isAvailable = availableModes.contains(correctedLine)
                    
                    // Create attributed string (red if not available)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .foregroundColor: isAvailable ? NSColor.labelColor : NSColor.systemRed
                    ]
                    correctedLines.append(NSAttributedString(string: correctedLine + "\n", attributes: attrs))
                    
                    if !isAvailable {
                        warnings.append("Line \(lineNum + 1): Mode not available on any display")
                    }
                    
                    // Add to resolutions list
                    resolutions.append(FavoriteResolution(width: width, height: height, refreshRate: refreshRate, hiDPI: hiDPI))
                } else {
                    // Invalid width/height
                    warnings.append("Line \(lineNum + 1): Invalid format - width and height must be numbers")
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                        .foregroundColor: NSColor.systemRed
                    ]
                    correctedLines.append(NSAttributedString(string: trimmedLine + "\n", attributes: attrs))
                }
            } else {
                // Not enough parts
                warnings.append("Line \(lineNum + 1): Invalid format - expected: width,height,refreshRate,hiDPI")
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: NSColor.systemRed
                ]
                correctedLines.append(NSAttributedString(string: trimmedLine + "\n", attributes: attrs))
            }
        }
        
        // Determine status message and color
        let statusMessage: String
        let statusColor: NSColor
        
        if !warnings.isEmpty {
            statusMessage = "⚠️ Saved with warnings (red = unavailable mode)"
            statusColor = NSColor.systemOrange
        } else if correctionsMade {
            statusMessage = "✓ Saved (defaults applied: refresh=30, hiDPI=true)"
            statusColor = NSColor.systemGreen
        } else {
            statusMessage = "✓ Saved successfully"
            statusColor = NSColor.systemGreen
        }
        
        return ValidationResult(
            correctedLines: correctedLines,
            validResolutions: resolutions,
            hasWarnings: !warnings.isEmpty,
            correctionsMade: correctionsMade,
            statusMessage: statusMessage,
            statusColor: statusColor
        )
    }
}

// MARK: - Settings Tab
final class SettingsTabViewController: NSViewController {
    private weak var menuController: MenuController?
    private let minRefreshField = NSTextField()
    private let startAtLoginCheckbox = NSButton(checkboxWithTitle: "Start at Login", target: nil, action: nil)
    private let showLowResCheckbox = NSButton(checkboxWithTitle: "Show Low Resolution Modes", target: nil, action: nil)
    private let favoritesTextView = NSTextView()
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    
    init(menuController: MenuController?) {
        self.menuController = menuController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            container.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
        
        var currentY: CGFloat = 0
        
        // Minimum Refresh Rate Section
        let minRefreshLabel = NSTextField(labelWithString: "Minimum Refresh Rate (Hz):")
        minRefreshLabel.translatesAutoresizingMaskIntoConstraints = false
        minRefreshLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        container.addSubview(minRefreshLabel)
        
        minRefreshField.translatesAutoresizingMaskIntoConstraints = false
        minRefreshField.placeholderString = "60"
        minRefreshField.font = NSFont.systemFont(ofSize: 12)
        container.addSubview(minRefreshField)
        
        NSLayoutConstraint.activate([
            minRefreshLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            minRefreshLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            minRefreshField.centerYAnchor.constraint(equalTo: minRefreshLabel.centerYAnchor),
            minRefreshField.leadingAnchor.constraint(equalTo: minRefreshLabel.trailingAnchor, constant: 10),
            minRefreshField.widthAnchor.constraint(equalToConstant: 80)
        ])
        currentY += 40
        
        // Show Low Resolution Modes Checkbox
        showLowResCheckbox.translatesAutoresizingMaskIntoConstraints = false
        showLowResCheckbox.target = self
        showLowResCheckbox.action = #selector(toggleShowLowRes)
        container.addSubview(showLowResCheckbox)
        
        NSLayoutConstraint.activate([
            showLowResCheckbox.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            showLowResCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0)
        ])
        currentY += 35
        
        // Start at Login Checkbox
        startAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        startAtLoginCheckbox.target = self
        startAtLoginCheckbox.action = #selector(toggleStartAtLogin)
        container.addSubview(startAtLoginCheckbox)
        
        NSLayoutConstraint.activate([
            startAtLoginCheckbox.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            startAtLoginCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0)
        ])
        currentY += 50
        
        // Favorite Resolutions Section
        let favoritesLabel = NSTextField(labelWithString: "Favorite Resolutions")
        favoritesLabel.translatesAutoresizingMaskIntoConstraints = false
        favoritesLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        container.addSubview(favoritesLabel)
        
        let infoLabel = NSTextField(labelWithString: "Format: width,height,refreshRate,hiDPI (one per line)")
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.secondaryLabelColor
        container.addSubview(infoLabel)
        
        let exampleLabel = NSTextField(labelWithString: "Example: 1920,1080,60,false")
        exampleLabel.translatesAutoresizingMaskIntoConstraints = false
        exampleLabel.font = NSFont.systemFont(ofSize: 11)
        exampleLabel.textColor = NSColor.tertiaryLabelColor
        container.addSubview(exampleLabel)
        
        NSLayoutConstraint.activate([
            favoritesLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            favoritesLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            infoLabel.topAnchor.constraint(equalTo: favoritesLabel.bottomAnchor, constant: 5),
            infoLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            exampleLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 2),
            exampleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0)
        ])
        currentY += 80
        
        // Text view for favorites
        let textScrollView = NSScrollView()
        textScrollView.translatesAutoresizingMaskIntoConstraints = false
        textScrollView.hasVerticalScroller = true
        textScrollView.hasHorizontalScroller = false
        textScrollView.borderType = .bezelBorder
        textScrollView.autohidesScrollers = false
        container.addSubview(textScrollView)
        
        // Configure text view properly for editing
        let textContentSize = textScrollView.contentSize
        favoritesTextView.frame = NSRect(x: 0, y: 0, width: textContentSize.width, height: textContentSize.height)
        favoritesTextView.minSize = NSSize(width: 0, height: textContentSize.height)
        favoritesTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        favoritesTextView.isVerticallyResizable = true
        favoritesTextView.isHorizontallyResizable = false
        favoritesTextView.autoresizingMask = [.width]
        
        if let textContainer = favoritesTextView.textContainer {
            textContainer.containerSize = NSSize(width: textContentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
        }
        
        favoritesTextView.isEditable = true
        favoritesTextView.isSelectable = true
        favoritesTextView.allowsUndo = true
        favoritesTextView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        favoritesTextView.textColor = NSColor.labelColor
        favoritesTextView.backgroundColor = NSColor.textBackgroundColor
        favoritesTextView.isRichText = false
        favoritesTextView.usesFontPanel = false
        favoritesTextView.isAutomaticQuoteSubstitutionEnabled = false
        favoritesTextView.isAutomaticDashSubstitutionEnabled = false
        favoritesTextView.isAutomaticTextReplacementEnabled = false
        favoritesTextView.isContinuousSpellCheckingEnabled = false
        favoritesTextView.isGrammarCheckingEnabled = false
        
        textScrollView.documentView = favoritesTextView
        
        NSLayoutConstraint.activate([
            textScrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            textScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            textScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
            textScrollView.heightAnchor.constraint(equalToConstant: 200)
        ])
        currentY += 220
        
        // Save Button, Reset Button, and Status
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        container.addSubview(buttonStack)
        
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        saveButton.bezelStyle = .rounded
        buttonStack.addArrangedSubview(saveButton)
        
        let resetButton = NSButton(title: "Reset to Default", target: self, action: #selector(resetToDefault))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        buttonStack.addArrangedSubview(resetButton)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = NSColor.systemGreen
        statusLabel.font = NSFont.systemFont(ofSize: 20)
        statusLabel.stringValue = ""
        container.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: container.topAnchor, constant: currentY),
            buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            statusLabel.centerYAnchor.constraint(equalTo: buttonStack.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: buttonStack.trailingAnchor, constant: 15),
            container.bottomAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 20)
        ])
    }
    
    private func loadSettings() {
        // Load minimum refresh rate
        minRefreshField.stringValue = String(Int(Preferences.minRefreshRate))
        
        // Load show low resolution setting
        showLowResCheckbox.state = Preferences.showLowResolution ? .on : .off
        
        // Load start at login setting
        startAtLoginCheckbox.state = Preferences.startAtLogin ? .on : .off
        
        // Load favorites - format refresh rate as integer
        let resolutions = Preferences.favoriteResolutions
        var lines: [String] = []
        for resolution in resolutions {
            lines.append("\(resolution.width),\(resolution.height),\(Int(resolution.refreshRate)),\(resolution.hiDPI)")
        }
        favoritesTextView.string = lines.joined(separator: "\n")
    }
    
    @objc private func toggleShowLowRes() {
        Preferences.showLowResolution = (showLowResCheckbox.state == .on)
        menuController?.refreshMenu()
    }
    
    @objc private func toggleStartAtLogin() {
        Preferences.startAtLogin = (startAtLoginCheckbox.state == .on)
    }
    
    @objc private func resetToDefault() {
        // Reset favorites to default list
        let defaults = Preferences.defaultFavoriteResolutions()
        var lines: [String] = []
        for resolution in defaults {
            lines.append("\(resolution.width),\(resolution.height),\(Int(resolution.refreshRate)),\(resolution.hiDPI)")
        }
        favoritesTextView.string = lines.joined(separator: "\n")
        
        // Show status message
        statusLabel.stringValue = "✓ Reset to default list (click Save to apply)"
        statusLabel.textColor = NSColor.systemBlue
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        
        // Hide message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
    
    @objc private func saveSettings() {
        // Save minimum refresh rate
        if let value = Double(minRefreshField.stringValue), value > 0 {
            Preferences.minRefreshRate = value
        }
        
        // Get all available display modes from MenuController cache
        let allAvailableModes = menuController?.getAllAvailableModeKeys() ?? Set<String>()
        
        // Validate and correct favorites using the utility
        let result = DisplayModeValidator.validateAndCorrect(
            text: favoritesTextView.string,
            availableModes: allAvailableModes
        )
        
        // Update text view with colored and corrected text (blank lines removed)
        let finalAttributedString = NSMutableAttributedString()
        for attrStr in result.correctedLines {
            finalAttributedString.append(attrStr)
        }
        favoritesTextView.textStorage?.setAttributedString(finalAttributedString)
        
        // Save validated resolutions
        Preferences.favoriteResolutions = result.validResolutions
        
        // Show status message
        statusLabel.stringValue = result.statusMessage
        statusLabel.textColor = result.statusColor
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        
        // Refresh cache and menu
        menuController?.cacheDisplayModes()
        menuController?.refreshMenu()
        
        // Hide success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
}

// MARK: - About Tab
final class AboutTabViewController: NSViewController {
    private var container: NSStackView?
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // Ensure container is centered when view layout happens
        container?.needsLayout = true
    }
    
    private func setupUI() {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 16
        container.alignment = .centerX
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        self.container = container
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        let titleLabel = NSTextField(labelWithString: AppConfig.appName)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        container.addArrangedSubview(titleLabel)
        
        let versionLabel = NSTextField(labelWithString: "Version \(AppConfig.version)")
        versionLabel.font = NSFont.systemFont(ofSize: 13)
        versionLabel.textColor = NSColor.secondaryLabelColor
        versionLabel.alignment = .center
        container.addArrangedSubview(versionLabel)        
        
        let devLabel = NSTextField(labelWithString: "Vibe coded by \(AppConfig.developerName)")
        devLabel.font = NSFont.systemFont(ofSize: 14)
        devLabel.alignment = .center
        container.addArrangedSubview(devLabel)
        
        let websiteButton = NSButton(title: "atpeaz.com", target: self, action: #selector(openWebsite))
        websiteButton.bezelStyle = .rounded
        container.addArrangedSubview(websiteButton)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalToConstant: 300).isActive = true
        
        let coffeeLabel = NSTextField(labelWithString: "Support this project")
        coffeeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        coffeeLabel.alignment = .center
        container.addArrangedSubview(coffeeLabel)
        
        let coffeeButton = NSButton(title: "Buy me a coffee ☕", target: self, action: #selector(openCoffee))
        coffeeButton.bezelStyle = .rounded
        container.addArrangedSubview(coffeeButton)
        
        // QR Code
        if let img = NSImage(named: "BuyCoffeeQR") {
            let imageView = NSImageView(image: img)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 180).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 180).isActive = true
            container.addArrangedSubview(imageView)
        }
    }
    
    @objc private func openWebsite() {
        if let url = URL(string: AppConfig.websiteURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openCoffee() {
        if let url = URL(string: AppConfig.buyMeCoffeeURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
