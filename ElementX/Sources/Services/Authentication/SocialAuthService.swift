//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import AuthenticationServices
import Foundation

final class SocialAuthService: NSObject, SocialAuthServiceProtocol {
    private var authSession: ASWebAuthenticationSession?
    
    private let redirectURI: String = "com.zero.ios.messenger://oauth-callback"
    
    func loginWithX(completion: @escaping (Result<String, any Error>) -> Void) {
        guard let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "https://zosapi.zero.tech/api/oauth/x/initiate?returnUrl=\(encodedRedirectURI)")
        else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        login(authURL: authURL, completion: completion)
    }
    
    func loginWithEpicGames(completion: @escaping (Result<String, any Error>) -> Void) {
        guard let encodedRedirectURI = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "https://zosapi.zero.tech/api/oauth/epic-games/initiate?returnUrl=\(encodedRedirectURI)")
        else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        login(authURL: authURL, completion: completion)
    }
    
    private func login(authURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: URL(string: redirectURI)?.scheme
        ) { callbackURL, sessionError in
            if let sessionError = sessionError {
                DispatchQueue.main.async {
                    completion(.failure(sessionError))
                }
                return
            }

            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let token = components.queryItems?.first(where: { $0.name == "sessionEstablishmentToken" })?.value
            else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "No auth token in callback URL", code: -2, userInfo: nil)))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.success(token))
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.start()
    }
}

extension SocialAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
