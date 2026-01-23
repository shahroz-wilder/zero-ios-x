//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias NFTDetailScreenViewModelType = StateStoreViewModel<NFTDetailScreenViewState, NFTDetailScreenViewAction>

class NFTDetailScreenViewModel: NFTDetailScreenViewModelType, NFTDetailScreenViewModelProtocol {
    
    init(nft: HomeScreenWalletNFTContent) {
        super.init(
            initialViewState: .init(nft: nft)
        )
    }
    
    override func process(viewAction: NFTDetailScreenViewAction) {
        switch viewAction {
        case .copyNFTId:
            copyNFTId(state.nft)
        case .openNFTTokenLink:
            openNFTTransaction(state.nft)
        }
    }
    
    private func copyNFTId(_ nft: HomeScreenWalletNFTContent) {
        UIPasteboard.general.string = nft.id
    }
    
    private func openNFTTransaction(_ nft: HomeScreenWalletNFTContent) {
        guard let tokenUrl = nft.getTokenLink() else { return }
        UIApplication.shared.open(tokenUrl)
    }
}
