//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ResendOtpView: View {
    let onResend: () -> Void
    
    @State private var timeRemaining: Int = 30
    @State private var isTimerActive: Bool = true
    
    // Timer that ticks every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Button(action: {
            if !isTimerActive {
                onResend()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    startTimer()
                }
            }
        }) {
            Text(isTimerActive ? "Resend in \(timeRemaining)" : "Resend OTP")
                .font(.compound.bodyMDSemibold)
                .foregroundColor(isTimerActive ? .compound.textDisabled : .zero.bgAccentRest)
        }
        .disabled(isTimerActive)
        .onReceive(timer) { _ in
            guard isTimerActive else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
            
            if timeRemaining == 0 {
                isTimerActive = false
            }
        }
    }
    
    private func startTimer() {
        timeRemaining = 30
        isTimerActive = true
    }
}
