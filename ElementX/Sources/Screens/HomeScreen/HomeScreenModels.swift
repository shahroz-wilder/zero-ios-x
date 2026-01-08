//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import UIKit
import SwiftUI

enum HomeScreenViewModelAction {
    case presentRoom(roomIdentifier: String)
    case presentRoomDetails(roomIdentifier: String)
    case presentReportRoom(roomIdentifier: String)
    case presentDeclineAndBlock(userID: String, roomID: String)
    case presentSpace(SpaceRoomListProxyProtocol)
    case roomLeft(roomIdentifier: String)
    case transferOwnership(roomIdentifier: String)
    case presentSecureBackupSettings
    case presentRecoveryKeyScreen
    case presentEncryptionResetScreen
    case presentSettingsScreen(userRewardsProtocol: UserRewardsProtocol)
    case presentFeedbackScreen
    case presentStartChatScreen
    case presentGlobalSearch
    case logout
    case selectRoomAlias(roomAlias: String)
    
    case refreshWallet
}

enum HomeScreenViewAction {
    case selectRoom(roomIdentifier: String)
    case showRoomDetails(roomIdentifier: String)
    case leaveRoom(roomIdentifier: String)
    case confirmLeaveRoom(roomIdentifier: String)
    case reportRoom(roomIdentifier: String)
    case showSettings
    case startChat
    case setupRecovery
    case confirmRecoveryKey
    case resetEncryption
    case skipRecoveryKeyConfirmation
    case dismissNewSoundBanner
    case updateVisibleItemRange(Range<Int>)
    case globalSearch
    case markRoomAsUnread(roomIdentifier: String)
    case markRoomAsRead(roomIdentifier: String)
    case markRoomAsFavourite(roomIdentifier: String, isFavourite: Bool)
    
    case acceptInvite(roomIdentifier: String)
    case declineInvite(roomIdentifier: String)
    
    case loadRewards
    case rewardsIntimated
    case claimRewards(trigger: Bool)
    
    case forceRefreshChannels
    case channelTapped(_ channel: HomeScreenChannel)
    case setNotificationFilter(_ tab: HomeNotificationsTab)
    
    case reachedPublicRoomsBottom
    case selectPublicRoom(RoomDirectorySearchResult)
}

enum HomeScreenRoomListMode: CustomStringConvertible {
    case skeletons
    case empty
    case rooms
    
    var description: String {
        switch self {
        case .skeletons:
            return "Showing placeholders"
        case .empty:
            return "Showing empty state"
        case .rooms:
            return "Showing rooms"
        }
    }
}

enum HomeScreenChannelListMode: CustomStringConvertible {
    case skeletons
    case empty
    case channels
    
    var description: String {
        switch self {
        case .skeletons:
            return "Showing placeholders"
        case .empty:
            return "Showing empty state"
        case .channels:
            return "Showing channels"
        }
    }
}

enum HomeScreenSecurityBannerMode: Equatable {
    case none
    case dismissed
    case show(HomeScreenRecoveryKeyConfirmationBanner.State)
    
    var isDismissed: Bool {
        switch self {
        case .dismissed: true
        default: false
        }
    }
    
    var isShown: Bool {
        switch self {
        case .show: true
        default: false
        }
    }
}

enum ClaimRewardsState {
    case none
    case claiming
    case success(String)
    case failure
}

struct HomeScreenViewState: BindableState {
    let userID: String
    var userDisplayName: String?
    var userAvatarURL: URL?
    
    var currentUserZeroProfile: ZCurrentUser?
    
    var securityBannerMode = HomeScreenSecurityBannerMode.none
    var shouldShowNewSoundBanner = false
    
    var requiresExtraAccountSetup = false
    
    var rooms: [HomeScreenRoom] = []
    var directRoomsUserStatusMap: [String : Bool] = [:]
    var channels: [HomeScreenChannel] = []
    
    // public rooms from room directory
    var publicRooms: [RoomDirectorySearchResult] = []
    var isLoadingPublicRooms = false
    
    var meowPrice: ZeroCurrency? = nil
    
    var roomListMode: HomeScreenRoomListMode = .skeletons
    var channelsListMode: HomeScreenChannelListMode = .skeletons
    
    var hasPendingInvitations = false
    
    var selectedRoomID: String?
    
    var hideInviteAvatars = false
    
    var reportRoomEnabled = false
    
    var shouldShowInActiveChatsTab: Bool = false
    
    var visibleRooms: [HomeScreenRoom] {
        if roomListMode == .skeletons {
            return placeholderRooms
        }
        
        return rooms
    }
    
    var visibleChannels: [HomeScreenChannel] {
        if channelsListMode == .skeletons {
            return placeholderChannels
        }
        
        return channels
    }
    
