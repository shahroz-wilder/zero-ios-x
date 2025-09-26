//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

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
    
    @State private var selectedTab: HomeChannelsTab = .all
    
    var body: some View {
        Group {
            if selectedTab == .gated {
                channelList
            } else {
                roomList
            }
        }
        .isSearching($context.isSearchFieldFocused)
        .searchable(text: $context.searchQuery)
        .compoundSearchField()
        .disableAutocorrection(true)
        .onAppear {
            context.filtersState.activateZeroFilter(.secondaryRooms)
        }
        .onDisappear {
            context.filtersState.clearFilters()
        }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .all:
                context.filtersState.activateZeroFilter(.secondaryRooms)
            case .gated:
                context.filtersState.activateZeroFilter(.channels)
            case .muted:
                context.filtersState.activateZeroFilter(.mutedRooms)
            }
        }
    }
    
    private var channelList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !context.isSearchFieldFocused {
                        topSection
                    }
                    switch context.viewState.channelsListMode {
                    case .skeletons:
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(context.viewState.visibleChannels) { channel in
                                HomeScreenChannelCell(channel: channel, onChannelSelected: { _ in }, mediaProvider: context.mediaProvider)
                                    .redacted(reason: .placeholder)
                                    .shimmer()
                            }
                        }
                        .disabled(true)
                    case .empty:
                        HomeContentEmptyView(message: "No channels")
                    case .channels:
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let channelsList = if context.isSearchFieldFocused {
                                context.viewState.visibleChannels.filter { $0.displayName.containsIgnoringCase(context.searchQuery) }
                            } else {
                                context.viewState.visibleChannels
                            }
                            ForEach(channelsList, id: \.id) { channel in
                                HomeScreenChannelCell(channel: channel, onChannelSelected: { channel in
                                    context.send(viewAction: .channelTapped(channel))
                                }, mediaProvider: context.mediaProvider)
                            }
                            
                            HomeTabBottomSpace()
                        }
                    }
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                guard scrollView != scrollViewAdapter.scrollView else { return }
                scrollViewAdapter.scrollView = scrollView
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.channelsListMode == .skeletons)
            .scrollBounceBehavior(context.viewState.channelsListMode == .empty ? .basedOnSize : .automatic)
            .animation(.elementDefault, value: context.viewState.channelsListMode)
            .animation(.none, value: context.viewState.visibleChannels)
//            .refreshable {
//                context.send(viewAction: .forceRefreshChannels)
//            }
        }
    }
    
    private var roomList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !context.isSearchFieldFocused {
                        topSection
                    }
                    switch context.viewState.roomListMode {
                    case .skeletons:
                        LazyVStack(spacing: 0) {
                            ForEach(context.viewState.visibleRooms) { room in
                                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                                    .redacted(reason: .placeholder)
                                    .shimmer() // Putting this directly on the LazyVStack creates an accordion animation on iOS 16.
                            }
                        }
                        .disabled(true)
                        .accessibilityRepresentation {
                            Text(L10n.commonLoading)
                        }
                    case .empty:
                        HomeScreenEmptyStateLayout(minHeight: geometry.size.height) {
                            HomeScreenEmptyStateView(context: context)
                                .layoutPriority(1)
                        }
                    case .rooms:
                        LazyVStack(spacing: 0) {
                            HomeScreenRoomList(context: context, fromChannelsTabs: true, channelMutedCategory: selectedTab == .muted)
                            
                            HomeTabBottomSpace()
                        }
                    }
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                guard scrollView != scrollViewAdapter.scrollView else { return }
                scrollViewAdapter.scrollView = scrollView
            }
            .onReceive(scrollViewAdapter.didScroll) { _ in
                updateVisibleRange()
            }
            .onReceive(scrollViewAdapter.isScrolling) { _ in
                updateVisibleRange()
            }
            .onChange(of: context.searchQuery) {
                updateVisibleRange()
            }
            .onChange(of: context.viewState.visibleRooms) {
                updateVisibleRange()
                
                // We have been seeing a lot of issues around the room list not updating properly after
                // rooms shifting around:
                // * Tapping on the room list doesn't always take you to the right room  - https://github.com/element-hq/element-x-ios/issues/2386
                // * Big blank gaps in the room list - https://github.com/element-hq/element-x-ios/issues/3026
                //
                // We initially thought it's caused by the filters header or the geometry reader but
                // the problem is still reproducible without those.
                //
                // As a last attempt we will manually force it to update by shifting the
                // inner scroll view by a point every time the room list is updated
                DispatchQueue.main.async {
                    guard !scrollViewAdapter.isScrolling.value, let scrollView = scrollViewAdapter.scrollView else {
                        return
                    }
                    
                    let oldOffset = scrollView.contentOffset
                    var newOffset = scrollView.contentOffset
                    newOffset.y += 1
                    
                    scrollView.setContentOffset(newOffset, animated: false)
                    scrollView.setContentOffset(oldOffset, animated: false)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.roomListMode == .skeletons)
            .scrollBounceBehavior(context.viewState.roomListMode == .empty ? .basedOnSize : .automatic)
            .animation(.elementDefault, value: context.viewState.roomListMode)
            .animation(.none, value: context.viewState.visibleRooms)
        }
    }
    
    @ViewBuilder
    private var topSection: some View {
        SimpleTabButtonsView(tabs: HomeChannelsTab.allCases,
                             selectedTab: selectedTab,
                             tabTitle: { tab in
            switch tab {
            case .all: return "Channels"
            case .gated: return "Gated"
            case .muted: return "Muted"
            }
        },
                             onTabSelected: { tab in
            selectedTab = tab
        })
    }
    
    /// FOR ROOMS LIST
    /// Often times the scroll view's content size isn't correct yet when this method is called e.g. when cancelling a search
    /// Dispatch it with a delay to allow the UI to update and the computations to be correct
    /// Once we move to iOS 17 we should remove all of this and use scroll anchors instead
    private func updateVisibleRange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { delayedUpdateVisibleRange() }
    }
    
    private func delayedUpdateVisibleRange() {
        guard let scrollView = scrollViewAdapter.scrollView,
              scrollViewAdapter.isScrolling.value == false, // Ignore while scrolling
              context.searchQuery.isEmpty == true, // Ignore while filtering
              context.viewState.visibleRooms.count > 0 else {
            return
        }
        
        guard scrollView.contentSize.height > scrollView.bounds.height else {
            return
        }
        
        let adjustedContentSize = max(scrollView.contentSize.height - scrollView.contentInset.top - scrollView.contentInset.bottom, scrollView.bounds.height)
        let cellHeight = adjustedContentSize / Double(context.viewState.visibleRooms.count)
        
        let firstIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.contentInset.top) / cellHeight)
        let lastIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.bounds.height) / cellHeight)
        
        // This will be deduped and throttled on the view model layer
        context.send(viewAction: .updateVisibleItemRange(firstIndex..<lastIndex))
    }
}
