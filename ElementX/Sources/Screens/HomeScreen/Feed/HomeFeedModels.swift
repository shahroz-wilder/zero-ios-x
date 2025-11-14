//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import UIKit
import SwiftUI

enum HomeFeedViewModelAction {
    case presentCreateFeedScreen(feedProtocol: FeedProtocol)
    case postTapped(_ post: HomeScreenPost, feedProtocol: FeedProtocol)
    case openPostUserProfile(_ profile: ZPostUserProfile, feedProtocol: FeedProtocol)
    case searchUser
}

enum HomeFeedViewAction {
    case onHomeTabChanged
    
    case newFeed
    case loadMoreAllPosts(followingPostsOnly: Bool)
    case forceRefreshAllPosts(followingPostsOnly: Bool)
    case addMeowToPost(postId: String, amount: Int)
    
    case postTapped(_ post: HomeScreenPost)
    case openArweaveLink(_ post: HomeScreenPost)
    case openYoutubeLink(_ url: String)
    case openUserProfile
    case openPostUserProfile(_ profile: ZPostUserProfile)
    case openMediaPreview(_ mediaId: String, key: String)
    case reloadFeedMedia(_ post: HomeScreenPost)
    
    case searchUser
}

enum HomeScreenPostListMode: CustomStringConvertible {
    case skeletons
    case empty
    case posts
    
    var description: String {
        switch self {
        case .skeletons:
            return "Showing placeholders"
        case .empty:
            return "Showing empty state"
        case .posts:
            return "Showing posts"
        }
    }
}

struct HomeFeedViewState: BindableState {
    let userID: String
    var userDisplayName: String?
    var userAvatarURL: URL?
    
    var currentUserZeroProfile: ZCurrentUser?
    
    var posts: [HomeScreenPost] = []
    var postListMode: HomeScreenPostListMode = .skeletons
    
    var canLoadMorePosts: Bool = true
    
    var visiblePosts: [HomeScreenPost] {
        if postListMode == .skeletons {
            return placeholderPosts
        }
        
        return posts
    }
    
    var bindings: HomeFeedViewStateBindings
    
    var placeholderPosts: [HomeScreenPost] {
        (1...10).map { _ in
            HomeScreenPost.placeholder()
        }
    }
    
    var userRewards = ZeroRewards.empty()
    var postLinkPreviewsMap: [String: ZLinkPreview] = [:]
    var postMediaInfoMap: [String: HomeScreenPostMediaInfo] = [:]
}

struct HomeFeedViewStateBindings {
    var alertInfo: AlertInfo<UUID>?

    /// A media item that will be previewed with QuickLook.
    var mediaPreviewItem: URL?
}

struct HomeScreenPost: Identifiable, Equatable {
    let id: String
    
    // sender info
    let senderInfo: UserProfileProxy
    let senderPrimaryZId: String?
    
    // post info
    let postText: String?
    let attributedSenderHeaderText: AttributedString
    let attributedPostText: AttributedString?
    let postUpdatedAt: String
    let postCreatedAt: String
    let postTimestamp: String
    
    let postImageURL: URL?
    
    let worldPrimaryZId: String?
    let repliesCount: String
    
    let isPostInOwnFeed: Bool
    let arweaveId: String
    let postDateTime: String
    let isMyPost: Bool
    
    let senderProfile: ZPostUserProfile?
    
    var meowCount: String
    var actualMeowCount: String
    var isMeowedByMe: Bool
    var actualMeowedByMy: Bool
    
    var mediaInfo: HomeScreenPostMediaInfo?
    var urlLinkPreview: ZLinkPreview?
    
