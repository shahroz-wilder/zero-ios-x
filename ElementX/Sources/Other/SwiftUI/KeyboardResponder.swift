//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import Combine

/// Manages keyboard height changes with smooth animations
final class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            .compactMap { notification -> (CGFloat, TimeInterval, UInt)? in
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                      let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
                    return nil
                }
                return (keyboardFrame.height, duration, curve)
            }
            .sink { [weak self] height, duration, curve in
//                let animation = Animation.timingCurve(duration)
//                withAnimation(animation) {
                // Use faster animation - 0.25 seconds instead of system duration
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.currentHeight = (height - 24) // - 24 due to significant space under chat composer
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification -> (TimeInterval, UInt)? in
                guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                      let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
                    return nil
                }
                return (duration, curve)
            }
            .sink { [weak self] duration, curve in
//                let animation = Animation.timingCurve(duration)
//                withAnimation(animation) {
                // Use faster animation - 0.25 seconds instead of system duration
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.currentHeight = 0
                }
            }
            .store(in: &cancellables)
    }
}

extension Animation {
    static func timingCurve(_ duration: TimeInterval) -> Animation {
        .easeOut(duration: duration)
    }
}
