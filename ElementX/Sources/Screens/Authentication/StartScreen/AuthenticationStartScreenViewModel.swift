//
// Copyright 2022-2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
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
    
    private let canReportProblem: Bool
    
    private var actionsSubject: PassthroughSubject<AuthenticationStartScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<AuthenticationStartScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

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
        
        let isQRCodeScanningSupported = !ProcessInfo.processInfo.isiOSAppOnMac
        
        let initialViewState = if !appSettings.allowOtherAccountProviders {
            // We don't show the create account button when custom providers are disallowed.
            // The assumption here being that if you're running a custom app, your users will already be created.
            AuthenticationStartScreenViewState(serverName: appSettings.accountProviders.count == 1 ? appSettings.accountProviders[0] : nil,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: isQRCodeScanningSupported)
        } else if let provisioningParameters {
            // We only show the "Sign in to …" button when using a provisioning link.
            AuthenticationStartScreenViewState(serverName: provisioningParameters.accountProvider,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: false)
        } else {
            // The default configuration.
            AuthenticationStartScreenViewState(serverName: nil,
                                               showCreateAccountButton: appSettings.showCreateAccountButton,
                                               showQRCodeLoginButton: isQRCodeScanningSupported)
        }
        
        super.init(initialViewState: initialViewState)
        
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startLoading()
            }
            .store(in: &cancellables)
        
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.stopLoading()
                switch response.result {
                case let .response(value):
                    self?.loginWithWallet(token: value.stringRepresentation.replacingOccurrences(of: "\"", with: ""))
                case let .error(error):
                    MXLog.error("Session error: \(error)")
                    self?.state.bindings.alertInfo = AlertInfo(id: .genericError)
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
            actionsSubject.send(.createAccount)
        }
    }
    
    // MARK: - Private
    
    private func login() async {
        if let serverName = state.serverName {
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
        WalletConnectService.shared.presentWalletConnectModal()
    }
    
    private func loginWithWallet(token: String) {
        startLoading()
        
        Task {
            defer { stopLoading() }
            switch await authenticationService.loginWithWeb3(web3Token: token,
                                                             initialDeviceName: UIDevice.current.initialDeviceName,
                                                             deviceID: nil) {
            case .success(let userSession):
                actionsSubject.send(.signedIn(userSession))
            case .failure(let error):
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
