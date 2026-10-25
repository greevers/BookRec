//
//  RecommendationsView.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

/// Recommendations for one book, pushed from the Discover screen.
struct RecommendationsView: View {
    @State private var viewModel: RecommendationsViewModel
    
    // BookSearchService and ReadingList added to init for preview purposes
    init(book: Book, searchService: BookSearchService = OpenLibraryService.shared, readingList: ReadingList = .shared) {
        viewModel = RecommendationsViewModel(book: book, searchService: searchService, readingList: readingList)
    }
    
    var body: some View {
        content
            .navigationTitle(viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Finding books like “\(viewModel.book.title)”…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let books) where books.isEmpty:
            ContentUnavailableView(
                "No recommendations yet",
                systemImage: "books.vertical",
                description: Text("We couldn't find similar books for “\(viewModel.book.title)”. Go back to choose another title.")
            )
        case .loaded(let books):
            List {
                Section {
                    ForEach(books) { book in
                        VStack(alignment: .leading) {
                            BookRowView(book: book)
                            SaveToListButton(isSaved: viewModel.isSaved(book)) {
                                await viewModel.save(book)
                            }
                        }
                        .onAppear {
                            viewModel.loadMoreIfNeeded(for: book)
                        }
                    }
                } header: {
                    Text("Because you enjoyed “\(viewModel.book.title)”")
                        .textCase(nil)
                }
            }
        case .failed:
            ContentUnavailableView(
                "Something went wrong",
                systemImage: "exclamationmark.triangle",
                description: Text("Please try searching again.")
            )
        }
    }
}

#Preview("Loaded") {
    NavigationStack {
        RecommendationsView(
            book: .previewDune,
            searchService: PreviewSearchService(recommendations: [.previewHailMary, .previewHobbit, .previewNoCover]),
            readingList: .preview()
        )
    }
}

#Preview("No recommendations") {
    NavigationStack {
        RecommendationsView(book: .previewDune, searchService: PreviewSearchService(), readingList: .preview())
    }
}

#Preview("Failed") {
    NavigationStack {
        RecommendationsView(book: .previewDune, searchService: PreviewSearchService(fails: true), readingList: .preview())
    }
}
