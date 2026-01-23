//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents
import Combine
import MatrixRustSDK
import SwiftUI
import Kingfisher

typealias HomeWalletViewModelType = StateStoreViewModel<HomeWalletViewState, HomeWalletViewAction>

class HomeWalletViewModel: HomeWalletViewModelType, HomeWalletViewModelProtocol, WalletTransactionProtocol {
    private let userSession: UserSessionProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private var actionsSubject: PassthroughSubject<HomeWalletViewModelAction, Never> = .init()
    var actions: AnyPublisher<HomeWalletViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.userSession = userSession
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: .init(userID: userSession.clientProxy.userID,
                                           bindings: .init()),
                   mediaProvider: userSession.mediaProvider)
        
        userSession.clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userAvatarURL, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userDisplayName, on: self)
            .store(in: &cancellables)
        
        userSession.clientProxy.zeroClient.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.state.currentUserZeroProfile = currentUser
                self?.fetchWalletData()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public
    
    override func process(viewAction: HomeWalletViewAction) {
        switch viewAction {
        case .toggleWalletBalance(let show):
            state.showWalletBalance = show
        case .loadMoreWalletTokens:
            loadMoreWalletTokenBalances()
        case .loadMoreWalletTransactions:
            loadMoreWalletTransactions()
        case .loadMoreWalletNFTs:
            loadMoreWalletNFTs()
        case .startWalletTransaction(let type):
            actionsSubject.send(.startWalletTransaction(self, type, state.meowPrice))
        case .viewTransactionDetails(let walletTransactionId, let chainId):
            viewWalletTransactionDetails(walletTransactionId, chainId: chainId)
        case .onStakePoolSelected(let stakePool):
            fetchStakeDataOfPool(stakePool)
        case .claimStakeRewards:
            claimStakeRewards()
        case .stakeAmount(let amount):
            stakeAmount(amount)
        case .unstakeAmount(let amount):
            unstakeAmount(amount)
        case .refreshWalletData:
            fetchWalletData()
        case .openNFT(let nft):
            actionsSubject.send(.openNFT(nft))
        case .copyNFTId(let nft):
            copyNFTId(nft)
        case .openNFTTransaction(let nft):
            openNFTTransaction(nft)
        }
    }
    
    private func displayError(title: String? = nil, message: String? = nil) {
        state.bindings.alertInfo = .init(id: UUID(),
                                         title: title ?? L10n.commonError,
                                         message: message ?? L10n.errorUnknown)
    }
    
    func refreshWallet() {
        fetchWalletData(silentRefresh: true)
    }
    
    private func fetchWalletData(silentRefresh: Bool = false) {
        guard let walletAddress = state.currentUserZeroProfile?.publicWalletAddress else { return }
        if !silentRefresh {
            state.walletContentListMode = .skeletons
        }
        Task {
            async let meowPriceResult = userSession.clientProxy.zeroClient.getZeroMeowPrice()
            async let tokensResult = userSession.clientProxy.zeroClient.getWalletTokenBalances(walletAddress: walletAddress,
                                                                                    nextPage: nil)
            async let transactionsResult = userSession.clientProxy.zeroClient.getWalletTransactions(walletAddress: walletAddress,
                                                                                         nextPage: nil)
            async let nftsResult = userSession.clientProxy.zeroClient.getWalletNFTs(walletAddress: walletAddress,
                                                                                         nextPage: nil)
            
            let (meowPrice, tokens, transactions, nfts) = await (meowPriceResult, tokensResult, transactionsResult, nftsResult)
            let newMeowPrice: ZeroCurrency? = {
                if case .success(let price) = meowPrice { return price }
                return nil
            }()
            let walletTokens: ([HomeScreenWalletContent], NextPageParams?) = {
                if case .success(let balances) = tokens {
                    setUserWalletBalance(balances.tokens)
                    let contents = balances.tokens.map { HomeScreenWalletContent(walletToken: $0, meowPrice: newMeowPrice) }
                    return (contents.uniqued(on: \.id), balances.nextPageParams)
                }
                return ([], nil)
            }()
            let walletTransactions: ([HomeScreenWalletContent], TransactionNextPageParams?) = {
                if case .success(let txs) = transactions {
                    let contents = txs.transactions.map { HomeScreenWalletContent(walletTransaction: $0, meowPrice: newMeowPrice) }
                    return (contents.uniqued(on: \.id), txs.nextPageParams)
                }
                return ([], nil)
            }()
            let walletNFTs: ([HomeScreenWalletNFTContent], NextPageParams?) = {
                if case .success(let response) = nfts {
                    let contents = response.nfts.map { HomeScreenWalletNFTContent(nft: $0) }
                    return (contents.uniqued(on: \.id), response.nextPageParams)
                }
                return ([], nil)
            }()
            
            // Batch state updates on main actor
            await MainActor.run {
                if let price = newMeowPrice {
                    state.meowPrice = price
                    fetchStakingData(stakePools: ZeroWalletStakingUtil.shared.stakePools,
                                     userWalletAddress: walletAddress,
                                     refreshAllData: silentRefresh)
                }
                if !walletTokens.0.isEmpty {
                    state.walletTokens = walletTokens.0
                    state.walletTokenNextPageParams = walletTokens.1
                }
                if !walletTransactions.0.isEmpty {
                    state.walletTransactions = walletTransactions.0
                    state.walletTransactionsNextPageParams = walletTransactions.1
                }
                if !walletNFTs.0.isEmpty {
                    state.walletNFTs = walletNFTs.0
                    state.walletNFTsNextPageParams = walletNFTs.1
                }
                state.walletContentListMode = .content
            }
        }
    }
    
    private func loadMoreWalletTokenBalances() {
        if let nextPageParams = state.walletTokenNextPageParams,
           let walletAddress = state.currentUserZeroProfile?.publicWalletAddress {
            Task {
                let result = await userSession.clientProxy.zeroClient.getWalletTokenBalances(walletAddress: walletAddress,
                                                                                  nextPage: nextPageParams)
                if case .success(let walletTokenBalances) = result {
                    var homeWalletContent: [HomeScreenWalletContent] = state.walletTokens
                    for token in walletTokenBalances.tokens {
                        let content = HomeScreenWalletContent(walletToken: token, meowPrice: state.meowPrice)
                        homeWalletContent.append(content)
                    }
                    state.walletTokens = homeWalletContent.uniqued(on: \.id)
                    state.walletTokenNextPageParams = walletTokenBalances.nextPageParams
                }
            }
        }
    }
    
    private func loadMoreWalletNFTs() {
        if let nextPageParams = state.walletNFTsNextPageParams,
           let walletAddress = state.currentUserZeroProfile?.publicWalletAddress {
            Task {
                let result = await userSession.clientProxy.zeroClient.getWalletNFTs(walletAddress: walletAddress, nextPage: nextPageParams)
                if case .success(let walletNFTs) = result {
                    var homeWalletContent: [HomeScreenWalletNFTContent] = state.walletNFTs
                    for nft in walletNFTs.nfts {
                        let content = HomeScreenWalletNFTContent(nft: nft)
                        homeWalletContent.append(content)
                    }
                    state.walletNFTs = homeWalletContent.uniqued(on: \.id)
                    state.walletNFTsNextPageParams = walletNFTs.nextPageParams
                }
            }
        }
    }
    
    private func loadMoreWalletTransactions() {
        if let nextPageParams = state.walletTransactionsNextPageParams,
           let walletAddress = state.currentUserZeroProfile?.publicWalletAddress {
            Task {
                let result = await userSession.clientProxy.zeroClient.getWalletTransactions(walletAddress: walletAddress,
                                                                                 nextPage: nextPageParams)
                if case .success(let walletTransactions) = result {
                    var homeWalletContent: [HomeScreenWalletContent] = state.walletTransactions
                    for transaction in walletTransactions.transactions {
                        let content = HomeScreenWalletContent(walletTransaction: transaction, meowPrice: state.meowPrice)
                        homeWalletContent.append(content)
                    }
                    state.walletTransactions = homeWalletContent.uniqued(on: \.id)
                    state.walletTransactionsNextPageParams = walletTransactions.nextPageParams
                }
            }
        }
    }
    
    private func setUserWalletBalance(_ tokens: [ZWalletToken]) {
        let totalWalletAmount = tokens
            .filter { $0.isClaimableToken }
            .reduce(0.0) { total, token in
                let isZChainToken = ZeroWalletChainsUtil.shared.isZChain(token.chainId)
                let tokenAmount = isZChainToken
                ? ZeroWalletUtil.shared.meowPrice(tokenAmount: token.amount.description, refPrice: state.meowPrice)
                : token.tokenPrice()
                return total + tokenAmount
            }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            self.state.walletBalance = totalWalletAmount
        })
    }
    
    private func viewWalletTransactionDetails(_ walletTransactionId: String, chainId: UInt64?) {
        Task {
            let userIndicatorID = UUID().uuidString
            defer {
                userIndicatorController.retractIndicatorWithId(userIndicatorID)
            }
            userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                                  type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                                  title: L10n.commonLoading,
                                                                  persistent: true))
            if case .success(let receipt) = await userSession.clientProxy.zeroClient.getTransactionReceipt(transactionHash: walletTransactionId, chainId: chainId),
               let link = URL(string: receipt.blockExplorerUrl) {
                await UIApplication.shared.open(link)
            }
        }
    }
    
    private func fetchStakingData(stakePools: [WalletStakePool], userWalletAddress: String, refreshAllData: Bool = false) {
        Task(priority: .background) { [weak self] in
            guard let self else { return }
            
            var stakingContents: [HomeScreenWalletStakingContent] = []
            let meowPrice = self.state.meowPrice
            
            await withTaskGroup(of: HomeScreenWalletStakingContent?.self) { group in
                for pool in stakePools {
                    group.addTask {
                        let poolAddress = pool.address
                        let chainId = pool.chainId.rawValue
                        let isAvaxChain = ZeroWalletChainsUtil.shared.isAvaxChain(chainId)
                        
                        async let totalStakedResult = self.userSession.clientProxy.zeroClient.getTotalStaked(poolAddress: poolAddress, chainId: chainId)
                        async let configResult = self.userSession.clientProxy.zeroClient.getStakingConfig(poolAddress: poolAddress, chainId: chainId)
                        async let stakerStatusResult = self.userSession.clientProxy.zeroClient.getStakerStatusInfo(
                            userWalletAddress: userWalletAddress,
                            poolAddress: poolAddress,
                            chainId: chainId
                        )
                        async let stakeRewardsResult = self.userSession.clientProxy.zeroClient.getStakeRewardsInfo(
                            userWalletAddress: userWalletAddress,
                            poolAddress: poolAddress,
                            chainId: chainId
                        )
                        
                        let (totalStaked, config, stakerStatus, stakeRewards) =
                        await (totalStakedResult, configResult, stakerStatusResult, stakeRewardsResult)
                        
                        guard case .success(let totalStaked) = totalStaked,
                              case .success(let stakingConfig) = config,
                              case .success(let stakerStatus) = stakerStatus,
                              case .success(let stakeRewards) = stakeRewards else {
                            return nil
                        }
                        
                        var tokenPrice: Double?
                        if isAvaxChain {
                            let tokenAddressResult = await self.userSession.clientProxy.zeroClient.getStakingToken(poolAddress: poolAddress, chainId: chainId)
                            if case .success(let result) = tokenAddressResult {
                                if case .success(let price) = await self.userSession.clientProxy.zeroClient.getAvaxTokenPrice(tokenAddress: result.stakingTokenAddress) {
                                    tokenPrice = price.usd
                                }
                            }
                        } else {
                            tokenPrice = meowPrice?.price
                        }
                        
                        return HomeScreenWalletStakingContent(
                            tokenPrice: tokenPrice,
                            userWalletAddress: userWalletAddress,
                            pool: pool,
                            totalStaked: totalStaked,
                            stakingConfig: stakingConfig,
                            stakerStatus: stakerStatus,
                            stakeRewards: stakeRewards
                        )
                    }
                }
                
                for await stakingContent in group {
                    if let stakingContent {
                        stakingContents.append(stakingContent)
                    }
                }
            }
            
            // Update state once on main actor
            await MainActor.run {
                let existingStakings = self.state.walletStakings
                let newStakings = Dictionary(uniqueKeysWithValues: stakingContents.map { ($0.id, $0) })
                self.state.walletStakings = existingStakings.merging(newStakings) { (_, new) in new }
                if refreshAllData {
                    for stakingContent in stakingContents {
                        self.fetchStakeDataOfPool(stakingContent, silentRefresh: refreshAllData)
                    }
                }
            }
        }
    }
    
    private func fetchStakeDataOfPool(_ pool: HomeScreenWalletStakingContent, silentRefresh: Bool = false) {
        Task {
            let userIndicatorID = UUID().uuidString
            if !silentRefresh {
                userIndicatorController.submitIndicator(
                    UserIndicator(
                        id: userIndicatorID,
                        type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                        title: L10n.commonLoading,
                        persistent: true
                    )
                )
            }
            
            func fetchTokenData(tokenAddress: String) async -> (ZWalletTokenInfo?, ZWalletTokenBalance?) {
                async let tokenInfo = userSession.clientProxy.zeroClient.getTokenInfo(tokenAddress: tokenAddress, chainId: pool.chainId)
                async let tokenBalance = userSession.clientProxy.zeroClient.getTokenBalance(userWalletAddress: pool.userWalletAddress,
                                                                                 tokenAddress: tokenAddress,
                                                                                 chainId: pool.chainId)
                return (try? await tokenInfo.get(), try? await tokenBalance.get())
            }
            
            async let stakingTokenResult = userSession.clientProxy.zeroClient.getStakingToken(poolAddress: pool.poolAddress, chainId: pool.chainId)
            async let rewardTokenResult = userSession.clientProxy.zeroClient.getRewardsToken(poolAddress: pool.poolAddress, chainId: pool.chainId)
            
            var stakeTokenInfo: ZWalletTokenInfo?
            var stakeTokenBalance: ZWalletTokenBalance?
            var rewardTokenInfo: ZWalletTokenInfo?
            var rewardTokenBalance: ZWalletTokenBalance?
            
            let (stakingTokenResponse, rewardTokenResponse) = await (stakingTokenResult, rewardTokenResult)
            if case .success(let stakingToken) = stakingTokenResponse {
                (stakeTokenInfo, stakeTokenBalance) = await fetchTokenData(tokenAddress: stakingToken.stakingTokenAddress)
            }
            if case .success(let rewardsToken) = rewardTokenResponse {
                (rewardTokenInfo, rewardTokenBalance) = await fetchTokenData(tokenAddress: rewardsToken.rewardsTokenAddress)
            }
            state.selectedStakePool = .init(
                pool: pool,
                stakeToken: stakeTokenInfo,
                stakeTokenBalance: stakeTokenBalance,
                rewardToken: rewardTokenInfo,
                rewardTokenBalance: rewardTokenBalance
            )
            userIndicatorController.retractIndicatorWithId(userIndicatorID)
            if !silentRefresh {
                state.bindings.stakePoolViewState = .details
                state.bindings.showStakePoolSheet = true
            }
        }
    }
    
    private func claimStakeRewards() {
        guard let selectedPool = state.selectedStakePool,
              let actualPool = ZeroWalletStakingUtil.shared.poolForId(poolId: selectedPool.pool.id)
        else { return }
        Task {
            let userIndicatorID = UUID().uuidString
            defer {
                userIndicatorController.retractIndicatorWithId(userIndicatorID)
            }
            userIndicatorController.submitIndicator(
                UserIndicator(
                    id: userIndicatorID,
                    type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                    title: L10n.commonLoading,
                    persistent: true
                )
            )
            let result = await userSession.clientProxy.zeroClient.claimStakeRewards(walletAddress: selectedPool.pool.userWalletAddress,
                                                                         poolAddress: selectedPool.pool.poolAddress,
                                                                         chainId: selectedPool.pool.chainId)
            switch result {
            case .success(_):
                try? await Task.sleep(for: .seconds(0.5))
                fetchStakingData(stakePools: [actualPool],
                                 userWalletAddress: selectedPool.pool.userWalletAddress,
                                 refreshAllData: true)
            case .failure(let error):
                displayError(message: error.localizedDescription)
            }
        }
    }
    
    private func stakeAmount(_ amount: String) {
        guard let selectedPool = state.selectedStakePool else { return }
        guard let token = selectedPool.stakeToken else { return }
        let stakeAmount = amount.toLocalizedDouble() ?? 0
        guard stakeAmount > 0 else { return }
        
        let actualStakeAmount = toSmallestUnit(amount: stakeAmount, decimals: token.decimals)
        
        Task {
            state.bindings.stakePoolViewState = .inProgress
            let result = await userSession.clientProxy.zeroClient.stakeAmount(walletAddress: selectedPool.pool.userWalletAddress,
                                                                   poolAddress: selectedPool.pool.poolAddress,
                                                                   tokenAddress: token.address,
                                                                   amount: actualStakeAmount,
                                                                   chainId: selectedPool.pool.chainId)
            switch result {
            case .success(_):
                state.bindings.stakePoolViewState = .success
                fetchWalletData(silentRefresh: true)
                fetchStakeDataOfPool(selectedPool.pool, silentRefresh: true)
            case .failure(let error):
                let message: String? = switch error {
                case .insufficientGasBalance:
                    "Gas balance is not enough for this transaction"
                default:
                    nil
                }
                state.bindings.stakePoolViewState = .failure(message)
            }
        }
    }
    
    private func unstakeAmount(_ amount: String) {
        guard let selectedPool = state.selectedStakePool else { return }
        guard let token = selectedPool.stakeToken else { return }
        let unstakeAmount = amount.toLocalizedDouble() ?? 0
        guard unstakeAmount > 0 else { return }
        
        let actualUnstakeAmount = toSmallestUnit(amount: unstakeAmount, decimals: token.decimals)
        
        Task {
            state.bindings.stakePoolViewState = .inProgress
            let result = await userSession.clientProxy.zeroClient.unstakeAmount(walletAddress: selectedPool.pool.userWalletAddress,
                                                                     poolAddress: selectedPool.pool.poolAddress,
                                                                     amount: actualUnstakeAmount,
                                                                     chainId: selectedPool.pool.chainId)
            switch result {
            case .success(_):
                state.bindings.stakePoolViewState = .success
                fetchWalletData(silentRefresh: true)
            case .failure(let error):
                let message: String? = switch error {
                case .insufficientGasBalance:
                    "Gas balance is not enough for this transaction"
                default:
                    nil
                }
                state.bindings.stakePoolViewState = .failure(message)
                
            }
        }
    }
    
    private func toSmallestUnit(amount: Double, decimals: Int) -> String {
        let decimalValue = Decimal(amount) * pow(Decimal(10), decimals)
        return NSDecimalNumber(decimal: decimalValue).stringValue
    }
    
    private func copyNFTId(_ nft: HomeScreenWalletNFTContent) {
        UIPasteboard.general.string = nft.id
    }
    
    private func openNFTTransaction(_ nft: HomeScreenWalletNFTContent) {
        guard let tokenUrl = nft.getTokenLink() else { return }
        UIApplication.shared.open(tokenUrl)
    }
    
    // MARK: Zero Protcol Functions
    
    func onTransactionCompleted() {
        fetchWalletData(silentRefresh: true)
    }
}
