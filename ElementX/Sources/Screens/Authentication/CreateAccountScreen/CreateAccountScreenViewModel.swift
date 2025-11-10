//
// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Combine
import ReownAppKit
import SwiftUI

typealias CreateAccountScreenViewModelType = StateStoreViewModel<CreateAccountScreenViewState, CreateAccountScreenViewAction>

class CreateAccountScreenViewModel: CreateAccountScreenViewModelType, CreateAccountScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var actionsSubject: PassthroughSubject<CreateAccountScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<CreateAccountScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(authenticationService: AuthenticationServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         inviteCode: String) {
        self.authenticationService = authenticationService
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init())
        
        AppKit.instance.sessionSettlePublisher
            .receive(on: DispatchQueue.main)
            .sink { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    WalletConnectService.shared.requestPersonalSign()
                })
            }
            .store(in: &cancellables)
        
        AppKit.instance.sessionResponsePublisher
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] response in
                switch response.result {
                case let .response(value):
                    self?.createUserAccountWithWallet(token: value.stringRepresentation.replacingOccurrences(of: "\"", with: ""))
                case let .error(error):
                    MXLog.error("Session error: \(error)")
                    self?.state.bindings.alertInfo = AlertInfo(id: .unknown)
                }
            }
            .store(in: &cancellables)
    }
    
    override func process(viewAction: CreateAccountScreenViewAction) {
        switch viewAction {
        case .openLoginScreen:
            actionsSubject.send(.openLoginScreen)
        case .createAccount:
            createUserAccount()
        case .openWalletConnectModal:
            presentWalletConnectModal()
        case .verifyInviteCode(let inviteCode):
            verifyInviteCode(inviteCode: inviteCode)
        }
    }
    
    private func createUserAccount() {
        guard !state.bindings.inviteCode.isEmpty else {
            return
        }
        
        startLoading()
        Task {
            switch await authenticationService.createUserAccount(email: state.bindings.emailAddress,
                                                                 password: state.bindings.password,
                                                                 inviteCode: state.bindings.inviteCode) {
            case .success(let userSession):
                stopLoading()
                actionsSubject.send(.accountCreated(userSession: userSession))
            case .failure(let error):
                stopLoading()
                handleError(error: error)
            }
        }
    }
    
    private func verifyInviteCode(inviteCode: String) {
        Task {
            startLoading()
            switch await authenticationService.verifyCreateAccountInviteCode(inviteCode: inviteCode) {
            case .success:
                stopLoading()
                withAnimation(.easeInOut(duration: 0.5)) {
                    state.bindings.inviteCode = inviteCode
                }
            case .failure(let error):
                stopLoading()
                let message = switch error {
                case .invalidInviteCode:
                    "Invite code not found. Please check your invite message."
                default:
                    L10n.errorUnknown
                }
                userIndicatorController.alertInfo = AlertInfo(id: UUID(),
                                                              title: L10n.commonError,
                                                              message: message)
            }
        }
    }
    
    private static let loadingIndicatorIdentifier = "\(CreateAccountScreenCoordinatorAction.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
    
    private func handleError(error: AuthenticationServiceError) {
        switch error {
        case .userAlreadyExists:
            state.bindings.alertInfo = AlertInfo(id: .unknown, title: L10n.commonError, message: "This email is already associated with a ZERO account")
        case .walletAlreadyExists:
            state.bindings.alertInfo = AlertInfo(id: .unknown, title: L10n.commonError, message: "This wallet is already associated with a ZERO account")
        default:
            state.bindings.alertInfo = AlertInfo(id: .unknown)
        }
    }
    
    private func presentWalletConnectModal() {
        /// Show user alert to navigate back to app manually due to walletConnect automatic redirection issues
        state.bindings.alertInfo = AlertInfo(id: .alert(""),
                                             title: "Wallet Connect",
                                             message: "Please return to the ZERO app after connecting your wallet and signing the message.",
                                             primaryButton: .init(title: L10n.actionConfirm) {
            WalletConnectService.shared.presentWalletConnectModal()
        },
                                             secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
    }
    
    private func createUserAccountWithWallet(token: String) {
        guard !state.bindings.inviteCode.isEmpty else {
            return
        }
        
        startLoading()
        Task {
            switch await authenticationService.createUserAccountWithWeb3(web3Token: token, inviteCode: state.bindings.inviteCode) {
            case .success(let userSession):
                stopLoading()
                actionsSubject.send(.accountCreated(userSession: userSession))
            case .failure(let error):
                stopLoading()
                handleError(error: error)
            }
        }
    }
}
