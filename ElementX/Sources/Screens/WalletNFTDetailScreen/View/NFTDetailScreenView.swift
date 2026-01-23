//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct NFTDetailScreen: View {
    @ObservedObject var context: NFTDetailScreenViewModel.Context
    
    var body: some View {
        VStack {
            NFTDetailsView(nft: context.viewState.nft,
                           onCopyId: {
                context.send(viewAction: .copyNFTId)
            }, onOpenTokenLink: {
                context.send(viewAction: .openNFTTokenLink)
            })
            
            if context.viewState.nft.attributes?.isEmpty == true {
                Spacer()
            } else {
                NFTAttributesView(attributes: context.viewState.nft.attributes!)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zero.bgCanvasDefault.ignoresSafeArea())
    }
}

private struct NFTDetailsView: View {
    let nft: HomeScreenWalletNFTContent
    let onCopyId: () -> Void
    let onOpenTokenLink: () -> Void
    
    @State private var didCopyId = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            media
                .frame(height: 250)
                .clipped()
            
            info
                .padding(16)
        }
        .overlay(alignment: .topLeading) {
            if let qty = nft.quantity, qty > 1 {
                WalletNFTPill(text: "Qty x\(qty)")
                    .padding(16)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let token = nft.tokenType, !token.isEmpty {
                WalletNFTPill(text: token)
                    .padding(16)
            }
        }
    }
    
    private var media: some View {
        ZStack {
            Color.white.opacity(0.06)
            
            if let url = nft.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderNFTImage
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.9)
                    @unknown default:
                        placeholderNFTImage
                    }
                }
            } else {
                placeholderNFTImage
            }
        }
    }
    
    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                nft.name?.isEmpty == false ? nft.name! : (
                    nft.collectionName ?? "—"
                )
            )
            .font(.compound.bodyLGSemibold)
            .foregroundStyle(.compound.textPrimary)
            .lineLimit(1)
            
            HStack(alignment: .center, spacing: 10) {
                Text("ID: \(nft.id)")
                    .font(.zero.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                WalletNFTActionButton(
                    imageAsset: didCopyId ? Asset.Images.checkIcon : Asset.Images.iconCopy,
                    onTap: {
                        onCopyId()
                        withAnimation(.easeInOut(duration: 0.15)) { didCopyId = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                            withAnimation(.easeInOut(duration: 0.15)) { didCopyId = false }
                        }
                    }
                )
                                
                WalletNFTActionButton(
                    imageAsset: Asset.Images.postArweaveIcon,
                    onTap: { onOpenTokenLink() }
                )
            }
            
            if let description = nft.description {
                Text(description)
                    .font(.zero.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                    .padding(.vertical, 4)
            }
        }
    }
    
    private var placeholderNFTImage: some View {
        VStack {
            Image(asset: Asset.Images.iconDefaultNft)
                .renderingMode(.template)
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.white.opacity(0.65))
            
            if let collectionName = nft.collectionName, !collectionName.isEmpty {
                Text(collectionName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

private struct NFTAttributesView: View {
    let attributes: [NFTCollectionAttribute]
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Attributes")
                .font(.compound.bodyLGSemibold)
                .foregroundStyle(.compound.textPrimary)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(attributes) { item in
                        NFTAttributeCell(attr: item)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
        .padding(.horizontal, 16)
    }
}

private struct NFTAttributeCell : View {
    let attr: NFTCollectionAttribute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            HStack {
                Text(attr.traitType)
                    .font(.zero.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            
            HStack {
                Text(attr.value)
                    .font(.compound.bodyLGSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.compound.bgCanvasDefault)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
