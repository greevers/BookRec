//
//  SaveToListButton.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

/// Presentational save control. The owning screen decides saved state and what saving does
struct SaveToListButton: View {
    let isSaved: Bool
    let onSave: () async -> Void
    
    var body: some View {
        if isSaved {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        } else {
            Button {
                Task {
                    await onSave()
                }
            } label: {
                Label("Save to Book List", systemImage: "bookmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

#Preview("Not saved") {
    SaveToListButton(isSaved: false) {}
}

#Preview("Saved") {
    SaveToListButton(isSaved: true) {}
}
