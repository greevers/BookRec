//
//  FileReadingListStore.swift
//  BookRec
//
//  Created by Sean Greevers on 10/21/26.
//

import Foundation

/// Local persistence protocol for DI
///
/// Async so callers (the view model) can hop off the main actor for the
/// actual disk work. Writes one book at a time, so no write can
/// remove books it wasn't asked about.
protocol ReadingListStore {
    /// Loads all books in the order they were added
    func load() async throws -> [Book]
    /// Inserts a book at the end of the list, or updates it in place if already stored
    func insert(_ book: Book) async throws
    /// Removes the book with the given id. Removing a book that isn't stored does nothing
    func delete(id: Book.ID) async throws
}

/// Entry point for persistent stores. Callers only ever see `ReadingListStore`
/// We don't want callers to be able to instantiate any FileReadingListStore anywhere,
/// so make FileReadingListStore private and force using a shared store
enum ReadingListStores {
    static let shared: ReadingListStore = FileReadingListStore(fileURL: .applicationSupportDirectory.appending(path: "ReadingList.json"))
}

/// ReadingListStore backed by a JSON file. An actor, so reads and writes
/// are serialized; the array order in the file is the insertion order.
/// Private so the rest of the app depends only on `ReadingListStore`
private actor FileReadingListStore: ReadingListStore {
    private let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    // Loads all books from persistent store (file storage here)
    func load() throws -> [Book] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([Book].self, from: Data(contentsOf: fileURL))
    }
    
    // Inserts a new book to persistent store
    func insert(_ book: Book) throws {
        var books = try load()
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            // Skip the write if nothing changed, otherwise upsert the book if id already exists
            if books[index] == book { return }
            books[index] = book
        } else {
            books.append(book)
        }
        try save(books)
    }
    
    // Removes a book from persistent store
    func delete(id: Book.ID) throws {
        var books = try load()
        books.removeAll { $0.id == id }
        try save(books)
    }
    
    // Atomic, so a crash mid-write leaves the previous list intact. Meaning we write
    // to an auxilliary file first, then replaces the original file once writing completes
    private func save(_ books: [Book]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(books).write(to: fileURL, options: .atomic)
    }
}