    var userRewards = ZeroRewards.empty()
    var claimableUserRewards = ZeroRewards.empty()
    var showNewUserRewardsIntimation = false
    
    var bindings: HomeScreenViewStateBindings
    
    var placeholderRooms: [HomeScreenRoom] {
        (1...10).map { _ in
            HomeScreenRoom.placeholder()
        }
    }
    var placeholderChannels: [HomeScreenChannel] {
        (1...20).map { index in
            HomeScreenChannel.placeholder(index)
        }
    }
    
    // Used to hide all the rooms when the search field is focused and the query is empty
    var shouldHideRoomList: Bool {
        bindings.isSearchFieldFocused && bindings.searchQuery.isEmpty
    }
    
    var shouldShowEmptyFilterState: Bool {
        !bindings.isSearchFieldFocused && bindings.filtersState.isFiltering && visibleRooms.isEmpty
    }
    
    var shouldShowFilters: Bool {
        !bindings.isSearchFieldFocused && roomListMode == .rooms
    }
    
    var shouldShowBanner: Bool {
        securityBannerMode.isShown || shouldShowNewSoundBanner
    }
    
    var notificationsContent: [HomeScreenRoom] = []
    var hasNewNotifications: Bool {
        let allNotificationContent = visibleRooms.filter {
            switch $0.type {
            case .placeholder, .knock:
                return false
            default:
                return $0.badges.isDotShown
            }
        }
        return !allNotificationContent.isEmpty
    }
    
    var claimRewardsState: ClaimRewardsState = .none
}

struct HomeScreenViewStateBindings {
    var filtersState: RoomListFiltersState
    var searchQuery = ""
    var isSearchFieldFocused = false
    
    var alertInfo: AlertInfo<UUID>?
    var leaveRoomAlertItem: LeaveRoomAlertItem?
    
    var showEarningsClaimedSheet: Bool = false
}

struct HomeScreenRoom: Identifiable, Equatable {
    enum RoomType: Equatable {
        case placeholder
        case room
        case invite(inviterDetails: RoomInviterDetails?)
        case knock
    }
    
    static let placeholderLastMessage = AttributedString("Hidden last message")
    
    /// The list item identifier is it's room identifier.
    let id: String
    
    /// The real room identifier this item points to
    let roomID: String?
    
    let type: RoomType
    
    var inviter: RoomInviterDetails? {
        if case .invite(let inviter) = type {
            return inviter
        }
        return nil
    }
    
    var badges: Badges
    struct Badges: Equatable {
        let isDotShown: Bool
        let isMentionShown: Bool
        var isMuteShown: Bool
        let isCallShown: Bool
    }
    
    let name: String
    
    let isDirect: Bool
    
    let isHighlighted: Bool
    
    let isFavourite: Bool
    
    let timestamp: String?
    
    let lastMessage: AttributedString?
    
    enum LastMessageState { case sending, failed }
    let lastMessageState: LastMessageState?
    
    let avatar: RoomAvatar
    
    let canonicalAlias: String?
    
    let isTombstoned: Bool
    
    let isArchived: Bool
    
    let isDiscoverable: Bool
    
    var displayedLastMessage: AttributedString? {
        if isTombstoned {
            AttributedString(L10n.screenRoomlistTombstonedRoomDescription)
        } else if lastMessageState == .failed {
            AttributedString(L10n.commonMessageFailedToSend)
        } else {
            lastMessage
        }
    }
    
    let unreadNotificationsCount: UInt
    
    var isAChannel: Bool {
        name.starts(with: ZeroConstants.ZERO_CHANNEL_PREFIX)
    }
    
    var isPrimary: Bool {
        !isAChannel && !isArchived && !badges.isMuteShown && isEncrypted
    }
    
    var isSecondary: Bool {
        !isAChannel && !isArchived && !badges.isMuteShown && !isEncrypted
    }
    
    var isMuted: Bool {
        !isAChannel && !isArchived && badges.isMuteShown
    }
    
    let isEncrypted: Bool
    
    static func placeholder() -> HomeScreenRoom {
        HomeScreenRoom(id: UUID().uuidString,
                       roomID: nil,
                       type: .placeholder,
                       badges: .init(isDotShown: false, isMentionShown: false, isMuteShown: false, isCallShown: false),
                       name: "Placeholder room name",
                       isDirect: false,
                       isHighlighted: false,
                       isFavourite: false,
                       timestamp: "Now",
                       lastMessage: placeholderLastMessage,
                       lastMessageState: nil,
                       avatar: .room(id: "", name: "", avatarURL: nil),
                       canonicalAlias: nil,
                       isTombstoned: false,
                       isArchived: false,
                       isDiscoverable: false,
                       unreadNotificationsCount: 0,
                       isEncrypted: false)
    }
}

