//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import Combine

struct OtpModifier: ViewModifier {
    
    @Binding var pin : String
    
    var textLimit = 1

    func limitText(_ upper : Int) {
        if pin.count > upper {
            self.pin = String(pin.prefix(upper))
        }
    }
        
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .onReceive(Just(pin)) {_ in limitText(textLimit)}
            .frame(width: 50, height: 60)
            .foregroundStyle(Color.compound.textPrimary)
            .font(.compound.headingSMSemibold)
            .background(Color.compound.bgCanvasDefault.cornerRadius(8))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.compound.bgCanvasDefaultLevel1, lineWidth: 1)
            )
    }
}
