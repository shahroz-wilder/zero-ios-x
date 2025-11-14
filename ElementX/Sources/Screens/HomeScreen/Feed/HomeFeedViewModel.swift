//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
import AnalyticsEvents
import Combine
import MatrixRustSDK
import SwiftUI
import Kingfisher

typealias HomeFeedViewModelType = StateStoreViewModel<HomeFeedViewState, HomeFeedViewAction>

class HomeFeedViewModel: HomeFeedViewModelType, HomeFeedViewModelProtocol, FeedProtocol {
    
    private let userSession: UserSessionProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let mediaProvider: MediaProviderProtocol
    
    private var actionsSubject: PassthroughSubject<HomeFeedViewModelAction, Never> = .init()
    var actions: AnyPublisher<HomeFeedViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private let HOME_SCREEN_POST_PAGE_COUNT = 10
    private var isFetchPostsInProgress = false
    
    private var feedMediaPreFetchService: FeedMediaPreFetchService? = nil
    
    init(userSession: UserSessionProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.userSession = userSession
        self.userIndicatorController = userIndicatorController
        self.mediaProvider = userSession.mediaProvider
        
        super.init(initialViewState: .init(userID: userSession.clientProxy.userID,
                                           bindings: .init()),
                   mediaProvider: userSession.mediaProvider)
        
        self.feedMediaPreFetchService = FeedMediaPreFetchService(mediaProtocol: .init(onMediaLoaded: { map in
            self.state.postMediaInfoMap = map
        }),
                                                                 clientProxy: userSession.clientProxy,
                                                                 loadInitialPosts: true)
        
        userSession.clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userAvatarURL, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userDisplayName, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.state.currentUserZeroProfile = currentUser
            }
            .store(in: &cancellables)
        
        userSession.clientProxy.userRewardsPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userRewards, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public
    
    override func process(viewAction: HomeFeedViewAction) {
        switch viewAction {
        case .onHomeTabChanged:
            onHomeTabChanged()
        case .newFeed:
            actionsSubject.send(.presentCreateFeedScreen(feedProtocol: self))
        case .loadMoreAllPosts(let following):
            Task {
                await fetchPosts(followingOnly: following)
            }
        case .forceRefreshAllPosts(let followingOnly):
            Task {
                await fetchPosts(isForceRefresh: true, followingOnly: followingOnly)
            }
        case .postTapped(let post):
            let mediaUrl = state.postMediaInfoMap[post.id]?.url
            let urlLinkPreview = state.postLinkPreviewsMap[post.id]
            actionsSubject.send(.postTapped(post.withUpdatedData(url: mediaUrl, urlLinkPreview: urlLinkPreview), feedProtocol: self))
        case .openArweaveLink(let post):
            openArweaveLink(post)
        case .addMeowToPost(let postId, let amount):
            addMeowToPost(postId, amount)
        case .openYoutubeLink(let url):
            openYoutubeLink(url)
        case .openUserProfile:
            let profile = ZPostUserProfile(userId: state.userID.matrixIdToCleanHex(),
                                           firstName: state.userDisplayName ?? "",
                                           profileImage: state.userAvatarURL?.absoluteString,
                                           primaryZid: state.currentUserZeroProfile?.primaryZID,
                                           publicAddress: state.currentUserZeroProfile?.publicWalletAddress,
                                           followersCount: state.currentUserZeroProfile?.followersCount,
                                           followingCount: state.currentUserZeroProfile?.followingCount,
                                           isZeroProSubscriber: state.currentUserZeroProfile?.subscriptions.zeroPro ?? false)
            actionsSubject.send(.openPostUserProfile(profile, feedProtocol: self))
        case .openPostUserProfile(let profile):
            actionsSubject.send(.openPostUserProfile(profile, feedProtocol: self))
        case .openMediaPreview(let mediaId, let key):
            displayFullScreenMedia(mediaId, key: key)
        case .reloadFeedMedia(let post):
            reloadFeedMedia(post)
        case .searchUser:
            actionsSubject.send(.searchUser)
        }
    }
    
