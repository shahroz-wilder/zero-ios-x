//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

public enum EmailAuthenticationMethod: String, Equatable, CaseIterable {
    case password = "Password"
    case otp = "OTP"
}

struct OnLoginScreen: View {
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    
    @State private var selectedEmailAuthMethod: EmailAuthenticationMethod = .otp
    
    @Bindable var context: LoginScreenViewModel.Context
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Continue with Email")
                .font(.compound.headingLG)
                .foregroundStyle(.zero.bgAccentRest)
                .padding(.top, 12)
            
            if selectedEmailAuthMethod == .otp {
                Text("Enter Email ID to generate a one-time OTP to login.")
                    .font(.compound.bodyLG)
                    .foregroundStyle(.compound.textSecondary)
            }
            
            emailInputField
                .padding(.vertical, 12)
            
            if selectedEmailAuthMethod == .password {
                passwordInputField
                
                forgotPasswordButton
                    .padding(.vertical, 12)
            }
            
            Spacer()
            
            if selectedEmailAuthMethod == .otp {
                generateLinkButton
                
                loginWithPasswordButton
                    .padding(.vertical, 12)
            } else {
                loginButton
                
                loginWithOTPButton
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
            
            TextField(text: $context.username) {
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
            .submitLabel(.next)
            .onChange(of: isEmailFocused, { _, focused in
                emailFocusChanged(isFocused: focused)
            })
            .onSubmit {
                if selectedEmailAuthMethod == .password {
                    isPasswordFocused = true
                } else {
                    
                }
            }
        }
    }
    
    @ViewBuilder
    private var passwordInputField: some View {
        VStack(alignment: .leading) {
            Text("Password")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            SecureInputField(text: $context.password,
                             isFocused: $isPasswordFocused,
                             placeHolder: "Enter password",
                             accessibilityIdentifier: A11yIdentifiers.loginScreen.password,
                             submitLabel: .done,
                             onSubmit: submit)
        }
    }
    
    var generateLinkButton: some View {
        Button(action: {  }) {
            Text("Generate Link")
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
    
    var loginButton: some View {
        Button(action: { submit() }) {
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
        .disabled(!context.viewState.hasValidCredentials)
    }
    
    var loginWithPasswordButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedEmailAuthMethod = .password
            }
        }) {
            HStack {
                Spacer()
                Text("Login with Password?")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.zero.bgAccentRest)
                Spacer()
            }
        }
    }
    
    var loginWithOTPButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedEmailAuthMethod = .otp
            }
        }) {
            HStack {
                Spacer()
                Text("Use OTP instead?")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.zero.bgAccentRest)
                Spacer()
            }
        }
    }
    
    var forgotPasswordButton: some View {
        Button(action: {
            context.send(viewAction: .forgotPassword)
        }) {
            HStack {
                Spacer()
                Text("Forgot Password?")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.zero.bgAccentRest)
                Spacer()
            }
        }
    }
    
    // Parses the username for a homeserver.
    private func emailFocusChanged(isFocused: Bool) {
        guard !isFocused, !context.username.isEmpty else { return }
        context.send(viewAction: .parseUsername)
    }
    
    // Sends the `next` view action so long as valid credentials have been input.
    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .next)
        isEmailFocused = false
        isPasswordFocused = false
    }
}
