//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct OtpVerificationScreenParameters {
    let authenticationService: AuthenticationServiceProtocol
    let appSettings: AppSettings
    let userIndicatorController: UserIndicatorControllerProtocol
    let userEmail: String
}

final class OtpVerificationScreenCoordinator: CoordinatorProtocol {
    private var viewModel: OtpVerificationScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<OtpVerificationScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<OtpVerificationScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: OtpVerificationScreenParameters) {
        viewModel = OtpVerificationScreenViewModel(authenticationService: parameters.authenticationService,
                                                   appSettings: parameters.appSettings,
                                                   userIndicatorController: parameters.userIndicatorController,
                                                   userEmail: parameters.userEmail)
    }
    
    // MARK: - Public
    
    func start() {
        viewModel.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .signedIn(let userSession):
                    actionsSubject.send(.signedIn(userSession))
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(OtpVerificationView(context: viewModel.context))
    }
}
