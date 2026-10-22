//
//  BookSearchService.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

// Used for pagination
/// One page of search results.
nonisolated struct BookPage: Equatable {
    let books: [Book]
    /// Whether a request at the next offset will return more results.
    let hasMore: Bool
    /// The offset to pass on the next request for this search.
    let nextOffset: Int
}

/// Book searching service protocol. Author and subject searches are paginated:
/// `offset` is the index of the first result to return. `limit` is the page size.
nonisolated protocol BookSearchService: Sendable {
    /// The most relevant books whose title matches `title` (a single request, no paging).
    func books(matchingTitle title: String) async throws -> [Book]
    /// Books written by `author`.
    func books(byAuthor author: String, offset: Int) async throws -> BookPage
    /// Books filed under `subject`.
    func books(inSubject subject: String, offset: Int) async throws -> BookPage
}

nonisolated enum BookServiceError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case badStatus(Int)
    case decodingFailed
}
