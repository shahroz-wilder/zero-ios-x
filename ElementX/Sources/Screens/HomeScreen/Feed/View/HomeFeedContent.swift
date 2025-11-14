//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum HomePostsTab: CaseIterable {
    case following
    case all
}

struct HomeFeedContent: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @ObservedObject var context: HomeFeedViewModel.Context
    let scrollViewAdapter: ScrollViewAdapter
    
    @State private var selectedTab: HomePostsTab = .following
    
    var body: some View {
        postList
            .task {
                context.send(viewAction: .loadMoreAllPosts(followingPostsOnly: selectedTab == .following))
            }
    }
    
    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Section {
                    switch context.viewState.postListMode {
                    case .skeletons:
                        LazyVStack(spacing: 0) {
                            ForEach(context.viewState.visiblePosts) { post in
                                VStack {
                                    HomeScreenPostCell(post: post)
                                    .padding(.all, 16)
                                    Divider()
                                }
                                .redacted(reason: .placeholder)
                                .shimmer()
                            }
                        }
                        .disabled(true)
                    case .empty:
                        HomeContentEmptyView(message: "No posts")
                    case .posts:
                        LazyVStack(spacing: 0) {
                            HomeScreenPostList(context: context)
                            
                            if context.viewState.canLoadMorePosts {
                                ProgressView()
                                    .padding()
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            context.send(viewAction: .loadMoreAllPosts(followingPostsOnly: selectedTab == .following))
                                        }
                                    }
                            }
                            /// Bottom space to keep content above `HomeScreenBottomBar`
                            HomeTabBottomSpace()
                        }
                    }
                } header: {
                    topSection
                }
            }
        }
        .introspect(.scrollView, on: .supportedVersions) { scrollView in
            guard scrollView != scrollViewAdapter.scrollView else { return }
            scrollViewAdapter.scrollView = scrollView
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollDisabled(context.viewState.postListMode == .skeletons)
        .scrollBounceBehavior(context.viewState.postListMode == .empty ? .basedOnSize : .automatic)
        .animation(.elementDefault, value: context.viewState.postListMode)
        .animation(.none, value: context.viewState.visiblePosts)
        .refreshable {
            context.send(viewAction: .forceRefreshAllPosts(followingPostsOnly: selectedTab == .following))
        }
    }
    
    @ViewBuilder
    private var topSection: some View {
        SimpleTabButtonsView(tabs: HomePostsTab.allCases,
                             selectedTab: selectedTab,
                             tabTitle: { tab in
            switch tab {
            case .following: return "Following"
            case .all: return "Everything"
            }
        },
                             onTabSelected: { tab in
            selectedTab = tab
            context.send(viewAction: .forceRefreshAllPosts(followingPostsOnly: tab == .following))
        })
    }
}
