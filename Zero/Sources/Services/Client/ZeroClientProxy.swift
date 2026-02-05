//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@preconcurrency import Combine
import Foundation
import OrderedCollections

import MatrixRustSDK
import StoreKit

class ZeroClientProxy: ZeroClientProxyProtocol {
    private let appSettings: AppSettings
    private let userID: String
    private let zeroApiProxy: ZeroApiProxyProtocol
    private let matrixApiProxy: MatrixApiProxyProtocol?
    private let client: ClientProtocol
    
    private var delegate: ZeroClientProxyDelegate?
    
    var matrixUserService: ZeroMatrixUsersService {
        zeroApiProxy.matrixUsersService
    }
    
    var chatApi: ZeroChatApiProtocol {
        zeroApiProxy.chatApi
    }
    
    private let userRewardsSubject = CurrentValueSubject<ZeroRewards, Never>(ZeroRewards.empty())
    var userRewardsPublisher: CurrentValuePublisher<ZeroRewards, Never> {
        userRewardsSubject.asCurrentValuePublisher()
    }
    
    private let showNewUserRewardsIntimationSubject = CurrentValueSubject<Bool, Never>(false)
    var showNewUserRewardsIntimationPublisher: CurrentValuePublisher<Bool, Never> {
        showNewUserRewardsIntimationSubject.asCurrentValuePublisher()
    }
    
    private let primaryZeroIdSubject = CurrentValueSubject<String?, Never>(nil)
    var primaryZeroId: CurrentValuePublisher<String?, Never> {
        primaryZeroIdSubject.asCurrentValuePublisher()
    }
    
    private let zeroMessengerInviteSubject = CurrentValueSubject<ZeroMessengerInvite, Never>(ZeroMessengerInvite.empty())
    var messengerInvitePublisher: CurrentValuePublisher<ZeroMessengerInvite, Never> {
        zeroMessengerInviteSubject.asCurrentValuePublisher()
    }
    
    private let directMemberZeroProfileSubject = CurrentValueSubject<ZMatrixUser?, Never>(nil)
    var directMemberZeroProfilePublisher: CurrentValuePublisher<ZMatrixUser?, Never> {
        directMemberZeroProfileSubject.asCurrentValuePublisher()
    }
    
    private let zeroCurrentUserSubject = CurrentValueSubject<ZCurrentUser, Never>(ZCurrentUser.placeholder)
    var zeroCurrentUserPublisher: CurrentValuePublisher<ZCurrentUser, Never> {
        zeroCurrentUserSubject.asCurrentValuePublisher()
    }
    
    private let homeRoomSummariesUsersSubject = CurrentValueSubject<[ZMatrixUser], Never>([])
    var homeRoomSummariesUsersPublisher: CurrentValuePublisher<[ZMatrixUser], Never> {
        homeRoomSummariesUsersSubject.asCurrentValuePublisher()
    }
    
    init(userID: String, client: ClientProtocol, appSettings: AppSettings) {
        self.userID = userID
        self.client = client
        self.appSettings = appSettings
        
        zeroApiProxy = ZeroApiProxy(appSettings: appSettings)
        matrixApiProxy = MatrixApiProxy(matrixClient: client)
        
        let allCachedUsers = matrixUserService.getAllCachedUsers()
        homeRoomSummariesUsersSubject.send(allCachedUsers)
    }
    
    func setDelegate(_ delegate: ZeroClientProxyDelegate) {
        self.delegate = delegate
    }
    
    func zeroProfile(userId: String) async {
        do {
            if let cachedUser = zeroApiProxy.matrixUsersService.userFromCache(userId) {
                directMemberZeroProfileSubject.send(cachedUser)
            }
            if let zeroProfile = try await zeroApiProxy.matrixUsersService.fetchZeroUser(userId: userId) {
                directMemberZeroProfileSubject.send(zeroProfile)
            }
        } catch {
            MXLog.error("Failed retrieving zero profile for userID: \(userID) with error: \(error)")
        }
    }
    
