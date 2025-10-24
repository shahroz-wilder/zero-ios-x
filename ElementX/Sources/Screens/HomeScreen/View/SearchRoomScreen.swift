//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SentrySwiftUI
import SwiftUI

struct SearchRoomScreen: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    
    var body: some View {
        NavigationStack {
            HomeChatContent(context: context,
                            scrollViewAdapter: scrollViewAdapter,
                            shouldAttachScrollAdapter: true,
                            isSearchableContent: true)
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
        }
        .task {
            context.isSearchFieldPresented = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                context.isSearchFieldFocused = true
            })
        }
    }
}
