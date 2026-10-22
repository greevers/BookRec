//
//  ReadingListView.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

struct ReadingListView: View {
    @State private var viewModel: ReadingListViewModel
    
    // init added for preview purposes
    init(viewModel: ReadingListViewModel = ReadingListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.books.isEmpty {
                    ContentUnavailableView(
                        "Your Reading List is empty",
                        systemImage: "books.vertical",
                        description: Text("Save recommendations from Discover and they'll show up here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.books) { book in
                            BookRowView(book: book)
                        }
                    }
                }
            }
            .navigationTitle("Reading List")
        }
    }
}

#Preview("Empty") {
    ReadingListView(viewModel: ReadingListViewModel(readingList: .preview()))
}

#Preview("With books") {
    let readingList = ReadingList.preview(Book.previewSamples + [.previewNoCover])
    ReadingListView(viewModel: ReadingListViewModel(readingList: readingList))
        .task { await readingList.load() }
}
