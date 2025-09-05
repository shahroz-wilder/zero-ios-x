//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct OnLandingScreen: View {
    @Bindable var context: AuthenticationStartScreenViewModel.Context
    
    @State private var showExtendedLoginActions: Bool = false
    
    var body: some View {
        VStack {
            LandingScreenTabPager()
            
            Spacer()
            
            VStack(spacing: 0) {
                loginWithXButton
                
                StrikedLabel(text: "or via")
                    .padding(.vertical, 12)
                
                HStack(spacing: 12) {
                    if showExtendedLoginActions {
                        extendedLoginActions
                    } else {
                        loginActions
                    }
                }
            }
            .padding(16)
        }
        .toolbar { toolbar }
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Image(asset: Asset.Images.zeroWordmark)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
//                context.send(viewAction: .searchUser)
            } label: {
                Text("Sign up")
                    .foregroundStyle(.compound.textPrimary)
            }
        }
    }
    
    @ViewBuilder
    var loginActions: some View {
        OnboardingLoginActionButton(icon: Asset.Images.logoEmail, onClick: {
            context.send(viewAction: .login)
        })
        OnboardingLoginActionButton(icon: Asset.Images.logoWalletConnect, onClick: {
            context.send(viewAction: .openWalletConnectModal)
        })
        OnboardingLoginActionButton(icon: Asset.Images.logoEpic, onClick: {})
//        OnboardingLoginActionButton(icon: Asset.Images.iconMore, onClick: {
//            withAnimation(.easeInOut(duration: 0.3)) {
//                showExtendedLoginActions.toggle()
//            }
//        })
    }
    
    @ViewBuilder
    var extendedLoginActions: some View {
        OnboardingLoginActionButton(icon: Asset.Images.iconBack, onClick: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showExtendedLoginActions.toggle()
            }
        })
        OnboardingLoginActionButton(icon: Asset.Images.logoApple, onClick: {})
        OnboardingLoginActionButton(icon: Asset.Images.logoGoogle, onClick: {})
        OnboardingLoginActionButton(icon: Asset.Images.logoEpic, onClick: {})
    }
    
    var loginWithXButton: some View {
        Button(action: {  }) {
            HStack(spacing: 0) {
                Text("Continue with")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 6)
                
                Image(asset: Asset.Images.logoX)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.zero.bgAccentRest)
            )
        }
    }
}

private struct OnboardingLoginActionButton : View {
    let icon: ImageAsset
    let onClick: () -> Void
    
    var body: some View {
        Button {
            onClick()
        } label: {
            Image(asset: icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(.zero.bgAccentRest)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.zero.bgAccentRest.opacity(0.125))
                        .stroke(.zero.bgAccentRest)
                )
        }
    }
}
