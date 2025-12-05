//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

protocol ZeroClientProxyDelegate: AnyObject {
    func setUserAvatar(media: MediaInfo) async -> Result<Void, ClientProxyError>
    func setUserInfo(_ name: String, primaryZId: String?) async -> Result<Void, ClientProxyError>
    func createDirectRoom(with userID: String, expectedRoomName: String?) async -> Result<String, ClientProxyError>
    func joinRoom(_ roomID: String, via: [String]) async -> Result<Void, ClientProxyError>
}
