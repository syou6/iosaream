import Foundation
import OkiMissionCore

public struct Entitlement: Sendable, Equatable, Codable {
    public var tier: SubscriptionTier
    public var expiresAt: Date?
    public var willRenew: Bool
    public var isInTrial: Bool
    public var familyShared: Bool

    public init(
        tier: SubscriptionTier,
        expiresAt: Date? = nil,
        willRenew: Bool = false,
        isInTrial: Bool = false,
        familyShared: Bool = false
    ) {
        self.tier = tier
        self.expiresAt = expiresAt
        self.willRenew = willRenew
        self.isInTrial = isInTrial
        self.familyShared = familyShared
    }

    public var isPro: Bool { tier == .pro }
    public static let free = Entitlement(tier: .free)
}

public struct ProductOffering: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public var displayName: String
    public var localizedPrice: String
    public var periodDescription: String
    public var hasIntroOffer: Bool
    public var introOfferDescription: String?

    public init(
        id: String,
        displayName: String,
        localizedPrice: String,
        periodDescription: String,
        hasIntroOffer: Bool = false,
        introOfferDescription: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.localizedPrice = localizedPrice
        self.periodDescription = periodDescription
        self.hasIntroOffer = hasIntroOffer
        self.introOfferDescription = introOfferDescription
    }
}

public enum PurchaseResult: Sendable, Equatable {
    case purchased(Entitlement)
    case cancelled
    case pending
}

public enum EntitlementError: Error, Equatable, Sendable {
    case productNotFound(String)
    case offeringsUnavailable
    case purchaseFailed(String)
}

public protocol EntitlementServicing: Sendable {
    var currentEntitlement: Entitlement { get async }
    var stream: AsyncStream<Entitlement> { get }

    func loadOfferings() async throws -> [ProductOffering]
    func purchase(productId: String) async throws -> PurchaseResult
    func restorePurchases() async throws -> Entitlement
}
