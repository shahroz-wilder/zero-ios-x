//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import UIKit

struct ZeroProSubcriptionScreenViewState: BindableState {
    var currentUser: ZCurrentUser?
    var isZeroProSubscriber: Bool = false
    var canPurchaseSubscription: Bool = false
    /// Indicates if the current user owns the StoreKit subscription (matched by appAccountToken)
    var isSubscriptionOwnedByCurrentUser: Bool = false

    var subscriptionExpiration: Date?

    var bindings: ZeroProSubcriptionScreenBindings
}

struct ZeroProSubcriptionScreenBindings {
    
}

enum ZeroProSubcriptionScreenViewAction {
    case purchaseSubscriptionTapped
    case restorePurchasesTapped
}
