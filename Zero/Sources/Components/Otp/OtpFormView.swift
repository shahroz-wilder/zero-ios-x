//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import SwiftUI

struct OtpFormFieldView: View {
    @Binding var pin: String
    
    private enum FocusPin: Int, Hashable {
        case pin0, pin1, pin2, pin3, pin4, pin5
    }
    
    @State private var pins: [String] = Array(repeating: "", count: 6)
    @FocusState private var pinFocusState: FocusPin?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Enter OTP")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textDisabled)
            
            HStack(spacing: 15) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: $pins[index])
                        .modifier(OtpModifier(pin: $pins[index]))
                        .focused($pinFocusState, equals: FocusPin(rawValue: index))
                        .onChange(of: pins[index]) { _, newVal in
                            handleInputChange(at: index, value: newVal)
                        }
                }
            }
            .padding(.vertical)
        }
        .onChange(of: pins) { _, _ in
            let otp = pins.joined()
            if otp.count == 6 {
                pin = otp
            }
        }
        .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pinFocusState = .pin0
            }
        }
    }
    
    private func handleInputChange(at index: Int, value: String) {
        if value.count == 1 {
            // Move to next field if available
            if index < 5 {
                pinFocusState = FocusPin(rawValue: index + 1)
            } else {
                pinFocusState = nil // Last digit entered, dismiss keyboard
            }
        } else if value.isEmpty {
            // Move back if deleting
            if index > 0 {
                pinFocusState = FocusPin(rawValue: index - 1)
            }
        } else if value.count > 1 {
            // If user pastes or types multiple digits, take only first
            pins[index] = String(value.prefix(1))
        }
    }
}
