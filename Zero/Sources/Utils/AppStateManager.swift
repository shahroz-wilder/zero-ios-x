//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import Combine

/// This AppStateManager is only to toggle `BorderLoadingView` on the main layout in case Server is syncing
@MainActor
final class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    
    @Published var isSyncing: Bool = false
    
    private init() {}
    
    func setSyncing(_ isSyncing: Bool) {
        self.isSyncing = isSyncing
    }
}
