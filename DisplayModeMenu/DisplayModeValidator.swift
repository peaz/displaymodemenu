//
//  DisplayModeValidator.swift
//  DisplayModeMenu
//
//  Utility for validating and correcting favorite resolution entries
//

import AppKit

/// Utility struct for validating and correcting display mode/resolution entries
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
        var duplicatesRemoved = false
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
                        duplicatesRemoved = true
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
        } else if duplicatesRemoved && correctionsMade {
            statusMessage = "✓ Saved (duplicates removed, defaults applied)"
            statusColor = NSColor.systemGreen
        } else if duplicatesRemoved {
            statusMessage = "✓ Saved (duplicates removed)"
            statusColor = NSColor.systemGreen
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
