//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct ZAvaxTokenPrice: Codable {
    let usd: Double
    let marketCap: Double
    let volume24h: Double
    let change24h: Double
    let lastUpdatedAt: Int
}
