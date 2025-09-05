//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias OtpVerificationScreenViewModelType = StateStoreViewModelV2<OtpVerificationScreenViewState, OtpVerificationScreenViewAction>

class OtpVerificationScreenViewModel: OtpVerificationScreenViewModelType, OtpVerificationScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
        
    private var actionsSubject: PassthroughSubject<OtpVerificationScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<OtpVerificationScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         appSettings: AppSettings,
         userIndicatorController: UserIndicatorControllerProtocol,
         userEmail: String) {
        self.authenticationService = authenticationService
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init(userEmail: userEmail))
    }

    override func process(viewAction: OtpVerificationScreenViewAction) {
        switch viewAction {
        case .verifyOtp:
            verifyOtp()
        case .resendOtp:
            resendOtp()
        }
    }
    
    // MARK: - Private
    
    private func verifyOtp() {
        Task {
            startLoading()
            defer { stopLoading() }
            
            let result = await authenticationService.verifyOtp(email: state.userEmail,
                                                               code: state.bindings.otp,
                                                               initialDeviceName: UIDevice.current.initialDeviceName)
            switch result {
            case .success(let userSession):
                actionsSubject.send(.signedIn(userSession))
            case .failure(let error):
                displayError()
            }
        }
    }
    
    private func resendOtp() {
        Task {
            startLoading()
            defer { stopLoading() }
            
            let result = await authenticationService.requestOtp(email: state.userEmail)
            switch result {
            case .success:
                break
            case .failure(let error):
                displayError()
            }
        }
    }
    
    private let loadingIndicatorID = "\(OtpVerificationScreenViewModel.self)-Loading"
    
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
