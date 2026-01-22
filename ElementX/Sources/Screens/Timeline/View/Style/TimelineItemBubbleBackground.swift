//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

extension View {
    /// - Parameters:
    ///   - isOutgoing: rounds the corners according to the side it shows on, defaults to true
    ///   - insets: defaults to what we use for file timeline items, text uses custom values
    ///   - color: self explanatory, defaults to subtle secondary
    ///   - isThreaded: if true, adds a left accent border in thread accent color
    func bubbleBackground(isOutgoing: Bool = true,
                          insets: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12),
                          color: Color? = .compound.bgSubtleSecondary,
                          isThreaded: Bool = false) -> some View {
        modifier(TimelineItemBubbleBackgroundModifier(isOutgoing: isOutgoing,
                                                      insets: insets,
                                                      color: color,
                                                      isThreaded: isThreaded))
    }
}

private struct TimelineItemBubbleBackgroundModifier: ViewModifier {
    @Environment(\.timelineGroupStyle) private var timelineGroupStyle

    let isOutgoing: Bool
    let insets: EdgeInsets
    var color: Color?
    let isThreaded: Bool

    private let threadBorderWidth: CGFloat = 3

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .background(color)
            .cornerRadius(12, corners: roundedCorners)
            .overlay(alignment: .leading) {
                if isThreaded {
                    threadAccentBorder
                }
            }
    }

    @ViewBuilder
    private var threadAccentBorder: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: topLeadingCornerRadius,
            bottomLeadingRadius: bottomLeadingCornerRadius,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        )
        .fill(Color.zero.threadAccentColor)
        .frame(width: threadBorderWidth)
    }

    private var topLeadingCornerRadius: CGFloat {
        switch timelineGroupStyle {
        case .single, .first:
            return 12
        case .middle, .last:
            return isOutgoing ? 12 : 0
        }
    }

    private var bottomLeadingCornerRadius: CGFloat {
        switch timelineGroupStyle {
        case .single, .last:
            return 12
        case .first, .middle:
            return isOutgoing ? 12 : 0
        }
    }

    private var roundedCorners: UIRectCorner {
        switch timelineGroupStyle {
        case .single:
            return .allCorners
        case .first:
            if isOutgoing {
                return [.topLeft, .topRight, .bottomLeft]
            } else {
                return [.topLeft, .topRight, .bottomRight]
            }
        case .middle:
            return isOutgoing ? [.topLeft, .bottomLeft] : [.topRight, .bottomRight]
        case .last:
            if isOutgoing {
                return [.topLeft, .bottomLeft, .bottomRight]
            } else {
                return [.topRight, .bottomLeft, .bottomRight]
            }
        }
    }
}
