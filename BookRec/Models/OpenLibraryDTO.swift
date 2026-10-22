//
//  OpenLibraryDTO.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

// Property names are the camelCase forms of the API's snake_case keys (decoded with `.convertFromSnakeCase`)
nonisolated struct SearchResponse: Decodable {
    let start: Int?
    let numFound: Int?
    let docs: [BookDTO]
}

nonisolated struct BookDTO: Decodable {
    let key: String?
    let title: String?
    let authorName: [String]?
    let firstPublishYear: Int?
    let isbn: [String]?
    let coverI: Int?
    let subject: [String]?
}

nonisolated extension Book {
    /// Maps a search doc to a `Book`. Needed because some records can't be
    /// displayed meaningfully (no key or no title). Return nil for those.
    init?(dto: BookDTO) {
        guard
            let rawKey = dto.key,
            let title = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty
        else {
            return nil
        }
        
        // The API returns keys like "/works/OL27448W"; keep just the identifier.
        let id = rawKey.replacingOccurrences(of: "/works/", with: "")
        let isbns = dto.isbn ?? []
        
        self.init(
            id: id,
            title: title,
            authors: dto.authorName ?? [],
            firstPublishYear: dto.firstPublishYear,
            // A work lists every edition's ISBN. Prefer an ISBN-13 when available.
            isbn: isbns.first(where: { $0.count == 13 }) ?? isbns.first,
            coverID: dto.coverI.flatMap { $0 > 0 ? $0 : nil },
            subjects: Array((dto.subject ?? []).prefix(25))
        )
    }
}
