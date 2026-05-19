import Foundation
import OkiMissionCore

public actor InMemoryEntitlementService: EntitlementServicing {
    private var entitlement: Entitlement
    private var offerings: [ProductOffering]
    private let continuation: AsyncStream<Entitlement>.Continuation
    public nonisolated let stream: AsyncStream<Entitlement>

    public init(
        initialEntitlement: Entitlement = .free,
        offerings: [ProductOffering] = InMemoryEntitlementService.defaultOfferings
    ) {
        self.entitlement = initialEntitlement
        self.offerings = offerings
        let (stream, continuation) = AsyncStream.makeStream(of: Entitlement.self)
        self.stream = stream
        self.continuation = continuation
    }

    public var currentEntitlement: Entitlement {
        get async { entitlement }
    }

    public func loadOfferings() async throws -> [ProductOffering] {
        offerings
    }

    public func purchase(productId: String) async throws -> PurchaseResult {
        guard let product = offerings.first(where: { $0.id == productId }) else {
            throw EntitlementError.productNotFound(productId)
        }
        let expires: Date
        if product.id.contains("yearly") || product.id.contains("annual") {
            expires = Date(timeIntervalSinceNow: 365 * 24 * 3600)
        } else {
            expires = Date(timeIntervalSinceNow: 30 * 24 * 3600)
        }
        let next = Entitlement(
            tier: .pro,
            expiresAt: expires,
            willRenew: true,
            isInTrial: product.hasIntroOffer
        )
        entitlement = next
        continuation.yield(next)
        return .purchased(next)
    }

    public func restorePurchases() async throws -> Entitlement {
        continuation.yield(entitlement)
        return entitlement
    }

    public func setEntitlement(_ next: Entitlement) {
        entitlement = next
        continuation.yield(next)
    }

    public func setOfferings(_ next: [ProductOffering]) {
        offerings = next
    }

    public static let defaultOfferings: [ProductOffering] = [
        ProductOffering(
            id: "com.example.okimission.pro.monthly",
            displayName: "Pro Monthly",
            localizedPrice: "¥600",
            periodDescription: "month",
            hasIntroOffer: true,
            introOfferDescription: "3 days free"
        ),
        ProductOffering(
            id: "com.example.okimission.pro.yearly",
            displayName: "Pro Annual",
            localizedPrice: "¥4,800",
            periodDescription: "year",
            hasIntroOffer: true,
            introOfferDescription: "7 days free"
        )
    ]
}
