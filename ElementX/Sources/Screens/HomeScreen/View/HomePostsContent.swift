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

struct HomePostsContent: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @ObservedObject var context: HomeScreenViewModel.Context
    let scrollViewAdapter: ScrollViewAdapter
    
    let shouldAttachScrollAdapter: Bool
    let selectedFeedTab: HomePostsTab
    
    var body: some View {
        postList
            .task {
                context.send(viewAction: .loadMoreAllPosts(followingPostsOnly: selectedFeedTab == .following))
            }
    }
    
    private var postList: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
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
                                            context.send(viewAction: .loadMoreAllPosts(followingPostsOnly: selectedFeedTab == .following))
                                        }
                                    }
                            }
                            /// Bottom space to keep content above `HomeScreenBottomBar`
                            HomeTabBottomSpace()
                        }
                    }
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                if shouldAttachScrollAdapter {
                    guard scrollView != scrollViewAdapter.scrollView else { return }
                    scrollViewAdapter.scrollView = scrollView
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.postListMode == .skeletons)
            .scrollBounceBehavior(context.viewState.postListMode == .empty ? .basedOnSize : .automatic)
            .animation(.elementDefault, value: context.viewState.postListMode)
            .animation(.none, value: context.viewState.visiblePosts)
            .refreshable {
                context.send(viewAction: .forceRefreshAllPosts(followingPostsOnly: selectedFeedTab == .following))
            }
        }
    }
}
