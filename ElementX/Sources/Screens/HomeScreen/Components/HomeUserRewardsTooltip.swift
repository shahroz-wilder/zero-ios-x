//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct HomeUserRewardsTooltip : View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var body: some View {
        Button {
            context.send(viewAction: .rewardsIntimated)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Triangle()
                    .fill(.ultraThickMaterial)
                    .frame(width: 25, height: 15)
                    .padding(.leading, 16)
                
                HStack {
                    Text("You earned $\(context.viewState.userRewards.getRefPriceFormatted())")
                        .font(.inter(size: 16))
                    Spacer()
                    CompoundIcon(\.close)
                }
                .padding(16)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .contentShape(Rectangle())
        .frame(width: 225, alignment: .leading)
        .zIndex(10)
    }
    
    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            // Define the three points of the triangle
            path.move(to: CGPoint(x: rect.midX, y: rect.minY)) // Top middle
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // Bottom right
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // Bottom left
            path.closeSubpath()
            return path
        }
    }
}
