//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct OtpVerificationView: View {
    @Bindable var context: OtpVerificationScreenViewModel.Context
    
    var body: some View {
        OnboardingContainer {
            Text("Continue with Email")
                .font(.compound.headingLG)
                .foregroundStyle(.compound.textPrimary)
                .padding(.top, 12)
            
            Text("Your verification code has been sent to your email id.")
                .font(.compound.bodyLG)
                .foregroundStyle(.compound.textSecondary)
            
            OtpFormFieldView(pin: $context.otp)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } footer: {
            loginButton
            
            ResendOtpView(onResend: {
                context.send(viewAction: .resendOtp)
            })
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Image(asset: Asset.Images.zeroWordmark)
        }
    }
    
    var loginButton: some View {
        ZeroPrimaryButton(title: "Login",
                          onClick: { context.send(viewAction: .verifyOtp) },
                          enabled: context.viewState.isOtpValid)
    }
}
