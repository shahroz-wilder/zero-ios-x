//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

enum HomeTab: CaseIterable {
    case chat
    case channels
    case feed
    case notifications
    case wallet
}

struct HomeScreenBottomBar : View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var selectedTab: Binding<HomeTab>
    let onTabSelected: (HomeTab) -> Void
    
    var body: some View {
        HomeScreenBottomBarView(selectedTab: selectedTab,
                                onTabSelected: { tab in
            switch tab {
            case .chat:
                context.filtersState.activateZeroFilter(.primaryRooms)
            case .channels:
                context.filtersState.activateZeroFilter(.secondaryRooms)
            default:
                break
            }
            onTabSelected(tab)
        },
                                hasNewNotifications: context.viewState.hasNewNotifications,
                                isHomeSearchActive: context.isSearchFieldFocused)
    }
}

private struct HomeScreenBottomBarView : View {
    var selectedTab: Binding<HomeTab>
    let onTabSelected: (HomeTab) -> Void
    let hasNewNotifications: Bool
    let isHomeSearchActive: Bool
    
    private let homeTabs: [(title: String, icon: ImageAsset, iconSelected: ImageAsset, tab: HomeTab)] = [
        ("Chat", Asset.Images.homeTabChatIcon, Asset.Images.homeTabChatFilledIcon, .chat),
        ("Channels", Asset.Images.homeTabExplorerIcon, Asset.Images.homeTabExplorerIcon, .channels),
        ("Feed", Asset.Images.homeTabFeedIcon, Asset.Images.homeTabFeedIcon, .feed),
        ("Notifications", Asset.Images.homeTabNotificationIcon, Asset.Images.homeTabNotificationFilledIcon, .notifications),
        ("Wallet", Asset.Images.homeTabWalletIcon, Asset.Images.homeTabWalletFilledIcon, .wallet)
    ]
    
    var body: some View {
        Group {
            if isHomeSearchActive {
                EmptyView()
            } else {
                customTabView
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }
    
    private var customTabView: some View {
        ZStack {
            tabBar
                .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [.clear, .clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var tabBar: some View {
        HStack {
            ForEach(homeTabs, id: \.tab) { tabInfo in
                tabButton(for: tabInfo)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .shadow(radius: 6)
        )
    }
    
    private func tabButton(for tabInfo: (title: String, icon: ImageAsset, iconSelected: ImageAsset, tab: HomeTab)) -> some View {
        let isTabSelected = selectedTab.wrappedValue == tabInfo.tab
        return Button {
            onTabSelected(tabInfo.tab)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(asset: isTabSelected ? tabInfo.iconSelected : tabInfo.icon)
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(isTabSelected ? .zero.bgAccentRest : .compound.iconSecondary)
                
                if hasNewNotifications && tabInfo.tab == .notifications {
                    Circle()
                        .fill(.zero.bgAccentRest)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}
