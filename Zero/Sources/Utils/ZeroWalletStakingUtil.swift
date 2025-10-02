//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

class ZeroWalletStakingUtil {
    static let shared = ZeroWalletStakingUtil()
    
    // Meow Pool
    private var meowPool: WalletStakePool {
        .init(id: "0xfbDC0647F0652dB9eC56c7f09B7dD3192324AD6a",
              address: "0xfbDC0647F0652dB9eC56c7f09B7dD3192324AD6a",
              name: "MEOW Pool",
              image: "https://zos.zero.tech/tokens/meow.png",
              chainId: .z)
    }
    
    // Meow Avax Pool
    private var meowAvaxPool: WalletStakePool {
        .init(id: "0xD7A1583286cEB8ce8F3C1a6d50C5eBDB1Cd83358",
              address: "0xD7A1583286cEB8ce8F3C1a6d50C5eBDB1Cd83358",
              name: "MEOW Pool",
              image: "https://zos.zero.tech/tokens/meow-avax.png",
              chainId: .avax)
    }
    
    var stakePools: [WalletStakePool] = []
    
    private init() {
        stakePools = [meowPool, meowAvaxPool]
    }
}

struct WalletStakePool: Identifiable {
    let id: String
    let address: String
    let name: String
    let image: String?
    let chainId: ZeroChainId
}