    static func placeholder() -> HomeScreenPost {
        HomeScreenPost(id: UUID().uuidString,
                       senderInfo: UserProfileProxy(userID: UUID().uuidString),
                       senderPrimaryZId: "0://placeholder-sender-zid",
                       postText: "Placeholder post text...",
                       attributedSenderHeaderText: AttributedString("Placeholder sender text..."),
                       attributedPostText: AttributedString("Placeholder post text..."),
                       postUpdatedAt: "",
                       postCreatedAt: "",
                       postTimestamp: "Now",
                       postImageURL: nil,
                       worldPrimaryZId: "0://placeholder-world-zid",
                       repliesCount: "0",
                       isPostInOwnFeed: false,
                       arweaveId: "",
                       postDateTime: "",
                       isMyPost: false,
                       senderProfile: nil,
                       meowCount: "0",
                       actualMeowCount: "0",
                       isMeowedByMe: false,
                       actualMeowedByMy: false,
                       mediaInfo: nil,
                       urlLinkPreview: nil)
    }
}

struct HomeScreenPostMediaInfo: Identifiable, Equatable {
    let id: String
    let mimeType: String?
    let aspectRatio: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var url: String?
}

extension HomeScreenPost {
    init(loggedInUserId: String, post: ZPost, rewardsDecimalPlaces: Int = 0) {
        let userProfile = post.user.profileSummary
        let meowCount = post.postsMeowsSummary?.meowCount(decimal: rewardsDecimalPlaces) ?? "0"
        let haveAddedMeows = (post.meows?.isEmpty == false)
        let postUpdatedAt = DateUtil.shared.dateFromISO8601String(post.updatedAt)
        let postTimeStamp = postUpdatedAt.timeAgo()
        let repliesCount = String(post.replies?.count ?? 0)
        
        let attributedSenderHeaderText = HomeScreenPost.attributedSenderHeader(from: userProfile.fullName,
                                                                               timeStamp: postTimeStamp)
        let attributedPostText = post.text.isEmpty ? nil : HomeScreenPost.attributedPostText(from: post.text)
        let isPostInOwnFeed = post.worldZid == post.zid
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm aa • MMM d, yyyy"
        let postDateTime = formatter.string(from: postUpdatedAt)
        
        let isMyPost = loggedInUserId.matrixIdToCleanHex() == post.userId.matrixIdToCleanHex()
        let mediaInfo: HomeScreenPostMediaInfo? = (post.media == nil) ? nil : .init(id: post.media!.id,
                                                                                    mimeType: post.media!.mimeType,
                                                                                    aspectRatio: post.media!.width / post.media!.height,
                                                                                    width: post.media!.width,
                                                                                    height: post.media!.height,
                                                                                    url: nil)
        
        self.init(
            id: post.id.rawValue,
            senderInfo: UserProfileProxy(userID: userProfile.id,
                                         displayName: userProfile.fullName,
                                         avatarURL: URL(string: userProfile.profileImage ?? "")),
            senderPrimaryZId: post.userProfileView?.zIdOrPublicAddressDisplayText,
            postText: post.text,
            attributedSenderHeaderText: attributedSenderHeaderText,
            attributedPostText: attributedPostText,
            postUpdatedAt: postTimeStamp,
            postCreatedAt: post.createdAt,
            postTimestamp: postTimeStamp,
            postImageURL: (post.imageUrl != nil) ? URL(string: post.imageUrl!) : nil,
            worldPrimaryZId: post.worldZIdDisplayText,
            repliesCount: repliesCount,
            isPostInOwnFeed: isPostInOwnFeed,
            arweaveId: post.arweaveId,
            postDateTime: postDateTime,
            isMyPost: isMyPost,
            senderProfile: post.userProfileView,
            meowCount: meowCount,
            actualMeowCount: meowCount,
            isMeowedByMe: haveAddedMeows,
            actualMeowedByMy: haveAddedMeows,
            mediaInfo: mediaInfo
        )
    }
    
    func withUpdatedData(mediaInfo: HomeScreenPostMediaInfo?, urlLinkPreview: ZLinkPreview?) -> Self {
        var updatedSelf = self
        updatedSelf.mediaInfo = mediaInfo
        updatedSelf.urlLinkPreview = urlLinkPreview
        return updatedSelf
    }
    
    func withUpdatedData(url: String?, urlLinkPreview: ZLinkPreview?) -> Self {
        var updatedSelf = self
        updatedSelf.mediaInfo?.url = url
        updatedSelf.urlLinkPreview = urlLinkPreview
        return updatedSelf
    }
    
