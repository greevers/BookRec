import XCTest
@testable import BookRec

final class BookTests: XCTestCase {
    func testCoverURLUsesCoverIDAndSize() {
        let book = Book.fixture(coverID: 8474036)

        XCTAssertEqual(
            book.coverURL()?.absoluteString,
            "https://covers.openlibrary.org/b/id/8474036-M.jpg?default=false"
        )
    }

    func testCoverURLIsNilWithoutCoverID() {
        XCTAssertNil(Book.fixture(coverID: nil).coverURL())
    }

    func testPresentationFallbacksForMissingData() {
        let book = Book.fixture(authors: [], year: nil, isbn: nil)

        XCTAssertEqual(book.authorLine, "Unknown author")
        XCTAssertEqual(book.yearText, "Year unknown")
        XCTAssertEqual(book.isbnText, "ISBN unavailable")
    }

    func testIdentityIgnoresCaseAccentsAndPunctuation() {
        let a = Book.fixture(id: "1", title: "Les Misérables!", authors: ["Victor Hugo"])
        let b = Book.fixture(id: "2", title: "les miserables", authors: ["victor hugo"])

        XCTAssertTrue(a.isSameWork(as: b))
    }

    func testPrimarySubjectFallsBackToFirstSubjectWhenAllAreNoisy() {
        let onlyNoise = Book.fixture(subjects: ["Fiction", "Accessible book"])
        XCTAssertEqual(onlyNoise.primarySubject, "Fiction")
    }

    func testRemovingDuplicatesKeepsFirstOccurrence() {
        let books = [
            Book.fixture(id: "1", title: "Dune"),
            Book.fixture(id: "1", title: "Dune (again)"),
            Book.fixture(id: "2", title: "dune"),
            Book.fixture(id: "3", title: "Emma", authors: ["Austen"])
        ]

        XCTAssertEqual(books.removingDuplicates().map(\.id), ["1", "3"])
    }
}
