//
// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import Compound
import SwiftUI

/// The screen shown at the beginning of the onboarding flow.
struct CompleteProfileScreen: View {
    @ObservedObject var context: CompleteProfileScreenViewModel.Context
    
    @FocusState private var isDisplayNameFocused: Bool
    
    var body: some View {
        OnboardingContainer {
            VStack {
                Text("Enter your details")
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.compound.textPrimary)
                    .padding(.top, 16)
                
                Text("Complete your Profile")
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                
                avatar
                    .padding(.vertical, 24)
                
                nameSection
                    .padding(.bottom, 24)
            }.frame(maxWidth: .infinity)
        } footer: {
            submitButton
        }
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("", isPresented: $context.showMediaSheet) {
            mediaActionSheet
        }
    }
    
    private var avatar: some View {
        Button {
            context.send(viewAction: .presentMediaSource)
        } label: {
            OverridableAvatarImage(overrideURL: context.viewState.localMedia?.thumbnailURL,
                                   url: context.viewState.selectedAvatarURL,
                                   name: nil,
                                   contentID: nil,
                                   avatarSize: .user(on: .completeProfile),
                                   mediaProvider: context.mediaProvider,
                                   onTap: { context.send(viewAction: .presentMediaSource) })
            .overlay(alignment: .bottomTrailing) {
                avatarOverlayIcon
            }
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading) {
            Text("Display Name")
                .font(.zero.bodyMD)
                .foregroundStyle(.compound.textSecondary)
            
            TextField(text: $context.name) {
                Text("Enter your display name").foregroundColor(.compound.textSecondary)
            }
            .focused($isDisplayNameFocused)
            .textFieldStyle(.element(accessibilityIdentifier: "complete-profile_display_name"))
            .disableAutocorrection(true)
            .autocapitalization(.none)
            .submitLabel(.done)
            .onSubmit(submit)
            
            InfoBox(text: "Name must be atleast 3 characters or more upto 24 characters", type: .general)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .padding(.vertical, 24)
    }
    
    private var submitButton: some View {
        ZeroPrimaryButton(title: "Continue",
                          onClick: { submit() },
                          enabled: context.viewState.canSubmit)
    }
    
    private var avatarOverlayIcon: some View {
        CompoundIcon(\.editSolid, size: .xSmall, relativeTo: .compound.bodyLG)
            .foregroundColor(.white)
            .padding(4)
            .background {
                Circle()
                    .foregroundColor(.black)
            }
    }
    
    @ViewBuilder
    private var mediaActionSheet: some View {
        Button {
            context.send(viewAction: .displayCameraPicker)
        } label: {
            Text(L10n.actionTakePhoto)
        }
        Button {
            context.send(viewAction: .displayMediaPicker)
        } label: {
            Text(L10n.actionChoosePhoto)
        }
    }
    
    private func submit() {
        guard context.viewState.canSubmit else { return }
        context.send(viewAction: .completeProfile)
        isDisplayNameFocused = false
    }
}
