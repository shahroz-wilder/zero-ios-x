import Alamofire
import Foundation

protocol ZeroAuthApiProtocol {
    func login(email: String, password: String) async throws -> Result<ZMatrixSession, Error>
    
    func loginSSO(email: String, password: String) async throws -> Result<ZSSOToken, Error>
    
    func fetchSSOToken() async throws -> Result<ZSSOToken, Error>
    
    func loginWithWeb3(web3Token: String) async throws -> Result<ZSSOToken, Error>
    
    func linkMatrixUserToZero(matrixUserId: String) async throws -> Result<Void, Error>
    
    func requestResetPassword(email: String) async throws -> Result<Void, Error>
    
    func requestOtp(email: String) async throws -> Result<Void, Error>
    
    func verifyOtp(email: String, otp: String) async throws -> Result<ZSSOToken, Error>
    
    func zeroSocialLogin(token: String) async throws -> Result<ZSSOToken, Error>
    
    func requestAuthenticationChallenge(userWalletAddress: String) async throws -> Result<ZAuthenticationChallenge, Error>
    
    func requestAuthenticationAuthorization(challenge: ZAuthenticationChallenge, walletSignature: String) async throws -> Result<ZSSOToken, Error>
}

class ZeroAuthApi: ZeroAuthApiProtocol {
    private let appSettings: AppSettings
    
    init(appSettings: AppSettings) {
        self.appSettings = appSettings
    }
    
    // MARK: - Public
    
    func login(email: String, password: String) async throws -> Result<ZMatrixSession, any Error> {
        let parameters: Parameters = [
            "email": email,
            "password": password
        ]
        // login user
        let authResult: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.loginEndPoint, method: .post, parameters: parameters)
        switch authResult {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                // fetch matrix session
                let sessionResult: Result<ZMatrixSession, Error> = try await fetchMatrixSession(ssoToken: ssoToken.token)
                switch sessionResult {
                case .success(let matrixSession):
                    return .success(matrixSession)
                case .failure(let error):
                    return .failure(error)
                }
            case .failure(let error):
                return .failure(error)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func loginSSO(email: String, password: String) async throws -> Result<ZSSOToken, any Error> {
        let parameters: Parameters = [
            "email": email,
            "password": password
        ]
        // login user
        let authResult: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.loginEndPoint, method: .post, parameters: parameters)
        switch authResult {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                return .success(ssoToken)
            case .failure(let error):
                return .failure(error)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func fetchSSOToken() async throws -> (Result<ZSSOToken, Error>) {
        try await APIManager.shared.authorisedRequest(AuthEndPoints.ssoTokenEndPoint, method: .get, appSettings: appSettings)
    }
    
    func loginWithWeb3(web3Token: String) async throws -> Result<ZSSOToken, any Error> {
        let headers: HTTPHeaders = [
            AuthConstants.web3AuthHeaderKey : "\(AuthConstants.web3AuthTokenPrefix) \(web3Token)"
        ]
        // login user
        let authResult: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.nonceOrAuthoriseEndpoint, method: .post, headers: headers)
        switch authResult {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                return .success(ssoToken)
            case .failure(let error):
                return .failure(error)
            }
            
        case .failure(let error):
            if error.asAFError?.isResponseSerializationError == true {
                // This is the case we get NONCE token in response Showing user needs to sign-up
                return .failure(APIErrorResponse(code: "USER_NOT_FOUND", message: "user not found."))
            } else {
                return .failure(error)
            }
        }
    }
    
    func linkMatrixUserToZero(matrixUserId: String) async throws -> Result<Void, any Error> {
        let request = ZLinkMatrixUser(matrixUserId: matrixUserId)
        let result: Result<Void, Error> = try await APIManager.shared.authorisedRequest(AuthEndPoints.linkMatrixUserEndpoint,
                                                                                        method: .post,
                                                                                        appSettings: appSettings,
                                                                                        parameters: request.toDictionary())
        return result
    }
    
    func zeroSocialLogin(token: String) async throws -> Result<ZSSOToken, any Error> {
        let headers: HTTPHeaders = [
            AuthConstants.web3AuthHeaderKey : "\(AuthConstants.socialAuthTokenPrefix) \(token)"
        ]
        // login user
        let authResult: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.zeroSocialLogin, method: .post, headers: headers)
        switch authResult {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                return .success(ssoToken)
            case .failure(let error):
                return .failure(error)
            }
            
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Private
    
