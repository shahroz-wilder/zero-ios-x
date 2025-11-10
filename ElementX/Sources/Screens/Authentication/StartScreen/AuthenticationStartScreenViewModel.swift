//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI
import ReownAppKit

typealias AuthenticationStartScreenViewModelType = StateStoreViewModelV2<AuthenticationStartScreenViewState, AuthenticationStartScreenViewAction>

class AuthenticationStartScreenViewModel: AuthenticationStartScreenViewModelType, AuthenticationStartScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let provisioningParameters: AccountProvisioningParameters?
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let socialAuthService: SocialAuthServiceProtocol
    
    private let canReportProblem: Bool
    
    private var actionsSubject: PassthroughSubject<AuthenticationStartScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<AuthenticationStartScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    private var shouldListenToWalletConnectListeners: Bool = false

    init(authenticationService: AuthenticationServiceProtocol,
         provisioningParameters: AccountProvisioningParameters?,
         isBugReportServiceEnabled: Bool,
         appSettings: AppSettings,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.provisioningParameters = provisioningParameters
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController
        canReportProblem = isBugReportServiceEnabled
        
        socialAuthService = SocialAuthService()
        
        let isQRCodeScanningSupported = !ProcessInfo.processInfo.isiOSAppOnMac
        
        let initialViewState = if !appSettings.allowOtherAccountProviders {
            // We don't show the create account button when custom providers are disallowed.
            // The assumption here being that if you're running a custom app, your users will already be created.
            AuthenticationStartScreenViewState(serverName: appSettings.accountProviders.count == 1 ? appSettings.accountProviders[0] : nil,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: isQRCodeScanningSupported,
                                               hideBrandChrome: appSettings.hideBrandChrome)
        } else if let provisioningParameters {
            // We only show the "Sign in to …" button when using a provisioning link.
            AuthenticationStartScreenViewState(serverName: provisioningParameters.accountProvider,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: false,
                                               hideBrandChrome: appSettings.hideBrandChrome)
        } else {
            // The default configuration.
            AuthenticationStartScreenViewState(serverName: nil,
                                               showCreateAccountButton: appSettings.showCreateAccountButton,
                                               showQRCodeLoginButton: isQRCodeScanningSupported,
                                               hideBrandChrome: appSettings.hideBrandChrome)
        }
        
        super.init(initialViewState: initialViewState)
        
        shouldListenToWalletConnectListeners = true
        
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if self?.shouldListenToWalletConnectListeners == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { [weak self] in
                        self?.requestAuthenticationConfirmation()
                    })
                }
            }
            .store(in: &cancellables)
        
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] response in
                if self?.shouldListenToWalletConnectListeners == true {
                    self?.stopLoading()
                    switch response.result {
                    case let .response(value):
                        self?.loginWithWallet(token: value.stringRepresentation.replacingOccurrences(of: "\"", with: ""))
                    case let .error(error):
                        self?.stopLoading()
                        MXLog.error("Session error: \(error)")
                        self?.state.bindings.alertInfo = AlertInfo(id: .genericError)
                    }
                }
            }
            .store(in: &cancellables)
    }

    override func process(viewAction: AuthenticationStartScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
        case .loginWithQR:
            actionsSubject.send(.loginWithQR)
        case .login:
            Task { await login() }
        case .loginWithX:
            loginWithX()
        case .loginWithEpicGames:
            loginWithEpicGames()
        case .register:
            actionsSubject.send(.register)
        case .reportProblem:
            if canReportProblem {
                actionsSubject.send(.reportProblem)
            }
        case .verifyInviteCode(let invite):
            actionsSubject.send(.verifyInviteCode(inviteCode: invite))
        case .openWalletConnectModal:
            presentWalletConnectModal()
        case .createAccount:
            shouldListenToWalletConnectListeners = false
            actionsSubject.send(.createAccount)
        }
    }
    
    // MARK: - Private
    
    private func login() async {
        if let serverName = state.serverName, !authenticationService.isHomeServerConfigured() {
            await configureAccountProvider(serverName, loginHint: provisioningParameters?.loginHint)
        } else {
            actionsSubject.send(.login) // No need to configure anything here, continue the flow.
        }
    }
    
    private func configureAccountProvider(_ accountProvider: String, loginHint: String? = nil) async {
        startLoading()
        defer { stopLoading() }
        
        guard case .success = await authenticationService.configure(for: accountProvider, flow: .login) else {
            // As the server was provisioned, we don't worry about the specifics and show a generic error to the user.
            displayError()
            return
        }
        
        guard authenticationService.homeserver.value.loginMode.supportsOIDCFlow else {
            actionsSubject.send(.loginDirectlyWithPassword(loginHint: loginHint))
            return
        }
        
        guard let window = state.window else {
            displayError()
            return
        }
        
        switch await authenticationService.urlForOIDCLogin(loginHint: loginHint) {
        case .success(let oidcData):
            actionsSubject.send(.loginDirectlyWithOIDC(data: oidcData, window: window))
        case .failure:
            displayError()
        }
    }
    
    private func presentWalletConnectModal() {
        /// Show user alert to navigate back to app manually due to walletConnect automatic redirection issues
        state.bindings.alertInfo = AlertInfo(id: .caution,
                                             title: "Wallet Connect",
                                             message: "Please return to the ZERO app after connecting your wallet and signing the message.",
                                             primaryButton: .init(title: L10n.actionConfirm) {
            WalletConnectService.shared.presentWalletConnectModal()
        },
                                             secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
    }
    
    private func loginWithWallet(token: String) {
        guard let authChallenge = state.authenticationChallenge else {
            stopLoading()
            return displayError()
        }
        startLoading()
        Task {
            defer { stopLoading() }
            switch await authenticationService.requestAuthenticationAuthorization(authChallenge,
                                                                                  walletSignature: token,
                                                                                  initialDeviceName: UIDevice.current.initialDeviceName,
                                                                                  deviceID: nil) {
            case .success(let userSession):
                actionsSubject.send(.signedIn(userSession))
            case .failure(let error):
                switch error {
                case .userNotFound:
                    state.bindings.alertInfo = AlertInfo(id: .userNotFound,
                                                         message: "This wallet is not associated with any account. Please try logging in with a different wallet.")
                default:
                    displayError()
                }
            }
        }
    }
    
    private func loginWithX() {
        socialAuthService.loginWithX { result in
            switch result {
            case .success(let token):
                self.startLoading()
                Task {
                    switch await self.authenticationService.loginWithSocialAuth(
                        token: token,
                        initialDeviceName: UIDevice.current.initialDeviceName,
                        deviceID: nil
                    ) {
                    case .success(let userSession):
                        self.stopLoading()
                        self.actionsSubject.send(.signedIn(userSession))
                    case .failure(_):
                        self.stopLoading()
                        self.displayError()
                    }
                }
            case .failure(_):
                self.displayError()
            }
        }
    }
    
    private func loginWithEpicGames() {
        socialAuthService.loginWithEpicGames { result in
            switch result {
            case .success(let token):
                self.startLoading()
                Task {
                    switch await self.authenticationService.loginWithSocialAuth(
                        token: token,
                        initialDeviceName: UIDevice.current.initialDeviceName,
                        deviceID: nil
                    ) {
                    case .success(let userSession):
                        self.stopLoading()
                        self.actionsSubject.send(.signedIn(userSession))
                    case .failure(_):
                        self.stopLoading()
                        self.displayError()
                    }
                }
            case .failure(_):
                self.displayError()
            }
        }
    }
    
    private func requestAuthenticationConfirmation() {
        guard let connectedWalletAddress = WalletConnectService.shared.connectedWalletAddress() else {
            return displayError()
        }
        Task {
            startLoading()
            let result = await authenticationService.requestAuthenticationConfirmation(connectedWalletAddress)
            switch result {
            case .success(let authChallenge):
                self.state.authenticationChallenge = authChallenge
                WalletConnectService.shared.requestPersonalSign(signingMessage: authChallenge.message)
            case .failure(_):
                stopLoading()
                displayError()
            }
        }
    }
    
    private let loadingIndicatorID = "\(AuthenticationStartScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .genericError)
    }
}
