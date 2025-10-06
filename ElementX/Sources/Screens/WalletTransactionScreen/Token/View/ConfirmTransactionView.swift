//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ConfirmTransactionView: View {
    @ObservedObject var context: TransferTokenViewModel.Context
    
    var body: some View {
        VStack(alignment: .center) {
            if let recipient = context.viewState.transferRecipient,
               let token = context.viewState.tokenAsset {
                
                Text("Confirm Transaction with")
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.compound.textPrimary)
                
                UserInfoView(
                    image: recipient.profileImage,
                    name: recipient.displayName,
                    address: recipient.publicAddress,
                    mediaProvider: context.mediaProvider
                )
                .padding(.vertical, 24)
                
                HStack {
                    Spacer()
                    
                    AssetInfoView(tokenAsset: token, amount: context.transferAmount)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 14))
                        .foregroundColor(.zero.bgAccentRest)
                        .padding(10)
                        .background(
                            Circle()
                                .stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
                        )
                    
                    Spacer()
                    
                    AssetInfoView(tokenAsset: token, amount: context.transferAmount)
                    
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
                )
                
                Spacer()
                
                if context.viewState.canMakeTransaction {
                    VStack {
                        Text("Review the above before confirming.\nOnce made, your transaction is irreversible.")
                            .font(.zero.bodySM)
                            .foregroundStyle(.compound.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        SwipeToConfirmButton(onConfirm: {
                            context.send(viewAction: .onTransactionConfirmed)
                        })
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .padding()
    }
}

private struct UserInfoView: View {
    let image: String?
    let name: String
    let address: String?
    let mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        VStack {
            LoadableAvatarImage(url: URL(string: image ?? ""),
                                name: name,
                                contentID: nil,
                                avatarSize: .user(on: .inviteUsers),
                                mediaProvider: mediaProvider)
            
            Text(name)
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.zero.bgAccentRest)
                .lineLimit(1)
                .truncationMode(.tail)
            
            if let des = address {
                Text(des)
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

private struct AssetInfoView: View {
    let tokenAsset: ZWalletToken
    let amount: String
    
    var body: some View {
        VStack(alignment: .center) {
            ZStack(alignment: .bottomTrailing) {
                WalletTokenImage(url: tokenAsset.logo, size: 52)
                
                if let chain = ZeroWalletChainsUtil.shared.getChain(tokenAsset.chainId) {
                    WalletChainIcon(chainIcon: chain.logo)
                }
            }
            .background(
                Circle().stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
            )
            
            Text(tokenAsset.name)
                .font(.zero.bodySM)
                .foregroundStyle(.compound.textPrimary)
            
            Text(amount)
                .font(.compound.headingSMSemibold)
                .foregroundStyle(.compound.textSecondary)
                .padding(.vertical, 1)
        }
        .padding(8)
    }
}
