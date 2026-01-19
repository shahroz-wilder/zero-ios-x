//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SwiftUI

struct RoomHeaderView: View {
    let roomName: String
    let roomSubtitle: String?
    let roomAvatar: RoomAvatar
    let showProSubscriptionBadge: Bool
    let isRoomDirect: Bool
    var dmRecipientVerificationState: UserIdentityVerificationState?
    
    let mediaProvider: MediaProviderProtocol?
    
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                // On iOS 26+ we use the toolbarRole(.editor) to leading align.
                content
            }
            .backportButtonStyleGlass()
        } else {
            // On iOS 18 and lower, the editor role causes an animation glitch with the back button whenever
            // you push a screen whilst the large title is visible on the room screen.
            content
                // So take up as much space as possible, with a leading alignment for use in the default principal toolbar position
                .frame(idealWidth: .greatestFiniteMagnitude, maxWidth: .infinity, alignment: .leading)
                // Using a button stops it from getting truncated in the navigation bar
                .contentShape(.rect)
                .onTapGesture(perform: action)
        }
    }
    
    private var content: some View {
        HStack(spacing: 8) {
            avatarImage
                .accessibilityHidden(true)
            HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(roomName)
                        .lineLimit(1)
                        .font(.zero.bodyMDSemibold)
                        .accessibilityIdentifier(A11yIdentifiers.roomScreen.name)
                    
                    if showProSubscriptionBadge {
                        CompoundIcon(\.verified, size: .xSmall, relativeTo: .zero.bodyMDSemibold)
                            .foregroundStyle(.zero.bgAccentRest)
                            .padding(.horizontal, 4)
                    }
                }
                if isRoomDirect {
                    Text(roomSubtitle ?? "")
                        .lineLimit(1)
                        .padding(.vertical, 1)
                        .font(.zero.bodySMSemibold)
                        .foregroundStyle(.compound.textSecondary)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: roomSubtitle)
                }
            }
                if let dmRecipientVerificationState {
                    VerificationBadge(verificationState: dmRecipientVerificationState)
                }
            }
        }
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        RoomAvatarImage(avatar: roomAvatar,
                        avatarSize: .room(on: .timeline),
                        mediaProvider: mediaProvider)
            .accessibilityIdentifier(A11yIdentifiers.roomScreen.avatar)
    }
}

extension RoomHeaderView {
    static var toolbarRole: ToolbarRole {
        if #available(iOS 26.0, *) {
            .editor
        } else {
            .automatic
        }
    }
}

struct RoomHeaderView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            makeHeader(avatarURL: nil, verificationState: .notVerified)
            makeHeader(avatarURL: .mockMXCAvatar, verificationState: .notVerified)
            makeHeader(avatarURL: .mockMXCAvatar, verificationState: .verified)
            makeHeader(avatarURL: .mockMXCAvatar, verificationState: .verificationViolation)
            makeHeader(avatarURL: .mockMXCAvatar,
                       roomSubtitle: "Subtitle",
                       verificationState: .verified)
        }
        .previewLayout(.sizeThatFits)
    }
    
    static func makeHeader(avatarURL: URL?,
                           roomSubtitle: String? = nil,
                           verificationState: UserIdentityVerificationState) -> some View {
        RoomHeaderView(roomName: "Some Room name",
                       roomSubtitle: nil,
                       roomAvatar: .room(id: "1",
                                         name: "Some Room Name",
                                         avatarURL: avatarURL),
                       showProSubscriptionBadge: false,
                       isRoomDirect: false,
                       dmRecipientVerificationState: verificationState,
                       mediaProvider: MediaProviderMock(configuration: .init())) { }
            .padding()
    }
}
