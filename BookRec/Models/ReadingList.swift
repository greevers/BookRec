//
//  ReadingList.swift
//  BookRec
//
//  Created by Sean Greevers on 10/21/26.
//

import Foundation

/// App-wide source of truth for saved books, injected into the view models that read
/// or save to the list (ReadingListViewModel, RecommendationsViewModel)
@Observable
final class ReadingList {
    static let shared = ReadingList(store: ReadingListStores.shared)
    
    private(set) var books: [Book] = []
    private(set) var errorMessage: String?
    
    // Persistent store - went with simple file storage
    // CoreData or SwiftData would be better but...ask me
    private let store: ReadingListStore
    
    // Displays error alert on RootView if the reading list couldn't be loaded or saved
    var showsError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }
    
    init(store: ReadingListStore) {
        self.store = store
    }
    
    /// Loads the stored list, called once at launch
    func load() async {
        do {
            books = try await store.load()
        } catch {
            errorMessage = "Your reading list couldn't be loaded."
        }
    }
    
    /// Check when adding to persistence & SaveToListButton state
    func contains(_ book: Book) -> Bool {
        books.contains { $0.id == book.id }
    }
    
    /// Add a book to persistent store, called from RecommendationsViewModel
    func add(_ book: Book) async {
        guard !contains(book) else { return }
        
        do {
            try await store.insert(book)
            // A second tap may have tried to insert again while we were awaiting the insert
            if !contains(book) {
                books.append(book)
            }
        } catch {
            errorMessage = "Your reading list couldn't be saved. Please try again."
        }
    }
    
    /// Remove books from persistent store, called from ReadingListViewModel
    func remove(at offsets: IndexSet) async {
        let ids = offsets.map { books[$0].id }
        for id in ids {
            do {
                try await store.delete(id: id)
                books.removeAll { $0.id == id }
            } catch {
                errorMessage = "That book couldn't be removed. Please try again."
            }
        }
    }
}
