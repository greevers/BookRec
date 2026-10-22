//
//  SearchViewModel.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

@Observable
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case matches(query: String, candidates: [Book])
        case failed
    }
    
    @ObservationIgnored private var currentTask: Task<Void, Never>?
    
    private(set) var state: State = .idle
    var selectedBook: Book?
    var query = ""
    
    private let searchService: BookSearchService
    
    init(searchService: BookSearchService = OpenLibraryService.shared) {
        self.searchService = searchService
    }
    
    /// User submitted the entered title.
    func submit() {
        let title = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        selectedBook = nil
        
        // Create a task & cancel any previous so we only load the response of the last created task
        currentTask?.cancel()
        currentTask = Task {
            await search(title: title)
        }
    }
    
    /// User picked one of the matching candidates.
    func select(_ book: Book) {
        selectedBook = book
    }
    
    /// Performs a book search with the given title.
    func search(title: String) async {
        state = .loading
        do {
            let candidates = try await searchService.books(matchingTitle: title)
            guard !Task.isCancelled else { return }
            
            // state update causes view reload & list to appear
            state = .matches(query: title, candidates: candidates)
            if candidates.count == 1 {
                // setting selectedBook automatically advances to RecommendationsView
                selectedBook = candidates[0]
            }
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            state = .failed
        }
    }
}
