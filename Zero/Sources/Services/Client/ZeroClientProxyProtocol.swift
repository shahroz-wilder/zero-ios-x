//
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

enum ZeroClientProxyError: Error {
    case zeroError(Error)

    case failedCompletingUserProfile
    
    case insufficientGasBalance
    case insufficientMeowBalance
    
    case matrixApiClientNotInitialised
    
    
}

// sourcery: AutoMockable
protocol ZeroClientProxyProtocol: AnyObject {
    
    var matrixUserService: ZeroMatrixUsersService { get }
    
    var chatApi: ZeroChatApiProtocol { get }
    
    func setDelegate(_ delegate: ZeroClientProxyDelegate)
    
    func verifyUserPassword(_ password: String) async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO REWARDS
    
    var userRewardsPublisher: CurrentValuePublisher<ZeroRewards, Never> { get }
    
    var showNewUserRewardsIntimationPublisher: CurrentValuePublisher<Bool, Never> { get }
    
    func getUserRewards(shouldCheckRewardsIntiamtion: Bool) async -> Result<Void, ZeroClientProxyError>
    
    func getZeroMeowPrice() async -> Result<ZeroCurrency, ZeroClientProxyError>
    
    func dismissRewardsIntimation()
    
    // MARK: - ZERO MESSENGER INVITE
    
    var messengerInvitePublisher: CurrentValuePublisher<ZeroMessengerInvite, Never> { get }
    
    @discardableResult func loadZeroMessengerInvite() async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO CREATE ACCOUNT
    
    func isProfileCompletionRequired() async -> Bool
    
    func completeUserAccountProfile(avatar: MediaInfo?, displayName: String, inviteCode: String) async -> Result<Void, ZeroClientProxyError>
    
    func deleteUserAccount() async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO USER
    
    var directMemberZeroProfilePublisher: CurrentValuePublisher<ZMatrixUser?, Never> { get }
    
    var zeroCurrentUserPublisher: CurrentValuePublisher<ZCurrentUser, Never> { get }
    
    var homeRoomSummariesUsersPublisher: CurrentValuePublisher<[ZMatrixUser], Never> { get }
        
    func zeroProfile(userId: String) async
    
    func zeroProfiles(userIds: Set<String>) async
    
    func checkAndLinkZeroUser() async
    
    func fetchZCurrentUser()
    
    func fetchUserWallets() async -> Result<[ZWallet], ZeroClientProxyError>
    
    func deleteWallet(walletId: String) async -> Result<Void, ZeroClientProxyError>
    
    func addWallet(canAuthenticate: Bool, web3Token: String) async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO FEED
    
    func fetchZeroFeeds(channelZId: String?, following: Bool, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError>
    
    func fetchFeedDetails(feedId: String) async -> Result<ZPost, ZeroClientProxyError>
    
    func fetchFeedReplies(feedId: String, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError>
    
    func addMeowsToFeed(feedId: String, amount: Int) async -> Result<ZPost, ZeroClientProxyError>
    
    func postNewFeed(channelZId: String?, walletAddress: String, content: String, replyToPost: String?, mediaFile: URL?) async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO FEED USER
    
    func fetchFeedUserProfile(userZId: String) async -> Result<ZPostUserProfile, ZeroClientProxyError>
    
    func fetchUserFeeds(userId: String, limit: Int, skip: Int) async -> Result<[ZPost], ZeroClientProxyError>
    
    func fetchFeedUserFollowingStatus(userId: String) async -> Result<ZPostUserFollowingStatus, ZeroClientProxyError>
    
    func followFeedUser(userId: String) async -> Result<Void, ZeroClientProxyError>
    
    func unFollowFeedUser(userId: String) async -> Result<Void, ZeroClientProxyError>
    
    // MARK: - ZERO CHANNEL
    
    func fetchUserZIds() async -> Result<[String], ZeroClientProxyError>
    
    func joinChannel(roomAliasOrId: String) async -> Result<String, ZeroClientProxyError>
    
    // MARK: - ZERO WALLET
    
    func initializeThirdWebWalletForUser() async -> Result<Void, ZeroClientProxyError>
    
    func getWalletTokenBalances(walletAddress: String, nextPage: NextPageParams?) async -> Result<ZWalletTokenBalances, ZeroClientProxyError>
    
    func getWalletNFTs(walletAddress: String, nextPage: NextPageParams?) async -> Result<ZWalletNFTs, ZeroClientProxyError>
    
    func getWalletTransactions(walletAddress: String, nextPage: TransactionNextPageParams?) async -> Result<ZWalletTransactions, ZeroClientProxyError>
    
    func transferToken(senderWalletAddress: String, recipientWalletAddress: String, amount: String, tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTransactionResponse, ZeroClientProxyError>
    
    func transferNFT(senderWalletAddress: String, recipientWalletAddress: String, tokenId: String, nftAddress: String) async -> Result<ZWalletTransactionResponse, ZeroClientProxyError>
    
    func getTransactionReceipt(transactionHash: String, chainId: UInt64?) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError>
    
    func searchTransactionRecipient(query: String) async -> Result<[WalletRecipient], ZeroClientProxyError>
    
    func claimRewards(userWalletAddress: String) async -> Result<String, ZeroClientProxyError>
    
    func getTokenInfo(tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTokenInfo, ZeroClientProxyError>
    
    func getTokenBalance(userWalletAddress: String, tokenAddress: String, chainId: UInt64) async -> Result<ZWalletTokenBalance, ZeroClientProxyError>
    
    func getAvaxTokenPrice(tokenAddress: String) async -> Result<ZAvaxTokenPrice, ZeroClientProxyError>
    
    // MARK: - ZERO STAKING
    
    func getTotalStaked(poolAddress: String, chainId: UInt64) async -> Result<String, ZeroClientProxyError>
    
    func getStakingConfig(poolAddress: String, chainId: UInt64) async -> Result<ZStackingConfig, ZeroClientProxyError>
    
    func getStakerStatusInfo(userWalletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZStakingStatus, ZeroClientProxyError>
    
    func getStakeRewardsInfo(userWalletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZStakingUserRewardsInfo, ZeroClientProxyError>
    
    func getStakingToken(poolAddress: String, chainId: UInt64) async -> Result<ZWalletStakingToken, ZeroClientProxyError>
    
    func getRewardsToken(poolAddress: String, chainId: UInt64) async -> Result<ZWalletStakingRewardsToken, ZeroClientProxyError>
    
    func stakeAmount(walletAddress: String, poolAddress: String, tokenAddress: String, amount: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError>
    
    func unstakeAmount(walletAddress: String, poolAddress: String, amount: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError>
    
    func claimStakeRewards(walletAddress: String, poolAddress: String, chainId: UInt64) async -> Result<ZWalletTransactionReceipt, ZeroClientProxyError>
    
    // MARK: - ZERO METADATA
    
    func getLinkPreviewMetaData(url: String) async -> Result<ZLinkPreview, ZeroClientProxyError>
    
    func getPostMediaInfo(mediaId: String) async -> Result<ZPostMedia, ZeroClientProxyError>
    
    func fetchYoutubeLinkMetaData(youtubrUrl: String) async -> Result<ZLinkPreview, ZeroClientProxyError>
    
    func loadFileFromUrl(_ remoteUrl: URL, key: String) async throws -> Result<URL, ZeroClientProxyError>
    
    func loadFileFromMediaId(_ mediaId: String, key: String) async throws -> Result<URL, ZeroClientProxyError>
    
    // MARK: - MATRIX APIS
    
    func resetExistingBackup() async -> Result<Void, ZeroClientProxyError>
}
