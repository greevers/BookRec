//
//  SaveToListButton.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

struct SaveToListButton: View {
    @Environment(ReadingList.self) private var readingList
    let book: Book
    
    var body: some View {
        if readingList.contains(book) {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        } else {
            Button {
                Task {
                    await readingList.add(book)
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
    SaveToListButton(book: .previewDune)
        .environment(ReadingList.preview())
}

#Preview("Saved") {
    let readingList = ReadingList.preview([.previewDune])
    SaveToListButton(book: .previewDune)
        .environment(readingList)
        .task { await readingList.load() }
}
