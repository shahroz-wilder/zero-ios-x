//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import UIKit
import SwiftUI

enum HomeWalletViewModelAction {
    case startWalletTransaction(WalletTransactionProtocol, WalletTransactionType, ZeroCurrency?)
}

enum HomeWalletViewAction {
    case toggleWalletBalance(show: Bool)
    case loadMoreWalletTokens
    case loadMoreWalletTransactions
    case loadMoreWalletNFTs
    case startWalletTransaction(WalletTransactionType)
    case viewTransactionDetails(transactionId: String, chainId: UInt64?)
    
    case onStakePoolSelected(HomeScreenWalletStakingContent)
    case claimStakeRewards
    case stakeAmount(String)
    case unstakeAmount(String)
    case refreshWalletData
}

enum HomeScreenWalletContentListMode: CustomStringConvertible {
    case skeletons
    case content
    
    var description: String {
        switch self {
        case .skeletons:
            return "Showing placeholders"
        case .content:
            return "Showing wallet content"
        }
    }
}

enum StakePoolViewState {
    case details
    case staking
    case unstaking
    case inProgress
    case success
    case failure(String?)
}

struct HomeWalletViewState: BindableState {
    let userID: String
    var userDisplayName: String?
    var userAvatarURL: URL?
    
    var currentUserZeroProfile: ZCurrentUser?
    
    var walletTokens: [HomeScreenWalletContent] = []
    var walletTransactions: [HomeScreenWalletContent] = []
    var walletNFTs: [HomeScreenWalletContent] = []
    var walletStakings: [String: HomeScreenWalletStakingContent] = [:]
    
    var walletTokenNextPageParams: NextPageParams? = nil
    var walletNFTsNextPageParams: NextPageParams? = nil
    var walletTransactionsNextPageParams: TransactionNextPageParams? = nil
    
    var meowPrice: ZeroCurrency? = nil

    var walletContentListMode: HomeScreenWalletContentListMode = .skeletons
    
    var visibleWalletTokens: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletTokens
    }
    var visibleWalletTransactions: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletTransactions
    }
    var visibleWalletNFTs: [HomeScreenWalletContent] {
        if walletContentListMode == .skeletons {
            return placeholderWalletContent
        }
        return walletNFTs
    }
    var visibleWalletStakings: [HomeScreenWalletStakingContent] {
        if walletContentListMode == .skeletons {
            return (1...20).map { _ in
                HomeScreenWalletStakingContent.placeholder()
            }
        }
        return walletStakings.map({ $0.value })
    }
    
    var bindings: HomeWalletViewStateBindings
    
    var placeholderWalletContent: [HomeScreenWalletContent] {
        (1...20).map { _ in
            HomeScreenWalletContent.placeholder()
        }
    }
    
    var walletBalance: Double = 0
    var showWalletBalance: Bool = true
    var userWalletBalance: String {
        showWalletBalance ? "$\(walletBalance.formatToThousandSeparatedString())" : "*****"
    }
    
    var selectedStakePool: SelectedHomeWalletStakePool?
}

struct HomeWalletViewStateBindings {
    var alertInfo: AlertInfo<UUID>?
    var showStakePoolSheet: Bool = false
    
    var stakePoolViewState: StakePoolViewState = .details
}

struct HomeScreenWalletContent: Identifiable, Equatable {
    let id: String
    let icon: String?
    let header: String?
    
    let transactionAction: String?
    let transactionAddress: String?
    let title: String
    let description: String?
    
    let actionPreText: String?
    let actionText: String
    let actionPostText: String?
    
    let chainId: UInt64
    
    static func placeholder() -> HomeScreenWalletContent {
        .init(id: UUID().uuidString,
              icon: nil,
              header: nil,
              transactionAction: nil,
              transactionAddress: nil,
              title: "placeholder title",
              description: "placeholder description",
              actionPreText: nil,
              actionText: "placeholder action text",
              actionPostText: "placeholder action post text",
              chainId: 0)
    }
}

struct HomeScreenWalletStakingContent: Identifiable, Equatable {
    let id: String
    let userWalletAddress: String
    
    let poolAddress: String
    let poolIcon: String?
    let poolName: String
    
    let tokenAmount: String
    let tokenIcon: String?
    
    let totalStakedAmount: Double
    let totalStakedAmountFormatted: String
    let myStakeAmount: Double
    let myStateAmountFormatted: String
    let pendingRewards: Double
    
    let chainId: UInt64
    
    static func placeholder() -> HomeScreenWalletStakingContent {
        .init(id: UUID().uuidString,
              userWalletAddress: "",
              poolAddress: "",
              poolIcon: nil,
              poolName: "placeholder pool",
              tokenAmount: "",
              tokenIcon: nil,
              totalStakedAmount: 0,
              totalStakedAmountFormatted: "",
              myStakeAmount: 0,
              myStateAmountFormatted: "",
              pendingRewards: 0,
              chainId: 0)
    }
    
}

