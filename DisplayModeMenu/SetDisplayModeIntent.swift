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
        description: "Settings format: '2560,1440,60,true' or Legacy: '1920x1080@60'",
        inputOptions: String.IntentInputOptions(
            keyboardType: .default,
            capitalizationType: .none,
            multiline: false,
            autocorrect: false
        ),
        requestValueDialog: IntentDialog("Enter resolution in format: width,height,refreshRate,hiDPI\nExample: 2560,1440,60,true\n\nOr legacy format: 1920x1080@60")
    )
    var resolution: String
    
    @Parameter(
        title: "Display Name",
        description: "Name of the display (e.g., 'DELL U2723QE'). Leave empty for main display.",
        default: nil,
        requestValueDialog: IntentDialog("Optional: Enter the display name for multi-display setups.\n\nLeave empty to use the main display.\n\nTip: Copy display name by clicking on the name on the DisplayMode menu")
    )
    var displayName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$displayName) to \(\.$resolution)") {
            \.$displayName
        }
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let displayService = DisplayService.shared
        
        // Parse and validate resolution format
        guard let spec = ResolutionSpec.parse(resolution) else {
            return .result(
                dialog: IntentDialog(stringLiteral: "Invalid format. Use:\nSettings: 2560,1440,60,true\nLegacy: 1920x1080@60")
            )
        }
        
        // Attempt to set the mode using pre-parsed spec (avoids double parsing)
        let result = displayService.setMode(spec: spec, displayName: displayName)
        
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
