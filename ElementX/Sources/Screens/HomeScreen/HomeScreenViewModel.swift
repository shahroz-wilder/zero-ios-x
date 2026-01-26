//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents
import Combine
import MatrixRustSDK
import SwiftUI
import Kingfisher

typealias HomeScreenViewModelType = StateStoreViewModel<HomeScreenViewState, HomeScreenViewAction>

protocol RoomNotificationModeUpdatedProtocol {
    func onRoomNotificationModeUpdated(for roomId: String, mode: RoomNotificationModeProxy)
}

class HomeScreenViewModel: HomeScreenViewModelType, HomeScreenViewModelProtocol, RoomNotificationModeUpdatedProtocol, UserRewardsProtocol {
    private let userSession: UserSessionProtocol
    private let spaceFilterSubject: CurrentValueSubject<SpaceServiceFilter?, Never>
    private let analyticsService: AnalyticsService
    private let appSettings: AppSettings
    private let notificationManager: NotificationManagerProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let mediaProvider: MediaProviderProtocol
    
    private let roomSummaryProvider: RoomSummaryProviderProtocol?
    private let roomDirectorySearchProxy: RoomDirectorySearchProxyProtocol
    
    private var actionsSubject: PassthroughSubject<HomeScreenViewModelAction, Never> = .init()
    var actions: AnyPublisher<HomeScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private var channelRoomMap: [String: RoomInfoProxy] = [:]
    private var roomNotificationUpdateMap: [String: RoomNotificationModeProxy] = [:]
        
    private var isRoomUsersExtractionInProgress: Bool = false
    private var isRoomAutoJoinInProgress: Bool = false
    
