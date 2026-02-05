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
    
    func subscribeToZeroPro(sku: Product, metaData: [String: String]) async throws -> (Product.PurchaseResult, StoreKit.Transaction?)
    
    func getSubscriptionExpirationDate(product: Product) async -> Date?
}

class ZeroSubscriptionService: ZeroSubscriptionServiceProtocol {
    
    private let storeContext: StoreContext
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
    
    func subscribeToZeroPro(sku: Product, metaData: [String : String]) async throws -> (Product.PurchaseResult, StoreKit.Transaction?) {
        var options: Set<Product.PurchaseOption> = []
        if !metaData.isEmpty {
            metaData.forEach { options.insert(.custom(key: $0.key, value: $0.value)) }
        }
        let result = try await storeService.purchase(sku, options: options)
        if case .success(_) = result.0 {
            await syncSubscriptions()
        }
        return result
    }
    
    func getSubscriptionExpirationDate(product: Product) async -> Date? {
        guard let subscription = product.subscription else {
            // Not a subscription product
            return nil
        }

        do {
            // Get the subscription statuses (usually only one active status per group)
            let statuses = try await subscription.status
            // Find the active status (example: choosing the highest level of service)
            if let activeStatus = statuses.first(where: { status in
                switch status.state {
                case .subscribed, .inBillingRetryPeriod, .inGracePeriod:
                    return true
                default:
                    return false
                }
            }) {
                // Verify the transaction
                let transaction = try checkVerified(activeStatus.transaction)
                // The expirationDate is the next billing date
                return transaction.expirationDate
            }
        } catch {
            print("Error fetching subscription status: \(error)")
        }
        return nil
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
