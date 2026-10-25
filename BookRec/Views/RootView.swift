//
//  RootView.swift
//  BookRec
//
//  Created by Sean Greevers on 10/20/26.
//

import SwiftUI

struct RootView: View {
    @State private var readingList: ReadingList = ReadingList.shared
    
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
            
            ReadingListView()
                .tabItem {
                    Label("Reading List", systemImage: "books.vertical")
                }
        }
        .task {
            await readingList.load()
        }
        .alert("Something went wrong",
               isPresented: $readingList.showsError,
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(readingList.errorMessage ?? "") }
        )
    }
}

#Preview {
    RootView()
}