struct HomeScreenChannel: Identifiable, Equatable {
    let id: String
    let channelFullName: String
    let displayName: String
    
    var notificationsCount: UInt = 0
    
    static func placeholder(_ index: Int) -> HomeScreenChannel {
        .init(id: UUID().uuidString,
              channelFullName: "0://placeholderChannel\(index).name",
              displayName: "0://placeholderChannel\(index)")
    }
}

extension HomeScreenRoom {
    init(summary: RoomSummary, hideUnreadMessagesBadge: Bool, seenInvites: Set<String> = []) {
        let roomID = summary.id
        
        let hasUnreadMessages = hideUnreadMessagesBadge ? false : summary.hasUnreadMessages
        let isUnseenInvite = summary.joinRequestType?.isInvite == true && !seenInvites.contains(roomID)
        
        let isDotShown = hasUnreadMessages || summary.hasUnreadMentions || summary.hasUnreadNotifications || summary.isMarkedUnread || isUnseenInvite
        let isMentionShown = summary.hasUnreadMentions && !summary.isMuted
        let isMuteShown = summary.isMuted
        let isCallShown = summary.hasOngoingCall
        let isHighlighted = summary.isMarkedUnread || (!summary.isMuted && (summary.hasUnreadNotifications || summary.hasUnreadMentions)) || isUnseenInvite
        
        let type: HomeScreenRoom.RoomType = switch summary.joinRequestType {
        case .invite(let inviter): .invite(inviterDetails: inviter.map(RoomInviterDetails.init))
        case .knock: .knock
        case .none: .room
        }
        
        self.init(id: roomID,
                  roomID: summary.id,
                  type: type,
                  badges: .init(isDotShown: isDotShown,
                                isMentionShown: isMentionShown,
                                isMuteShown: isMuteShown,
                                isCallShown: isCallShown),
                  name: summary.name,
                  isDirect: summary.isDirect,
                  isHighlighted: isHighlighted,
                  isFavourite: summary.isFavourite,
                  timestamp: summary.lastMessageDate?.formattedMinimal(),
                  lastMessage: summary.lastMessage,
                  lastMessageState: summary.homeScreenLastMessageState,
                  avatar: summary.avatar,
                  canonicalAlias: summary.canonicalAlias,
                  isTombstoned: summary.isTombstoned,
                  isArchived: summary.isDead,
                  isDiscoverable: false,
                  unreadNotificationsCount: summary.unreadMessagesCount, // settings to unread messages count to show new messages count only
                  isEncrypted: summary.isEncrypted
        )
    }
}

extension HomeScreenChannel {
    init(channelZId: String) {
        let channelDisplayName = String((channelZId.split(separator: ".").first ?? ""))
        let rootChannelName = channelDisplayName.replacingOccurrences(of: ZeroConstants.ZERO_CHANNEL_PREFIX, with: "")
        let channelId = "#\(rootChannelName):\(ZeroConstants.appServer.matrixHomeServerPostfix)"
        
        self.init(
            id: channelId,
            channelFullName: channelZId,
            displayName: channelDisplayName
        )
    }
    
    func mapToHomeScreenRoom() -> HomeScreenRoom {
        .init(id: id,
              roomID: channelFullName,
              type: .room,
              badges: .init(isDotShown: false, isMentionShown: false, isMuteShown: false, isCallShown: false),
              name: displayName,
              isDirect: false,
              isHighlighted: false,
              isFavourite: false,
              timestamp: nil,
              lastMessage: nil,
              lastMessageState: nil,
              avatar: .room(id: id, name: displayName, avatarURL: nil),
              canonicalAlias: nil,
              isTombstoned: false,
              isArchived: false,
              isDiscoverable: false,
              unreadNotificationsCount: 0,
              isEncrypted: true)
    }
}

extension RoomDirectorySearchResult {
    func mapToHomeScreenRoom() -> HomeScreenRoom {
        .init(id: id,
              roomID: id,
              type: .room,
              badges: .init(isDotShown: false, isMentionShown: false, isMuteShown: false, isCallShown: false),
              name: name ?? "",
              isDirect: false,
              isHighlighted: false,
              isFavourite: false,
              timestamp: nil,
              lastMessage: nil,
              lastMessageState: nil,
              avatar: avatar,
              canonicalAlias: nil,
              isTombstoned: false,
              isArchived: false,
              isDiscoverable: true,
              unreadNotificationsCount: 0,
              isEncrypted: false)
    }
}

private extension RoomSummary {
    var homeScreenLastMessageState: HomeScreenRoom.LastMessageState? {
        if isTombstoned {
            nil
        } else {
            switch lastMessageState {
            case .sending: .sending
            case .failed: .failed
            case .none: .none
            }
        }
    }
}
