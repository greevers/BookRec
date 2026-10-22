//
//  SearchView.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel = SearchViewModel()
    
    // init added for preview purposes
    init(viewModel: SearchViewModel = SearchViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Discover")
                .searchable(text: $viewModel.query, prompt: "Title of a book you enjoyed")
                .onSubmit(of: .search) {
                    viewModel.submit()
                }
                .autocorrectionDisabled()
                .navigationDestination(item: $viewModel.selectedBook) { book in
                    RecommendationsView(book: book)
                }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "Find your next read",
                systemImage: "text.book.closed",
                description: Text("Enter the title of a book you enjoyed and we'll suggest others you might like.")
            )
        case .loading:
            ProgressView("Looking for that book…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .matches(let query, let candidates) where candidates.isEmpty:
            ContentUnavailableView(
                "No books found",
                systemImage: "questionmark.circle",
                description: Text("We couldn't find a book titled “\(query)”. Please try entering another title.")
            )
        case .matches(let query, let candidates):
            List {
                Section {
                    ForEach(candidates) { book in
                        Button {
                            viewModel.select(book)
                        } label: {
                            HStack {
                                BookRowView(book: book)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(candidates.count == 1
                         ? "Result for “\(query)”"
                         : "Which book did you mean by “\(query)”? Select the correct title.")
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

#Preview("Idle") {
    SearchView(viewModel: SearchViewModel(searchService: PreviewSearchService()))
        .environment(ReadingList.preview())
}

#Preview("Multiple matches") {
    let viewModel = SearchViewModel(
        searchService: PreviewSearchService(titleResults: Book.previewSamples, recommendations: Book.previewSamples)
    )
    SearchView(viewModel: viewModel)
        .environment(ReadingList.preview())
        .task { await viewModel.search(title: "Dune") }
}

#Preview("No matches") {
    let viewModel = SearchViewModel(searchService: PreviewSearchService())
    SearchView(viewModel: viewModel)
        .environment(ReadingList.preview())
        .task { await viewModel.search(title: "Asdfghjkl") }
}

#Preview("Failed") {
    let viewModel = SearchViewModel(searchService: PreviewSearchService(fails: true))
    SearchView(viewModel: viewModel)
        .environment(ReadingList.preview())
        .task { await viewModel.search(title: "Dune") }
}
