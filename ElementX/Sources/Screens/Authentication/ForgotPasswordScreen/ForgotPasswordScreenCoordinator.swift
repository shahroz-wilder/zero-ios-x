//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct ForgotPasswordScreenParameters {
    let authenticationService: AuthenticationServiceProtocol
    let appSettings: AppSettings
    let userIndicatorController: UserIndicatorControllerProtocol
}

final class ForgotPasswordScreenCoordinator: CoordinatorProtocol {
    private var viewModel: ForgotPasswordScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<ForgotPasswordScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<ForgotPasswordScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: ForgotPasswordScreenParameters) {
        viewModel = ForgotPasswordScreenViewModel(authenticationService: parameters.authenticationService,
                                                  appSettings: parameters.appSettings,
                                                  userIndicatorController: parameters.userIndicatorController)
    }
    
    // MARK: - Public
    
    func start() {
        viewModel.actions
            .sink { [weak self] action in
                guard let self else { return }
                
                switch action {
                case .login:
                    actionsSubject.send(.login)
                }
            }
            .store(in: &cancellables)
    }
    
    func toPresentable() -> AnyView {
        AnyView(ForgotPasswordView(context: viewModel.context))
    }
}
