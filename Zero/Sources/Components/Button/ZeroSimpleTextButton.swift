//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ZeroSimpleTextButton : View {
    let title: String
    let onClick: () -> Void
    var enabled: Bool = true
    
    var body: some View {
        Button(action: onClick) {
            Text(title)
                .font(.compound.bodyMDSemibold)
                .foregroundColor(enabled ? .zero.bgAccentRest : .compound.textDisabled)
        }
        .disabled(!enabled)
    }
}
