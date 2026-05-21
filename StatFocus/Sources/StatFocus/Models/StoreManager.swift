// StatFocus/Models/StoreManager.swift
// StoreKit 2 wrapper for the single non-consumable IAP "StatFocus Premium".
// App Store build only — Dev ID distribution doesn't transact with the App Store.
#if APP_STORE
import Foundation
import StoreKit
import Observation

@Observable
@MainActor
final class StoreManager {
    static let shared = StoreManager()

    static let productID = "com.thiagogruber.statfocus.premium"

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case userCancelled
        case failed(String)
    }

    private(set) var product: Product?
    private(set) var loadState: LoadState = .idle
    private(set) var purchaseState: PurchaseState = .idle

    /// Localized display price (e.g. "R$ 24,00"). Returns nil before the product loads.
    var displayPrice: String? { product?.displayPrice }

    private init() {
        // Listen for transactions arriving outside of an active purchase flow:
        // restores, parental approvals, purchases made on other devices via Family Sharing, etc.
        // No cancel needed — StoreManager is a process-lifetime singleton.
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    // MARK: - Public API

    /// Load the single Premium product so we can show its localized price in the paywall.
    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: [Self.productID])
            guard let p = products.first else {
                loadState = .failed("product_not_found")
                return
            }
            product = p
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Refresh the entitlement on launch — covers the case where the user bought on another device
    /// or restored from a backup.
    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            await handle(transactionResult: result)
        }
    }

    /// Start a purchase flow.
    func buy() async {
        guard let product else {
            purchaseState = .failed("product_not_loaded")
            return
        }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification: verification)
                purchaseState = .success
            case .userCancelled:
                purchaseState = .userCancelled
            case .pending:
                // Awaiting parental approval or external action. The transaction listener will
                // pick it up when (if) it resolves.
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed("unknown_result")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    /// Sync purchases — same outcome as restoreCompletedTransactions on StoreKit 1.
    /// Apple requires a visible "Restore Purchases" affordance for App Store apps.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Internal

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else {
            // Unverified — drop silently. Don't grant entitlement on tampered receipts.
            return
        }
        if transaction.productID == Self.productID && transaction.revocationDate == nil {
            TrialState.shared.isPremium = true
        } else if transaction.revocationDate != nil {
            TrialState.shared.isPremium = false
        }
        await transaction.finish()
    }

    private func handle(verification: VerificationResult<Transaction>) async {
        await handle(transactionResult: verification)
    }
}
#endif
