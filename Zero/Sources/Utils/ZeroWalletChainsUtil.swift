//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

class ZeroWalletChainsUtil {
    static let shared = ZeroWalletChainsUtil()
    
    private var chains: [WalletChain] = []
    
    let Z_CHAIN_ID: UInt64 = 9369
    private let Z_CHAIN_ID_ZEPHYR: UInt64 = 9369
    let AVAX_CHAIN_ID: UInt64 = 43114
    
    private init() {
        // ZChain
        let zChainId = (ZeroContants.appServer is ProdServer) ? Z_CHAIN_ID : Z_CHAIN_ID_ZEPHYR
        let zChain = WalletChain(id: zChainId, name: "ZChain", logo: Asset.Images.iconZChain)
        // Avax
        let avaxChain = WalletChain(id: AVAX_CHAIN_ID, name: "AvaxChain", logo: Asset.Images.iconAvaxChain)
        
        chains = [zChain, avaxChain]
    }
    
    var zChain: WalletChain {
        chains.first { $0.id == Z_CHAIN_ID }!
    }
    
    var avaxChain: WalletChain {
        chains.first { $0.id == AVAX_CHAIN_ID }!
    }
    
    func isZChain(_ id: UInt64) -> Bool {
        let zChainId = (ZeroContants.appServer is ProdServer) ? Z_CHAIN_ID : Z_CHAIN_ID_ZEPHYR
        return id == zChainId
    }
    
    func isAvaxChain(_ id: UInt64) -> Bool {
        return id == AVAX_CHAIN_ID
    }
}

struct WalletChain: Identifiable {
    let id: UInt64
    let name: String
    let logo: ImageAsset
}
