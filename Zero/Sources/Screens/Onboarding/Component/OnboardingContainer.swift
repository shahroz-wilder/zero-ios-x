//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct OnboardingContainer<BodyContent: View, Footer: View>: View {
    let bodyContent: BodyContent
    let footer: Footer

    init(
        @ViewBuilder bodyContent: () -> BodyContent,
        @ViewBuilder footer: () -> Footer
    ) {
        self.bodyContent = bodyContent()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    bodyContent
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            footer
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
        }
        .padding(20)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
