//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct CreateAccountOptionSegmentControl: View {
    @State private var selectedIndex = 1
    let onSegmentSelected: (ZeroAuthenticationMethod) -> Void
    
    private let items: [SegmentItem] = [
        SegmentItem(image: Asset.Images.logoWalletConnect, title: "Web3"),
        SegmentItem(image: Asset.Images.logoEmail, title: "Email")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let isSelected = selectedIndex == index
                
                Button {
                    withAnimation(.spring()) {
                        selectedIndex = index
                        onSegmentSelected(index == 0 ? .web3 : .email)
                    }
                } label: {
                    Image(asset: items[index].image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(isSelected ? .zero.bgAccentRest : .compound.iconSecondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.zero.bgAccentRest.opacity(isSelected ? 0.125 : 0))
                                .stroke(.zero.bgAccentRest.opacity(isSelected ? 1 : 0))
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.compound.iconSecondary)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
}

struct SegmentItem {
    let image: ImageAsset
    let title: String
}
