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
}
