//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import CryptoKit
import SwiftUI
import StoreKit

typealias ZeroProSubcriptionScreenViewModelType = StateStoreViewModel<ZeroProSubcriptionScreenViewState, ZeroProSubcriptionScreenViewAction>

class ZeroProSubcriptionScreenViewModel: ZeroProSubcriptionScreenViewModelType, ZeroProSubcriptionScreenViewModelProtocol {

    private let clientProxy: ClientProxyProtocol
    private let zeroClientProxy: ZeroClientProxyProtocol

    private var zeroProSubscriptionProduct: Product?

    /// Deterministic UUID generated from the user's ID for StoreKit App Account Token
    private var appAccountToken: UUID? {
        guard let userId = state.currentUser?.id.rawValue else { return nil }
        return UUID.fromDeterministicString(userId)
    }

    init(userSession: UserSessionProtocol) {
        self.clientProxy = userSession.clientProxy
        self.zeroClientProxy = userSession.clientProxy.zeroClient

        super.init(
            initialViewState: .init(bindings: .init())
        )

        userSession.clientProxy.zeroClient.zeroCurrentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currentUser in
                self?.state.currentUser = currentUser
                self?.state.isZeroProSubscriber = currentUser.subscriptions.zeroPro
                // Re-check subscription ownership when user changes
                self?.checkSubscriptionOwnership()
            }
            .store(in: &cancellables)

        // Fetch Zero Pro Subscription Product
        fetchZeroProSubscription()
    }
    
    override func process(viewAction: ZeroProSubcriptionScreenViewAction) {
        switch viewAction {
        case .purchaseSubscriptionTapped:
            purchaseZeroProSubscription()
        case .restorePurchasesTapped:
            restorePurchases()
        }
    }
    
    private func fetchZeroProSubscription() {
        Task {
            do {
                if let zeroProSubscription = try await zeroClientProxy.fetchZeroSubscriptionSKU() {
                    zeroProSubscriptionProduct = zeroProSubscription
                    state.canPurchaseSubscription = true
                    await checkSubscriptionOwnership()
                } else {
                    state.canPurchaseSubscription = false
                }
            } catch {
                MXLog.error("Failed to fetch zero pro subscription product: \(error)")
                state.canPurchaseSubscription = false
            }
        }
    }

    private func checkSubscriptionOwnership() {
        guard let product = zeroProSubscriptionProduct,
              let token = appAccountToken else {
            return
        }
        Task {
            let isOwned = await zeroClientProxy.isSubscriptionOwnedByUser(product: product, appAccountToken: token)
            state.isSubscriptionOwnedByCurrentUser = isOwned
            if isOwned {
                state.subscriptionExpiration = await zeroClientProxy.getSubscriptionExpirationDate(product: product, appAccountToken: token)
            } else {
                state.subscriptionExpiration = nil
            }
        }
    }

    private func purchaseZeroProSubscription() {
        guard let zeroProSubscriptionProduct,
              let token = appAccountToken else {
            return
        }
        Task {
            do {
                let result = try await zeroClientProxy.subscribeToZeroPro(sku: zeroProSubscriptionProduct, appAccountToken: token)
                if case .success(_) = result.0 {
                    clientProxy.zeroClient.fetchZCurrentUser()
                    await checkSubscriptionOwnership()
                }
            } catch {
                MXLog.error("Failed to purchase zero pro subscription: \(error)")
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                try await zeroClientProxy.restorePurchases()
                clientProxy.zeroClient.fetchZCurrentUser()
                await checkSubscriptionOwnership()
            } catch {
                MXLog.error("Failed to restore purchases: \(error)")
            }
        }
    }
}

// MARK: - UUID Extension for Deterministic Generation

private extension UUID {
    /// Creates a deterministic UUID from a string using SHA256 hash
    static func fromDeterministicString(_ string: String) -> UUID {
        let hash = SHA256.hash(data: Data(string.utf8))
        let hashBytes = Array(hash)
        // Use first 16 bytes of the hash to create a UUID
        return UUID(uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
    }
}
