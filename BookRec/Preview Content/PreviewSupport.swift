#if DEBUG
import Foundation

// Sample data and service doubles for SwiftUI previews, so no preview touches the network or the real reading list

extension Book {
    static let previewDune = Book(
        id: "OL893414W",
        title: "Dune",
        authors: ["Frank Herbert"],
        firstPublishYear: 1965,
        isbn: "9780441172665",
        coverID: 11481354,
        subjects: ["Science fiction"]
    )

    static let previewHobbit = Book(
        id: "OL27482W",
        title: "The Hobbit",
        authors: ["J.R.R. Tolkien"],
        firstPublishYear: 1937,
        isbn: "9780547844978",
        coverID: 14627509,
        subjects: ["Fantasy"]
    )

    static let previewHailMary = Book(
        id: "OL21745884W",
        title: "Project Hail Mary",
        authors: ["Andy Weir"],
        firstPublishYear: 2021,
        isbn: "9780593135211",
        coverID: 11200092,
        subjects: ["Science fiction"]
    )

    /// Missing every optional field, to show the placeholders
    static let previewNoCover = Book(
        id: "OL0W",
        title: "An Obscure Pamphlet",
        authors: [],
        firstPublishYear: nil,
        isbn: nil,
        coverID: nil,
        subjects: []
    )

    static let previewSamples: [Book] = [previewDune, previewHobbit, previewHailMary]
}

/// `BookSearchService` returning canned results, or failing every request
struct PreviewSearchService: BookSearchService {
    var titleResults: [Book] = []
    var recommendations: [Book] = []
    var fails = false

    func books(matchingTitle title: String) async throws -> [Book] {
        if fails { throw URLError(.notConnectedToInternet) }
        return titleResults
    }

    func books(byAuthor author: String, offset: Int) async throws -> BookPage {
        try page()
    }

    func books(inSubject subject: String, offset: Int) async throws -> BookPage {
        try page()
    }

    // Everything comes back in a single page
    private func page() throws -> BookPage {
        if fails { throw URLError(.notConnectedToInternet) }
        return BookPage(books: recommendations, hasMore: false, nextOffset: recommendations.count)
    }
}

/// In-memory `ReadingListStore`
final class PreviewReadingListStore: ReadingListStore {
    private var books: [Book]

    init(books: [Book] = []) {
        self.books = books
    }

    func load() async throws -> [Book] {
        books
    }

    func insert(_ book: Book) async throws {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
        } else {
            books.append(book)
        }
    }
}

extension ReadingList {
    /// A reading list over an in-memory store seeded with `books`. Call `load()` to populate it
    static func preview(_ books: [Book] = []) -> ReadingList {
        ReadingList(store: PreviewReadingListStore(books: books))
    }
}
#endif
