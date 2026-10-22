import Foundation
@testable import BookRec

extension Book {
    static func fixture(
        id: String = "OL1W",
        title: String = "Fixture Title",
        authors: [String] = ["Fixture Author"],
        year: Int? = 2000,
        isbn: String? = "9780000000001",
        coverID: Int? = 1,
        subjects: [String] = ["Fantasy"]
    ) -> Book {
        Book(
            id: id,
            title: title,
            authors: authors,
            firstPublishYear: year,
            isbn: isbn,
            coverID: coverID,
            subjects: subjects
        )
    }
}

struct StubError: LocalizedError, Equatable {
    var errorDescription: String? { "stub failure" }
}

/// Scriptable `BookSearchService` that records the queries it receives.
/// Author and subject results hold every matching book; calls return the `offset..<offset+pageSize` slice of it.
final class StubSearcher: BookSearchService {
    private(set) var titleQueries: [String] = []
    private(set) var authorQueries: [String] = []
    private(set) var subjectQueries: [String] = []
    private(set) var authorOffsets: [Int] = []
    private(set) var subjectOffsets: [Int] = []

    var pageSize = 2
    var titleResult: Result<[Book], Error> = .success([])
    var authorResult: Result<[Book], Error> = .success([])
    var subjectResult: Result<[Book], Error> = .success([])

    func books(matchingTitle title: String) async throws -> [Book] {
        titleQueries.append(title)
        return try titleResult.get()
    }

    func books(byAuthor author: String, offset: Int) async throws -> BookPage {
        authorQueries.append(author)
        authorOffsets.append(offset)
        return try page(of: authorResult, offset: offset)
    }

    func books(inSubject subject: String, offset: Int) async throws -> BookPage {
        subjectQueries.append(subject)
        subjectOffsets.append(offset)
        return try page(of: subjectResult, offset: offset)
    }

    private func page(of result: Result<[Book], Error>, offset: Int) throws -> BookPage {
        let all = try result.get()
        let start = min(offset, all.count)
        let end = min(offset + pageSize, all.count)
        return BookPage(books: Array(all[start..<end]), hasMore: end < all.count, nextOffset: end)
    }
}

final class MockHTTPClient: HTTPClient {
    private let handler: (URLRequest) throws -> (Data, URLResponse)
    private(set) var requests: [URLRequest] = []

    init(handler: @escaping (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try handler(request)
    }
}

/// Persistence double whose saves always fail.
struct FailingStore: ReadingListStore {
    func load() async throws -> [Book] { [] }
    func insert(_ book: Book) async throws { throw StubError() }
}

/// In-memory `ReadingListStore` double for view-model-level tests.
final class InMemoryReadingListStore: ReadingListStore {
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
