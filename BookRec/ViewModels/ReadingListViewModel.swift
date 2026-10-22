//
//  ReadingListViewModel.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import Foundation

// Basically just a wrapper around ReadingList, but wanted to conform to MVVM principles
// Allows future extension of ReadingListView
@Observable
final class ReadingListViewModel {
    private let readingList: ReadingList
    
    init(readingList: ReadingList = ReadingList.shared) {
        self.readingList = readingList
    }
    
    var books: [Book] { readingList.books }
}
