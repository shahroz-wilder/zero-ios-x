//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct CreateAccountFormsView : View {
    @ObservedObject var context: CreateAccountScreenViewModel.Context
    
    @State private var selectedSegment: ZeroAuthenticationMethod = .email
    
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool
    
    var body: some View {
        CreateAccountOptionSegmentControl(
            onSegmentSelected: { segment in self.selectedSegment = segment }
        )
        .padding(.top, 12)
        
        Text("Continue with \(selectedSegment == .email ? "Email" : "Web3")")
            .font(.compound.headingLG)
            .foregroundStyle(.zero.bgAccentRest)
            .padding(.top, 12)
        
        Text("\(selectedSegment == .email ? "Enter your credentials to continue signing up." : "Connect your web3 wallet to continue signing up.")")
            .font(.compound.bodyLG)
            .foregroundStyle(.compound.textSecondary)
        
        ScrollView {
            Group {
                switch selectedSegment {
                case .web3:
                    web3CreateAccountView
                case .email:
                    createAccountForm
                }
            }
        }
        .padding(.vertical, 24)
        
        Spacer()
        
        if selectedSegment == .email {
            Button(action: { submit() }) {
                Text("Create account")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.zero.bgAccentRest)
                    )
            }
            .disabled(!context.viewState.canSubmit)
        }
    }
    
    var web3CreateAccountView: some View {
        Button(action: { context.send(viewAction: .openWalletConnectModal) }) {
            HStack {
                Image(asset: Asset.Images.logoWalletConnect)
                    .renderingMode(.template)
                    .foregroundStyle(.black)
                
                Text("Connect a Wallet")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.zero.bgAccentRest)
            )
        }
    }
    
    var createAccountForm: some View {
        VStack(alignment: .leading) {
            Text("Email")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            TextField(text: $context.emailAddress) {
                Text("Enter email address").foregroundColor(.compound.textSecondary)
            }
            .focused($isEmailFocused)
            .textFieldStyle(.element(accessibilityIdentifier: "create-account_email_address"))
            .disableAutocorrection(true)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .submitLabel(.next)
            .onSubmit { isPasswordFocused = true }
            
            if !context.emailAddress.isEmpty, !context.viewState.isEmailValid {
                InfoBox(text: "Please enter a valid email address", type: .error)
            }
            
            Spacer().frame(height: 20)
            
            Text("Password")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            SecureInputField(text: $context.password,
                             isFocused: $isPasswordFocused,
                             placeHolder: "Enter password",
                             accessibilityIdentifier: "create-account_password",
                             submitLabel: .next,
                             onSubmit: {
                                 isConfirmPasswordFocused = true
                             })
            
            if !context.password.isEmpty {
                let infoBoxType: InfoBoxType = context.viewState.isValidPassword ? .success : (isPasswordFocused ? .general : .error)
                InfoBox(text: "Must include at least 8 characters, 1 number, 1 lowercase and 1 uppercase letter",
                        type: infoBoxType)
            }
            
            Spacer().frame(height: 20)
            
            Text("Confirm Password")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            SecureInputField(text: $context.confirmPassword,
                             isFocused: $isConfirmPasswordFocused,
                             placeHolder: "Confirm your password",
                             accessibilityIdentifier: "create-account_confirm_password",
                             submitLabel: .done,
                             onSubmit: submit)
            
            if !context.confirmPassword.isEmpty {
                let infoBoxText = context.viewState.isValidConfirmPassword ? "Passwords match" : "Passwords do not match"
                let infoBoxType: InfoBoxType = context.viewState.isValidConfirmPassword ? .success : .error
                
                InfoBox(text: infoBoxText, type: infoBoxType)
            }
            
            Spacer()
        }
    }
    
    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .createAccount)
        isEmailFocused = false
        isPasswordFocused = false
        isConfirmPasswordFocused = false
    }
}
