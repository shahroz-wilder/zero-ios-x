//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

import Compound

struct ThreadDecorator: View {
    var body: some View {
        Label {
            Text(L10n.commonThread)
                .foregroundColor(.zero.threadAccentColor)
                .font(.zero.bodyXS)
        } icon: {
            CompoundIcon(\.threads, size: .xSmall, relativeTo: .compound.bodyXS)
                .foregroundColor(.zero.threadAccentColor)
        }
        .labelStyle(.custom(spacing: 4))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.zero.threadChipBackground)
        .cornerRadius(4)
    }
}

struct ThreadDecorator_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        ThreadDecorator()
    }
}