    private func onHomeTabChanged() {
        Task.detached {
            await self.fetchPosts(isForceRefresh: true)
        }
    }
    
    private func displayError(title: String? = nil, message: String? = nil) {
        state.bindings.alertInfo = .init(id: UUID(),
                                         title: title ?? L10n.commonError,
                                         message: message ?? L10n.errorUnknown)
    }
    
    private func fetchPosts(isForceRefresh: Bool = false, followingOnly: Bool = true) async {
        guard !isFetchPostsInProgress else { return }
        isFetchPostsInProgress = true
        
        //        defer { isFetchPostsInProgress = false } // Ensure flag is reset when the task completes
        
        if isForceRefresh {
            state.canLoadMorePosts = true
        }
        
        state.postListMode = state.posts.isEmpty ? .skeletons : .posts
        let skipItems = isForceRefresh ? 0 : state.posts.count
        let postsResult = await userSession.clientProxy.fetchZeroFeeds(channelZId: nil,
                                                                       following: followingOnly,
                                                                       limit: HOME_SCREEN_POST_PAGE_COUNT,
                                                                       skip: skipItems)
        switch postsResult {
        case .success(let posts):
            let hasNoPosts = posts.isEmpty
            if hasNoPosts {
                state.postListMode = isForceRefresh ? .empty : state.posts.isEmpty ? .empty : .posts
                state.canLoadMorePosts = false
                isFetchPostsInProgress = false
            } else {
                var homePosts: [HomeScreenPost] = isForceRefresh ? [] : state.posts
                for post in posts {
                    let homePost = HomeScreenPost(loggedInUserId: userSession.clientProxy.userID,
                                                  post: post,
                                                  rewardsDecimalPlaces: state.userRewards.decimals)
                    homePosts.append(homePost)
                }
                state.posts = homePosts.uniqued(on: \.id)
                state.postListMode = .posts
                isFetchPostsInProgress = false
                state.canLoadMorePosts = posts.count >= HOME_SCREEN_POST_PAGE_COUNT
                
                if isForceRefresh {
                    self.feedMediaPreFetchService?.forceRefreshHomeFeedMedia(following: followingOnly)
                }
                
                await loadPostContentConcurrently(for: state.posts, followingPosts: followingOnly)
            }
        case .failure(let error):
            MXLog.error("Failed to fetch zero posts: \(error)")
            state.postListMode = state.posts.isEmpty ? .empty : .posts
            isFetchPostsInProgress = false
        }
    }
    
    private func updatePostsVisibleRange(_ range: Range<Int>) {
        print("Update Posts Visible Range: Upper bound: \(range.upperBound), Lower bound: \(range.lowerBound)")
    }
    
    private func openArweaveLink(_ post: HomeScreenPost) {
        guard let arweaveUrl = post.getArweaveLink() else { return }
        UIApplication.shared.open(arweaveUrl)
    }
    
    private func openYoutubeLink(_ url: String) {
        guard let youtubeUrl = URL(string: url) else { return }
        UIApplication.shared.open(youtubeUrl)
    }
    
    private func addMeowToPost(_ postId: String, _ amount: Int) {
        //update post locally first
        guard let postIndex = state.posts.firstIndex(where: { $0.id == postId }) else { return }
        let originalPost = state.posts[postIndex]
        state.posts[postIndex] = originalPost.withUpdatedMeowCount(amount)
        
        Task(priority: .background) {
            let addMeowResult = await userSession.clientProxy.addMeowsToFeed(feedId: postId, amount: amount)
            switch addMeowResult {
            case .success(let post):
                let homePost = HomeScreenPost(loggedInUserId: userSession.clientProxy.userID,
                                              post: post,
                                              rewardsDecimalPlaces: state.userRewards.decimals)
                state.posts[postIndex] = homePost
            case .failure(let error):
                MXLog.error("Failed to add meow: \(error)")
                // revert to original post
                state.posts[postIndex] = originalPost.withDefaultMeowCount()
                switch error {
                case .insufficientMeowBalance:
                    displayError(message: "Insuffient Meow Balance")
                default:
                    displayError(message: "Failed to add meow to post. Please try again later.")
                }
            }
        }
    }
    
