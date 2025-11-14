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
    case startWalletTransaction(WalletTransactionProtocol, WalletTransactionType, ZeroCurrency?)
    case selectRoomAlias(roomAlias: String)
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
    
    case forceRefreshChannels
    case channelTapped(_ channel: HomeScreenChannel)
    case setNotificationFilter(_ tab: HomeNotificationsTab)
    
    case toggleWalletBalance(show: Bool)
    case loadMoreWalletTokens
    case loadMoreWalletTransactions
    case loadMoreWalletNFTs
    case startWalletTransaction(WalletTransactionType)
    case viewTransactionDetails(transactionId: String, chainId: UInt64?)
    case claimRewards(trigger: Bool)
    
    case onStakePoolSelected(HomeScreenWalletStakingContent)
    case claimStakeRewards
    case stakeAmount(String)
    case unstakeAmount(String)
    case refreshWalletData
    
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

enum HomeScreenWalletContentListMode: CustomStringConvertible {
    case skeletons
    case content
    
    var description: String {
        switch self {
        case .skeletons:
            return "Showing placeholders"
        case .content:
            return "Showing wallet content"
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

enum StakePoolViewState {
    case details
    case staking
    case unstaking
    case inProgress
    case success
    case failure(String?)
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
    var walletTokens: [HomeScreenWalletContent] = []
    var walletTransactions: [HomeScreenWalletContent] = []
    var walletNFTs: [HomeScreenWalletContent] = []
    var walletStakings: [HomeScreenWalletStakingContent] = []
    
    // public rooms from room directory
    var publicRooms: [RoomDirectorySearchResult] = []
    var isLoadingPublicRooms = false
    
    var walletTokenNextPageParams: NextPageParams? = nil
    var walletNFTsNextPageParams: NextPageParams? = nil
    var walletTransactionsNextPageParams: TransactionNextPageParams? = nil
    
    var meowPrice: ZeroCurrency? = nil
    
    var roomListMode: HomeScreenRoomListMode = .skeletons
    var channelsListMode: HomeScreenChannelListMode = .skeletons
    var walletContentListMode: HomeScreenWalletContentListMode = .skeletons
    
    var hasPendingInvitations = false
    
    var selectedRoomID: String?
    
    var hideInviteAvatars = false
    
    var reportRoomEnabled = false
    
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
    var visibleWalletTokens: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletTokens
    }
    var visibleWalletTransactions: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletTransactions
    }
    var visibleWalletNFTs: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletNFTs
    }
    var visibleWalletStakings: [HomeScreenWalletStakingContent] {
        if walletContentListMode == .skeletons {
            return (1...20).map { _ in
                HomeScreenWalletStakingContent.placeholder()
            }
        }
        return walletStakings
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
    var placeholderWalletContent: [HomeScreenWalletContent] {
        (1...20).map { _ in
            HomeScreenWalletContent.placeholder()
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
    
    var walletBalance: Double = 0
    var showWalletBalance: Bool = true
    var userWalletBalance: String {
        showWalletBalance ? "$\(walletBalance.formatToThousandSeparatedString())" : "*****"
    }
    
    var selectedStakePool: SelectedHomeWalletStakePool?
}

struct HomeScreenViewStateBindings {
    var filtersState: RoomListFiltersState
    var searchQuery = ""
    var isSearchFieldFocused = false
    
    var alertInfo: AlertInfo<UUID>?
    var leaveRoomAlertItem: LeaveRoomAlertItem?
    
    var showEarningsClaimedSheet: Bool = false
    var showStakePoolSheet: Bool = false
    
    var stakePoolViewState: StakePoolViewState = .details
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
    
    let avatar: RoomAvatar
    
    let canonicalAlias: String?
    
    let isTombstoned: Bool
    
    let isDiscoverable: Bool
    
    var displayedLastMessage: AttributedString? {
        // If the room is tombstoned, show a specific message, regardless of any last message.
        guard !isTombstoned else {
            return AttributedString(L10n.screenRoomlistTombstonedRoomDescription)
        }
        return lastMessage
    }
    
    let unreadNotificationsCount: UInt
    
    var isAChannel: Bool {
        name.starts(with: ZeroContants.ZERO_CHANNEL_PREFIX)
    }
    
    var isPrimary: Bool {
        !isAChannel && !badges.isMuteShown && isEncrypted
    }
    
    var isSecondary: Bool {
        !isAChannel && !badges.isMuteShown && !isEncrypted
    }
    
    var isMuted: Bool {
        !isAChannel && badges.isMuteShown
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
                       avatar: .room(id: "", name: "", avatarURL: nil),
                       canonicalAlias: nil,
                       isTombstoned: false,
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

struct HomeScreenWalletContent: Identifiable, Equatable {
    let id: String
    let icon: String?
    let header: String?
    
    let transactionAction: String?
    let transactionAddress: String?
    let title: String
    let description: String?
    
    let actionPreText: String?
    let actionText: String
    let actionPostText: String?
    
    let chainId: UInt64
    
    static func placeholder() -> HomeScreenWalletContent {
        .init(id: UUID().uuidString,
              icon: nil,
              header: nil,
              transactionAction: nil,
              transactionAddress: nil,
              title: "placeholder title",
              description: "placeholder description",
              actionPreText: nil,
              actionText: "placeholder action text",
              actionPostText: "placeholder action post text",
              chainId: 0)
    }
}

struct HomeScreenWalletStakingContent: Identifiable, Equatable {
    let id: String
    let userWalletAddress: String
    
    let poolAddress: String
    let poolIcon: String?
    let poolName: String
    
    let tokenAmount: String
    let tokenIcon: String?
    
    let totalStakedAmount: Double
    let totalStakedAmountFormatted: String
    let myStakeAmount: Double
    let myStateAmountFormatted: String
    let pendingRewards: Double
    
    let chainId: UInt64
    
    static func placeholder() -> HomeScreenWalletStakingContent {
        .init(id: UUID().uuidString,
              userWalletAddress: "",
              poolAddress: "",
              poolIcon: nil,
              poolName: "placeholder pool",
              tokenAmount: "",
              tokenIcon: nil,
              totalStakedAmount: 0,
              totalStakedAmountFormatted: "",
              myStakeAmount: 0,
              myStateAmountFormatted: "",
              pendingRewards: 0,
              chainId: 0)
    }
    
}

struct SelectedHomeWalletStakePool {
    let pool: HomeScreenWalletStakingContent
    let stakeToken: ZWalletTokenInfo?
    let stakeTokenBalance: ZWalletTokenBalance?
    let rewardToken: ZWalletTokenInfo?
    let rewardTokenBalance: ZWalletTokenBalance?
}

extension SelectedHomeWalletStakePool {
    var claimableRewardValue: String {
        ZeroRewards.parseCredits(credits: rewardTokenBalance?.balance ?? "0", decimals: rewardToken?.decimals ?? 18)
            .formatToSuffix()
    }
    
    var myStakedTokens: Double {
        ZeroRewards.parseCredits(credits: pool.tokenAmount, decimals: stakeToken?.decimals ?? 18)
    }
    
    var myStakedTokensFormatted: String {
        myStakedTokens.formatToSuffix()
    }
    
    var totalAvailableTokenBalance: Double {
        ZeroRewards.parseCredits(credits: stakeTokenBalance?.balance ?? "0", decimals: stakeToken?.decimals ?? 18)
    }
    
    var totalAvailableTokenBalanceFormatted: String {
        totalAvailableTokenBalance.formatToSuffix()
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
                  avatar: summary.avatar,
                  canonicalAlias: summary.canonicalAlias,
                  isTombstoned: summary.isTombstoned,
                  isDiscoverable: false,
                  unreadNotificationsCount: summary.unreadMessagesCount, // settings to unread messages count to show new messages count only
                  isEncrypted: summary.isEncrypted
        )
    }
}

extension HomeScreenChannel {
    init(channelZId: String) {
        let channelDisplayName = String((channelZId.split(separator: ".").first ?? ""))
        let rootChannelName = channelDisplayName.replacingOccurrences(of: ZeroContants.ZERO_CHANNEL_PREFIX, with: "")
        let channelId = "#\(rootChannelName):\(ZeroContants.appServer.matrixHomeServerPostfix)"
        
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
              avatar: .room(id: id, name: displayName, avatarURL: nil),
              canonicalAlias: nil,
              isTombstoned: false,
              isDiscoverable: false,
              unreadNotificationsCount: 0,
              isEncrypted: true)
    }
}

extension HomeScreenWalletContent {
    init (walletToken: ZWalletToken, meowPrice: ZeroCurrency?) {
        let priceDiff = walletToken.percentChange.map(Double.init) ?? meowPrice?.diff

        let isZChainToken = ZeroWalletChainsUtil.shared.isZChain(walletToken.chainId)
        let tokenPriceFormatted = walletToken.isClaimableToken
            ? (isZChainToken ? walletToken.meowPriceFormatted(ref: meowPrice) : walletToken.tokenPriceFormatted()) : ""
        
        self.init(id: walletToken.tokenAddress,
                  icon: walletToken.logo,
                  header: nil,
                  transactionAction: nil,
                  transactionAddress: nil,
                  title: walletToken.name,
                  description: "\(walletToken.formattedAmount) \(walletToken.symbol.uppercased())",
                  actionPreText: nil,
                  actionText: tokenPriceFormatted.isEmpty ? "" : "$\(tokenPriceFormatted)",
                  actionPostText: walletToken.isClaimableToken ? priceDiff?.description : nil,
                  chainId: walletToken.chainId
        )
    }
    
    init(walletNFT: NFT) {
        self.init(id: walletNFT.id,
                  icon: walletNFT.imageUrl,
                  header: nil,
                  transactionAction: nil,
                  transactionAddress: nil,
                  title: walletNFT.collectionName ?? walletNFT.metadata.name ?? "",
                  description: nil,
                  actionPreText: nil,
                  actionText: "0",
                  actionPostText: nil,
                  chainId: 0)
    }
    
    init(walletTransaction: WalletTransaction, meowPrice: ZeroCurrency?) {
        let isTransactionReceived = walletTransaction.action.lowercased() == "receive"
        
        self.init(id: walletTransaction.hash,
                  icon: walletTransaction.token.logo,
                  header: nil, //walletTransaction.timestamp
                  transactionAction: isTransactionReceived ? "Received from" : "Sent to",
                  transactionAddress: isTransactionReceived ? displayFormattedAddress(walletTransaction.from) : displayFormattedAddress( walletTransaction.to),
                  title: walletTransaction.token.name,
                  description: nil,
                  actionPreText: nil,
                  actionText: walletTransaction.formattedAmount,
                  actionPostText: "--",
                  chainId: walletTransaction.token.chainId ?? ZeroWalletChainsUtil.shared.zChainId)
    }
}

extension HomeScreenWalletStakingContent {
    init(tokenPrice: Double?, userWalletAddress: String,
         pool: WalletStakePool, totalStaked: String, stakingConfig: ZStackingConfig,
         stakerStatus: ZStakingStatus, stakeRewards: ZStakingUserRewardsInfo) {
        
        let totalStakedAmount = ZeroWalletUtil.shared.tokenPrice(tokenAmount: ZeroRewards.parseCredits(credits: totalStaked,
                                                                                                      decimals: 18),
                                                                tokenPrice: tokenPrice)
        let myStakeAmount = ZeroWalletUtil.shared.tokenPrice(tokenAmount: ZeroRewards.parseCredits(credits: stakerStatus.amountStaked,
                                                                                                  decimals: 18),
                                                             tokenPrice: tokenPrice)
        let pendingRewards = ZeroRewards.parseCredits(credits: stakeRewards.pendingRewards, decimals: 18)
        self.init(id: pool.address,
                  userWalletAddress: userWalletAddress,
                  poolAddress: pool.address,
                  poolIcon: pool.image,
                  poolName: pool.name,
                  tokenAmount: stakerStatus.amountStaked,
                  tokenIcon: pool.image,
                  totalStakedAmount: totalStakedAmount,
                  totalStakedAmountFormatted: "$\(totalStakedAmount.formatToSuffix())",
                  myStakeAmount: myStakeAmount,
                  myStateAmountFormatted: "$\(myStakeAmount.formatToSuffix())",
                  pendingRewards: pendingRewards,
                  chainId: pool.chainId.rawValue)
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
              avatar: avatar,
              canonicalAlias: nil,
              isTombstoned: false,
              isDiscoverable: true,
              unreadNotificationsCount: 0,
              isEncrypted: false)
    }
}
