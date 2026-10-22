//
//  Book.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

/// App-level representation of a book. Decoupled from the network DTO so the
/// UI, persistence and recommendation logic never depend on API field names.
nonisolated struct Book: Identifiable, Hashable, Codable {
    /// Open Library work identifier, ex. `OL27448W`
    let id: String
    let title: String
    let authors: [String]
    let firstPublishYear: Int?
    let isbn: String?
    let coverID: Int?
    let subjects: [String]
}

/// Inputs to the author and subject searches in RecommendationsViewModel
nonisolated extension Book {
    private static let noisySubjects: Set<String> = [
        "accessible book", "protected daisy", "in library", "large type books",
        "lending library", "internet archive wishlist", "overdrive", "general",
        "fiction", "open library staff picks"
    ]
    
    var primaryAuthor: String? { authors.first }
    
    /// Open Library subject lists mix useful genres with catalogue noise
    /// ("Accessible book", "nyt:hardcover-fiction=2012-01-01"). Pick the first useful one.
    var primarySubject: String? {
        let candidates = subjects
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let useful = candidates.first { subject in
            !Book.noisySubjects.contains(subject.lowercased()) && !subject.contains(":")
        }
        return useful ?? candidates.first
    }
}

/// Formatted values shown by BookRowView
nonisolated extension Book {
    var authorLine: String {
        authors.isEmpty ? "Unknown author" : authors.joined(separator: ", ")
    }
    
    var yearText: String {
        firstPublishYear.map(String.init) ?? "Year unknown"
    }
    
    var isbnText: String {
        isbn ?? "ISBN unavailable"
    }
    
    /// Cover art URL. `default=false` makes Open Library answer 404 (rather than a
    /// blank pixel) when no cover exists, so the UI can show its own placeholder.
    /// Default to size M.
    func coverURL() -> URL? {
        guard let coverID else { return nil }
        return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg?default=false")
    }
}

/// Identity and de-duplication
nonisolated extension Book {
    /// Loose identity used to collapse duplicate listings of the same book
    /// (same title + first author, ignoring case, accents and punctuation).
    var identityKey: String {
        "\(Book.normalize(title))|\(Book.normalize(primaryAuthor ?? ""))"
    }
    
    // Filters out the original searched-for book from the fetched book list
    func isSameWork(as other: Book) -> Bool {
        id == other.id || identityKey == other.identityKey
    }
    
    /// Lowercases, strips accents, and keeps only letters and digits:
    /// "Les Misérables!" → "lesmiserables"
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).filter { $0.isLetter || $0.isNumber }
    }
}

nonisolated extension Array where Element == Book {
    // Search by author and search by subject can return the same book, so we compare and remove those duplicates
    /// Removes repeated books (by id, then by loose title/author identity), keeping first occurrences.
    func removingDuplicates() -> [Book] {
        var seenIDs = Set<String>()
        var seenIdentities = Set<String>()
        return filter { book in
            guard seenIDs.insert(book.id).inserted else { return false }
            return seenIdentities.insert(book.identityKey).inserted
        }
    }
}
