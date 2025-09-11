//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import FirebaseAuth
import Foundation
import UIKit

final class FirebaseAuthenticationService: FirebaseAuthServiceProtocol {
    
    private let xAuthProvider = OAuthProvider(providerID: "twitter.com")
    
    func loginWithX() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            xAuthProvider.customParameters = ["lang": "en"]
            xAuthProvider.getCredentialWith(nil) { credential, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let credential = credential else {
                    continuation.resume(throwing: NSError(
                        domain: "FirebaseAuth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Missing auth credentials."]
                    ))
                    return
                }
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard
                        let oauthCred = authResult?.credential as? OAuthCredential,
                        let accessToken = oauthCred.accessToken
                    else {
                        continuation.resume(throwing: NSError(
                            domain: "FirebaseAuth",
                            code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Missing X access token."]
                        ))
                        return
                    }
                    
                    continuation.resume(returning: accessToken)
                }
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getCurrentUser() -> FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
}
