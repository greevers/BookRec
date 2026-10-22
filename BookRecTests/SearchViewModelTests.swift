import XCTest
@testable import BookRec

final class SearchViewModelTests: XCTestCase {
    private var searcher: StubSearcher!
    private var sut: SearchViewModel!

    override func setUp() {
        super.setUp()
        searcher = StubSearcher()
        sut = SearchViewModel(searchService: searcher)
    }

    func testStartsIdle() {
        XCTAssertEqual(sut.state, .idle)
        XCTAssertNil(sut.selectedBook)
    }

    func testNoMatchesPromptsToTryAnotherTitle() async {
        searcher.titleResult = .success([])

        await sut.search(title: "zzzz")

        XCTAssertEqual(sut.state, .matches(query: "zzzz", candidates: []))
        XCTAssertNil(sut.selectedBook)
    }

    func testSingleMatchNavigatesStraightToItsRecommendations() async {
        let match = Book.fixture(id: "ONLY")
        searcher.titleResult = .success([match])

        await sut.search(title: "only")

        XCTAssertEqual(sut.state, .matches(query: "only", candidates: [match]))
        XCTAssertEqual(sut.selectedBook, match)
        XCTAssertTrue(searcher.authorQueries.isEmpty, "The pushed screen fetches recommendations, not the search screen")
    }

    func testMultipleMatchesPromptForDisambiguation() async {
        let first = Book.fixture(id: "ONE", title: "Dune")
        let second = Book.fixture(id: "TWO", title: "Dune Messiah")
        searcher.titleResult = .success([first, second])

        await sut.search(title: "dune")

        XCTAssertEqual(sut.state, .matches(query: "dune", candidates: [first, second]))
        XCTAssertNil(sut.selectedBook, "No navigation until the user chooses")
        XCTAssertTrue(searcher.authorQueries.isEmpty)
    }

    func testSelectingACandidateShowsItsRecommendations() async {
        let first = Book.fixture(id: "ONE")
        let second = Book.fixture(id: "TWO")
        searcher.titleResult = .success([first, second])
        await sut.search(title: "x")

        sut.select(second)

        XCTAssertEqual(sut.selectedBook, second)
    }

    func testSubmittingANewSearchPopsBackToTheRoot() async {
        sut.selectedBook = .fixture()
        sut.query = "dune"

        sut.submit()

        XCTAssertNil(sut.selectedBook)
    }

    func testSearchFailureShowsFailedState() async {
        searcher.titleResult = .failure(StubError())

        await sut.search(title: "x")

        XCTAssertEqual(sut.state, .failed)
    }

    func testCancelledSearchDoesNotShowFailure() async {
        searcher.titleResult = .failure(CancellationError())

        await sut.search(title: "x")

        XCTAssertEqual(sut.state, .loading, "The newer search that cancelled this one owns the state")
    }

    func testBlankQueryIsIgnored() {
        sut.query = "   "

        sut.submit()

        XCTAssertEqual(sut.state, .idle)
    }
}