    func withUpdatedMeowCount(_ meowCount: Int) -> Self {
        var updatedSelf = self
        let updatedMeowCount = (updatedSelf.meowCount.toLocalizedDouble() ?? 0) + Double(meowCount)
        updatedSelf.meowCount = updatedMeowCount.description
        updatedSelf.isMeowedByMe = true
        return updatedSelf
    }
    
    func withDefaultMeowCount() -> Self {
        var updatedSelf = self
        updatedSelf.meowCount = updatedSelf.actualMeowCount
        updatedSelf.isMeowedByMe = updatedSelf.actualMeowedByMy
        return updatedSelf
    }
    
    func getArweaveLink() -> URL? {
        let arweaveHost = "https://of2ub4a2ai55lgpqj5z7so7j7v6uwjcruh6cdm3ojgnhqngahkwa.arweave.net/"
        let arweaveUrl = arweaveHost.appending(arweaveId)
        return URL(string: arweaveUrl)
    }
    
    private static func attributedPostText(from text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        
        let patterns: [(String, Color, Bool)] = [
            ("#\\w+", Asset.Colors.blue11.swiftUIColor, false),  // Hashtags
            ("@\\w+", Asset.Colors.blue11.swiftUIColor, false),  // Mentions
            ("(https?://\\S+|www\\.\\S+)", Asset.Colors.blue11.swiftUIColor, true) // URLs
        ]
        
        for (pattern, color, isLink) in patterns {
            applyAttributes(&attributedString, pattern: pattern, color: color, isLink: isLink)
        }
        
        return attributedString
    }
    
    
    private static func attributedSenderHeader(from senderName: String, timeStamp: String) -> AttributedString {
        let timeStampPostFix = " • \(timeStamp)"
        var attributedSenderHeader = AttributedString("\(senderName)\(timeStampPostFix)")
        // applyAttributes
        let nameRange = attributedSenderHeader.range(of: senderName)!
        let timeStampRange = attributedSenderHeader.range(of: timeStampPostFix)!
        attributedSenderHeader[nameRange].foregroundColor = .compound.textPrimary
        attributedSenderHeader[timeStampRange].foregroundColor = .compound.textSecondary
        attributedSenderHeader[nameRange].font = .compound.bodyMDSemibold
        attributedSenderHeader[timeStampRange].font = .zero.bodyMD
        
        return attributedSenderHeader
    }
    
    private static func applyAttributes(_ attributedString: inout AttributedString,
                                        pattern: String,
                                        color: Color,
                                        isLink: Bool = false) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        
        let fullText = String(attributedString.characters)
        let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: fullText.utf16.count))
        
        for match in matches.reversed() {  // Reverse order to avoid index shifting issues
            guard let range = Range(match.range, in: attributedString) else { continue }
            
            attributedString[range].foregroundColor = color
            
            if isLink {
                let linkText = String(attributedString[range].characters)
                let urlString = linkText.hasPrefix("www.") ? "https://\(linkText)" : linkText
                if let url = URL(string: urlString) {
                    attributedString[range].link = url
                    attributedString[range].underlineStyle = .single
                }
            }
        }
    }
}

extension HomeScreenPostMediaInfo {
    init (media: ZPostMedia) {
        let mediaInfo = media.media
        self.init(id: mediaInfo.id,
                  mimeType: mediaInfo.mimeType,
                  aspectRatio: mediaInfo.width / mediaInfo.height,
                  width: mediaInfo.width,
                  height: mediaInfo.height,
                  url: media.signedUrl)
    }
    
    var isVideo: Bool {
        return mimeType?.hasPrefix("video/") == true
    }
    
    func withUpdatedUrl(mediaUrl: URL) -> HomeScreenPostMediaInfo {
        return .init(id: self.id, mimeType: self.mimeType, aspectRatio: self.aspectRatio,
                     width: self.width, height: self.height, url: mediaUrl.absoluteString)
    }
}
