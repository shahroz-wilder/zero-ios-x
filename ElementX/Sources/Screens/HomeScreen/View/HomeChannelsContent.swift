//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

enum HomeChannelsTab: CaseIterable {
    case all
    case gated
    case muted
}

struct HomeChannelsContent: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @ObservedObject var context: HomeScreenViewModel.Context
    let scrollViewAdapter: ScrollViewAdapter
    
    let shouldAttachScrollAdapter: Bool
    
    var body: some View {
        ZStack {
            channelList
                .id("channels")
        }
    }
    
    private var channelList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    switch context.viewState.channelsListMode {
                    case .skeletons:
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(
                                context.viewState.visibleChannels
                            ) { channel in
                                HomeScreenChannelCell(
                                    channel: channel,
                                    onChannelSelected: { _ in
                                    },
                                    mediaProvider: context.mediaProvider)
                                .redacted(reason: .placeholder)
                                .shimmer()
                            }
                        }
                        .disabled(true)
                    case .empty:
                        HomeContentEmptyView(message: "No channels")
                    case .channels:
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(
                                context.viewState.visibleChannels,
                                id: \.id
                            ) { channel in
                                HomeScreenChannelCell(
                                    channel: channel,
                                    onChannelSelected: { channel in
                                        context
                                            .send(
                                                viewAction: .channelTapped(channel)
                                            )
                                    },
                                    mediaProvider: context.mediaProvider)
                            }
                            
                            /// Bottom space to keep content above `HomeScreenBottomBar`
                            HomeTabBottomSpace()
                        }
//                        .isSearching($context.isSearchFieldFocused)
//                        .searchable(text: $context.searchQuery)
//                        .compoundSearchField()
//                        .disableAutocorrection(true)
                    }
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                if shouldAttachScrollAdapter {
                    guard scrollView != scrollViewAdapter.scrollView else {
                        return
                    }
                    scrollViewAdapter.scrollView = scrollView
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.channelsListMode == .skeletons)
            .scrollBounceBehavior(
                context.viewState.channelsListMode == .empty ? .basedOnSize : .automatic
            )
            .animation(
                .elementDefault,
                value: context.viewState.channelsListMode
            )
            .animation(.none, value: context.viewState.visibleChannels)
        }
    }
}
