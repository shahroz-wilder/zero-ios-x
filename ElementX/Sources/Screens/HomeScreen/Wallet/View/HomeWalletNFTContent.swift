//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct HomeWalletNFTContent : View {
    let nftItems: [HomeScreenWalletNFTContent]
    let nextPageParams: NextPageParams?
    let mediaProvider: MediaProviderProtocol?
    
    var loadMoreNFTs: (() -> Void)? = nil
    var onTap: ((HomeScreenWalletNFTContent) -> Void)? = nil
    var onCopyNFTId: ((HomeScreenWalletNFTContent) -> Void)? = nil
    var onOpenNFTTransaction: ((HomeScreenWalletNFTContent) -> Void)? = nil
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        if nftItems.isEmpty {
            HomeContentEmptyView(message: "No NFTs")
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(nftItems) { item in
                        WalletNFTCard(
                            nft: item,
                            onTap: { onTap?(item) },
                            onCopyNFTId: { onCopyNFTId?(item) },
                            onOpenNFTTransaction: { onOpenNFTTransaction?(item) }
                        )
                    }
                    if nextPageParams != nil {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                                .onAppear {
                                    DispatchQueue.main
                                        .asyncAfter(deadline: .now() + 0.2) {
                                            loadMoreNFTs?()
                                        }
                                }
                            Spacer()
                        }
                    } else {
                        HomeTabBottomSpace()
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

struct WalletNFTCard: View {
    let nft: HomeScreenWalletNFTContent
    let onTap: () -> Void
    let onCopyNFTId: () -> Void
    let onOpenNFTTransaction: () -> Void
    
    @State private var didCopyId = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                media
                    .frame(height: 150)
                    .clipped()
                
                info
                    .padding(12)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if let qty = nft.quantity, qty > 1 {
                    WalletNFTPill(text: "Qty x\(qty)")
                        .padding(8)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let token = nft.tokenType, !token.isEmpty {
                    WalletNFTPill(text: token)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 4) {
                WalletNFTActionButton(
                    imageAsset: didCopyId ? Asset.Images.checkIcon : Asset.Images.iconCopy,
                    onTap: {
                        onCopyNFTId()
                        withAnimation(.easeInOut(duration: 0.15)) { didCopyId = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                            withAnimation(.easeInOut(duration: 0.15)) { didCopyId = false }
                        }
                    }
                )
                
                WalletNFTActionButton(
                    imageAsset: Asset.Images.postArweaveIcon,
                    onTap: { onOpenNFTTransaction() }
                )
            }
            .padding(4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(
                nft.name?.isEmpty == false ? nft.name! : (
                    nft.collectionName ?? "—"
                )
            )
            .font(.zero.bodyLGBold)
            .foregroundStyle(.compound.textPrimary)
            .lineLimit(1)
            
            HStack(alignment: .center, spacing: 10) {
                Text("ID: \(nft.id)")
                    .font(.zero.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
                    .padding(.trailing, 60) // space so text doesn't run under icons
            }
        }
    }
    
    private var cardBackground: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var placeholderNFTImage: some View {
        VStack {
            Image(asset: Asset.Images.iconDefaultNft)
                .renderingMode(.template)
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundStyle(.white.opacity(0.65))
            
            if let collectionName = nft.collectionName, !collectionName.isEmpty {
                Text(collectionName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

struct WalletNFTActionButton : View {
    let imageAsset: ImageAsset
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(asset: imageAsset)
                .renderingMode(.template)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(.compound.iconSecondary)
                .padding(6)
        }
    }
}

struct WalletNFTPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.zero.bodyXS)
            .foregroundStyle(.zero.bgAccentRest)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.zero.bgAccentRest.opacity(0.25))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                .zero.bgAccentRest.opacity(0.5),
                                lineWidth: 1
                            )
                    )
            )
    }
}