    init(userSession: UserSessionProtocol,
         selectedRoomPublisher: CurrentValuePublisher<String?, Never>,
         appSettings: AppSettings,
         analyticsService: AnalyticsService,
         notificationManager: NotificationManagerProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.userSession = userSession
        self.analyticsService = analyticsService
        self.appSettings = appSettings
        self.notificationManager = notificationManager
        self.userIndicatorController = userIndicatorController
        self.mediaProvider = userSession.mediaProvider
        
        spaceFilterSubject = CurrentValueSubject<SpaceServiceFilter?, Never>(nil)
        
        roomSummaryProvider = userSession.clientProxy.roomSummaryProvider
        roomDirectorySearchProxy = userSession.clientProxy.roomDirectorySearchProxy()
        
        super.init(initialViewState: .init(userID: userSession.clientProxy.userID,
                                           spaceFiltersEnabled: appSettings.spaceFiltersEnabled,
                                           bindings: .init(filtersState: .init(appSettings: appSettings))),
                   mediaProvider: userSession.mediaProvider)
        
        state.publicRooms = roomDirectorySearchProxy.resultsPublisher.value
        
        userSession.clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userAvatarURL, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userDisplayName, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroClient.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.state.currentUserZeroProfile = currentUser
                ZeroCustomLogsService.shared.setup(userId: currentUser.id.rawValue, userName: currentUser.displayName)
            }
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] securityState in
                guard let self else { return }
                
                switch securityState.recoveryState {
                case .disabled:
                    state.requiresExtraAccountSetup = true
                    if !state.securityBannerMode.isDismissed {
                        state.securityBannerMode = .show(.setUpRecovery)
                    }
                case .incomplete:
                    state.requiresExtraAccountSetup = true
                    state.securityBannerMode = .show(.recoveryOutOfSync)
                default:
                    state.securityBannerMode = .none
                    state.requiresExtraAccountSetup = false
                }
            }
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .filter { state in
                state.verificationState != .unknown
                && state.recoveryState != .settingUp
                && state.recoveryState != .unknown
            }
            .sink { [weak self] state in
                guard let self else { return }
                
                self.analyticsService.updateUserProperties(AnalyticsEvent.newVerificationStateUserProperty(verificationState: state.verificationState, recoveryState: state.recoveryState))
                self.analyticsService.trackSessionSecurityState(state)
            }
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroClient.userRewardsPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userRewards, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroClient.showNewUserRewardsIntimationPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.showNewUserRewardsIntimation, on: self)
            .store(in: &cancellables)
        
        selectedRoomPublisher
            .weakAssign(to: \.state.selectedRoomID, on: self)
            .store(in: &cancellables)
        
        appSettings.$hideUnreadMessagesBadge
            .sink { [weak self] _ in self?.updateRooms() }
            .store(in: &cancellables)
        
        appSettings.$seenInvites
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.updateRooms()
            }
            .store(in: &cancellables)
        
        appSettings.$hasSeenNewSoundBanner
            .sink { [weak self] hasSeenNewSoundBanner in
//                self?.state.shouldShowNewSoundBanner = !hasSeenNewSoundBanner
                self?.state.shouldShowNewSoundBanner = false
            }
            .store(in: &cancellables)
        
        appSettings.$spaceFiltersEnabled
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.spaceFiltersEnabled, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.hideInviteAvatarsPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.hideInviteAvatars, on: self)
            .store(in: &cancellables)
        
        spaceFilterSubject
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.selectedSpaceFilter, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroClient.homeRoomSummariesUsersPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                self?.mapDirectChatUsersProBadgeStatus(users)
            }
            .store(in: &cancellables)
        
        roomDirectorySearchProxy.resultsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                guard let self else { return }
                
                let uniqueRooms = rooms.uniqued(on: \.id)
                if self.state.bindings.isSearchFieldFocused, !self.state.bindings.searchQuery.isEmpty {
                    //user is searching, this result is search result, we need to assign it
                    self.state.publicRooms = uniqueRooms
                } else {
                    var existingRooms = self.state.publicRooms
                    existingRooms.append(contentsOf: uniqueRooms)
                    self.state.publicRooms = existingRooms.uniqued(on: \.id)
                }
            }
            .store(in: &cancellables)
                
        Task {
            state.reportRoomEnabled = await userSession.clientProxy.isReportRoomSupported
        }
        
        let isSearchFieldFocused = context.$viewState.map(\.bindings.isSearchFieldFocused)
        let searchQuery = context.$viewState.map(\.bindings.searchQuery)
        let activeFilters = context.$viewState.map(\.bindings.filtersState.activeFilters)
        let activeZeroFilters = context.$viewState.map(\.bindings.filtersState.activeZeroFilter)
        isSearchFieldFocused
            .combineLatest(searchQuery, activeFilters, spaceFilterSubject, activeZeroFilters)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] isSearchFieldFocused, _, _, _ in
                guard let self else { return }
                // isSearchFieldFocused` is sometimes turning to true after cancelling the search. So to be extra sure we are updating the values correctly we read them directly in the next run loop, and we add a small delay if the value has changed
                let delay = isSearchFieldFocused == self.context.viewState.bindings.isSearchFieldFocused ? 0.0 : 0.05
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.updateFilter()
                }
            }
            .store(in: &cancellables)
        
        setupRoomListSubscriptions()
        
        updateRooms()
        
        loadPublicRoomsNextPage()
        
        fetchZeroHomeScreenData()
        
    }
    
    // MARK: - Public
    
    override func process(viewAction: HomeScreenViewAction) {
        switch viewAction {
        case .selectRoom(let roomIdentifier):
            // check whether a room is selected or channel
            let isAChannel = roomIdentifier.starts(with: ZeroConstants.ZERO_CHANNEL_PREFIX)
            if isAChannel {
                if let channel = state.channels.first(where: { $0.channelFullName == roomIdentifier }) {
                    joinZeroChannel(channel)
                }
            } else {
                actionsSubject.send(.presentRoom(roomIdentifier: roomIdentifier))
            }
        case .showRoomDetails(let roomIdentifier):
            actionsSubject.send(.presentRoomDetails(roomIdentifier: roomIdentifier))
        case .leaveRoom(let roomIdentifier):
            startLeaveRoomProcess(roomID: roomIdentifier)
        case .confirmLeaveRoom(let roomIdentifier):
            Task { await leaveRoom(roomID: roomIdentifier) }
        case .reportRoom(let roomIdentifier):
            actionsSubject.send(.presentReportRoom(roomIdentifier: roomIdentifier))
        case .showSettings:
            actionsSubject.send(.presentSettingsScreen(userRewardsProtocol: self))
        case .setupRecovery:
            actionsSubject.send(.presentSecureBackupSettings)
        case .confirmRecoveryKey:
            actionsSubject.send(.presentRecoveryKeyScreen)
        case .resetEncryption:
            actionsSubject.send(.presentEncryptionResetScreen)
        case .skipRecoveryKeyConfirmation:
            state.securityBannerMode = .dismissed
        case .dismissNewSoundBanner:
            appSettings.hasSeenNewSoundBanner = true
        case .updateVisibleItemRange(let range):
            roomSummaryProvider?.updateVisibleRange(range)
        case .startChat:
            actionsSubject.send(.presentStartChatScreen)
        case .globalSearch:
            actionsSubject.send(.presentGlobalSearch)
        case .spaceFilters:
            if spaceFilterSubject.value != nil {
                spaceFilterSubject.send(nil)
            } else {
                state.bindings.spaceFiltersViewModel = ChatsSpaceFiltersScreenViewModel(spaceService: userSession.clientProxy.spaceService,
                                                                                        mediaProvider: userSession.mediaProvider)
                
                state.bindings.spaceFiltersViewModel?.actionsPublisher.sink { [weak self] action in
                    guard let self else { return }
                    
                    switch action {
                    case .confirm(let spaceServiceFilter):
                        spaceFilterSubject.send(spaceServiceFilter)
                        state.bindings.spaceFiltersViewModel = nil
                    case .cancel:
                        state.bindings.spaceFiltersViewModel = nil
                    }
                }
                .store(in: &cancellables)
            }
        case .markRoomAsUnread(let roomIdentifier):
            Task {
                guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomIdentifier) else {
                    MXLog.error("Failed retrieving room for identifier: \(roomIdentifier)")
                    return
                }
                
                switch await roomProxy.flagAsUnread(true) {
                case .success:
                    analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuUnreadToggle)
                case .failure(let error):
                    MXLog.error("Failed marking room \(roomIdentifier) as unread with error: \(error)")
                }
            }
        case .markRoomAsRead(let roomIdentifier):
            Task {
                guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomIdentifier) else {
                    MXLog.error("Failed retrieving room for identifier: \(roomIdentifier)")
                    return
                }
                
                switch await roomProxy.flagAsUnread(false) {
                case .success:
                    analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuUnreadToggle)
                    
                    if case .failure(let error) = await roomProxy.markAsRead(receiptType: appSettings.sharePresence ? .read : .readPrivate) {
                        MXLog.error("Failed marking room \(roomIdentifier) as read with error: \(error)")
                    }
                case .failure(let error):
                    MXLog.error("Failed flagging room \(roomIdentifier) as read with error: \(error)")
                }
            }
        case .markRoomAsFavourite(let roomIdentifier, let isFavourite):
            Task {
                await markRoomAsFavourite(roomIdentifier, isFavourite: isFavourite)
            }
        case .acceptInvite(let roomIdentifier):
            Task {
                await acceptInvite(roomID: roomIdentifier)
            }
        case .declineInvite(let roomIdentifier):
            Task { await showDeclineInviteConfirmationAlert(roomID: roomIdentifier) }
        case .loadRewards:
            loadUserRewards()
            checkAndUpdateRoomNotificationMode()
        case .rewardsIntimated:
            dismissNewRewardsIntimation()
        case .forceRefreshChannels:
            Task { await fetchChannels(isForceRefresh: true) }
        case .channelTapped(let channel):
            joinZeroChannel(channel)
        case .setNotificationFilter(let tab):
            applyCustomFilterToNotificationsList(tab)
        case .claimRewards(let trigger):
            if trigger {
                claimUserRewards()
            } else {
                state.claimRewardsState = .none
                state.bindings.showEarningsClaimedSheet = false
            }
        case .reachedPublicRoomsBottom:
            loadPublicRoomsNextPage()
        case .selectPublicRoom(let publicRoom):
            if let alias = publicRoom.alias {
                actionsSubject.send(.selectRoomAlias(roomAlias: alias))
            } else {
                actionsSubject.send(.presentRoom(roomIdentifier: publicRoom.id))
            }
        }
    }
    
    // perphery: ignore - used in release mode
    func presentCrashedLastRunAlert() {
        // Delay setting the alert otherwise it automatically gets dismissed. Same as the force logout one.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.state.bindings.alertInfo = AlertInfo(id: UUID(),
                                                      title: L10n.crashDetectionDialogContent(InfoPlistReader.main.bundleDisplayName),
                                                      primaryButton: .init(title: L10n.actionNo, action: nil),
                                                      secondaryButton: .init(title: L10n.actionYes) { [weak self] in
                self?.actionsSubject.send(.presentFeedbackScreen)
            })
        }
    }
    
    // MARK: - Private
    
    private func updateFilter() {
        if state.shouldHideRoomList {
            roomSummaryProvider?.setFilter(.excludeAll)
        } else {
            if state.bindings.isSearchFieldFocused {
                roomSummaryProvider?.setFilter(.search(query: state.bindings.searchQuery))
            } else {
                if let spaceFilter = spaceFilterSubject.value {
                    roomSummaryProvider?.setFilter(.rooms(roomsIDs: spaceFilter.descendants,
                                                          filters: state.bindings.filtersState.activeFilters.set))
                } else {
                    roomSummaryProvider?.setFilter(.all(filters: state.bindings.filtersState.activeFilters.set))
                }
            }
        }
    }
    
    private func setupRoomListSubscriptions() {
        userSession.clientProxy.setRoomNotificationModeProtocol(self)
        
        guard let roomSummaryProvider else {
            MXLog.error("Room summary provider unavailable")
            return
        }
        
        analyticsService.signpost.beginFirstRooms()
        
        roomSummaryProvider.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                updateRoomListMode(with: state)
            }
            .store(in: &cancellables)
        
        roomSummaryProvider.roomListPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRooms()
            }
            .store(in: &cancellables)
    }
    
    private func updateRoomListMode(with roomSummaryProviderState: RoomSummaryProviderState) {
        let isLoadingData = !roomSummaryProviderState.isLoaded
        let hasNoRooms = roomSummaryProviderState.isLoaded && roomSummaryProviderState.totalNumberOfRooms == 0
        
        var roomListMode = state.roomListMode
        if isLoadingData {
            roomListMode = .skeletons
        } else if hasNoRooms {
            roomListMode = .empty
        } else {
            roomListMode = .rooms
        }
        
        guard roomListMode != state.roomListMode else {
            return
        }
        
        if roomListMode == .rooms, state.roomListMode == .skeletons {
            analyticsService.signpost.endFirstRooms()
        }
        
        state.roomListMode = roomListMode
        
        MXLog.info("Received room summary provider update, setting view room list mode to \"\(state.roomListMode)\"")
        // Delay user profile detail loading until after the initial room list loads
        if roomListMode == .rooms {
            Task {
                await self.userSession.clientProxy.loadUserAvatarURL()
                await self.userSession.clientProxy.loadUserDisplayName()
            }
        }
    }
    
    private func updateRooms() {
        guard let roomSummaryProvider else {
            MXLog.error("Room summary provider unavailable")
            return
        }
        
        var rooms = [HomeScreenRoom]()
        let seenInvites = appSettings.seenInvites
        
        let matrixRoomSummaries = roomSummaryProvider.roomListPublisher.value
        for summary in matrixRoomSummaries {
            let room = HomeScreenRoom(summary: summary,
                                      hideUnreadMessagesBadge: appSettings.hideUnreadMessagesBadge,
                                      seenInvites: seenInvites)
            rooms.append(room)
        }
        if !state.bindings.filtersState.isFiltering {
            state.shouldShowInActiveChatsTab = rooms.contains(where: \.isArchived)
        }
        
        // We need to append gated channels in the search listing as well, only when user is searching on home screen
        if context.isSearchFieldFocused, !context.searchQuery.isEmpty {
            rooms = rooms.filter { !$0.isAChannel && !$0.isArchived }
            // append gated channels in the same list in case user is searching
            let gatedChannels = state.channels
                .filter { $0.displayName.containsIgnoringCase(context.searchQuery) }
                .map { $0.mapToHomeScreenRoom() }
            rooms.append(contentsOf: gatedChannels)
            
            // append public rooms in the same list in case user is searching
            let publicRooms = state.publicRooms
                .filter { $0.name?.containsIgnoringCase(context.searchQuery) == true }
                .map { $0.mapToHomeScreenRoom() }
            rooms.append(contentsOf: publicRooms)
        } else {
            // We need to filter rooms based on active zeroFilter
            switch context.filtersState.activeZeroFilter {
            case .primaryRooms:
                rooms = rooms.filter { $0.isPrimary }
            case .secondaryRooms:
                rooms = rooms.filter { $0.isSecondary }
            case .mutedRooms:
                rooms = rooms.filter { $0.isMuted }
            case .channels:
                rooms = rooms.filter { $0.isAChannel }
            case .inactiveRooms:
                rooms = rooms.filter { $0.isArchived }
            
            }
        }
        
        state.rooms = rooms.uniqued(on: { $0.id })
        
        applyCustomFilterToNotificationsList(.all)
        extractAllRoomUsers(matrixRoomSummaries)
        autoJoinInvitedRooms(matrixRoomSummaries)
    }
    
    private func markRoomAsFavourite(_ roomID: String, isFavourite: Bool) async {
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            MXLog.error("Failed retrieving room for identifier: \(roomID)")
            return
        }
        
        switch await roomProxy.flagAsFavourite(isFavourite) {
        case .success:
            analyticsService.trackInteraction(name: .MobileRoomListRoomContextMenuFavouriteToggle)
        case .failure(let error):
            MXLog.error("Failed marking room \(roomID) as favourite: \(isFavourite) with error: \(error)")
        }
    }
    
    private static let leaveRoomLoadingID = "LeaveRoomLoading"
    
    private func startLeaveRoomProcess(roomID: String) {
        Task {
            defer {
                userIndicatorController.retractIndicatorWithId(Self.leaveRoomLoadingID)
            }
            userIndicatorController.submitIndicator(UserIndicator(id: Self.leaveRoomLoadingID, type: .modal, title: L10n.commonLoading, persistent: true))
            
            guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
                state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
                return
            }
            
            guard roomProxy.infoPublisher.value.joinedMembersCount > 1 else {
                state.bindings.leaveRoomAlertItem = LeaveRoomAlertItem(roomID: roomID,
                                                                       isDM: roomProxy.isDirectOneToOneRoom,
                                                                       state: roomProxy.infoPublisher.value.isPrivate ?? true ? .empty : .public)
                return
            }
            
            if !roomProxy.isDirectOneToOneRoom {
                if case let .success(ownMember) = await roomProxy.getMember(userID: roomProxy.ownUserID),
                   ownMember.role.isOwner {
                    await roomProxy.updateMembers()
                    var isLastOwner = true
                    for member in roomProxy.membersPublisher.value where member.userID != roomProxy.ownUserID && member.membership == .join {
                        if member.role.isOwner {
                            isLastOwner = false
                            break
                        }
                    }
                    
                    if isLastOwner {
                        state.bindings.alertInfo = .init(id: UUID(),
                                                         title: L10n.leaveRoomAlertSelectNewOwnerTitle,
                                                         message: L10n.leaveRoomAlertSelectNewOwnerSubtitle,
                                                         primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                                         secondaryButton: .init(title: L10n.leaveRoomAlertSelectNewOwnerAction, role: .destructive) { [weak self] in
                                                             self?.actionsSubject.send(.transferOwnership(roomIdentifier: roomID))
                                                         })
                        return
                    }
                }
            }
            
            state.bindings.leaveRoomAlertItem = LeaveRoomAlertItem(roomID: roomID, isDM: roomProxy.isDirectOneToOneRoom, state: roomProxy.infoPublisher.value.isPrivate ?? true ? .private : .public)
        }
    }
    
    private func leaveRoom(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(Self.leaveRoomLoadingID)
        }
        userIndicatorController.submitIndicator(UserIndicator(id: Self.leaveRoomLoadingID, type: .modal, title: L10n.commonLeavingRoom, persistent: true))
        
        guard case let .joined(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID),
              case .success = await roomProxy.leaveRoom() else {
            state.bindings.alertInfo = AlertInfo(id: UUID(), title: L10n.errorUnknown)
            return
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: UUID().uuidString,
                                                              type: .toast,
                                                              title: L10n.commonCurrentUserLeftRoom,
                                                              iconName: "checkmark"))
        actionsSubject.send(.roomLeft(roomIdentifier: roomID))
    }
    
    // MARK: Invites
    
    private func acceptInvite(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(roomID)
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: roomID, type: .modal, title: L10n.commonLoading, persistent: true))
        
        //        guard case let .invited(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
        //            displayError()
        //            return
        //        }
        
        switch await userSession.clientProxy.joinRoom(roomID, via: []) {
        case .success:
            actionsSubject.send(.presentRoom(roomIdentifier: roomID))
            //            analyticsService.trackJoinedRoom(isDM: roomProxy.info.isDirect,
            //                                             isSpace: roomProxy.info.isSpace,
            //                                             activeMemberCount: UInt(roomProxy.info.activeMembersCount))
            appSettings.seenInvites.remove(roomID)
        case .failure(let error):
            switch error {
            case .invalidInvite:
                displayError(title: L10n.dialogTitleError, message: L10n.errorInvalidInvite)
            default:
                displayError()
            }
        }
    }
    
    private func finishAcceptInvite(roomProxy: InvitedRoomProxyProtocol) async {
        if roomProxy.info.isSpace {
            let spaceService = userSession.clientProxy.spaceService
            
            switch await spaceService.spaceRoomList(spaceID: roomProxy.id) {
            case .success(let spaceRoomListProxy):
                actionsSubject.send(.presentSpace(spaceRoomListProxy))
            case .failure(let error):
                MXLog.error("Failed to get the space room list after accepting invite: \(error)")
                displayError()
                return
            }
        } else {
            actionsSubject.send(.presentRoom(roomIdentifier: roomProxy.id))
        }
        
        analyticsService.trackJoinedRoom(isDM: roomProxy.info.isDirect,
                                         isSpace: roomProxy.info.isSpace,
                                         activeMemberCount: UInt(roomProxy.info.activeMembersCount))
        appSettings.seenInvites.remove(roomProxy.id)
    }
    
    private func showDeclineInviteConfirmationAlert(roomID: String) async {
        guard let room = state.rooms.first(where: { $0.id == roomID }) else {
            displayError()
            return
        }
        
        let roomPlaceholder = room.isDirect ? (room.inviter?.displayName ?? room.name) : room.name
        let title = room.isDirect ? L10n.screenInvitesDeclineDirectChatTitle : L10n.screenInvitesDeclineChatTitle
        let message = room.isDirect ? L10n.screenInvitesDeclineDirectChatMessage(roomPlaceholder) : L10n.screenInvitesDeclineChatMessage(roomPlaceholder)
        
        if await userSession.clientProxy.isReportRoomSupported, let userID = room.inviter?.id {
            state.bindings.alertInfo = .init(id: UUID(),
                                             title: title,
                                             message: message,
                                             primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                             secondaryButton: .init(title: L10n.actionDeclineAndBlock, role: .destructive) { [weak self] in self?.declineAndBlockInvite(userID: userID, roomID: roomID) },
                                             verticalButtons: [.init(title: L10n.actionDecline) { [weak self] in Task { await self?.declineInvite(roomID: room.id) } }])
        } else {
            state.bindings.alertInfo = .init(id: UUID(),
                                             title: title,
                                             message: message,
                                             primaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil),
                                             secondaryButton: .init(title: L10n.actionDecline, role: .destructive) { [weak self] in Task { await self?.declineInvite(roomID: room.id) } })
        }
    }
    
    private func declineAndBlockInvite(userID: String, roomID: String) {
        actionsSubject.send(.presentDeclineAndBlock(userID: userID, roomID: roomID))
    }
    
    private func declineInvite(roomID: String) async {
        defer {
            userIndicatorController.retractIndicatorWithId(roomID)
        }
        
        userIndicatorController.submitIndicator(UserIndicator(id: roomID, type: .modal, title: L10n.commonLoading, persistent: true))
        
        guard case let .invited(roomProxy) = await userSession.clientProxy.roomForIdentifier(roomID) else {
            displayError()
            return
        }
        
        let result = await roomProxy.rejectInvitation()
        //        let result = await userSession.clientProxy.leaveRoom(roomID)
        
        if case .failure = result {
            displayError()
        } else {
            await notificationManager.removeDeliveredMessageNotifications(for: roomID) // Normally handled by the room flow, but that's never presented in this case.
            appSettings.seenInvites.remove(roomID)
        }
    }
    
    private func displayError(title: String? = nil, message: String? = nil) {
        state.bindings.alertInfo = .init(id: UUID(),
                                         title: title ?? L10n.commonError,
                                         message: message ?? L10n.errorUnknown)
    }
    
    private func loadUserRewards() {
        Task.detached {
            try await Task.sleep(for: .seconds(2))
            _ = await self.userSession.clientProxy.zeroClient.getUserRewards(shouldCheckRewardsIntiamtion: true)
        }
    }
    
    private func dismissNewRewardsIntimation() {
        Task {
            try await Task.sleep(for: .seconds(4))
            state.showNewUserRewardsIntimation = false
        }
    }
    
    private func fetchZeroHomeScreenData() {
        /// This is temp to fix the glass effect not being applied issue, triggering a UI change for a minute to apply effects
        /// https://stackoverflow.com/questions/79739688/liquid-glass-not-appearing-for-the-first-launch-of-the-app
        toggleSyncing()
        
        Task.detached {
            async let checkUser: () = self.userSession.clientProxy.zeroClient.checkAndLinkZeroUser()
            async let channels: () = self.fetchChannels()
//            async let posts: () = fetchPosts()
            _ = await (checkUser, channels)
        }
    }
    
    private func toggleSyncing() {
        AppStateManager.shared.setSyncing(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            AppStateManager.shared.setSyncing(false)
        }
    }
    
    private func checkAndLinkZeroUser() async {
        await userSession.clientProxy.zeroClient.checkAndLinkZeroUser()
    }
    
    private func fetchChannels(isForceRefresh: Bool = false) async {
        state.channelsListMode = .skeletons
        let channelsResult = await userSession.clientProxy.zeroClient.fetchUserZIds()
        switch channelsResult {
        case .success(let zIds):
            if zIds.isEmpty {
                state.channelsListMode = .empty
            } else {
                let mappedChannels = zIds.sorted().map { HomeScreenChannel(channelZId: $0) }
                state.channels = mappedChannels.uniqued(on: \.id)
                state.channelsListMode = .channels
                mapChannelsToRoomInfo()
            }
        case .failure(let error):
            state.channelsListMode = .empty
            MXLog.error("Failed to fetch channels: \(error)")
        }
    }
    
    private func joinZeroChannel(_ channel: HomeScreenChannel) {
        if let channelRoom = channelRoomMap[channel.id] {
            actionsSubject.send(.presentRoom(roomIdentifier: channelRoom.id))
            markChannelRead(channel)
            return
        }
        
        Task {
            let userIndicatorID = UUID().uuidString
            defer {
                userIndicatorController.retractIndicatorWithId(userIndicatorID)
            }
            userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                                  type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                                  title: L10n.commonLoading,
                                                                  persistent: true))
            let roomAliasResult = await userSession.clientProxy.resolveRoomAlias(channel.id)
            switch roomAliasResult {
            case .success(let roomInfo):
                actionsSubject.send(.presentRoom(roomIdentifier: roomInfo.roomId))
                markChannelRead(channel)
                getRoomInfoFromAlias(channel.id)
            case .failure(let error):
                MXLog.error("Failed to resolve room alias: \(channel.id). Error: \(error)")
                let joinChannelResult = await userSession.clientProxy.zeroClient.joinChannel(roomAliasOrId: channel.id)
                switch joinChannelResult {
                case .success(let roomId):
                    actionsSubject.send(.presentRoom(roomIdentifier: roomId))
                    markChannelRead(channel)
                    getRoomInfoFromAlias(channel.id)
                case .failure(let failure):
                    MXLog.error("Failed to join channel: \(failure)")
                    displayError(message: "Failed to join channel. Please try again later.")
                }
            }
        }
    }
    
    private func getRoomInfoFromAlias(_ alias: String) {
        Task {
            if let roomInfo = await userSession.clientProxy.roomInfoForAlias(alias) {
                channelRoomMap[alias] = roomInfo
            }
        }
    }
    
    private func mapChannelsToRoomInfo() {
        Task {
            state.channels = await state.channels.asyncMap { homeChannel in
                var updatedChannel = homeChannel
                if let roomInfo = await self.userSession.clientProxy.roomInfoForAlias(homeChannel.id) {
                    self.channelRoomMap[homeChannel.id] = roomInfo
                    updatedChannel.notificationsCount = roomInfo.unreadMessagesCount
                }
                return updatedChannel
            }
        }
    }
    
    private func markChannelRead(_ channel: HomeScreenChannel) {
        var mChannel = channel
        mChannel.notificationsCount = 0
        if let index = state.channels.firstIndex(where: { $0.id == channel.id }) {
            state.channels[index] = mChannel
        }
    }
    
    private func checkAndUpdateRoomNotificationMode() {
        roomNotificationUpdateMap.forEach { roomId, mode in
            guard let roomSummary = state.rooms.first(where: { $0.roomID == roomId }) else { return }
            var mRoomSummary = roomSummary
            mRoomSummary.badges.isMuteShown = mode == .mute
            if let index = state.rooms.firstIndex(where: { $0.roomID == roomId }) {
                state.rooms[index] = mRoomSummary
            }
        }
        roomNotificationUpdateMap.removeAll()
    }
    
    private func applyCustomFilterToNotificationsList(_ tab: HomeNotificationsTab) {
        let filteredNotificationContent = state.visibleRooms.filter {
            switch $0.type {
            case .placeholder, .knock:
                return false
            default:
                switch tab {
                case .all:
                    return $0.badges.isDotShown && !$0.badges.isMentionShown && !$0.badges.isMuteShown
                case .highlighted:
                    return $0.badges.isMentionShown
                case .muted:
                    return $0.badges.isDotShown && $0.badges.isMuteShown
                }
            }
        }
        state.notificationsContent = filteredNotificationContent
    }
    
    private func extractAllRoomUsers(_ rooms: [RoomSummary]) {
        if !isRoomUsersExtractionInProgress {
            isRoomUsersExtractionInProgress = true
            Task.detached {
                let heroUserIds = rooms.flatMap { $0.heroes.compactMap(\.userID) }
                var userIds = Set(heroUserIds)
                // Add current logged-in user as well
                await userIds.insert(self.userSession.clientProxy.userID)
                
                await self.userSession.clientProxy.zeroClient.zeroProfiles(userIds: userIds)
            }
        }
    }
    
    private func autoJoinInvitedRooms(_ rooms: [RoomSummary]) {
        if !isRoomAutoJoinInProgress {
            isRoomAutoJoinInProgress = true
            Task.detached {
                let roomsToBeJoined = rooms.compactMap { roomSummary in
                    if case .invited = roomSummary.room.membership() {
                        roomSummary.id
                    } else {
                        nil
                    }
                }
                if !roomsToBeJoined.isEmpty {
                    await withTaskGroup(of: Result<Void, ClientProxyError>.self) { group in
                        for roomId in roomsToBeJoined {
                            group.addTask {
                                await self.userSession.clientProxy.joinRoom(roomId, via: [])
                            }
                        }
                        for await item in group {
                            if case .success = item { MXLog.debug("Successfully joined room") }
                            else { MXLog.debug("Failed to join room") }
                        }
                        await MainActor.run { self.isRoomAutoJoinInProgress = false }
                    }
                } else {
                    await MainActor.run { self.isRoomAutoJoinInProgress = false }
                }
            }
        }
    }
    
    private func mapDirectChatUsersProBadgeStatus(_ zeroProfiles: [ZMatrixUser]) {
        guard let roomSummaryProvider else {
            isRoomUsersExtractionInProgress = false
            return
        }
        guard !zeroProfiles.isEmpty else {
            isRoomUsersExtractionInProgress = false
            return
        }
        let currentUserId = userSession.clientProxy.userID
        Task.detached {
            let directChatRooms = roomSummaryProvider.roomListPublisher.value.filter(\.isDirectOneToOneRoom)
            let userStatusMap: [String: Bool] = directChatRooms.reduce(into: [:]) { result, room in
                let directUser = if let hero = room.heroes.first, hero.userID != currentUserId {
                    zeroProfiles.first { $0.matrixId == hero.userID }
                } else {
                    zeroProfiles.first {
                        $0.displayName.caseInsensitiveCompare(room.name) == .orderedSame ||
                        $0.id.rawValue.caseInsensitiveCompare(room.name) == .orderedSame
                    }
                }
                if let user = directUser {
                    result[room.id] = user.subscriptions?.zeroPro ?? false
                }
            }

            await MainActor.run {
                self.isRoomUsersExtractionInProgress = false
                self.state.directRoomsUserStatusMap = userStatusMap
            }
        }
    }
    
    private func loadPublicRoomsNextPage() {
        guard !state.isLoadingPublicRooms else {
            return
        }
        
        Task {
            state.isLoadingPublicRooms = true
            let _ = await roomDirectorySearchProxy.nextPage()
            state.isLoadingPublicRooms = false
        }
    }
    
    // MARK: Zero Protcol Functions
    
    func onRoomNotificationModeUpdated(for roomId: String, mode: RoomNotificationModeProxy) {
        roomNotificationUpdateMap[roomId] = mode
    }
    
    func claimUserRewards() {
        if let walletAddress = state.currentUserZeroProfile?.publicWalletAddress {
            state.claimRewardsState = .claiming
            state.bindings.showEarningsClaimedSheet = true
            state.claimableUserRewards = state.userRewards
            Task {
                let result = await userSession.clientProxy.zeroClient.claimRewards(userWalletAddress: walletAddress)
                switch result {
                case .success(let transactionHash):
                    state.claimRewardsState = .success(transactionHash)
                    loadUserRewards()
                    actionsSubject.send(.refreshWallet)
                case .failure(_):
                    state.claimRewardsState = .failure
                }
            }
        }
    }
}
