//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias ForgotPasswordScreenViewModelType = StateStoreViewModelV2<ForgotPasswordScreenViewState, ForgotPasswordScreenViewAction>

class ForgotPasswordScreenViewModel: ForgotPasswordScreenViewModelType, ForgotPasswordScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
        
    private var actionsSubject: PassthroughSubject<ForgotPasswordScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<ForgotPasswordScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         appSettings: AppSettings,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init())
    }

    override func process(viewAction: ForgotPasswordScreenViewAction) {
        switch viewAction {
        case .login:
            actionsSubject.send(.login)
        case .resetPassword:
            requestResetPassword()
        }
    }
    
    // MARK: - Private
    
    private func requestResetPassword() {
        Task {
            startLoading()
            defer { stopLoading() }
            let result = await authenticationService.requestResetPassword(email: state.bindings.email)
            switch result {
            case .success:
                state.bindings.state = .completed
            case .failure:
                displayError()
            }
        }
    }
    
    private let loadingIndicatorID = "\(ForgotPasswordScreenViewModel.self)-Loading"
    
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
