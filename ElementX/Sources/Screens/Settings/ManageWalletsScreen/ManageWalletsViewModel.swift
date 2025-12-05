//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import ReownAppKit
import SwiftUI

typealias ManageWalletsViewModelType = StateStoreViewModel<ManageWalletsViewState, ManageWalletsViewAction>

class ManageWalletsViewModel: ManageWalletsViewModelType, ManageWalletsViewModelProtocol {
    
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var enableLoggingIn: Bool = false
    
    init(userSession: UserSessionProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        
        self.clientProxy = userSession.clientProxy
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init(bindings: .init()))
        
        fetchUserWallets()
        
        userSession.clientProxy.zeroClient.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.state.userZeroWalletAddress = currentUser.publicWalletAddress
            }
            .store(in: &cancellables)
        
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
            .sink { [weak self] response in
                switch response.result {
                case let .response(value):
                    let token = value.stringRepresentation.replacingOccurrences(of: "\"", with: "")
                    self?.addUserWallet(token)
                case let .error(error):
                    self?.displayError(message: error.localizedDescription)
                }
            }
            .store(in: &cancellables)
    }
    
    override func process(viewAction: ManageWalletsViewAction) {
        switch viewAction {
        case .onWalletSelected(let wallet):
            openWalletAddress(wallet)
        case .linkWallet:
            linkWallet()
        case .addWalletToZero(let enableLoggingIn):
            startAddWalletFlow(enableLoggingIn)
        case .removeWallet(let wallet):
            deleteWallet(wallet: wallet)
        }
    }
    
    private func fetchUserWallets() {
        Task {
            showLoadingIndicator()
            defer { hideLoadingIndicator() }
            
            let result = await clientProxy.zeroClient.fetchUserWallets()
            switch result {
            case .success(let wallets):
                state.wallets = wallets.map(ZeroWallet.init)
                state.connectedWalletAddress = state.firstSelfCustodyWallet?.address
                clientProxy.zeroClient.fetchZCurrentUser()
            case .failure(let error):
                displayError(message: error.localizedDescription)
            }
        }
    }
    
    private func openWalletAddress(_ wallet: ZeroWallet) {
        if let url = wallet.zcanLiveUrl {
            UIApplication.shared.open(url)
        }
    }
    
    private func linkWallet() {
        if let connectedWalletAddress = WalletConnectService.shared.connectedWalletAddress() {
            state.connectedWalletAddress = connectedWalletAddress
            state.bindings.showLinkWalletAddressDialog = true
        } else {
            /// Show user alert to navigate back to app manually due to walletConnect automatic redirection issues
            state.bindings.alertInfo = AlertInfo(id: UUID(),
                                                 title: "Wallet Connect",
                                                 message: "Please return to the ZERO app after connecting your wallet and signing the message.",
                                                 primaryButton: .init(title: L10n.actionConfirm) {
                WalletConnectService.shared.presentWalletConnectModal()
            },
                                                 secondaryButton: .init(title: L10n.actionCancel, role: .cancel, action: nil))
        }
    }
    
    private func startAddWalletFlow(_ enableLoggingIn: Bool = false) {
        self.enableLoggingIn = enableLoggingIn
        WalletConnectService.shared.requestPersonalSign()
    }
    
    private func addUserWallet(_ token: String) {
        Task {
            showLoadingIndicator()
            defer { hideLoadingIndicator() }
            
            let result = await clientProxy.zeroClient.addWallet(canAuthenticate: enableLoggingIn, web3Token: token)
            switch result {
            case .success:
                fetchUserWallets()
            case .failure(let error):
                displayError(message: error.localizedDescription)
            }
        }
    }
        
    private func deleteWallet(wallet: ZeroWallet) {
        Task {
            showLoadingIndicator()
            defer { hideLoadingIndicator() }
            
            let result = await clientProxy.zeroClient.deleteWallet(walletId: wallet.id)
            switch result {
            case .success:
                fetchUserWallets()
            case .failure(let error):
                parseRemoveWalletError(error)
            }
        }
    }
    
    private func parseRemoveWalletError(_ error: ZeroClientProxyError) {
        if case .zeroError(let error) = error {
            if let apiError = (error as? APIErrorResponse) {
                let message = switch apiError.code {
                case "CANNOT_REMOVE_ONLY_AUTH_METHOD":
                    "This wallet is the only login method on this account. Add another login method (e.g., email or a different wallet), in order to remove it."
                default:
                    "Failed to remove wallet."
                }
                displayError(message: message)
            } else {
                displayError(message: "Failed to remove wallet.")
            }
        } else {
            displayError(message: "Failed to remove wallet.")
        }
    }
    
    private func displayError(message: String) {
        state.bindings.alertInfo = AlertInfo(id: UUID(),
                                             title: L10n.commonError,
                                             message: message)
    }
    
    // MARK: Loading indicator
    
    private static let loadingIndicatorIdentifier = "\(ManageWalletsViewModel.self)-Loading"
    
    private func showLoadingIndicator(delay: Duration? = nil) {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.commonLoading,
                                                              persistent: true),
                                                delay: delay)
    }
    
    private func hideLoadingIndicator() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
    }
}
