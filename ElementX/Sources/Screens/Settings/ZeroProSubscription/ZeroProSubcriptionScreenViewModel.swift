//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI
import StoreKit

typealias ZeroProSubcriptionScreenViewModelType = StateStoreViewModel<ZeroProSubcriptionScreenViewState, ZeroProSubcriptionScreenViewAction>

class ZeroProSubcriptionScreenViewModel: ZeroProSubcriptionScreenViewModelType, ZeroProSubcriptionScreenViewModelProtocol {
    
    private let clientProxy: ClientProxyProtocol
    private let zeroClientProxy: ZeroClientProxyProtocol
    
    private var zeroProSubscriptionProduct: Product?
    
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
            }
            .store(in: &cancellables)
        
        // Fetch Zero Pro Subscription Product
        fetchZeroProSubscription()
    }
    
    override func process(viewAction: ZeroProSubcriptionScreenViewAction) {
        switch viewAction {
        case .purchaseSubscriptionTapped:
            purchaseZeroProSubscription()
        }
    }
    
    private func fetchZeroProSubscription() {
        Task {
            do {
                if let zeroProSubscription = try await zeroClientProxy.fetchZeroSubscriptionSKU() {
                    zeroProSubscriptionProduct = zeroProSubscription
                    state.canPurchaseSubscription = true
                    await fetchSubscriptionExpiration(zeroProSubscription)
                } else {
                    state.canPurchaseSubscription = false
                }
            } catch {
                MXLog.error("Failed to fetch zero pro subscription product: \(error)")
                state.canPurchaseSubscription = false
            }
        }
    }
    
    private func fetchSubscriptionExpiration(_ zeroProSubscription: Product) async {
        state.subscriptionExpiration = await zeroClientProxy.getSubscriptionExpirationDate(product: zeroProSubscription)
    }
    
    private func purchaseZeroProSubscription() {
        guard let zeroProSubscriptionProduct else {
            return
        }
        Task {
            do {
                var metaData: [String: String] = [:]
                if let currentUser = state.currentUser {
                    metaData["user_id"] = currentUser.id.rawValue
                }
                let result = try await zeroClientProxy.subscribeToZeroPro(sku: zeroProSubscriptionProduct, metaData: metaData)
                if case .success(_) = result.0 {
                    clientProxy.zeroClient.fetchZCurrentUser()
                }
            } catch {
                MXLog.error("Failed to purchase zero pro subscription: \(error)")
            }
        }
    }
}
