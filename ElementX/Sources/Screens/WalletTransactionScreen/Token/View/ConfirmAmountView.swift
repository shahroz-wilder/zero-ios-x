//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct ConfirmAmountView: View {
    @ObservedObject var context: TransferTokenViewModel.Context
    
    @FocusState private var isAmountFieldFocused: Bool
        
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                if let currentUser = context.viewState.currentUser,
                   let recipient = context.viewState.transferRecipient,
                   let token = context.viewState.tokenAsset {
                    
                    VStack(alignment: .leading) {
                        UserInfoView(preText: "From:",
                                     userName: currentUser.displayName,
                                     userAddress: displayFormattedAddress(currentUser.publicWalletAddress),
                                     onTap: { isAmountFieldFocused = false })
                        
                        AssetInfoView(tokenAsset: token,
                                      amount: $context.transferAmount,
                                      isSenderSideInfo: true,
                                      iconUrl: token.logo,
                                      isFocused: $isAmountFieldFocused)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading) {
                        UserInfoView(preText: "Sending To:",
                                     userName: recipient.displayName,
                                     userAddress: displayFormattedAddress(recipient.publicAddress),
                                     onTap: { isAmountFieldFocused = false })
                        
                        AssetInfoView(tokenAsset: token,
                                      amount: $context.transferAmount,
                                      isSenderSideInfo: false,
                                      iconUrl: token.logo,
                                      isFocused: $isAmountFieldFocused)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
                    )
                    .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
            .toolbar {
                if context.viewState.canMakeTransaction {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Next") {
                            context.send(viewAction: .onConfirmTransaction)
                        }
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                    }
                }
            }
            
//            if context.viewState.canMakeTransaction {
//                continueButton
//            }
        }
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
    }
    
    var continueButton: some View {
        ZeroPrimaryButton(title: "Continue",
                          onClick: { context.send(viewAction: .onConfirmTransaction) })
        .padding(16)
    }
}

private struct UserInfoView: View {
    let preText: String
    let userName: String
    let userAddress: String?
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Text(preText)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textSecondary)
            
            Text(userName)
                .font(.compound.bodySMSemibold)
                .foregroundStyle(.compound.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            if let address = userAddress {
                Text(address)
                    .font(.compound.bodySMSemibold)
                    .foregroundStyle(.compound.textSecondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(.compound.bgCanvasDefaultLevel1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

private struct AssetInfoView: View {
    let tokenAsset: ZWalletToken
    @Binding var amount: String
    let isSenderSideInfo: Bool
    let iconUrl: String?
    var isFocused: FocusState<Bool>.Binding
    
    @State private var balance: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ZStack(alignment: .bottomTrailing) {
                    WalletTokenImage(url: iconUrl, size: 52)
                    
                    if ZeroWalletChainsUtil.shared.isAvaxChain(tokenAsset.chainId) {
                        AvaxChainIcon(size: 16)
                    } else {
                        ZChainIcon(size: 16)
                    }
                }
                .background(
                    Circle().stroke(.compound.bgCanvasDefaultLevel1, lineWidth: 1)
                )
                
                VStack(alignment: .leading) {
                    Text(tokenAsset.name.uppercased())
                        .font(.zero.bodyLG)
                        .foregroundStyle(.compound.textPrimary)
                    
                    Text(tokenAsset.symbol)
                        .font(.zero.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .padding(.vertical, 1)
                }
                
                Spacer()
            }
            
            if isSenderSideInfo {
                HStack {
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .font(.zero.headingSMSemibold)
                        .focused(isFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.isFocused.wrappedValue = true
                            }
                        }
                        .onChange(of: amount) { _, newValue in
                            let enteredAmount = Double(newValue) ?? 0
                            let maxAccount = Double(tokenAsset.amount) ?? 0
                            if enteredAmount > maxAccount {
                                amount = tokenAsset.amount
                            }
                        }
                    
                    Spacer()
                    
                    if amount != tokenAsset.amount {
                        Button {
                            amount = tokenAsset.amount
                        } label: {
                            Text("Use Max")
                                .font(.zero.bodySMSemibold)
                                .foregroundStyle(.compound.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12).fill(.compound.bgCanvasDefaultLevel1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                
                HStack {
                    Spacer()
                    
                    Text("Balance: \(amount.isEmpty ? tokenAsset.formattedAmount : balance)")
                        .font(.compound.bodySMSemibold)
                        .foregroundStyle(.compound.textSecondary)
                }
            } else {
                HStack {
                    Text(amount.isEmpty ? "0" : amount)
                        .font(.zero.headingSMSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .padding(.vertical, 12)
                    
                    Spacer()
                }
            }
        }
        .onChange(of: amount, { _, newValue in
            if let tokenMaxAmmount = Double(tokenAsset.amount),
               let userAmount = Double(newValue) {
                if userAmount > tokenMaxAmmount {
                    amount = tokenAsset.amount
                } else {
                    let diff = tokenMaxAmmount - userAmount
                    balance = String(format: "%.2f", diff)
                }
            } else {
                balance = tokenAsset.formattedAmount
            }
        })
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused.wrappedValue = false
        }
        .padding(8)
    }
}
