//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import UIKit

struct BorderLoadingView: View {
    @State private var phase: CGFloat = 0
    
    var lineWidth: CGFloat = 2
    var animationSpeed: Double = 2.5
    var borderColor: Color = .zero.bgAccentRest.opacity(0.7)
    
    // Automatically detect device corner radius
    private var deviceCornerRadius: CGFloat {
        // Use UIWindow's cornerRadius if available (iOS 17+ often reports real value)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first {
            let radius = window.layer.cornerRadius
            if radius > 0 {
                return radius
            }
        }
        
        // Otherwise use approximate defaults
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return 44 // Good match for iPhone 11–15 series
        case .pad:
            return 24
        default:
            return 32
        }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            
            ZStack {
                // Static faint border (optional)
                RoundedRectangle(cornerRadius: deviceCornerRadius)
                    .inset(by: lineWidth / 2)
                    .stroke(borderColor.opacity(0.2), lineWidth: lineWidth)
                
                // Animated glowing border
                RoundedRectangle(cornerRadius: deviceCornerRadius)
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: 1)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                borderColor,
                                borderColor.opacity(0.1),
                                borderColor,
                                borderColor.opacity(0.1)
                            ]),
                            center: .center,
                            angle: .degrees(Double(phase * 360))
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .animation(.linear(duration: animationSpeed).repeatForever(autoreverses: false), value: phase)
                    .onAppear { phase = 1 }
            }
            .frame(width: rect.width, height: rect.height)
        }
        .ignoresSafeArea()
    }
}
