//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import StoreKitPlus
import StoreKit

protocol ZeroSubscriptionServiceProtocol {
    func syncSubscriptions() async

    func fetchZeroSubscriptionSKU() async throws -> Product?

    func subscribeToZeroPro(sku: Product, appAccountToken: UUID) async throws -> (Product.PurchaseResult, StoreKit.Transaction?)

    func getSubscriptionExpirationDate(product: Product, appAccountToken: UUID) async -> Date?

    func isSubscriptionOwnedByUser(product: Product, appAccountToken: UUID) async -> Bool

    func restorePurchases() async throws

    func clearCache()
}

class ZeroSubscriptionService: ZeroSubscriptionServiceProtocol {

    private var storeContext: StoreContext
    private let storeService: StandardStoreService

    init() {
        let products = ZeroSubscriptions.allCases
        storeContext = StoreContext()
        storeService = StandardStoreService(products: products)
    }
    
    func syncSubscriptions() async {
        do {
            try await storeService.syncStoreData(to: storeContext)
        } catch {
            MXLog.error("Failed to sync store data: \(error)")
        }
    }
    
    func fetchZeroSubscriptionSKU() async throws -> Product? {
        await syncSubscriptions()
        let products = try await storeService.getProducts()
        return products.first
    }
    
    func subscribeToZeroPro(sku: Product, appAccountToken: UUID) async throws -> (Product.PurchaseResult, StoreKit.Transaction?) {
        let options: Set<Product.PurchaseOption> = [.appAccountToken(appAccountToken)]
        let result = try await storeService.purchase(sku, options: options)
        if case .success(_) = result.0 {
            await syncSubscriptions()
        }
        return result
    }
    
    func getSubscriptionExpirationDate(product: Product, appAccountToken: UUID) async -> Date? {
        guard let subscription = product.subscription else {
            return nil
        }

        do {
            let statuses = try await subscription.status
            // Find active status that belongs to this user (matching appAccountToken)
            if let activeStatus = statuses.first(where: { status in
                guard case .subscribed = status.state,
                      case .verified(let transaction) = status.transaction,
                      transaction.appAccountToken == appAccountToken else {
                    return false
                }
                return true
            }) {
                let transaction = try checkVerified(activeStatus.transaction)
                return transaction.expirationDate
            }
        } catch {
            MXLog.error("Error fetching subscription status: \(error)")
        }
        return nil
    }

    func isSubscriptionOwnedByUser(product: Product, appAccountToken: UUID) async -> Bool {
        guard let subscription = product.subscription else {
            return false
        }

        do {
            let statuses = try await subscription.status
            return statuses.contains { status in
                switch status.state {
                case .subscribed, .inBillingRetryPeriod, .inGracePeriod:
                    if case .verified(let transaction) = status.transaction {
                        return transaction.appAccountToken == appAccountToken
                    }
                    return false
                default:
                    return false
                }
            }
        } catch {
            MXLog.error("Error checking subscription ownership: \(error)")
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await syncSubscriptions()
    }

    func clearCache() {
        storeContext = StoreContext()
    }

    // A simple helper function to unwrap the VerificationResult
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            // Handle unverified data as per your security requirements
            print("Warning: Unverified data - \(error)")
            throw error // Or return unverified data if acceptable
        case .verified(let verified):
            return verified
        }
    }
}
