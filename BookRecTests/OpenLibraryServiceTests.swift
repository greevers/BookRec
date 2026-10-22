import XCTest
@testable import BookRec

@MainActor
final class OpenLibraryServiceTests: XCTestCase {
    private func makeService(status: Int = 200, body: String) -> (OpenLibraryService, MockHTTPClient) {
        let client = MockHTTPClient { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
        return (OpenLibraryService(client: client), client)
    }

    private func queryItems(of request: URLRequest?) throws -> [String: String] {
        let url = try XCTUnwrap(request?.url)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
    }

    func testTitleSearchBuildsExpectedRequest() async throws {
        let (service, client) = makeService(body: #"{"docs":[]}"#)

        _ = try await service.books(matchingTitle: "  The Hobbit ")

        let request = try XCTUnwrap(client.requests.first)
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "openlibrary.org")
        XCTAssertEqual(components.path, "/search.json")

        let items = try queryItems(of: request)
        XCTAssertEqual(items["title"], "The Hobbit")
        XCTAssertEqual(items["offset"], "0")
        XCTAssertEqual(items["limit"], "10")
        XCTAssertEqual(items["fields"]?.contains("cover_i"), true)
    }

    func testAuthorAndSubjectSearchesUseTheirOwnParameters() async throws {
        let (service, client) = makeService(body: #"{"docs":[]}"#)

        _ = try await service.books(byAuthor: "J.R.R. Tolkien", offset: 0)
        _ = try await service.books(inSubject: "Fantasy", offset: 0)

        XCTAssertEqual(try queryItems(of: client.requests[0])["author"], "J.R.R. Tolkien")
        XCTAssertEqual(try queryItems(of: client.requests[1])["subject"], "Fantasy")
    }

    func testPlusAndSpaceAreEscaped() async throws {
        let (service, client) = makeService(body: #"{"docs":[]}"#)

        _ = try await service.books(byAuthor: "C++ Primer", offset: 0)

        let absolute = try XCTUnwrap(client.requests.first?.url?.absoluteString)
        XCTAssertTrue(absolute.contains("author=C%2B%2B%20Primer"), absolute)
    }

    func testAmpersandAndEqualsStayInsideTheValue() async throws {
        let (service, client) = makeService(body: #"{"docs":[]}"#)

        _ = try await service.books(matchingTitle: "Pride & Prejudice = Love")

        let items = try queryItems(of: client.requests.first)
        XCTAssertEqual(items["title"], "Pride & Prejudice = Love")
        XCTAssertEqual(items.count, 4)
    }

    func testDecodesAndMapsDocs() async throws {
        let body = #"""
        {
          "numFound": 4,
          "docs": [
            {
              "key": "/works/OL27448W",
              "title": "The Lord of the Rings",
              "author_name": ["J.R.R. Tolkien"],
              "first_publish_year": 1954,
              "isbn": ["0618640150", "9780618640157"],
              "cover_i": 8474036,
              "subject": ["Fantasy", "Middle Earth"]
            },
            { "key": "OL2W", "title": "Sparse Record" },
            { "key": "OL3W" },
            { "title": "Missing key" }
          ]
        }
        """#
        let (service, _) = makeService(body: body)

        let books = try await service.books(matchingTitle: "rings")

        XCTAssertEqual(books.count, 2, "Records without a key or title are dropped")

        let first = books[0]
        XCTAssertEqual(first.id, "OL27448W")
        XCTAssertEqual(first.title, "The Lord of the Rings")
        XCTAssertEqual(first.authors, ["J.R.R. Tolkien"])
        XCTAssertEqual(first.firstPublishYear, 1954)
        XCTAssertEqual(first.isbn, "9780618640157", "Prefers ISBN-13")
        XCTAssertEqual(first.coverID, 8474036)
        XCTAssertEqual(first.subjects, ["Fantasy", "Middle Earth"])

        let sparse = books[1]
        XCTAssertTrue(sparse.authors.isEmpty)
        XCTAssertNil(sparse.isbn)
        XCTAssertNil(sparse.coverID)
        XCTAssertNil(sparse.firstPublishYear)
    }

    func testEmptyDocsReturnsEmptyArray() async throws {
        let (service, _) = makeService(body: #"{"docs":[]}"#)
        let books = try await service.books(matchingTitle: "nothing")
        XCTAssertTrue(books.isEmpty)
    }

    func testNonSuccessStatusThrows() async {
        let (service, _) = makeService(status: 503, body: "")
        do {
            _ = try await service.books(matchingTitle: "x")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? BookServiceError, .badStatus(503))
        }
    }

    func testMalformedJSONThrowsDecodingFailed() async {
        let (service, _) = makeService(body: "not json")
        do {
            _ = try await service.books(matchingTitle: "x")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? BookServiceError, .decodingFailed)
        }
    }

    func testBlankQueryIsRejectedWithoutHittingTheNetwork() async {
        let (service, client) = makeService(body: #"{"docs":[]}"#)
        do {
            _ = try await service.books(matchingTitle: "   ")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? BookServiceError, .invalidRequest)
        }
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testTitleSearchCollapsesDuplicateListings() async throws {
        let body = #"""
        { "docs": [
          { "key": "OL1W", "title": "Dune", "author_name": ["Frank Herbert"] },
          { "key": "OL2W", "title": "DUNE", "author_name": ["Frank Herbert"] },
          { "key": "OL3W", "title": "Dune Messiah", "author_name": ["Frank Herbert"] }
        ] }
        """#
        let (service, _) = makeService(body: body)

        let books = try await service.books(matchingTitle: "dune")

        XCTAssertEqual(books.map(\.id), ["OL1W", "OL3W"])
    }

    // MARK: Paging

    private func docs(_ count: Int) -> String {
        (0..<count).map { #"{ "key": "OL\#($0)W", "title": "Book \#($0)" }"# }.joined(separator: ",")
    }

    private let limit = OpenLibraryService.recommendationLimit

    func testRequestCarriesOffsetAndLimit() async throws {
        let (service, client) = makeService(body: #"{"docs":[]}"#)

        _ = try await service.books(inSubject: "Fantasy", offset: 40)

        let items = try queryItems(of: client.requests.first)
        XCTAssertEqual(items["offset"], "40")
        XCTAssertEqual(items["limit"], String(limit))
    }

    func testFullPageBelowNumFoundHasMore() async throws {
        let (service, _) = makeService(body: #"{"numFound": \#(limit * 3), "docs": [\#(docs(limit))]}"#)

        let page = try await service.books(byAuthor: "x", offset: 0)

        XCTAssertEqual(page.books.count, limit)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextOffset, limit)
    }

    func testPageReachingNumFoundHasNoMore() async throws {
        let (service, _) = makeService(body: #"{"numFound": \#(limit * 2), "docs": [\#(docs(limit))]}"#)

        let page = try await service.books(byAuthor: "x", offset: limit)

        XCTAssertFalse(page.hasMore)
    }

    func testShortPageHasNoMoreEvenIfNumFoundIsLarger() async throws {
        let (service, _) = makeService(body: #"{"numFound": 500, "docs": [\#(docs(limit - 1))]}"#)

        let page = try await service.books(byAuthor: "x", offset: 0)

        XCTAssertFalse(page.hasMore)
    }

    func testMissingNumFoundFallsBackToPageLength() async throws {
        let (full, _) = makeService(body: #"{"docs": [\#(docs(limit))]}"#)
        let (short, _) = makeService(body: #"{"docs": [\#(docs(1))]}"#)

        let fullPage = try await full.books(byAuthor: "x", offset: 0)
        let shortPage = try await short.books(byAuthor: "x", offset: 0)

        XCTAssertTrue(fullPage.hasMore)
        XCTAssertFalse(shortPage.hasMore)
    }

    func testUnusableRecordsStillCountTowardsAFullPageAndTheNextOffset() async throws {
        let unusable = #"{ "key": "OLXW" }"#
        let body = #"{"numFound": 100, "docs": [\#(docs(limit - 1)), \#(unusable)]}"#
        let (service, _) = makeService(body: body)

        let page = try await service.books(byAuthor: "x", offset: limit)

        XCTAssertEqual(page.books.count, limit - 1)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextOffset, limit * 2)
    }
}