    private func fetchMatrixSession(ssoToken: String) async throws -> (Result<ZMatrixSession, Error>) {
        let homeAddress = ZeroContants.appServer.matrixHomeServerUrl
        let url = "\(homeAddress)/\(AuthEndPoints.matrixSessionEndPoint)"
        var host = ""
        if let range = homeAddress.range(of: "https://") {
            host = String(homeAddress[range.upperBound...])
        } else {
            host = homeAddress
        }
        let parameters: Parameters = [
            "token": ssoToken,
            "type": AuthConstants.ssoTokenType
        ]
        let headers: HTTPHeaders = [
            "Host": host,
            "Origin": AuthConstants.origin
        ]
        return try await APIManager.shared.request(url, method: .post, parameters: parameters, headers: headers)
    }
    
    func requestResetPassword(email: String) async throws -> Result<Void, any Error> {
        let parameters: [String: Any] = ["email": email]
        let result: Result<Void, Error> = try await APIManager.shared.request(AuthEndPoints.requestResetPasswordEndPoint,
                                                                                        method: .post,
                                                                                        parameters: parameters)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func requestOtp(email: String) async throws -> Result<Void, any Error> {
        let parameters: [String: Any] = ["email": email]
        let result: Result<Void, Error> = try await APIManager.shared.request(AuthEndPoints.requestOtpEndPoint,
                                                                                        method: .post,
                                                                                        parameters: parameters)
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func verifyOtp(email: String, otp: String) async throws -> Result<ZSSOToken, any Error> {
        let parameters: [String: Any] = ["email": email, "code": otp]
        let result: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.verifyOtpEndPoint,
                                                                                        method: .post,
                                                                                        parameters: parameters)
        switch result {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                return .success(ssoToken)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func requestAuthenticationChallenge(userWalletAddress: String) async throws -> Result<ZAuthenticationChallenge, any Error> {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return .failure(AuthenticationError.missingBundleIdentifier)
        }
        let parameters: [String: Any] = [
            "address": userWalletAddress,
            "domain": bundleIdentifier
        ]
        let result: Result<ZAuthenticationChallenge, Error> = try await APIManager.shared.request(AuthEndPoints.authenticationChallengeEndPoint,
                                                                                                  method: .get,
                                                                                                  parameters: parameters,
                                                                                                  encoding: URLEncoding.queryString)
        switch result {
        case .success(let challenge):
            return .success(challenge)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func requestAuthenticationAuthorization(challenge: ZAuthenticationChallenge, walletSignature: String) async throws -> Result<ZSSOToken, any Error> {
        let parameters: [String: Any] = [
            "message": challenge.message,
            "signature": walletSignature
        ]
        let result: Result<ZSessionDataResponse, Error> = try await APIManager.shared.request(AuthEndPoints.authenticationAuthorizationEndPoint,
                                                                                              method: .post,
                                                                                              parameters: parameters)
        switch result {
        case .success(let sessionData):
            // save Access Token
            appSettings.zeroAccessToken = sessionData.accessToken
            // fetch SSO Token
            let ssoResult: Result<ZSSOToken, Error> = try await fetchSSOToken()
            switch ssoResult {
            case .success(let ssoToken):
                return .success(ssoToken)
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Constants
    
    private enum AuthEndPoints {
        private static let hostURL = ZeroContants.appServer.zeroRootUrl
        
        static let loginEndPoint = "\(hostURL)api/v2/accounts/login"
        static let ssoTokenEndPoint = "\(hostURL)accounts/ssoToken"
        static let matrixSessionEndPoint = "_matrix/client/r0/login"
        
        static let nonceOrAuthoriseEndpoint = "\(hostURL)authentication/nonceOrAuthorize"
        
        static let linkMatrixUserEndpoint = "\(hostURL)matrix/link-zero-user"
        
        static let requestResetPasswordEndPoint = "\(hostURL)api/v2/accounts/request-password-reset"
        static let requestOtpEndPoint = "\(hostURL)api/otp/request"
        static let verifyOtpEndPoint = "\(hostURL)api/otp/verify"
        
        static let zeroSocialLogin = "\(hostURL)api/oauth/establish-session"
        
        static let authenticationChallengeEndPoint = "\(hostURL)api/v2/authentication/challenge"
        static let authenticationAuthorizationEndPoint = "\(hostURL)api/v2/authentication/authorize"
    }
    
    private enum AuthConstants {
        static let ssoTokenType = "org.matrix.login.jwt"
        static let origin = "https://zos.zero.tech"
        
        static let web3AuthHeaderKey = "Authorization"
        static let web3AuthTokenPrefix = "Web3"
        static let socialAuthTokenPrefix = "Bearer"
    }
    
    private enum AuthenticationError: Error {
        case missingBundleIdentifier
    }
}
