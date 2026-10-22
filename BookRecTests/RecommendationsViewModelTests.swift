import XCTest
@testable import BookRec

final class RecommendationsViewModelTests: XCTestCase {
    private var searcher: StubSearcher!
    private let book = Book.fixture(id: "SEED", authors: ["Seed Author"], subjects: ["Fantasy"])
    private var sut: RecommendationsViewModel!

    override func setUp() {
        super.setUp()
        searcher = StubSearcher()
        sut = RecommendationsViewModel(book: book, searchService: searcher)
    }

    private func books(_ ids: String...) -> [Book] {
        ids.map { Book.fixture(id: $0, title: "Title \($0)", authors: ["Other Author"]) }
    }

    func testStartsLoading() {
        XCTAssertEqual(sut.state, .loading)
    }

    func testLoadShowsRecommendationsForTheBook() async {
        let recs = books("REC")
        searcher.authorResult = .success(recs)

        await sut.load()

        XCTAssertEqual(sut.state, .loaded(recs))
        XCTAssertEqual(searcher.authorQueries, ["Seed Author"])
        XCTAssertEqual(searcher.subjectQueries, ["Fantasy"])
    }

    func testNoSimilarBooksLoadsAnEmptyList() async {
        await sut.load()

        XCTAssertEqual(sut.state, .loaded([]))
    }

    func testFirstPageFailsWhenEitherSourceFails() async {
        searcher.authorResult = .success(books("A1"))
        searcher.subjectResult = .failure(StubError())

        await sut.load()

        XCTAssertEqual(sut.state, .failed)
    }

    func testFailureThenRetryLoadsRecommendations() async {
        let recs = books("REC")
        searcher.authorResult = .failure(StubError())
        searcher.subjectResult = .failure(StubError())
        await sut.load()
        XCTAssertEqual(sut.state, .failed)

        searcher.authorResult = .success(recs)
        searcher.subjectResult = .success([])
        await sut.load()

        XCTAssertEqual(sut.state, .loaded(recs))
    }

    func testLoadingAgainAfterSuccessDoesNotRefetch() async {
        await sut.load()

        await sut.load()

        XCTAssertEqual(searcher.authorQueries.count, 1)
    }

    func testTheMatchedBookIsFilteredOut() async {
        searcher.authorResult = .success([book] + books("A1"))

        await sut.load()

        XCTAssertEqual(sut.state, .loaded(books("A1")))
    }

    func testSkipsNoisySubjectsWhenChoosingSubject() async {
        let noisy = Book.fixture(
            id: "N", title: "Noisy", authors: ["Author"],
            subjects: ["Accessible book", "nyt:hardcover-fiction=2012-01-01", "Fiction", "Science fiction"]
        )
        sut = RecommendationsViewModel(book: noisy, searchService: searcher)

        await sut.load()

        XCTAssertEqual(searcher.subjectQueries, ["Science fiction"])
    }

    func testSeedWithoutAuthorOrSubjectLoadsNothingWithoutQuerying() async {
        let bare = Book.fixture(id: "BARE", authors: [], subjects: [])
        sut = RecommendationsViewModel(book: bare, searchService: searcher)

        await sut.load()

        XCTAssertEqual(sut.state, .loaded([]))
        XCTAssertTrue(searcher.authorQueries.isEmpty)
        XCTAssertTrue(searcher.subjectQueries.isEmpty)
    }

    // MARK: Paging

    private var loaded: [Book] {
        if case .loaded(let books) = sut.state { books } else { [] }
    }

    func testBothSourcesPageTogetherAndAFinishedSourceIsSkipped() async {
        searcher.authorResult = .success(books("A1", "A2"))
        searcher.subjectResult = .success(books("S1", "S2", "S3", "S4"))
        await sut.load()
        XCTAssertEqual(loaded, books("A1", "A2", "S1", "S2"))

        sut.loadMoreIfNeeded(for: loaded[3])
        await waitUntil { self.loaded.count == 6 }

        XCTAssertEqual(loaded, books("A1", "A2", "S1", "S2", "S3", "S4"))
        XCTAssertEqual(searcher.authorOffsets, [0], "Author ran out on the first page")
        XCTAssertEqual(searcher.subjectOffsets, [0, 2])
    }

    func testEachSourceAdvancesByItsOwnPageAfterTheOtherRunsOut() async {
        searcher.authorResult = .success(books("A1", "A2", "A3"))
        searcher.subjectResult = .success(books("S1", "S2", "S3", "S4", "S5", "S6"))
        await sut.load()

        await sut.loadNextPage()
        await sut.loadNextPage()

        XCTAssertEqual(loaded, books("A1", "A2", "S1", "S2", "A3", "S3", "S4", "S5", "S6"))
        XCTAssertEqual(searcher.authorOffsets, [0, 2], "Author's short second page ends it")
        XCTAssertEqual(searcher.subjectOffsets, [0, 2, 4])
    }

    func testRowFarFromTheEndDoesNotLoad() async {
        searcher.authorResult = .success((1...20).map { Book.fixture(id: "A\($0)", title: "Title \($0)") })
        searcher.pageSize = 10
        await sut.load()

        sut.loadMoreIfNeeded(for: loaded[4])

        XCTAssertEqual(searcher.authorOffsets, [0])
    }

    func testFailedPageKeepsBooksAndTheNextScrollRequestsBothSourcesAgain() async {
        searcher.authorResult = .success(books("A1", "A2", "A3"))
        searcher.subjectResult = .success(books("S1", "S2", "S3"))
        await sut.load()

        searcher.subjectResult = .failure(StubError())
        await sut.loadNextPage()
        XCTAssertEqual(sut.state, .loaded(books("A1", "A2", "S1", "S2")))

        searcher.subjectResult = .success(books("S1", "S2", "S3"))
        sut.loadMoreIfNeeded(for: loaded[3])
        await waitUntil { self.loaded.count == 6 }

        XCTAssertEqual(loaded, books("A1", "A2", "S1", "S2", "A3", "S3"))
        XCTAssertEqual(searcher.authorOffsets, [0, 2, 2])
        XCTAssertEqual(searcher.subjectOffsets, [0, 2, 2])
    }

    /// Lets the task started by an intent (e.g. `loadMoreIfNeeded(for:)`) run, up to a short timeout.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
