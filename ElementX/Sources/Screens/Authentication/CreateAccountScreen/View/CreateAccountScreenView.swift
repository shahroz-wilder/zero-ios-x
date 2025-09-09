//
// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE in the repository root for full details.
//

import SwiftUI

struct CreateAccountScreen: View {
    @ObservedObject var context: CreateAccountScreenViewModel.Context
    
    var body: some View {
        VStack(alignment: .leading) {
            if context.viewState.hasValidInviteCode {
                CreateAccountFormsView(context: context)
            } else {
                ValidateInviteCodeView(context: context)
            }
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
}
