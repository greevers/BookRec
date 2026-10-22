//
//  RecommendationsViewModel.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

@Observable
final class RecommendationsViewModel {
    enum State: Equatable {
        case loading
        case loaded([Book])
        case failed
    }
    
    let book: Book
    private(set) var state: State = .loading
    
    private let searchService: BookSearchService
    @ObservationIgnored private var authorPageOffset = 0
    @ObservationIgnored private var subjectPageOffset = 0
    @ObservationIgnored private var author: String?
    @ObservationIgnored private var subject: String?
    @ObservationIgnored private var isLoadingPage = false
    
    /// Whether another page may add books
    private var hasMore: Bool { author != nil || subject != nil }
    
    init(book: Book, searchService: BookSearchService = OpenLibraryService.shared) {
        self.book = book
        self.searchService = searchService
        self.author = book.primaryAuthor
        self.subject = book.primarySubject
    }
    
    /// Perform first call to load initial book recommendations
    func load() async {
        if case .loaded = state { return }
        state = .loading
        do {
            state = .loaded(try await fetchNextPage(appendingTo: []))
        } catch {
            // The screen went away mid-request; `load()` will fetch again if it reappears.
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            state = .failed
        }
    }
    
    /// Called when book row appears. Loads the next page when it's within the last 5
    func loadMoreIfNeeded(for book: Book) {
        guard
            case .loaded(let books) = state,
            hasMore,
            !isLoadingPage,
            let index = books.firstIndex(of: book),
            index >= books.count - 5
        else {
            return
        }
        
        isLoadingPage = true
        Task {
            await loadNextPage()
        }
    }
    
    /// Appends the next page. On failure the books stay as they are, so the next
    /// scroll near the end requests the same page again
    func loadNextPage() async {
        defer {
            isLoadingPage = false
        }
        
        guard
            case .loaded(let books) = state,
            let updated = try? await fetchNextPage(appendingTo: books)
        else {
            return
        }
        
        state = .loaded(updated)
    }
    
    // Pagination
    /// Fetches the next page from both searches, each at its own offset (author books first), and
    /// returns `existing` plus the new, de-duplicated books. Nothing advances on failure
    private func fetchNextPage(appendingTo existingBookList: [Book]) async throws -> [Book] {
        // If author is nil that means there are no more books to retrieve via author search
        async let byAuthor: BookPage? = if let author {
            try await searchService.books(byAuthor: author, offset: authorPageOffset)
        } else { nil }
        
        // If subject is nil that means there are no more books to retrieve via subject search
        async let bySubject: BookPage? = if let subject {
            try await searchService.books(inSubject: subject, offset: subjectPageOffset)
        } else { nil }
        
        let (authorPage, subjectPage) = try await (byAuthor, bySubject)
        
        // Each search pages independently. The service reports where the next page starts
        var fetchedBookList: [Book] = []
        if let authorPage {
            self.authorPageOffset = authorPage.nextOffset
            // No more books left for author search so set author to nil
            if !authorPage.hasMore { self.author = nil }
            fetchedBookList.append(contentsOf: authorPage.books)
        }
        if let subjectPage {
            self.subjectPageOffset = subjectPage.nextOffset
            // No more books left for subject search so set subject to nil
            if !subjectPage.hasMore { self.subject = nil }
            fetchedBookList.append(contentsOf: subjectPage.books)
        }
        
        // 1) Filter out the original searched-for book from the fetched book list
        // 2) Add the fetched book list to the existing book list
        // 3) Remove duplicates
        return (existingBookList + fetchedBookList.filter { !book.isSameWork(as: $0) }).removingDuplicates()
    }
}
