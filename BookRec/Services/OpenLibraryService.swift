//
//  OpenLibraryService.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

// Protocol for DI & testing
protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

/// `BookSearchService` backed by the Open Library search API.
/// https://openlibrary.org/dev/docs/api/search
struct OpenLibraryService: BookSearchService {
    static let shared = OpenLibraryService()
    private static let endpoint = URL(string: "https://openlibrary.org/search.json")!
    private static let responseFields = "key,title,author_name,first_publish_year,isbn,cover_i,subject"
    private static let titleLimit = 10
    static let recommendationLimit = 20
    
    // API response is snake case, use JSON decoding strategy to convert
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    // For DI, testing purposes
    private let client: HTTPClient
    
    init(client: HTTPClient = URLSession.shared) {
        self.client = client
    }
    
    // Search
    // Perform API search for books matching title
    //
    // removingDuplicates() note
    // Open Library often has several work records for the same book (same title and author,
    // different keys); collapse them so one real match isn't shown as an ambiguous choice.
    func books(matchingTitle title: String) async throws -> [Book] {
        try await search(parameter: "title", value: title, offset: 0, limit: Self.titleLimit).books.removingDuplicates()
    }
    
    // Recommendations
    // Perform API search for book recommendations based on matched book's author
    func books(byAuthor author: String, offset: Int) async throws -> BookPage {
        try await search(parameter: "author", value: author, offset: offset, limit: Self.recommendationLimit)
    }
    
    // Recommendations
    // Perform API search for book recommendations based on matched book's subject
    func books(inSubject subject: String, offset: Int) async throws -> BookPage {
        try await search(parameter: "subject", value: subject, offset: offset, limit: Self.recommendationLimit)
    }
    
    // Perform an API search & decode response
    private func search(parameter: String, value: String, offset: Int, limit: Int) async throws -> BookPage {
        let request = try makeRequest(parameter: parameter, value: value, offset: offset, limit: limit)
        let (data, response) = try await client.send(request)
        
        guard let http = response as? HTTPURLResponse else {
            throw BookServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BookServiceError.badStatus(http.statusCode)
        }
        
        do {
            let decoded = try Self.decoder.decode(SearchResponse.self, from: data)
            let returnedCount = decoded.docs.count
            
            // 1) If returnedCount < limit, that means we've reached the end of items for this search type (author, subject)
            // 2) offset is the number of items we've already seen. If offset + returnedCount >= numFound, that
            //    means we've reached the end of items for this search type
            let hasMore = returnedCount == limit && offset + returnedCount < (decoded.numFound ?? .max)
            // Advance by the raw doc count, not the decoded books, so dropped docs don't cause overlapping pages
            return BookPage(books: decoded.docs.compactMap(Book.init(dto:)), hasMore: hasMore, nextOffset: offset + returnedCount)
        } catch {
            throw BookServiceError.decodingFailed
        }
    }
    
    // Build the URL request w/ query params
    private func makeRequest(parameter: String, value: String, offset: Int, limit: Int) throws -> URLRequest {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw BookServiceError.invalidRequest }
        
        guard var components = URLComponents(url: Self.endpoint, resolvingAgainstBaseURL: false) else {
            throw BookServiceError.invalidRequest
        }
        
        components.queryItems = [
            URLQueryItem(name: parameter, value: trimmed),
            URLQueryItem(name: "fields", value: Self.responseFields),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        // URLComponents leaves "+" unescaped, which Open Library reads as a space ("C++ Primer" -> "C   Primer").
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        
        guard let url = components.url else { throw BookServiceError.invalidRequest }
        return URLRequest(url: url)
    }
}
