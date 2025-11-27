//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias FeedDetailsScreenViewModelType = StateStoreViewModel<FeedDetailsScreenViewState, FeedDetailsScreenViewAction>

class FeedDetailsScreenViewModel: FeedDetailsScreenViewModelType, FeedDetailsScreenViewModelProtocol,
                                  FeedProtocol, FeedMediaSelectedProtocol {
    
    private let clientProxy: ClientProxyProtocol
    private let mainFeedProtocol: FeedProtocol?
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let POST_REPLIES_PAGE_COUNT = 10
    private var isFetchRepliesInProgress = false
    
    private var currentUserWalletAddress: String? = nil
    private var defaultChannelZId: String? = nil
    
    private var feedMediaPreFetchService: FeedMediaPreFetchService? = nil
    
    private var actionsSubject: PassthroughSubject<FeedDetailsScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<FeedDetailsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         mainFeedProtocol: FeedProtocol?,
         userIndicatorController: UserIndicatorControllerProtocol,
         feedItem: HomeScreenPost) {
        self.clientProxy = userSession.clientProxy
        self.mainFeedProtocol = mainFeedProtocol
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init(userID: clientProxy.userID, bindings: .init(feed: feedItem)), mediaProvider: userSession.mediaProvider)
        
        self.feedMediaPreFetchService = FeedMediaPreFetchService(mediaProtocol: .init(onMediaLoaded: { map in
            self.state.postRepliesMediaInfoMap = map
        }),
                                                                 clientProxy: userSession.clientProxy)
        
        userSession.clientProxy.zeroClient.userRewardsPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userRewards, on: self)
            .store(in: &cancellables)
        
        clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userAvatarURL, on: self)
            .store(in: &cancellables)
        
        clientProxy.zeroClient.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.currentUserWalletAddress = currentUser.publicWalletAddress
                self?.defaultChannelZId = currentUser.primaryZID
            }
            .store(in: &cancellables)
        
        fetchFeed(feedItem.id)
        fetchFeedReplies(feedItem.id)
    }
    
    override func process(viewAction: FeedDetailsScreenViewAction) {
        switch viewAction {
        case .replyTapped(let reply):
            let mediaUrl = state.postRepliesMediaInfoMap[reply.id]?.url
            let urlLinkPreview = state.postRepliesLinkPreviewsMap[reply.id]
            actionsSubject.send(.replyTapped(reply.withUpdatedData(url: mediaUrl, urlLinkPreview: urlLinkPreview), replyProtocol: self))
        case .openArweaveLink(let post):
            openArweaveLink(post)
        case .openYoutubeLink(let url):
            openYoutubeLink(url)
        case .loadMoreRepliesIfNeeded:
            fetchFeedReplies(state.bindings.feed.id)
        case .forceRefreshFeed:
            forceRefreshFeed()
        case .meowTapped(let postId, let amount, let isPostAReply):
            addMeowToPost(postId, amount, isPostAReply: isPostAReply)
        case .postReply:
            postFeedReply()
        case .attachMedia:
            actionsSubject.send(.attachMedia(self))
        case .deleteMedia:
            state.bindings.feedMedia = nil
        case .openPostUserProfile(let profile):
            actionsSubject.send(.openPostUserProfile(profile))
        case .openMediaPreview(let mediaId):
            displayFullScreenMedia(mediaId)
        case .reloadFeedMedia(let post):
            reloadFeedMedia(post)
        }
    }
    
    private func fetchFeed(_ feedId: String) {
        Task {
            let feedResult = await clientProxy.zeroClient.fetchFeedDetails(feedId: feedId)
            switch feedResult {
            case .success(let feed):
                let homePost = HomeScreenPost.init(loggedInUserId: clientProxy.userID, post: feed)
                state.bindings.feed = homePost.withUpdatedData(mediaInfo: state.bindings.feed.mediaInfo,
                                                               urlLinkPreview: state.bindings.feed.urlLinkPreview)
                mainFeedProtocol?.onFeedUpdated(homePost)
            case .failure(let error):
                MXLog.error("Failed to fetch feed details: \(error)")
            }
        }
    }
    
    private func fetchFeedReplies(_ feedId: String, isForceRefresh: Bool = false) {
        guard !isFetchRepliesInProgress else { return }
        isFetchRepliesInProgress = true
        
        Task {
//            defer { isFetchRepliesInProgress = false } // Ensure flag is reset when the task completes
            
            state.repliesListMode = state.feedReplies.isEmpty ? .skeletons : .replies
            let skipItems = isForceRefresh ? 0 : state.feedReplies.count
            let repliesResult = await clientProxy.zeroClient.fetchFeedReplies(feedId: feedId, limit: POST_REPLIES_PAGE_COUNT,
                                                                   skip: skipItems)
            switch repliesResult {
            case .success(let replies):
                let hasNoReplies = replies.isEmpty
                if hasNoReplies {
                    state.repliesListMode = state.feedReplies.isEmpty ? .empty : .replies
                    state.canLoadMoreReplies = false
                    isFetchRepliesInProgress = false
                } else {
                    var feedReplies: [HomeScreenPost] = isForceRefresh ? [] : state.feedReplies
                    for reply in replies {
                        let feedReply = HomeScreenPost(loggedInUserId: clientProxy.userID,
                                                       post: reply,
                                                       rewardsDecimalPlaces: state.userRewards.decimals)
                        feedReplies.append(feedReply)
                    }
                    state.feedReplies = feedReplies.uniqued(on: \.id)
                    state.repliesListMode = .replies
                    isFetchRepliesInProgress = false
                    
                    await loadPostContentConcurrently(for: state.feedReplies, isForceRefresh: isForceRefresh)
                }
            case .failure(let error):
                MXLog.error("Failed to fetch zero post replies: \(error)")
                state.repliesListMode = state.feedReplies.isEmpty ? .empty : .replies
                isFetchRepliesInProgress = false
            }
        }
    }
    
    private func openArweaveLink(_ post: HomeScreenPost) {
        guard let arweaveUrl = post.getArweaveLink() else { return }
        UIApplication.shared.open(arweaveUrl)
    }
    
    private func openYoutubeLink(_ url: String) {
        guard let youtubeUrl = URL(string: url) else { return }
        UIApplication.shared.open(youtubeUrl)
    }
    
    private func forceRefreshFeed() {
        let feedId = state.bindings.feed.id
        fetchFeed(feedId)
        fetchFeedReplies(feedId, isForceRefresh: true)
    }
    
    private func addMeowToPost(_ postId: String, _ amount: Int, isPostAReply: Bool) {
        // update post locally first
        var originalPost: HomeScreenPost
        var updatedPost: HomeScreenPost
        if isPostAReply {
            guard let index = state.feedReplies.firstIndex(where: { $0.id == postId }) else { return }
            originalPost = state.feedReplies[index]
            updatedPost = originalPost.withUpdatedMeowCount(amount)
            state.feedReplies[index] = updatedPost
        } else {
            originalPost = state.bindings.feed
            updatedPost = originalPost.withUpdatedMeowCount(amount)
            state.bindings.feed = updatedPost
            mainFeedProtocol?.onFeedUpdated(updatedPost)
        }
        
        Task(priority: .background) {
            let result = await clientProxy.zeroClient.addMeowsToFeed(feedId: postId, amount: amount)
            switch result {
            case .success(let post):
                let homePost = HomeScreenPost(loggedInUserId: clientProxy.userID, post: post, rewardsDecimalPlaces: state.userRewards.decimals)
                if isPostAReply {
                    guard let index = state.feedReplies.firstIndex(where: { $0.id == postId }) else { return }
                    state.feedReplies[index] = homePost
                } else {
                    state.bindings.feed = homePost
                }
                mainFeedProtocol?.onFeedUpdated(homePost)
                
            case .failure(let error):
                MXLog.error("Failed to add meow: \(error)")
                if isPostAReply {
                    guard let index = state.feedReplies.firstIndex(where: { $0.id == postId }) else { return }
                    state.feedReplies[index] = originalPost.withDefaultMeowCount()
                } else {
                    state.bindings.feed = originalPost.withDefaultMeowCount()
                }
                switch error {
                case .insufficientMeowBalance:
                    displayError(message: "Insuffient Meow Balance")
                default:
                    displayError(message: "Failed to add meow to post. Please try again later.")
                }
            }
        }
    }
    
    private func displayError(title: String? = nil, message: String? = nil) {
        state.bindings.alertInfo = .init(id: UUID(),
                                         title: title ?? L10n.commonError,
                                         message: message ?? L10n.errorUnknown)
    }
    
    private func postFeedReply() {
        guard let userWalletAddress = currentUserWalletAddress else {
            return
        }
        
        Task {
            let userIndicatorID = UUID().uuidString
            defer {
                userIndicatorController.retractIndicatorWithId(userIndicatorID)
            }
            userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                                  type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                                  title: "Posting...",
                                                                  persistent: true))
            let postFeedResult = await clientProxy.zeroClient.postNewFeed(channelZId: defaultChannelZId,
                                                               walletAddress: userWalletAddress,
                                                               content: state.bindings.myPostReply,
                                                               replyToPost: state.bindings.feed.id,
                                                               mediaFile: state.bindings.feedMedia)
            switch postFeedResult {
            case .success(_):
                state.bindings.myPostReply = ""
                state.bindings.feedMedia = nil
                forceRefreshFeed()
            case .failure(_):
                state.bindings.alertInfo = .init(id: UUID(),
                                                 title: L10n.commonError,
                                                 message: "Failed to post reply. Please try again.")
            }
        }
    }
    
    private func loadPostContentConcurrently(for posts: [HomeScreenPost], isForceRefresh: Bool) async {
        async let nextPagePostsTask: () =  feedMediaPreFetchService?.loadFeedRepliesPage(postId: state.bindings.feed.id,
                                                                                         currentCount: posts.count,
                                                                                         isForceRefresh: isForceRefresh) ?? ()
        async let linkPreviewTask: () = loadPostLinkPreviews(for: posts)
        _ = await (nextPagePostsTask, linkPreviewTask)
    }
    
    private func reloadFeedMedia(_ post: HomeScreenPost) {
        feedMediaPreFetchService?.reloadMedia(post) { mediaInfo in
            self.state.postRepliesMediaInfoMap[post.id] = mediaInfo
        }
    }
    
    private func loadPostLinkPreviews(for posts: [HomeScreenPost]) async {
        let postsToFetchLinkPreviews = posts.filter({
            LinkPreviewUtil.shared.firstAvailableYoutubeLink(from: $0.postText) != nil && state.postRepliesLinkPreviewsMap[$0.id] == nil
        })
        await withTaskGroup(of: (String, ZLinkPreview)?.self) { group in
            for post in postsToFetchLinkPreviews {
                guard let url = LinkPreviewUtil.shared.firstAvailableYoutubeLink(from: post.postText) else { continue }
                group.addTask {
                    if let previewResult = await withTimeout(seconds: 5, operation: {
                        await self.clientProxy.zeroClient.fetchYoutubeLinkMetaData(youtubrUrl: url)
                    }), case let .success(preview) = previewResult {
                        return (post.id, preview)
                    }
                    return nil
                }
            }
            for await item in group {
                guard let (postId, preview) = item else { continue }
                state.postRepliesLinkPreviewsMap[postId] = preview
            }
        }
    }
    
    func onMediaSelected(media: URL) {
        state.bindings.feedMedia = media
    }
    
    private func displayFullScreenMedia(_ mediaId: String) {
        let loadingIndicatorIdentifier = "roomAvatarLoadingIndicator"
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorIdentifier, type: .modal, title: L10n.commonLoading, persistent: true))
        
        Task {
            defer {
                userIndicatorController.retractIndicatorWithId(loadingIndicatorIdentifier)
            }
            
            do {
                if case let .success(localUrl) = try await clientProxy.zeroClient.loadFileFromMediaId(mediaId, key: state.bindings.feed.id) {
                    state.bindings.mediaPreviewItem = localUrl
                }
            } catch {
                MXLog.error("Failed to preview feed media: \(error)")
            }
        }
    }
    
    func onFeedUpdated(_ feed: HomeScreenPost) {
        // this would be the reply case
        if let postIndex = state.feedReplies.firstIndex(where: { $0.id == feed.id }) {
            state.feedReplies[postIndex] = feed
        }
    }
    
    func onNewFeedPosted() {
        fetchFeed(state.bindings.feed.id)
    }
}
