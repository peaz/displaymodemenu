//
//  DisplayService.swift
//  DisplayModeMenu
//
//  Core service for display enumeration, mode management, and resolution changes.
//

import AppKit
import CoreGraphics

/// Errors that can occur during display mode operations
enum DisplayModeError: LocalizedError {
    case invalidResolutionFormat
    case displayNotFound(String)
    case noMatchingMode(String)
    case setModeFailed
    case mainDisplayNotFound
    case couldNotDetermineDisplay
    
    var errorDescription: String? {
        switch self {
        case .invalidResolutionFormat:
            return "Invalid resolution format. Use format like '1920x1080@60' or '1920x1080'"
        case .displayNotFound(let name):
            return "Display '\(name)' not found"
        case .noMatchingMode(let resolution):
            return "No matching mode found for resolution \(resolution)"
        case .setModeFailed:
            return "Failed to set display mode"
        case .mainDisplayNotFound:
            return "Main display not found"
        case .couldNotDetermineDisplay:
            return "Could not determine target display"
        }
    }
}

/// Represents a display with its ID and user-friendly name
struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String  // Includes disambiguation suffix like "-0", "-1"
    let localizedName: String  // Original NSScreen.localizedName
    let isBuiltIn: Bool
}

/// Represents a display mode with formatted labels
struct DisplayModeInfo {
    let mode: CGDisplayMode
    let width: Int
    let height: Int
    let refreshRate: Double
    let isHiDPI: Bool
    let isCurrent: Bool
    
    var label: String {
        var label = "\(width) × \(height)"
        
        // Add refresh rate if non-zero
        if refreshRate > 0 {
            label += String(format: " @ %.0fHz", refreshRate)
        }
        
        return label
    }
}

/// Resolution specification parsed from string like "1920x1080@60"
struct ResolutionSpec {
    let width: Int
    let height: Int
    let refreshRate: Double?  // nil if not specified
    let hiDPI: Bool?  // nil if not specified
    
    static func parse(_ input: String) -> ResolutionSpec? {
        // Try new format first: width,height,refreshRate,hiDPI (e.g., "2560,1440,60,true")
        if let commaSpec = parseCommaFormat(input) {
            return commaSpec
        }
        
        // Fall back to legacy format: widthxheight[@refresh] (e.g., "1920x1080@60")
        return parseLegacyFormat(input)
    }
    
    private static func parseCommaFormat(_ input: String) -> ResolutionSpec? {
        let parts = input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        guard parts.count >= 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else {
            return nil
        }
        
        var refreshRate: Double? = nil
        if parts.count >= 3, let parsed = Double(parts[2]) {
            refreshRate = parsed
        }
        
        var hiDPI: Bool? = nil
        if parts.count >= 4, let parsed = Bool(parts[3].lowercased()) {
            hiDPI = parsed
        }
        
        return ResolutionSpec(width: width, height: height, refreshRate: refreshRate, hiDPI: hiDPI)
    }
    
    private static func parseLegacyFormat(_ input: String) -> ResolutionSpec? {
        // Regex pattern: width x height [@refresh]
        let pattern = #"^(\d{3,5})\s*x\s*(\d{3,5})(?:@(\d{1,3}(?:\.\d+)?))?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) else {
            return nil
        }
        
        guard let widthRange = Range(match.range(at: 1), in: input),
              let heightRange = Range(match.range(at: 2), in: input),
              let width = Int(input[widthRange]),
              let height = Int(input[heightRange]) else {
            return nil
        }
        
        var refreshRate: Double? = nil
        if match.range(at: 3).location != NSNotFound,
           let refreshRange = Range(match.range(at: 3), in: input),
           let refresh = Double(input[refreshRange]) {
            refreshRate = refresh
        }
        
        return ResolutionSpec(width: width, height: height, refreshRate: refreshRate, hiDPI: nil)
    }
}

class DisplayService {
    static let shared = DisplayService()
    
