//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

public struct MatrixBackupVersion: Codable {
    public let algorithm: String
    public let count: UInt16
    public let version: String
}
