//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ValidateInviteCodeView : View {
    @ObservedObject var context: CreateAccountScreenViewModel.Context
    
    @State private var inviteCode: String = ""
    @FocusState private var isInviteFieldFocused: Bool
    
    private var isInviteCodeValid: Bool {
        !inviteCode.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Enter your invite code")
                .font(.compound.headingLG)
                .foregroundStyle(.zero.bgAccentRest)
                .padding(.top, 12)
            
            Text("Enter your invite code to start using ZERO.")
                .font(.compound.bodyLG)
                .foregroundStyle(.compound.textSecondary)
            
            Spacer().frame(height: 32)
            
            Text("Invite Code")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            TextField(text: $inviteCode) {
                Text("Enter your invite code").foregroundColor(.compound.textSecondary)
            }
            .focused($isInviteFieldFocused)
            .textFieldStyle(.element(accessibilityIdentifier: "create-account_invite_code"))
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .submitLabel(.next)
            .onSubmit {
                if isInviteCodeValid {
                    context.send(viewAction: .verifyInviteCode(inviteCode))
                }
            }
            
            Spacer()
            
            Button(action: {
                if isInviteCodeValid {
                    context.send(viewAction: .verifyInviteCode(inviteCode))
                }
            }) {
                Text("Continue")
                    .font(.compound.bodyMDSemibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.zero.bgAccentRest)
                    )
            }
            .disabled(!isInviteCodeValid)            
        }
    }
}
