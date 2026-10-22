//
//  BookRowView.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

/// Displays the required fields for a book: cover art, title, author, year and ISBN.
struct BookRowView: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: book.coverURL()) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray
                    .opacity(0.15)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    )
            }
            .frame(width: 64, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                Text(book.authorLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Year: \(book.yearText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ISBN: \(book.isbnText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview("With cover") {
    List {
        BookRowView(book: .previewDune)
    }
}

#Preview("Missing details") {
    List {
        BookRowView(book: .previewNoCover)
    }
}
