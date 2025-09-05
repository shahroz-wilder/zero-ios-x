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
        VStack(alignment: .leading) {
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
            
            Spacer()
            
            loginButton
            
            ResendOtpView(onResend: {
                context.send(viewAction: .resendOtp)
            })
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .toolbar { toolbar }
        .padding(24)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Image(asset: Asset.Images.zeroWordmark)
        }
    }
    
    var loginButton: some View {
        Button(action: { context.send(viewAction: .verifyOtp) }) {
            Text("Login")
                .font(.compound.bodyMDSemibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.zero.bgAccentRest)
                )
        }
        .disabled(!context.viewState.isOtpValid)
    }
}
