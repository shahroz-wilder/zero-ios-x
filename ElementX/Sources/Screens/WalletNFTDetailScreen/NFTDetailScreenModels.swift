//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import UIKit

struct NFTDetailScreenViewState: BindableState {
    let nft: HomeScreenWalletNFTContent
}

enum NFTDetailScreenViewAction {
    case copyNFTId
    case openNFTTokenLink
}
