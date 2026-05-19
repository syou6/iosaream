import Foundation
import OkiMissionCore
import OkiMissionServices

// Wraps RevenueCat's Purchases SDK in our EntitlementServicing protocol.
// Requires the RevenueCat SPM dependency to be added to the App target.
// Once added, change `#if canImport(RevenueCat)` so this file compiles.

#if canImport(RevenueCat) && os(iOS)
import RevenueCat

public actor RevenueCatEntitlementService: EntitlementServicing {
    private let entitlementId: String
    private let continuation: AsyncStream<Entitlement>.Continuation
    public nonisolated let stream: AsyncStream<Entitlement>
    private var bootstrapped = false
    private var cached: Entitlement = .free
    private var listenerTask: Task<Void, Never>?

    public init(entitlementId: String = "pro") {
        self.entitlementId = entitlementId
        let (stream, continuation) = AsyncStream.makeStream(of: Entitlement.self)
        self.stream = stream
        self.continuation = continuation
    }

    public var currentEntitlement: Entitlement {
        get async { cached }
    }

    public func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        if let info = try? await Purchases.shared.customerInfo() {
            cached = Self.translate(info: info, entitlementId: entitlementId)
        }
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                let next = Self.translate(info: info, entitlementId: self.entitlementId)
                await self.update(next)
            }
        }
    }

    private func update(_ next: Entitlement) {
        cached = next
        continuation.yield(next)
    }

    public func loadOfferings() async throws -> [ProductOffering] {
        let offerings = try await Purchases.shared.offerings()
        guard let current = offerings.current else { throw EntitlementError.offeringsUnavailable }
        return current.availablePackages.map { package in
            let storeProduct = package.storeProduct
            return ProductOffering(
                id: storeProduct.productIdentifier,
                displayName: storeProduct.localizedTitle,
                localizedPrice: storeProduct.localizedPriceString,
                periodDescription: storeProduct.subscriptionPeriod?.unit.debugDescription ?? "",
                hasIntroOffer: storeProduct.introductoryDiscount != nil,
                introOfferDescription: storeProduct.introductoryDiscount?.localizedPriceString
            )
        }
    }

    public func purchase(productId: String) async throws -> PurchaseResult {
        let offerings = try await Purchases.shared.offerings()
        guard let package = offerings.current?.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productId
        }) else {
            throw EntitlementError.productNotFound(productId)
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                return .cancelled
            }
            let next = Self.translate(info: result.customerInfo, entitlementId: entitlementId)
            update(next)
            return .purchased(next)
        } catch {
            throw EntitlementError.purchaseFailed(error.localizedDescription)
        }
    }

    public func restorePurchases() async throws -> Entitlement {
        let info = try await Purchases.shared.restorePurchases()
        let next = Self.translate(info: info, entitlementId: entitlementId)
        update(next)
        return next
    }

    private static func translate(info: CustomerInfo, entitlementId: String) -> Entitlement {
        guard let entitlement = info.entitlements[entitlementId], entitlement.isActive else {
            return .free
        }
        return Entitlement(
            tier: .pro,
            expiresAt: entitlement.expirationDate,
            willRenew: entitlement.willRenew,
            isInTrial: entitlement.periodType == .trial,
            familyShared: entitlement.ownershipType == .familyShared
        )
    }
}
#endif
