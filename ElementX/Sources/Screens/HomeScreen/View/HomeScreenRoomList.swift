//
// Copyright 2023, 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct HomeScreenRoomList: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    var fromChannelsTabs: Bool = false
    
    var body: some View {
        // Hide the room list when the search bar is focused but the query is empty
        // This works hand in hand with the room list service layer filtering and
        // avoids glitches when focusing the search bar
        let _ = ZeroCustomEventService.shared.roomScreenEvent(parameters: [
            "execution": "HomeScreenRoomList",
            "view": "showing rooms list",
            "shouldHideRoomList": context.viewState.shouldHideRoomList.description,
            "fromChannelsTab": fromChannelsTabs.description
        ])
        if !context.viewState.shouldHideRoomList {
            content
        }
    }
    
    @ViewBuilder
    private var content: some View {
        let roomsList: [HomeScreenRoom] = {
            let list = context.viewState.visibleRooms
            if !context.isSearchFieldFocused, context.searchQuery.isEmpty {
                switch context.filtersState.activeZeroFilter {
                case .primaryRooms:
                    return list.filter { $0.isPrimary }
                case .secondaryRooms:
                    return list.filter { $0.isSecondary }
                case .mutedRooms:
                    return list.filter { $0.isMuted }
                case .channels:
                    return list
                }
            } else {
                return list
            }
        }()
        
        let _ = ZeroCustomEventService.shared.roomScreenEvent(parameters: [
            "execution": "HomeScreenRoomList",
            "view": "showing rooms list",
            "roomsListCount": "\(roomsList.count)"
        ])
        
        if fromChannelsTabs, roomsList.isEmpty, !context.isSearchFieldFocused {
            HomeContentEmptyView(message: "No channels")
        } else {
            ForEach(roomsList) { room in
                switch room.type {
                case .placeholder:
                    HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                        .redacted(reason: .placeholder)
                case .invite:
                    HomeScreenInviteCell(room: room, context: context, hideInviteAvatars: context.viewState.hideInviteAvatars)
                case .knock:
                    HomeScreenKnockedCell(room: room, context: context)
                case .room:
                    let isSelected = context.viewState.selectedRoomID == room.id
                    
                    HomeScreenRoomCell(room: room,
                                       isSelected: isSelected,
                                       mediaProvider: context.mediaProvider,
                                       action: context.send,
                                       showProBadge: context.viewState.directRoomsUserStatusMap[room.id] == true)
                    .contextMenu {
                        if room.badges.isDotShown {
                            Button {
                                context.send(viewAction: .markRoomAsRead(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsRead, icon: \.markAsRead)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsUnread(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.screenRoomlistMarkAsUnread, icon: \.markAsUnread)
                            }
                        }
                        
                        if room.isFavourite {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: false))
                            } label: {
                                Label(L10n.commonFavourited, icon: \.favouriteSolid)
                            }
                        } else {
                            Button {
                                context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: true))
                            } label: {
                                Label(L10n.commonFavourite, icon: \.favourite)
                            }
                        }
                        
                        Button {
                            context.send(viewAction: .showRoomDetails(roomIdentifier: room.id))
                        } label: {
                            Label(L10n.commonSettings, icon: \.settings)
                        }
                        
                        if context.viewState.reportRoomEnabled {
                            Button(role: .destructive) {
                                context.send(viewAction: .reportRoom(roomIdentifier: room.id))
                            } label: {
                                Label(L10n.actionReportRoom, icon: \.chatProblem)
                            }
                        }
                        
                        //                        Button(role: .destructive) {
                        //                            context.send(viewAction: .leaveRoom(roomIdentifier: room.id))
                        //                        } label: {
                        //                            Label(L10n.actionLeaveRoom, icon: \.leave)
                        //                        }
                    }
                }
            }
        }
    }
}
