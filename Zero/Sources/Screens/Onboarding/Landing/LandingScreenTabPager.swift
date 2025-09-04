//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct LandingScreenTabPager : View {
    
    private let images: [ImageAsset] = [
        Asset.Images.landingPagerImage1,
        Asset.Images.landingPagerImage2,
        Asset.Images.landingPagerImage3,
        Asset.Images.landingPagerImage4
    ]
    
    @State private var currentIndex = 0
    
    var title: String {
        switch currentIndex {
        case 0:
            return "Make internet money."
        case 1:
            return "Securely chat with friends and family."
        case 2:
            return "Buy, sell, and swap millions of coins."
        default:
            return "Work for yourself and own your future."
        }
    }
    
    var subTitle: String {
        switch currentIndex {
        case 0:
            return "Turn your ideas into money with a platform that rewards creativity."
        case 1:
            return "Stay connected with those who matter most, without compromise."
        case 2:
            return "Seamless, secure trading with deep liquidity and instant execution."
        default:
            return "Turn your ideas into money with a platform that rewards creativity."
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.compound.headingLG)
                    .foregroundStyle(.zero.bgAccentRest)
                
                Text(subTitle)
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textSecondary)
            }
            .padding(16)
            
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    Image(asset: images[index])
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 350)
            .padding(.vertical, 8)
            
            // Custom Indicator
            HStack(spacing: 12) {
                Spacer()
                
                ForEach(images.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(currentIndex == index ? .zero.bgAccentRest : .compound.bgCanvasDefaultLevel1)
                        .frame(width: 40, height: 4)
                        .animation(.easeInOut, value: currentIndex)
                }
                
                Spacer()
            }
            .padding(.top, 8)
        }
    }
}
