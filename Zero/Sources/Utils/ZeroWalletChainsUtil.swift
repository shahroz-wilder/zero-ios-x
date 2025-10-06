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
    
    private init() {
        // ZChains
        let zChain = WalletChain(id: ZeroChainId.z, name: "ZChain", logo: Asset.Images.iconChainZ)
        let zZephyrChain = WalletChain(id: ZeroChainId.z_zephyr, name: "ZChain", logo: Asset.Images.iconChainZ)
        
        // Ethereum Chains
        let ethereumChain = WalletChain(id: ZeroChainId.ethereum, name: "Ethereurm", logo: Asset.Images.iconChainEthereum)
        let ethereumSepoliaChain = WalletChain(id: ZeroChainId.ethereum_sepolia, name: "Ethereurm", logo: Asset.Images.iconChainEthereum)
        
        // Avax Chains
        let avaxChain = WalletChain(id: ZeroChainId.avax, name: "AvaxChain", logo: Asset.Images.iconChainAvax)
        let avaxFujiChain = WalletChain(id: ZeroChainId.avax_fuji, name: "AvaxChain", logo: Asset.Images.iconChainAvax)
        
        // Polygon Chains
        let polygonChain = WalletChain(id: ZeroChainId.polygon, name: "Polygon", logo: Asset.Images.iconChainPolygon)
        let polygonAmoyChain = WalletChain(id: ZeroChainId.polygon_amoy, name: "Polygon", logo: Asset.Images.iconChainPolygon)
        
        // Base Chains
        let baseChain = WalletChain(id: ZeroChainId.base, name: "BaseChain", logo: Asset.Images.iconChainBase)
        let baseSepoliaChain = WalletChain(id: ZeroChainId.base_sepolia, name: "BaseChain", logo: Asset.Images.iconChainBase)
        
        chains = [
            zChain, zZephyrChain,
            ethereumChain, ethereumSepoliaChain,
            avaxChain, avaxFujiChain,
            polygonChain, polygonAmoyChain,
            baseChain, baseSepoliaChain
        ]
    }
    
    var zChainId: UInt64 {
        ZeroChainId.z.rawValue
    }
    
    var avaxChainId: UInt64 {
        ZeroChainId.avax.rawValue
    }
    
    func isZChain(_ id: UInt64) -> Bool {
        id == zChainId
    }
    
    func isAvaxChain(_ id: UInt64) -> Bool {
        id == avaxChainId
    }
    
    func getChain(_ chainId: UInt64) -> WalletChain? {
        chains.first { $0.id.rawValue == chainId }
    }
}

enum ZeroChainId: UInt64 {
    case z = 9369
    case z_zephyr = 1417429182
    case ethereum = 1
    case ethereum_sepolia = 11155111
    case avax = 43114
    case avax_fuji = 43113
    case polygon = 137
    case polygon_amoy = 80002
    case base = 8453
    case base_sepolia = 84532
}

struct WalletChain: Identifiable {
    let id: ZeroChainId
    let name: String
    let logo: ImageAsset
}
