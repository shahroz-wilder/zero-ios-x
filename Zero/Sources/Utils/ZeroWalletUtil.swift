//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

class ZeroWalletUtil {
    static let shared = ZeroWalletUtil()
    
    private init() { }
    
    private enum WalletType: String {
        case ethereum
        case bitcoinLegacy
        case bitcoinP2SH
        case bitcoinBech32
        case solana
        case unknown
    }
    
    private let patterns: [WalletType: String] = [
        // Ethereum (0x + 40 hex chars)
        .ethereum: #"^0x[a-fA-F0-9]{40}$"#,
        
        // Bitcoin Legacy (starts with 1, 26–35 chars, Base58)
        .bitcoinLegacy: #"^1[a-km-zA-HJ-NP-Z1-9]{25,34}$"#,
        
        // Bitcoin P2SH (starts with 3, 26–35 chars, Base58)
        .bitcoinP2SH: #"^3[a-km-zA-HJ-NP-Z1-9]{25,34}$"#,
        
        // Bitcoin Bech32 (starts with bc1, length 14–74)
        .bitcoinBech32: #"^bc1[ac-hj-np-z0-9]{11,71}$"#,
        
        // Solana (Base58, 32–44 chars)
        .solana: #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#
    ]
    
    func meowPrice(tokenAmount: String?, refPrice: ZeroCurrency?) -> Double {
        meowPrice(tokenAmount: Double(tokenAmount ?? "0") ?? 0, refPrice: refPrice)
    }
    
    func meowPrice(tokenAmount: Double, refPrice: ZeroCurrency?) -> Double {
        if let currency = refPrice, let price = currency.price, tokenAmount > 0 {
            return tokenAmount * price
        } else {
            return 0
        }
    }
    
    func tokenPrice(tokenAmount: String?, price: Double?) -> Double {
        tokenPrice(tokenAmount: Double(tokenAmount ?? "0") ?? 0, tokenPrice: price)
    }
    
    func tokenPrice(tokenAmount: Double, tokenPrice: Double?) -> Double {
        if let price = tokenPrice, tokenAmount > 0 {
            return tokenAmount * price
        } else {
            return 0
        }
    }
    
    func meowPriceFormatted(tokenAmount: String?, refPrice: ZeroCurrency?) -> String {
        return meowPrice(tokenAmount: tokenAmount, refPrice: refPrice).formatToThousandSeparatedString()
    }
    
    func tokenPriceFormatted(tokenAmount: String?, tPrice: Double?) -> String {
        return tokenPrice(tokenAmount: tokenAmount, price: tPrice).formatToThousandSeparatedString()
    }
    
    func isValidEthereumAddress(_ address: String) -> Bool {
        if let pattern = patterns[.ethereum] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(address.startIndex..<address.endIndex, in: address)
            return regex.firstMatch(in: address, options: [], range: range) != nil
        } else {
            return false
        }
    }
}