    // Cache for display enumeration (invalidated on hot-plug)
    private var displaysCache: [DisplayInfo]?
    
    private init() {}
    
    // MARK: - Display Enumeration
    
    /// Invalidate the display cache (call when displays are hot-plugged)
    func invalidateDisplayCache() {
        displaysCache = nil
        #if DEBUG
        NSLog("[DisplayService] Display cache invalidated")
        #endif
    }
    
    /// Get all active displays with disambiguated names
    func getDisplays() -> [DisplayInfo] {
        // Return cached displays if available
        if let cached = displaysCache {
            return cached
        }
        
        var displays: [DisplayInfo] = []
        
        // Get all screens
        let screens = NSScreen.screens
        
        // Build a map of localizedName -> count for disambiguation
        var nameCount: [String: Int] = [:]
        var nameIndex: [String: Int] = [:]
        
        for screen in screens {
            let localizedName = screen.localizedName
            nameCount[localizedName, default: 0] += 1
        }
        
        for screen in screens {
            guard let displayID = screen.displayID else { continue }
            
            let localizedName = screen.localizedName
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            
            // Add disambiguation suffix if needed
            var name = localizedName
            if let count = nameCount[localizedName], count > 1 {
                let index = nameIndex[localizedName, default: 0]
                name = "\(localizedName)-\(index)"
                nameIndex[localizedName] = index + 1
            }
            
            displays.append(DisplayInfo(
                id: displayID,
                name: name,
                localizedName: localizedName,
                isBuiltIn: isBuiltIn
            ))
        }
        
        // Cache the result
        displaysCache = displays
        #if DEBUG
        NSLog("[DisplayService] Cached \(displays.count) display(s)")
        #endif
        return displays
    }
    
    /// Find display by disambiguated name
    func findDisplay(byName name: String) -> DisplayInfo? {
        return getDisplays().first { $0.name == name }
    }
    
    /// Get the main display
    func getMainDisplay() -> DisplayInfo? {
        guard let mainScreen = NSScreen.main,
              let displayID = mainScreen.displayID else {
            return nil
        }
        
        return getDisplays().first { $0.id == displayID }
    }
    
    // MARK: - Mode Enumeration
    
    /// Get all available modes for a display
    func getModes(for displayID: CGDirectDisplayID) -> [DisplayModeInfo] {
        // Request ALL modes, including those that might not be officially supported
        let options: [String: Any] = [
            kCGDisplayShowDuplicateLowResolutionModes as String: kCFBooleanTrue as Any
        ]
        
        guard let modes = CGDisplayCopyAllDisplayModes(displayID, options as CFDictionary) as? [CGDisplayMode],
              let currentMode = CGDisplayCopyDisplayMode(displayID) else {
            return []
        }
        
        let currentModeID = currentMode.ioDisplayModeID
        
        var modeInfos: [DisplayModeInfo] = []
        
        for mode in modes {
            let width = mode.width
            let height = mode.height
            let pixelWidth = mode.pixelWidth
            let pixelHeight = mode.pixelHeight
            let refreshRate = mode.refreshRate
            
            // Determine if HiDPI (pixel dimensions > point dimensions)
            let isHiDPI = pixelWidth > width || pixelHeight > height
            
            // Check if this is the current mode
            let modeID = mode.ioDisplayModeID
            let isCurrent = modeID == currentModeID
            
            modeInfos.append(DisplayModeInfo(
                mode: mode,
                width: width,
                height: height,
                refreshRate: refreshRate,
                isHiDPI: isHiDPI,
                isCurrent: isCurrent
            ))
        }
        
        // Sort by resolution (width, then height), then by HiDPI (prefer HiDPI), then by refresh
        modeInfos.sort { lhs, rhs in
            if lhs.width != rhs.width {
                return lhs.width > rhs.width  // Largest first
            }
            if lhs.height != rhs.height {
                return lhs.height > rhs.height  // Largest first
            }
            if lhs.isHiDPI != rhs.isHiDPI {
                return lhs.isHiDPI && !rhs.isHiDPI  // HiDPI first
            }
            return lhs.refreshRate > rhs.refreshRate  // Highest refresh first
        }
        
        return modeInfos
    }
    
