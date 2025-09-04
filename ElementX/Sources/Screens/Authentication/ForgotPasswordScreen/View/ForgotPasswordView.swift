//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ForgotPasswordView: View {
    @Bindable var context: ForgotPasswordScreenViewModel.Context
    
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            if context.state == .notCompleted {
                Text("Password Reset")
                    .font(.compound.headingLG)
                    .foregroundStyle(.compound.textPrimary)
                    .padding(.top, 12)
                
                Text("Enter your registered Email ID and we’ll email you a reset password link.")
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textSecondary)
                
                emailInputField
                    .padding(.vertical, 12)
                
                Spacer()
                
                sendResetLinkButton
                    .padding(.vertical, 12)
            } else {
                Spacer()
                
                VStack {
                    Text("A reset link has been sent to")
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textSecondary)
                    
                    Text(context.email)
                        .font(.compound.headingMDBold)
                        .foregroundStyle(.compound.textPrimary)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                backButton
                    .padding(.vertical, 12)
            }
        }
        .toolbar { toolbar }
        .padding(24)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Image(asset: Asset.Images.zeroWordmark)
        }
    }
    
    @ViewBuilder
    private var emailInputField: some View {
        VStack(alignment: .leading) {
            Text("Email")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            TextField(text: $context.email) {
                Text("Enter email address")
                    .foregroundColor(.compound.textSecondary)
            }
            .focused($isEmailFocused)
            .textFieldStyle(
                .element(
                    accessibilityIdentifier: A11yIdentifiers.loginScreen.emailUsername
                )
            )
            .disableAutocorrection(true)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .submitLabel(.done)
            .onSubmit {
                context.send(viewAction: .resetPassword)
            }
        }
    }
    
    var sendResetLinkButton: some View {
        Button(action: { context.send(viewAction: .resetPassword) }) {
            Text("Send Reset Link")
                .font(.compound.bodyMDSemibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.zero.bgAccentRest)
                )
        }
        .disabled(!context.viewState.hasValidEmail)
    }
    
    var backButton: some View {
        Button(action: { context.send(viewAction: .login) }) {
            Text("Go back")
                .font(.compound.bodyMDSemibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.zero.bgAccentRest)
                )
        }
    }
}
