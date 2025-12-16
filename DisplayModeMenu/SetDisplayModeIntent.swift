//
//  SetDisplayModeIntent.swift
//  DisplayModeMenu
//
//  App Intent for Shortcuts integration to set display modes.
//

import AppIntents
import Foundation

struct SetDisplayModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Display Mode"
    
    static var description = IntentDescription(
        "Changes the resolution and refresh rate of a display.",
        categoryName: "Display"
    )
    
    @Parameter(
        title: "Resolution",
        description: "Resolution in format like '1920x1080@60' or '1920x1080'",
        inputOptions: String.IntentInputOptions(
            keyboardType: .default,
            capitalizationType: .none,
            autocorrect: false
        )
    )
    var resolution: String
    
    @Parameter(
        title: "Display Name",
        description: "Name of the display (e.g., 'Built-in Retina Display-0'). Leave empty for main display.",
        default: nil
    )
    var displayName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set display to \(\.$resolution)") {
            \.$displayName
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let displayService = DisplayService.shared
        
        // Validate resolution format first
        guard ResolutionSpec.parse(resolution) != nil else {
            return .result(
                dialog: IntentDialog(stringLiteral: "Invalid resolution format. Use format like '1920x1080@60' or '1920x1080'.")
            )
        }
        
        // Attempt to set the mode
        let result = displayService.setMode(resolution: resolution, displayName: displayName)
        
        switch result {
        case .success(let message):
            return .result(
                dialog: IntentDialog(stringLiteral: message),
                view: DisplayModeResultView(success: true, message: message)
            )
        case .failure(let error):
            let errorMessage = error.localizedDescription
            return .result(
                dialog: IntentDialog(stringLiteral: "Failed: \(errorMessage)"),
                view: DisplayModeResultView(success: false, message: errorMessage)
            )
        }
    }
}

// Snippet view for Shortcuts results
struct DisplayModeResultView: View {
    let success: Bool
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? .green : .red)
                    .font(.title2)
                Text(success ? "Success" : "Failed")
                    .font(.headline)
            }
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// SwiftUI import
import SwiftUI
