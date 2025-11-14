//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine

@MainActor
protocol HomeWalletViewModelProtocol {
    var actions: AnyPublisher<HomeWalletViewModelAction, Never> { get }
    
    var context: HomeWalletViewModelType.Context { get }
}
