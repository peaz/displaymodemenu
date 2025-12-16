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
    
    static func parse(_ input: String) -> ResolutionSpec? {
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
        
        return ResolutionSpec(width: width, height: height, refreshRate: refreshRate)
    }
}

class DisplayService {
    static let shared = DisplayService()
    
    private init() {}
    
    // MARK: - Display Enumeration
    
    /// Get all active displays with disambiguated names
    func getDisplays() -> [DisplayInfo] {
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
        
        // 1. Try exact match (width, height, and refresh if specified)
        if let exactMatch = modes.first(where: { mode in
            mode.width == spec.width &&
            mode.height == spec.height &&
            (spec.refreshRate == nil || matchesRefreshRate(spec.refreshRate!, actual: mode.refreshRate))
        }) {
            return exactMatch
        }
        
        // 2. Try resolution match without refresh constraint
        let resolutionMatches = modes.filter { $0.width == spec.width && $0.height == spec.height }
        if !resolutionMatches.isEmpty {
            // Prefer HiDPI, then closest refresh rate
            return resolutionMatches.sorted { lhs, rhs in
                if lhs.isHiDPI != rhs.isHiDPI {
                    return lhs.isHiDPI && !rhs.isHiDPI
                }
                if let targetRefresh = spec.refreshRate {
                    let lhsDiff = abs(lhs.refreshRate - targetRefresh)
                    let rhsDiff = abs(rhs.refreshRate - targetRefresh)
                    return lhsDiff < rhsDiff
                }
                return lhs.refreshRate > rhs.refreshRate
            }.first
        }
        
        // 3. Find closest resolution
        let sortedByDistance = modes.sorted { lhs, rhs in
            let lhsDist = resolutionDistance(spec.width, spec.height, lhs.width, lhs.height)
            let rhsDist = resolutionDistance(spec.width, spec.height, rhs.width, rhs.height)
            
            if lhsDist != rhsDist {
                return lhsDist < rhsDist
            }
            // Prefer HiDPI when distance is equal
            if lhs.isHiDPI != rhs.isHiDPI {
                return lhs.isHiDPI && !rhs.isHiDPI
            }
            if let targetRefresh = spec.refreshRate {
                let lhsRefreshDiff = abs(lhs.refreshRate - targetRefresh)
                let rhsRefreshDiff = abs(rhs.refreshRate - targetRefresh)
                return lhsRefreshDiff < rhsRefreshDiff
            }
            return lhs.refreshRate > rhs.refreshRate
        }
        
        return sortedByDistance.first
    }
    
    private func matchesRefreshRate(_ specified: Double, actual: Double) -> Bool {
        let tolerance = 0.5
        return abs(specified - actual) < tolerance
    }
    
    private func resolutionDistance(_ w1: Int, _ h1: Int, _ w2: Int, _ h2: Int) -> Double {
        let dw = Double(w1 - w2)
        let dh = Double(h1 - h2)
        return sqrt(dw * dw + dh * dh)
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
            return .failure(.noMatchingMode(resolution))
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