    func zeroProfiles(userIds: Set<String>) async {
        do {
            let zeroProfiles = try await zeroApiProxy.matrixUsersService.fetchZeroUsers(userIds: Array(userIds))
            homeRoomSummariesUsersSubject.send(zeroProfiles)
        } catch {
            MXLog.error("Failed retrieving zero profiles for userIDs: \(userIds) with error: \(error)")
        }
    }
    
    func getUserRewards(shouldCheckRewardsIntiamtion: Bool = false) async -> Result<Void, ZeroClientProxyError> {
        do {
            let oldRewards = appSettings.zeroRewardsCredit
            if shouldCheckRewardsIntiamtion {
                userRewardsSubject.send(oldRewards)
            }
            
            let apiRewards = try await zeroApiProxy.rewardsApi.fetchMyRewards()
            switch apiRewards {
            case .success(let zRewards):
                let apiCurrency = try await zeroApiProxy.rewardsApi.loadZeroCurrenyRate()
                switch apiCurrency {
                case .success(let zCurrency):
                    let zeroRewards = ZeroRewards(rewards: zRewards, currency: zCurrency)
                    
                    if shouldCheckRewardsIntiamtion {
                        let oldCredits = oldRewards.zeroCredits
                        let newCredits = zeroRewards.zeroCredits
                        showNewUserRewardsIntimationSubject.send(newCredits > oldCredits)
                    }
                    
                    appSettings.zeroRewardsCredit = zeroRewards
                    userRewardsSubject.send(zeroRewards)
                    return .success(())
                case .failure(let error):
                    return .failure(.zeroError(error))
                }
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func getZeroMeowPrice() async -> Result<ZeroCurrency, ZeroClientProxyError> {
        let result = try! await zeroApiProxy.rewardsApi.loadZeroCurrenyRate()
        switch result {
        case .success(let currency):
            return .success(currency)
        case .failure(let error):
            return .failure(.zeroError(error))
        }
    }
    
    func dismissRewardsIntimation() {
        Task {
            try await Task.sleep(for: .seconds(3))
            showNewUserRewardsIntimationSubject.send(false)
        }
    }
    
    func loadZeroMessengerInvite() async -> Result<Void, ZeroClientProxyError> {
        do {
            let apiMessengerInvite = try await zeroApiProxy.messengerInviteApi.fetchMessengerInvite()
            switch apiMessengerInvite {
            case .success(let invite):
                let zeroMessengerInvite = ZeroMessengerInvite(messengerInvite: invite)
                zeroMessengerInviteSubject.send(zeroMessengerInvite)
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func isProfileCompletionRequired() async -> Bool {
        do {
            guard let user = try await zeroApiProxy.matrixUsersService.fetchCurrentUser() else {
                return false
            }
            let name = user.displayName
            if name.isEmpty || name.isStringMatrixHexId() {
                return true
            }
            try? await client.setDisplayName(name: name)
            return false
        } catch {
            MXLog.error(error)
            return false
        }
    }
    
    func completeUserAccountProfile(avatar: MediaInfo?, displayName: String, inviteCode: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    if let localMedia = avatar {
                        try await self.delegate?.setUserAvatar(media: localMedia).get()
                    }
                }
                group.addTask {
                    try await self.delegate?.setUserInfo(displayName, primaryZId: nil).get()
                }
                try await group.waitForAll()
            }
            let avatarUrl = try await client.avatarUrl() ?? ""
            let result = try await zeroApiProxy.createAccountApi
                .finaliseCreateAccount(request: ZFinaliseCreateAccount(inviteCode: inviteCode, name: displayName, userId: userID, profileImageUrl: avatarUrl))
            
            switch result {
            case .success(let user):
                /// create a room with the user who invited
                _ = await delegate?.createDirectRoom(with: user.inviter.matrixId, expectedRoomName: user.inviter.displayName)
                return .success(())
                
            case .failure(_):
                return .failure(.failedCompletingUserProfile)
            }
        } catch {
            MXLog.error(error)
            return .failure(.failedCompletingUserProfile)
        }
    }
    
    func deleteUserAccount() async -> Result<Void, ZeroClientProxyError> {
        do {
            let deleteAccountResult = try await zeroApiProxy.userAccountApi.deleteAccount()
            switch deleteAccountResult {
            case .success(_):
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func checkAndLinkZeroUser() async {
        do {
            zeroCurrentUserSubject.send(appSettings.zeroLoggedInUser)
            guard let currentUser = try await fetchZeroCurrentUser() else { return }
            if currentUser.matrixId == nil {
                _ = try await zeroApiProxy.createAccountApi.linkMatrixUserToZero(matrixUserId: userID)
            }
            let thirdWebWalletAddress = currentUser.thirdWebWalletAddress
            if thirdWebWalletAddress == nil {
                _ = try await zeroApiProxy.walletsApi.initializeThirdWebWallet()
                _ = try await fetchZeroCurrentUser()
            }
        } catch {
            MXLog.error("Failed linking matrixId to zero user. Error: \(error)")
        }
    }
    
    func fetchZCurrentUser() {
        Task {
            do {
                _ = try await fetchZeroCurrentUser()
            } catch {
                MXLog.error("Failed to fetch zero current user. Error: \(error)")
            }
        }
    }
    
    func fetchUserWallets() async -> Result<[ZWallet], ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.userAccountApi.fetchWallets()
            switch result {
            case .success(let wallets):
                return .success(wallets)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch user wallets. Error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func deleteWallet(walletId: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.userAccountApi.deleteWallet(walletId: walletId)
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to delete wallet. Error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func addWallet(canAuthenticate: Bool, web3Token: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.userAccountApi.addWallet(canAuthenticate: canAuthenticate, web3Token: web3Token)
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to add wallet. Error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func fetchZeroFeeds(channelZId: String?, following: Bool, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError> {
        do {
            let zeroPostsResult = try await zeroApiProxy.postsApi.fetchPosts(channelZId: channelZId, following: following, limit: limit, skip: skip)
            switch zeroPostsResult {
            case .success(let posts):
                return .success(posts)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchFeedDetails(feedId: String) async -> Result<ZPost, ZeroClientProxyError> {
        do {
            let zeroPostResult = try await zeroApiProxy.postsApi.fetchPostDetails(postId: feedId)
            switch zeroPostResult {
            case .success(let post):
                return .success(post)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchFeedReplies(feedId: String, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError> {
        do {
            let zeroFeedRepliesResult = try await zeroApiProxy.postsApi.fetchPostReplies(postId: feedId, limit: limit, skip: skip)
            switch zeroFeedRepliesResult {
            case .success(let replies):
                return .success(replies)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func addMeowsToFeed(feedId: String, amount: Int) async -> Result<ZPost, ZeroClientProxyError> {
        do {
            let zeroAddPostMeowResult = try await zeroApiProxy.postsApi.addMeowsToPst(amount: amount, postId: feedId)
            switch zeroAddPostMeowResult {
            case .success(let post):
                return .success(post)
            case .failure(let error):
                return handleZeroError(error, fallbackError: .zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return handleZeroError(error, fallbackError: .zeroError(error))
        }
    }
    
    func postNewFeed(channelZId: String?, walletAddress: String, content: String, replyToPost: String?, mediaFile: URL?) async -> Result<Void, ZeroClientProxyError> {
        do {
            var mediaId: String? = nil
            if let mediaFile = mediaFile {
                let uploadMediaResult = try await zeroApiProxy.metaDataApi.uploadMedia(media: mediaFile)
                switch uploadMediaResult {
                case .success(let uploadedMediaId):
                    mediaId = uploadedMediaId
                case .failure(let error):
                    return .failure(.zeroError(error))
                }
            }
            let postFeedResult = try await zeroApiProxy.postsApi.createNewPost(channelZId: channelZId,
                                                                               walletAddress: walletAddress,
                                                                               content: content,
                                                                               replyToPost: replyToPost,
                                                                               mediaId: mediaId)
            switch postFeedResult {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchFeedUserProfile(userZId: String) async -> Result<ZPostUserProfile, ZeroClientProxyError> {
        do {
            let cleanedUserZId = userZId.replacingOccurrences(of: ZeroConstants.ZERO_CHANNEL_PREFIX, with: "")
            let result = try await zeroApiProxy.postUserApi.fetchUserProfile(userZId: cleanedUserZId)
            switch result {
            case .success(let profile):
                return .success(profile)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchUserFeeds(userId: String, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.postsApi.fetchUserPosts(userId: userId, limit: limit, skip: skip)
            switch result {
            case .success(let feeds):
                return .success(feeds)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchFeedUserFollowingStatus(userId: String) async -> Result<ZPostUserFollowingStatus, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.postUserApi.fetchUserFollowingStatus(userId: userId)
            switch result {
            case .success(let following):
                return .success(following)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func followFeedUser(userId: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.postUserApi.followPostUser(userId: userId)
            switch result {
            case .success(_):
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func unFollowFeedUser(userId: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.postUserApi.unFollowPostUser(userId: userId)
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func fetchUserZIds() async -> Result<[String], ZeroClientProxyError> {
        do {
            let zIdsResult = try await zeroApiProxy.channelsApi.fetchZeroIds()
            switch zIdsResult {
            case .success(let zIds):
                return .success(zIds)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func joinChannel(roomAliasOrId: String) async -> Result<String, ZeroClientProxyError> {
        do {
            let joinChannelResult = try await zeroApiProxy.channelsApi.joinChannel(roomAliasOrId: roomAliasOrId)
            switch joinChannelResult {
            case .success(let roomId):
                _ = await delegate?.joinRoom(roomAliasOrId, via: [])
                return .success(roomId)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error(error)
            return .failure(.zeroError(error))
        }
    }
    
    func initializeThirdWebWalletForUser() async -> Result<Void, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.initializeThirdWebWallet()
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to initialize third web wallet for user: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getWalletTokenBalances(walletAddress: String, nextPage: NextPageParams?) async -> Result<ZWalletTokenBalances, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getTokenBalances(walletAddress: walletAddress,
                                                                            nextPageParams: nextPage)
            switch result {
            case .success(let tokenBalances):
                return .success(tokenBalances)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch token balances for wallet address: \(walletAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getWalletNFTs(walletAddress: String, nextPage: NextPageParams?) async -> Result<ZWalletNFTs, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getNFTs(walletAddress: walletAddress,
                                                                   nextPageParams: nextPage)
            switch result {
            case .success(let nfts):
                return .success(nfts)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch nfts for wallet address: \(walletAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getWalletTransactions(walletAddress: String, nextPage: TransactionNextPageParams?) async -> Result<ZWalletTransactions, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getTransactions(walletAddress: walletAddress,
                                                                           nextPageParams: nextPage)
            switch result {
            case .success(let transactions):
                return .success(transactions)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch transactions for wallet address: \(walletAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func transferToken(senderWalletAddress: String, recipientWalletAddress: String, amount: String, tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTransactionResponse, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.transferToken(senderWalletAddress: senderWalletAddress,
                                                                         recipientWalletAddress: recipientWalletAddress,
                                                                         amount: amount,
                                                                         tokenAddress: tokenAddress,
                                                                         chainId: chainId)
            switch result {
            case .success(let transactionResponse):
                return .success(transactionResponse)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to transfer token, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func transferNFT(senderWalletAddress: String, recipientWalletAddress: String, tokenId: String, nftAddress: String) async -> Result<ZWalletTransactionResponse, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.transferNFT(senderWalletAddress: senderWalletAddress, recipientWalletAddress: recipientWalletAddress, tokenId: tokenId, nftAddress: nftAddress)
            switch result {
            case .success(let transactionResponse):
                return .success(transactionResponse)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to transfer nft, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getTransactionReceipt(transactionHash: String, chainId: UInt64?) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getTransactionReceipt(transactionHash: transactionHash, chainId: chainId)
            switch result {
            case .success(let receipt):
                return .success(receipt)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get transaction receipt, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func searchTransactionRecipient(query: String) async -> Result<[WalletRecipient], ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.searchRecipients(query: query)
            switch result {
                case .success(let recipients):
                return .success(recipients)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to search recipients, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func claimRewards(userWalletAddress: String) async -> Result<String, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.claimRewards(walletAddress: userWalletAddress)
            switch result {
            case .success(let transaction):
                return .success(transaction.transactionHash)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to claim user rewards, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getTotalStaked(poolAddress: String, chainId: UInt64) async -> Result<String, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getTotalStaked(poolAddress: poolAddress, chainId: chainId)
            switch result {
            case .success(let totalStaked):
                return .success(totalStaked)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get total staked, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getStakingConfig(poolAddress: String, chainId: UInt64) async -> Result<ZStackingConfig, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getStakingConfig(poolAddress: poolAddress, chainId: chainId)
            switch result {
            case .success(let config):
                return .success(config)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get staking config, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getStakerStatusInfo(userWalletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZStakingStatus, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getStakerStatusInfo(userWalletAddress: userWalletAddress,
                                                                               poolAddress: poolAddress,
                                                                               chainId: chainId)
            switch result {
            case .success(let status):
                return .success(status)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get staker status info, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getStakeRewardsInfo(userWalletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZStakingUserRewardsInfo, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getStakeRewardsInfo(userWalletAddress: userWalletAddress,
                                                                               poolAddress: poolAddress,
                                                                               chainId: chainId)
            switch result {
            case .success(let rewardsInfo):
                return .success(rewardsInfo)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get stake user rewards info, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getTokenInfo(tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTokenInfo, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getTokenInfo(tokenAddress: tokenAddress, chainId: chainId)
            switch result {
            case .success(let tokenInfo):
                return .success(tokenInfo)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get token info, of token: \(tokenAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getTokenBalance(userWalletAddress: String, tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTokenBalance, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getTokenBalance(walletAddress: userWalletAddress, tokenAddress: tokenAddress, chainId: chainId)
            switch result {
            case .success(let tokenBalance):
                return .success(tokenBalance)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get token balance, of token: \(tokenAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getAvaxTokenPrice(tokenAddress: String) async -> Result<ZAvaxTokenPrice, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.walletsApi.getAvaxTokenPrice(tokenAddress: tokenAddress)
            switch result {
            case .success(let price):
                return .success(price)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch avax token price, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getStakingToken(poolAddress: String, chainId: UInt64) async -> Result<ZWalletStakingToken, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getStakingToken(poolAddress: poolAddress, chainId: chainId)
            switch result {
            case .success(let token):
                return .success(token)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get staking token, of pool: \(poolAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getRewardsToken(poolAddress: String, chainId: UInt64) async -> Result<ZWalletStakingRewardsToken, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.getRewardsToken(poolAddress: poolAddress, chainId: chainId)
            switch result {
            case .success(let token):
                return .success(token)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to get reward token, of pool: \(poolAddress), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func stakeAmount(walletAddress: String, poolAddress: String, tokenAddress: String, amount: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError> {
        do {
            // 1. Send approval request
            let approveResult = try await zeroApiProxy.walletsApi.approveERC20(
                walletAddress: walletAddress,
                poolAddress: poolAddress,
                tokenAddress: tokenAddress,
                amount: amount,
                chainId: chainId
            )
            
            let transaction = try approveResult.get()
            
            // 2. Verify approval transaction
            let _ = try await zeroApiProxy.walletsApi.getTransactionReceipt(
                transactionHash: transaction.transactionHash,
                chainId: chainId
            ).get()
            
            // 3. Verify approval request
            try await zeroApiProxy.walletsApi.verifyERC20Approval(
                walletAddress: walletAddress,
                poolAddress: poolAddress,
                tokenAddress: tokenAddress,
                chainId: chainId
            ).get()
            
            // 4. Stake amount
            let stakeTransaction = try await zeroApiProxy.stakingApi.stakeAmount(
                userWalletAddress: walletAddress,
                poolAddress: poolAddress,
                amount: amount,
                chainId: chainId
            ).get()
            
            // 5. Get final transaction receipt
            let finalReceipt = try await zeroApiProxy.walletsApi.getTransactionReceipt(
                transactionHash: stakeTransaction.transactionHash,
                chainId: chainId
            ).get()
            
            return .success(finalReceipt)
        } catch {
            MXLog.error("Failed to stake amount, with error: \(error)")
            return handleZeroError(error, fallbackError: .zeroError(error))
        }
    }
    
    func unstakeAmount(walletAddress: String, poolAddress: String, amount: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.unstakeAmount(userWalletAddress: walletAddress,
                                                                         poolAddress: poolAddress,
                                                                         amount: amount,
                                                                         chainId: chainId)
            switch result {
            case .success(let transaction):
                let receiptResult = try await zeroApiProxy.walletsApi.getTransactionReceipt(transactionHash: transaction.transactionHash, chainId: chainId)
                switch receiptResult {
                case .success(let receipt):
                    return .success(receipt)
                case .failure(let error):
                    return .failure(.zeroError(error))
                }
            case .failure(let error):
                return handleZeroError(error, fallbackError: .zeroError(error))
            }
        } catch {
            MXLog.error("Failed to unstake amount, with error: \(error)")
            return handleZeroError(error, fallbackError: .zeroError(error))
        }
    }
    
    func claimStakeRewards(walletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.stakingApi.claimStakeRewards(userWalletAddress: walletAddress,
                                                                             poolAddress: poolAddress,
                                                                             chainId: chainId)
            switch result {
            case .success(let transaction):
                let receiptResult = try await zeroApiProxy.walletsApi.getTransactionReceipt(transactionHash: transaction.transactionHash, chainId: chainId)
                switch receiptResult {
                case .success(let receipt):
                    return .success(receipt)
                case .failure(let error):
                    return .failure(.zeroError(error))
                }
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to claim stake rewards, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getLinkPreviewMetaData(url: String) async -> Result<ZLinkPreview, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.metaDataApi.getLinkPreview(url: url)
            switch result {
            case .success(let linkPreview):
                return .success(linkPreview)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch link preview of url: \(url), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func getPostMediaInfo(mediaId: String) async -> Result<ZPostMedia, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.metaDataApi.getPostMediaInfo(mediaId: mediaId, isPreview: true)
            switch result {
            case .success(let media):
                return .success(media)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to fetch post media with id: \(mediaId), with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func fetchYoutubeLinkMetaData(youtubrUrl: String) async -> Result<ZLinkPreview, ZeroClientProxyError> {
        do {
            let result = try await zeroApiProxy.metaDataApi.fetchYoutubeLinkMetaData(youtubeUrl: youtubrUrl)
            switch result {
            case .success(let metaData):
                return .success(metaData)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to youtube url(\(youtubrUrl)) meta data, with error: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    func loadFileFromUrl(_ remoteUrl: URL, key: String) async throws -> Result<URL, ZeroClientProxyError> {
        let result = try await zeroApiProxy.metaDataApi.loadFileFromUrl(remoteUrl, key: key)
        switch result {
        case .success(let localURL):
            return .success(localURL)
        case .failure(let error):
            return .failure(.zeroError(error))
        }
    }
    
    func loadFileFromMediaId(_ mediaId: String, key: String) async throws -> Result<URL, ZeroClientProxyError> {
        let result = try await zeroApiProxy.metaDataApi.loadFileFromMediaId(mediaId, key: key)
        switch result {
        case .success(let localURL):
            return .success(localURL)
        case .failure(let error):
            return .failure(.zeroError(error))
        }
    }
    
    func verifyUserPassword(_ password: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            let verifyPasswordResult = try await zeroApiProxy.userAccountApi.verifyPassword(password: password)
            switch verifyPasswordResult {
            case .success:
                return .success(())
            case .failure(let error):
                MXLog.error("Failed to verify password: \(error)")
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to verify password: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    // MARK: - ZERO SUBSCRIPTION
    
    func syncSubscriptions() async {
        await zeroApiProxy.subscriptionApi.syncSubscriptions()
    }
    
    func fetchZeroSubscriptionSKU() async throws -> Product? {
        return try await zeroApiProxy.subscriptionApi.fetchZeroSubscriptionSKU()
    }
    
    func subscribeToZeroPro(sku: Product, metaData: [String : String]) async throws -> (Product.PurchaseResult, StoreKit.Transaction?) {
        return try await zeroApiProxy.subscriptionApi.subscribeToZeroPro(sku: sku, metaData: metaData)
    }
    
    func getSubscriptionExpirationDate(product: Product) async -> Date? {
        return await zeroApiProxy.subscriptionApi.getSubscriptionExpirationDate(product: product)
    }
    
    // MARK: - MATRIX APIS
    
    func resetExistingBackup() async -> Result<Void, ZeroClientProxyError> {
        guard let matrixApiProxy else { return .failure(.matrixApiClientNotInitialised) }
        
        let backupVersionResult = await getKeyBackupVersion()
        switch backupVersionResult {
        case .success(let backup):
            let deleteResult = await deleteBackupVersion(version: backup.version)
            switch deleteResult {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        case .failure(let failure):
            return .failure(.zeroError(failure))
        }
    }
    
    private func getKeyBackupVersion() async -> Result<MatrixBackupVersion, ZeroClientProxyError> {
        do {
            guard let matrixApiProxy else { return .failure(.matrixApiClientNotInitialised) }
            let result = try await matrixApiProxy.e2eEncryptionApi.getBackupVersion()
            switch result {
            case .success(let backupVersion):
                return .success(backupVersion)
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            MXLog.error("Failed to retrieve key backup version: \(error)")
            return .failure(.zeroError(error))
        }
    }
    
    private func deleteBackupVersion(version: String) async -> Result<Void, ZeroClientProxyError> {
        do {
            guard let matrixApiProxy else { return .failure(.matrixApiClientNotInitialised) }
            let result = try await matrixApiProxy.e2eEncryptionApi.deleteBackupVersion(version: version)
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(.zeroError(error))
            }
        } catch {
            return .failure(.zeroError(error))
        }
    }
    
    // MARK: - Private
    
    private func handleZeroError<T>(
        _ error: Error,
        fallbackError: ZeroClientProxyError
    ) -> Result<T, ZeroClientProxyError> {
        if let apiError = error as? APIErrorResponse {
            switch apiError.code {
            case "INSUFFICIENT_BALANCE":
                return .failure(.insufficientGasBalance)
            case "INSUFFICIENT_MEOW_BALANCE":
                return .failure(.insufficientMeowBalance)
            default:
                return .failure(fallbackError)
            }
        } else {
            return .failure(fallbackError)
        }
    }
    
    private func fetchZeroCurrentUser() async throws -> ZCurrentUser? {
        let currentUser = try await zeroApiProxy.matrixUsersService.fetchCurrentUser()
        if currentUser != nil {
            zeroCurrentUserSubject.send(currentUser!)
        }
        return currentUser
    }
}