    private func loadPostContentConcurrently(for posts: [HomeScreenPost], followingPosts: Bool) async {
        async let nextPagePostsTask: () =  feedMediaPreFetchService?.loadHomePostsPage(following: followingPosts,
                                                                                       currentCount: posts.count) ?? ()
        async let linkPreviewTask: () = loadPostLinkPreviews(for: posts)
        _ = await (nextPagePostsTask, linkPreviewTask)
    }
    
    private func reloadFeedMedia(_ post: HomeScreenPost) {
        feedMediaPreFetchService?.reloadMedia(post) { mediaInfo in
            self.state.postMediaInfoMap[post.id] = mediaInfo
        }
    }
    
    private func loadPostLinkPreviews(for posts: [HomeScreenPost]) async {
        let postsToFetchLinkPreviews = posts.filter({
            LinkPreviewUtil.shared.firstAvailableYoutubeLink(from: $0.postText) != nil && state.postLinkPreviewsMap[$0.id] == nil
        })
        await withTaskGroup(of: (String, ZLinkPreview)?.self) { group in
            for post in postsToFetchLinkPreviews {
                guard let url = LinkPreviewUtil.shared.firstAvailableYoutubeLink(from: post.postText) else { continue }
                group.addTask {
                    if let previewResult = await withTimeout(seconds: 5, operation: {
                        await self.userSession.clientProxy.fetchYoutubeLinkMetaData(youtubrUrl: url)
                    }), case let .success(preview) = previewResult {
                        return (post.id, preview)
                    }
                    return nil
                }
            }
            for await item in group {
                guard let (postId, preview) = item else { continue }
                state.postLinkPreviewsMap[postId] = preview
            }
        }
    }
    
    private func displayFullScreenMedia(_ mediaId: String, key: String) {
        let loadingIndicatorIdentifier = "roomAvatarLoadingIndicator"
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorIdentifier, type: .modal, title: L10n.commonLoading, persistent: true))
        
        Task {
            defer {
                userIndicatorController.retractIndicatorWithId(loadingIndicatorIdentifier)
            }
            
            do {
                if case let .success(localUrl) = try await userSession.clientProxy.loadFileFromMediaId(mediaId, key: key) {
                    state.bindings.mediaPreviewItem = localUrl
                }
            } catch {
                MXLog.error("Failed to preview feed media: \(error)")
            }
        }
    }
    
    // MARK: Zero Protcol Functions
    
    func onFeedUpdated(_ feed: HomeScreenPost) {
        //        Task {
        //            let feedDetailsResult = await userSession.clientProxy.fetchFeedDetails(feedId: feedId)
        //            switch feedDetailsResult {
        //            case .success(let post):
        //                let homePost = HomeScreenPost(loggedInUserId: userSession.clientProxy.userID,
        //                                              post: post,
        //                                              rewardsDecimalPlaces: state.userRewards.decimals)
        //                if let index = state.posts.firstIndex(where: { $0.id == homePost.id }) {
        //                    state.posts[index] = homePost
        //                }
        //            case .failure(let error):
        //                MXLog.error("Failed to fetch updated feed details: \(error)")
        //            }
        //        }
        if let index = state.posts.firstIndex(where: { $0.id == feed.id }) {
            state.posts[index] = feed
        }
    }
    
    func onNewFeedPosted() {
        Task {
            await (fetchPosts(isForceRefresh: true))
        }
    }
}