struct SelectedHomeWalletStakePool {
    let pool: HomeScreenWalletStakingContent
    let stakeToken: ZWalletTokenInfo?
    let stakeTokenBalance: ZWalletTokenBalance?
    let rewardToken: ZWalletTokenInfo?
    let rewardTokenBalance: ZWalletTokenBalance?
}

extension SelectedHomeWalletStakePool {
    var claimableRewardValue: String {
        ZeroRewards.parseCredits(credits: rewardTokenBalance?.balance ?? "0", decimals: rewardToken?.decimals ?? 18)
            .formatToSuffix()
    }
    
    var myStakedTokens: Double {
        ZeroRewards.parseCredits(credits: pool.tokenAmount, decimals: stakeToken?.decimals ?? 18)
    }
    
    var myStakedTokensFormatted: String {
        myStakedTokens.formatToSuffix()
    }
    
    var totalAvailableTokenBalance: Double {
        ZeroRewards.parseCredits(credits: stakeTokenBalance?.balance ?? "0", decimals: stakeToken?.decimals ?? 18)
    }
    
    var totalAvailableTokenBalanceFormatted: String {
        totalAvailableTokenBalance.formatToSuffix()
    }
}

extension HomeScreenWalletContent {
    init (walletToken: ZWalletToken, meowPrice: ZeroCurrency?) {
        let priceDiff = walletToken.percentChange.map(Double.init) ?? meowPrice?.diff

        let isZChainToken = ZeroWalletChainsUtil.shared.isZChain(walletToken.chainId)
        let tokenPriceFormatted = walletToken.isClaimableToken
            ? (isZChainToken ? walletToken.meowPriceFormatted(ref: meowPrice) : walletToken.tokenPriceFormatted()) : ""
        
        self.init(id: walletToken.tokenAddress,
                  icon: walletToken.logo,
                  header: nil,
                  transactionAction: nil,
                  transactionAddress: nil,
                  title: walletToken.name,
                  description: "\(walletToken.formattedAmount) \(walletToken.symbol.uppercased())",
                  actionPreText: nil,
                  actionText: tokenPriceFormatted.isEmpty ? "" : "$\(tokenPriceFormatted)",
                  actionPostText: walletToken.isClaimableToken ? priceDiff?.description : nil,
                  chainId: walletToken.chainId
        )
    }
    
    init(walletNFT: NFT) {
        self.init(id: walletNFT.id,
                  icon: walletNFT.imageUrl,
                  header: nil,
                  transactionAction: nil,
                  transactionAddress: nil,
                  title: walletNFT.collectionName ?? walletNFT.metadata.name ?? "",
                  description: nil,
                  actionPreText: nil,
                  actionText: "0",
                  actionPostText: nil,
                  chainId: 0)
    }
    
    init(walletTransaction: WalletTransaction, meowPrice: ZeroCurrency?) {
        let isTransactionReceived = walletTransaction.action.lowercased() == "receive"
        
        self.init(id: walletTransaction.hash,
                  icon: walletTransaction.token.logo,
                  header: nil, //walletTransaction.timestamp
                  transactionAction: isTransactionReceived ? "Received from" : "Sent to",
                  transactionAddress: isTransactionReceived ? displayFormattedAddress(walletTransaction.from) : displayFormattedAddress( walletTransaction.to),
                  title: walletTransaction.token.name,
                  description: nil,
                  actionPreText: nil,
                  actionText: walletTransaction.formattedAmount,
                  actionPostText: "--",
                  chainId: walletTransaction.token.chainId ?? ZeroWalletChainsUtil.shared.zChainId)
    }
}

extension HomeScreenWalletStakingContent {
    init(tokenPrice: Double?, userWalletAddress: String,
         pool: WalletStakePool, totalStaked: String, stakingConfig: ZStackingConfig,
         stakerStatus: ZStakingStatus, stakeRewards: ZStakingUserRewardsInfo) {
        
        let totalStakedAmount = ZeroWalletUtil.shared.tokenPrice(tokenAmount: ZeroRewards.parseCredits(credits: totalStaked,
                                                                                                      decimals: 18),
                                                                tokenPrice: tokenPrice)
        let myStakeAmount = ZeroWalletUtil.shared.tokenPrice(tokenAmount: ZeroRewards.parseCredits(credits: stakerStatus.amountStaked,
                                                                                                  decimals: 18),
                                                             tokenPrice: tokenPrice)
        let pendingRewards = ZeroRewards.parseCredits(credits: stakeRewards.pendingRewards, decimals: 18)
        self.init(id: pool.address,
                  userWalletAddress: userWalletAddress,
                  poolAddress: pool.address,
                  poolIcon: pool.image,
                  poolName: pool.name,
                  tokenAmount: stakerStatus.amountStaked,
                  tokenIcon: pool.image,
                  totalStakedAmount: totalStakedAmount,
                  totalStakedAmountFormatted: "$\(totalStakedAmount.formatToSuffix())",
                  myStakeAmount: myStakeAmount,
                  myStateAmountFormatted: "$\(myStakeAmount.formatToSuffix())",
                  pendingRewards: pendingRewards,
                  chainId: pool.chainId.rawValue)
    }
}
