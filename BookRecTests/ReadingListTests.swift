import XCTest
@testable import BookRec

@MainActor
final class ReadingListModelTests: XCTestCase {
    func testLoadLoadsStoredBooks() async {
        let store = InMemoryReadingListStore(books: [.fixture(id: "A")])
        let sut = ReadingList(store: store)

        await sut.load()

        XCTAssertEqual(sut.books.map(\.id), ["A"])
    }

    func testAddingABookPersistsIt() async throws {
        let store = InMemoryReadingListStore()
        let sut = ReadingList(store: store)
        let book = Book.fixture(id: "A")

        await sut.add(book)

        XCTAssertEqual(sut.books, [book])
        let loaded = try await store.load()
        XCTAssertEqual(loaded, [book])
    }

    func testAddingTheSameBookTwiceKeepsOneEntry() async {
        let sut = ReadingList(store: InMemoryReadingListStore())
        let book = Book.fixture(id: "A")

        await sut.add(book)
        await sut.add(book)

        XCTAssertEqual(sut.books.count, 1)
        XCTAssertTrue(sut.contains(book))
    }

    func testRemovingABookDeletesItFromStore() async throws {
        let store = InMemoryReadingListStore(books: [.fixture(id: "A"), .fixture(id: "B"), .fixture(id: "C")])
        let sut = ReadingList(store: store)
        await sut.load()

        await sut.remove(at: IndexSet([0, 2]))

        XCTAssertEqual(sut.books.map(\.id), ["B"])
        let loaded = try await store.load()
        XCTAssertEqual(loaded.map(\.id), ["B"])
    }

    func testFailedSaveDoesNotChangeListAndReportsError() async {
        let sut = ReadingList(store: FailingStore())

        await sut.add(.fixture(id: "A"))

        XCTAssertTrue(sut.books.isEmpty)
        XCTAssertNotNil(sut.errorMessage)

        sut.showsError = false
        XCTAssertNil(sut.errorMessage)
    }
}

@MainActor
final class ReadingListViewModelTests: XCTestCase {
    func testBooksReflectLoadedReadingList() async {
        let readingList = ReadingList(store: InMemoryReadingListStore(books: [.fixture(id: "A")]))
        let sut = ReadingListViewModel(readingList: readingList)
        XCTAssertTrue(sut.books.isEmpty)

        await readingList.load()

        XCTAssertEqual(sut.books.map(\.id), ["A"])
        XCTAssertFalse(sut.books.isEmpty)
    }

    func testBooksReflectBooksAddedToReadingList() async {
        let readingList = ReadingList(store: InMemoryReadingListStore())
        let sut = ReadingListViewModel(readingList: readingList)

        await readingList.add(.fixture(id: "A"))

        XCTAssertEqual(sut.books.map(\.id), ["A"])
    }
}
