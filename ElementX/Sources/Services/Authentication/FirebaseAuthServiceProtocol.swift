//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import FirebaseAuth
import Foundation

protocol FirebaseAuthServiceProtocol {
    func loginWithX() async throws -> String
    func signOut() throws
    func getCurrentUser() -> FirebaseAuth.User?
}
