//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SentrySwiftUI
import SwiftUI

struct HomeScreen: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    @State private var selectedHomeTab: HomeTab = .chat
    
    @State private var selectedChildChannelsTab: HomeChannelsTab = .all
    @State private var selectedChildFeedsTab: HomePostsTab = .following
    @State private var selectedChildNotificationsTab: HomeNotificationsTab = .all
    
    @State private var showBackToTop = false
    @State private var hideNavigationBar = false
    @State private var roomSearchTriggered = false
    
    var body: some View {
        ZStack {
            mainContent
        }
        // Animation to slide content up/down whenever tabs get visible
        .animation(.easeInOut(duration: 0.25), value: selectedHomeTab)
        // To disable the home screen animation jerk whenever the search closes
        .animation(.none, value: context.isSearchFieldPresented)
        .alert(item: $context.alertInfo)
        .alert(item: $context.leaveRoomAlertItem,
               actions: leaveRoomAlertActions,
               message: leaveRoomAlertMessage)
        .toolbar { toolbar }
        .navigationBarHidden(hideNavigationBar)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .track(screen: .Home)
        .sentryTrace("\(Self.self)")
        .quickLookPreview($context.mediaPreviewItem)
        .safeAreaInset(edge: .top) {
            topTabView
                .transition(.asymmetric(insertion: .move(edge: .top), removal: .move(edge: .top)))
                .opacity(hideNavigationBar ? 0 : 1)
                .opacity(context.isSearchFieldPresented ? 0 : 1)
        }
        .overlay(alignment: .top) {
            backToTopButton
                .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .top) {
            topBarGradientOverlay
                .opacity(hideNavigationBar ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: hideNavigationBar)
        }
        .overlay(alignment: .bottom) {
            HomeScreenBottomBar(
                context: context,
                selectedTab: $selectedHomeTab,
                onTabSelected: {
                    homeTab in self.selectedHomeTab = homeTab
                })
        }
        .overlay(alignment: .bottomTrailing) {
            if !context.isSearchFieldFocused {
                if let action = floatingButtonAction {
                    FloatingActionButton(onTap: action)
                        .padding(.bottom, 70)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            HomeUserRewardsTooltip(context: context)
                .offset(x: 18, y: 90)
                .ignoresSafeArea()
                .opacity(context.viewState.showNewUserRewardsIntimation ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: context.viewState.showNewUserRewardsIntimation)
        }
        .sheet(isPresented: $context.showEarningsClaimedSheet) {
            ClaimedEarningsSheetContent(context: context)
        }
        .sheet(isPresented: $context.showStakePoolSheet) {
            StakePoolSheetContent(context: context)
        }
        .sheet(isPresented: $roomSearchTriggered) {
            SearchRoomScreen(context: context)
        }
        .onReceive(
            scrollViewAdapter.isAtTopEdge.removeDuplicates()
        ) { isAtTop in
            guard showBackToTop != isAtTop else { return }
            
            // Use a task to debounce updates
            Task { @MainActor in
                showBackToTop = isAtTop
            }
        }
        .onReceive(
            scrollViewAdapter.scrollDirection.removeDuplicates()
        ) { direction in
            let shouldHideNavBar = scrollViewAdapter.isAtTopEdge.value && direction == .down
            
            guard shouldHideNavBar != hideNavigationBar else { return }
            
            // Use a task to debounce updates
            Task { @MainActor in
                hideNavigationBar = shouldHideNavBar
            }
        }
        .onChange(of: context.viewState.securityBannerMode) { _, newValue in
            switch newValue {
            case .show(let state):
                if state == .recoveryOutOfSync {
                    DispatchQueue.main
                        .asyncAfter(deadline: .now() + 2, execute: {
                            context.send(viewAction: .setupRecovery)
                        })
                }
            default:
                break
            }
        }
        .onChange(of: selectedHomeTab) { _, newTab in
            // Reset other tabs to initial position
            selectedChildChannelsTab = .all
            selectedChildFeedsTab = .following
            selectedChildNotificationsTab = .all
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                showBackToTop = false
                hideNavigationBar = false
                context.send(viewAction: .onHomeTabChanged)
            }
        }
        .onChange(of: roomSearchTriggered) { _, value in
            if !value {
                context.isSearchFieldPresented = false
                context.searchQuery = ""
            }
        }
        .onChange(of: context.isSearchFieldFocused) { _, value in
            if !value {
                roomSearchTriggered = false
            }
        }
    }
    
    @ViewBuilder
    private var topTabView: some View {
        Group {
            switch selectedHomeTab {
            case .channels:
                SimpleFixedTabButtonsView(tabs: HomeChannelsTab.allCases,
                                          selectedTab: selectedChildChannelsTab,
                                          tabTitle: { tab in
                    switch tab {
                    case .all: return "Channels"
                    case .gated: return "Gated"
                    case .muted: return "Muted"
                    }
                },
                                          onTabSelected: { tab in
                    selectedChildChannelsTab = tab
                })
            case .feed:
                SimpleFixedTabButtonsView(
                    tabs: HomePostsTab.allCases,
                    selectedTab: selectedChildFeedsTab,
                    tabTitle: { tab in
                        switch tab {
                        case .following: return "Following"
                        case .all: return "Everything"
                        }
                    },
                    onTabSelected: { tab in
                        selectedChildFeedsTab = tab
                        context
                            .send(
                                viewAction:
                                        .forceRefreshAllPosts(
                                            followingPostsOnly: tab == .following
                                        )
                            )
                    })
            case .notifications:
                SimpleFixedTabButtonsView(tabs: HomeNotificationsTab.allCases,
                                          selectedTab: selectedChildNotificationsTab,
                                          tabTitle: { tab in
                    switch tab {
                    case .highlighted: return "Highlights"
                    case .muted: return "Muted"
                    case .all: return "All"
                    }
                },
                                          onTabSelected: { tab in
                    selectedChildNotificationsTab = tab
                })
            default:
                EmptyView()
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .top) {
            /// Chats Content
            HomeChatContent(context: context,
                            scrollViewAdapter: scrollViewAdapter,
                            shouldAttachScrollAdapter: selectedHomeTab == .chat,
                            isSearchableContent: false)
            .opacity(selectedHomeTab == .chat ? 1 : 0)
            
            /// Channels Content
            HomeChannelsContent(context: context,
                                scrollViewAdapter: scrollViewAdapter,
                                selectedChannelsTab: selectedChildChannelsTab,
                                shouldAttachScrollAdapter: selectedHomeTab == .channels)
            .opacity(selectedHomeTab == .channels ? 1 : 0)
            
            /// Posts Content
            HomePostsContent(context: context,
                             scrollViewAdapter: scrollViewAdapter,
                             shouldAttachScrollAdapter: selectedHomeTab == .feed,
                             selectedFeedTab: selectedChildFeedsTab)
            .opacity(selectedHomeTab == .feed ? 1 : 0)
            
            /// Notifications Content
            HomeNotificationsContent(context: context,
                                     scrollViewAdapter: scrollViewAdapter,
                                     shouldAttachScrollAdapter: selectedHomeTab == .notifications,
                                     selectedNotificationsTab: selectedChildNotificationsTab)
            .opacity(selectedHomeTab == .notifications ? 1 : 0)
            
            /// Wallet Content
            HomeWalletContent(context: context)
                .opacity(selectedHomeTab == .wallet ? 1 : 0)
        }
    }
    
    // MARK: - Private
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        //        if #available(iOS 26.0, *) {
        //            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        //        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            settingsButton
        }
        .backportSharedBackgroundVisibility(.hidden)
        
        ToolbarItem(placement: .principal) {
            Image(asset: Asset.Images.zeroWordmark)
        }
        .backportSharedBackgroundVisibility(.hidden)
        
        if selectedHomeTab == HomeTab.feed {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    context.send(viewAction: .searchUser)
                } label: {
                    CompoundIcon(\.search)
                        .tint(.compound.iconSecondary)
                }
            }
        }
        
        if selectedHomeTab == HomeTab.chat || selectedHomeTab == HomeTab.channels {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    roomSearchTriggered = true
                } label: {
                    CompoundIcon(\.search)
                        .tint(.compound.iconSecondary)
                }
            }
        }
        
        ToolbarItem(placement: .primaryAction) {
            userProfileButton
        }
    }
    
    private var settingsButton: some View {
        Button {
            context.send(viewAction: .showSettings)
        } label: {
            ZStack {
                if context.viewState.showNewUserRewardsIntimation {
                    ZStack(alignment: .center) {
                        Circle()
                            .stroke(
                                Color.zero.bgAccentRest.opacity(0.5),
                                lineWidth: 1
                            )
                            .frame(width: 38, height: 38)
                        Circle().stroke(Color.zero.bgAccentRest, lineWidth: 1)
                            .frame(width: 35, height: 35)
                    }
                    .task {
                        context.send(viewAction: .rewardsIntimated)
                    }
                }
                
                LoadableAvatarImage(url: context.viewState.userAvatarURL,
                                    name: context.viewState.userDisplayName,
                                    contentID: context.viewState.userID,
                                    avatarSize: .user(on: .chats),
                                    mediaProvider: context.mediaProvider,
                                    onTap: { _ in
                    context.send(viewAction: .showSettings)
                })
                .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
                .clipShape(.circle)
                .overlayBadge(
                    10,
                    isBadged: context.viewState.requiresExtraAccountSetup
                )
                .compositingGroup()
            }
        }
        .accessibilityLabel(L10n.commonSettings)
    }
    
    @ViewBuilder
    private var userProfileButton: some View {
        Button {
            context.send(viewAction: .openUserProfile)
        } label: {
            Image(asset: Asset.Images.homeTabProfileIcon)
                .tint(.compound.iconSecondary)
        }
        .accessibilityLabel("action_user_profile")
        .accessibilityIdentifier("action_user_profile")
    }
    
    @ViewBuilder
    private var backToTopButton: some View {
        Button(action: {
            scrollViewAdapter.scrollToTop(addTabBarPadding: showsTopTab)
        }) {
            HStack {
                Text("Back to Top")
                    .font(.zero.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.compound.textSecondary)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.compound.bgCanvasDefault)
            .clipShape(RoundedRectangle(cornerRadius: 32))
        }
        .frame(maxWidth: .infinity)
        // Smooth fade + slide animation
        .opacity(showBackToTop ? 1 : 0)
        .offset(y: showBackToTop ? 110 : -40)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8),
            value: showBackToTop
        )
        .animation(.easeInOut(duration: 0.25), value: showBackToTop)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    @ViewBuilder
    private var topBarGradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [.black, .clear, .clear]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 200)
        .ignoresSafeArea(edges: .top)
        .transition(.opacity)
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func leaveRoomAlertActions(_ item: LeaveRoomAlertItem) -> some View {
        Button(item.cancelTitle, role: .cancel) { }
        Button(item.confirmationTitle, role: .destructive) {
            context
                .send(
                    viewAction: .confirmLeaveRoom(roomIdentifier: item.roomID)
                )
        }
    }
    
    private func leaveRoomAlertMessage(_ item: LeaveRoomAlertItem) -> some View {
        Text(item.subtitle)
    }
    
    private var floatingButtonAction: (() -> Void)? {
        switch selectedHomeTab {
        case .chat where context.viewState.roomListMode != .skeletons:
            return { context.send(viewAction: .startChat) }
        case .feed where context.viewState.postListMode != .skeletons:
            return { context.send(viewAction: .newFeed) }
        default:
            return nil
        }
    }
    
    private var showsTopTab: Bool {
        switch selectedHomeTab {
        case .channels, .feed, .notifications:
            return true
        default:
            return false
        }
    }
}

