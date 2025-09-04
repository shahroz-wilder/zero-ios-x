//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

// MARK: - Coordinator

enum OtpVerificationScreenCoordinatorAction {
    case signedIn(UserSessionProtocol)
}

enum OtpVerificationScreenViewModelAction {
    case signedIn(UserSessionProtocol)
}

struct OtpVerificationScreenViewState: BindableState {
    var userEmail: String
    var bindings = OtpVerificationScreenViewStateBindings()
}

struct OtpVerificationScreenViewStateBindings {
    var otp: String = ""
    var alertInfo: AlertInfo<OtpVerificationScreenAlertType>?
}

enum OtpVerificationScreenAlertType {
    case genericError
}

enum OtpVerificationScreenViewAction {
}
