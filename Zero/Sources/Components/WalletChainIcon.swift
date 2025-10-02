//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct WalletChainIcon: View {
    let chainIcon: ImageAsset
    var size: CGFloat = 16
    
    var body: some View {
        Image(asset: chainIcon)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
