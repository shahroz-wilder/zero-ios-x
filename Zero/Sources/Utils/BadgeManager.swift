//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import UIKit
import UserNotifications

final class BadgeManager {
    static let shared = BadgeManager()
    
    private init() {}
    
    /// Update badge count to match your app's unread count
    func updateBadge(unreadCount: Int) {
        UIApplication.shared.applicationIconBadgeNumber = unreadCount
    }
    
    /// Clear both badge and delivered notifications
    func clearBadgeAndNotifications() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
