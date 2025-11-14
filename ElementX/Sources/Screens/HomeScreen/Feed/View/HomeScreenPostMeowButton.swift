//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import Combine

struct HomeScreenPostMeowButton: View {
    let count: String
    let highlightColor: Bool
    let isEnabled: Bool
    let onMeowTouchEnded: (Int) -> Void

    @State private var totalCounter: Int = 0
    @State private var holdCounter: Int = 0
    @State private var isTouching: Bool = false
    @State private var timer: Timer? = nil
    @State private var debounceCancellable: AnyCancellable? = nil

    private let MAX_MEOW_LIMIT = 50
    private let debounceDelay: TimeInterval = 1.0

    var body: some View {
        HStack(alignment: .center) {
            HomeScreenPostFooterItem(
                icon: Asset.Images.postMeowIcon,
                count: count,
                highlightColor: highlightColor,
                action: {}
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled else { return }

                        if !isTouching {
                            // Start long press accumulation
                            isTouching = true
                            startIncrementing()
                        }
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }

                        stopIncrementing()
                        isTouching = false
                        scheduleDebouncedSend()
                    }
            )

            // Shows live hold count while pressed
            if isTouching && holdCounter > 0 {
                Text("+\(totalCounter)")
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.zero.bgAccentRest)
            }
        }
    }

    private func startIncrementing() {
        stopIncrementing()

        holdCounter = min(holdCounter + 1, MAX_MEOW_LIMIT)
        totalCounter = min(totalCounter + 1, MAX_MEOW_LIMIT)
        restartDebounce()

        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            guard holdCounter < MAX_MEOW_LIMIT else { return }
            holdCounter = min(holdCounter + 1, MAX_MEOW_LIMIT)
            totalCounter = min(totalCounter + 1, MAX_MEOW_LIMIT)
            restartDebounce()
        }
    }

    private func stopIncrementing() {
        timer?.invalidate()
        timer = nil
        holdCounter = 0
    }

    private func restartDebounce() {
        debounceCancellable?.cancel()

        debounceCancellable = Just(())
            .delay(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .sink { _ in
                guard totalCounter > 0 else { return }
                onMeowTouchEnded(totalCounter)
                totalCounter = 0
            }
    }

    private func scheduleDebouncedSend() {
        // Extend or restart debounce window after a long press ends
        restartDebounce()
    }
}