// MARK: - Previews

struct HomeScreen_Previews: PreviewProvider, TestablePreview {
    static let loadingViewModel = viewModel(.skeletons)
    static let emptyViewModel = viewModel(.empty)
    static let loadedViewModel = viewModel(.rooms)
    
    static var previews: some View {
        NavigationStack {
            HomeScreen(context: loadingViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .skeletons
        })
        .previewDisplayName("Loading")
        
        NavigationStack {
            HomeScreen(context: emptyViewModel.context)
        }
        .snapshotPreferences(expect: emptyViewModel.context.$viewState.map { state in
            state.roomListMode == .empty
        })
        .previewDisplayName("Empty")
        
        NavigationStack {
            HomeScreen(context: loadedViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms
        })
        .previewDisplayName("Loaded")
    }
    
    static func viewModel(_ mode: HomeScreenRoomListMode) -> HomeScreenViewModel {
        let userID = "@alice:example.com"
        
        let roomSummaryProviderState: RoomSummaryProviderMockConfigurationState = switch mode {
        case .skeletons:
                .loading
        case .empty:
                .loaded([])
        case .rooms:
                .loaded(.mockRooms)
        }
        
        let clientProxy = ClientProxyMock(
            .init(
                userID: userID,
                roomSummaryProvider: RoomSummaryProviderMock(
                    .init(state: roomSummaryProviderState)
                )
            )
        )
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        return HomeScreenViewModel(
            userSession: userSession,
            selectedRoomPublisher: CurrentValueSubject<String?,
            Never>(
                nil
            )
            .asCurrentValuePublisher(),
            appSettings: ServiceLocator.shared.settings,
            analyticsService: ServiceLocator.shared.analytics,
            notificationManager: NotificationManagerMock(),
            userIndicatorController: ServiceLocator.shared.userIndicatorController
        )
    }
}
