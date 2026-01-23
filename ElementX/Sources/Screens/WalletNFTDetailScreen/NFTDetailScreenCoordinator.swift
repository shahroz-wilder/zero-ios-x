//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct NFTDetailScreenCoordinatorParameters {
    let nft: HomeScreenWalletNFTContent
}

final class NFTDetailScreenCoordinator: CoordinatorProtocol {
    private var viewModel: NFTDetailScreenViewModel
    
    init(parameters: NFTDetailScreenCoordinatorParameters) {
        viewModel = NFTDetailScreenViewModel(nft: parameters.nft)
    }
            
    func toPresentable() -> AnyView {
        AnyView(NFTDetailScreen(context: viewModel.context))
    }
}
