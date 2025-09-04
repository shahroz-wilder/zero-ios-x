//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

// MARK: - Coordinator

enum ForgotPasswordRequestState {
    case completed
    case notCompleted
}

enum ForgotPasswordScreenCoordinatorAction {
    case login
}

enum ForgotPasswordScreenViewModelAction: Equatable {
    case login
}

struct ForgotPasswordScreenViewState: BindableState {
    var bindings = ForgotPasswordScreenViewStateBindings()
    
    var hasValidEmail: Bool {
        !bindings.email.isEmpty
    }
}

struct ForgotPasswordScreenViewStateBindings {
    /// The email input by the user.
    var email = ""
    var state = ForgotPasswordRequestState.notCompleted
    var alertInfo: AlertInfo<ForgotPasswordScreenAlertType>?
}

enum ForgotPasswordScreenAlertType {
    case genericError
}

enum ForgotPasswordScreenViewAction {
    case login
    case resetPassword
}