    // MARK: - Mode Matching
    
    /// Find the best matching mode for a resolution specification
    func findMatchingMode(for spec: ResolutionSpec, displayID: CGDirectDisplayID) -> DisplayModeInfo? {
        let modes = getModes(for: displayID)
        
        guard !modes.isEmpty else { return nil }
        
        // Use single-pass min(by:) to find best match based on scoring
        return modes.min { lhs, rhs in
            // Score each mode (lower is better)
            let lhsScore = calculateMatchScore(mode: lhs, spec: spec)
            let rhsScore = calculateMatchScore(mode: rhs, spec: spec)
            return lhsScore < rhsScore
        }
    }
    
    /// Calculate match score for a mode (lower is better)
    private func calculateMatchScore(mode: DisplayModeInfo, spec: ResolutionSpec) -> Double {
        var score: Double = 0
        
        // 1. Resolution match (highest priority)
        let widthDiff = abs(mode.width - spec.width)
        let heightDiff = abs(mode.height - spec.height)
        let resolutionDistance = sqrt(Double(widthDiff * widthDiff + heightDiff * heightDiff))
        score += resolutionDistance * 10000  // High weight for resolution
        
        // 2. HiDPI preference (if specified or default prefer HiDPI)
        let preferHiDPI = spec.hiDPI ?? true
        if mode.isHiDPI != preferHiDPI {
            score += 1000  // Penalty for not matching HiDPI preference
        }
        
        // 3. Refresh rate match (if specified)
        if let targetRefresh = spec.refreshRate {
            let refreshDiff = abs(mode.refreshRate - targetRefresh)
            score += refreshDiff * 10  // Moderate weight for refresh rate
        } else {
            // Prefer higher refresh rate when not specified
            score += (120 - mode.refreshRate)  // Assumes max 120Hz
        }
        
        return score
    }
    
    // MARK: - Mode Setting
    
    /// Set a display mode
    @discardableResult
    func setMode(_ modeInfo: DisplayModeInfo, for displayID: CGDirectDisplayID) -> Bool {
        let error = CGDisplaySetDisplayMode(displayID, modeInfo.mode, nil)
        return error == .success
    }
    
    /// Set a display mode by resolution string
    @discardableResult
    func setMode(resolution: String, displayName: String? = nil) -> Result<String, DisplayModeError> {
        // Parse resolution
        guard let spec = ResolutionSpec.parse(resolution) else {
            return .failure(.invalidResolutionFormat)
        }
        
        return setMode(spec: spec, displayName: displayName)
    }
    
    /// Set a display mode using a pre-parsed ResolutionSpec (avoids double parsing)
    @discardableResult
    func setMode(spec: ResolutionSpec, displayName: String? = nil) -> Result<String, DisplayModeError> {
        
        // Find target display
        let display: DisplayInfo?
        if let displayName = displayName {
            display = findDisplay(byName: displayName)
            if display == nil {
                return .failure(.displayNotFound(displayName))
            }
        } else {
            display = getMainDisplay()
            if display == nil {
                return .failure(.mainDisplayNotFound)
            }
        }
        
        guard let targetDisplay = display else {
            return .failure(.couldNotDetermineDisplay)
        }
        
        // Find matching mode
        guard let mode = findMatchingMode(for: spec, displayID: targetDisplay.id) else {
            let specString = "\(spec.width)x\(spec.height)" + (spec.refreshRate.map { "@\(Int($0))" } ?? "")
            return .failure(.noMatchingMode(specString))
        }
        
        // Apply mode
        if setMode(mode, for: targetDisplay.id) {
            return .success("Changed \(targetDisplay.name) to \(mode.label)")
        } else {
            return .failure(.setModeFailed)
        }
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
