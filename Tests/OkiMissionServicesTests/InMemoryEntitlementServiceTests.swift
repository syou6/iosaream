import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

@Suite("InMemoryEntitlementService")
struct InMemoryEntitlementServiceTests {
    @Test("starts at free tier by default")
    func startsFree() async {
        let service = InMemoryEntitlementService()
        let entitlement = await service.currentEntitlement
        #expect(entitlement == .free)
    }

    @Test("loadOfferings returns at least monthly and yearly")
    func defaultOfferings() async throws {
        let service = InMemoryEntitlementService()
        let offerings = try await service.loadOfferings()
        #expect(offerings.contains { $0.id.contains("monthly") })
        #expect(offerings.contains { $0.id.contains("yearly") })
    }

    @Test("purchasing monthly elevates to pro")
    func purchaseMonthly() async throws {
        let service = InMemoryEntitlementService()
        let result = try await service.purchase(productId: "com.example.okimission.pro.monthly")
        guard case .purchased(let entitlement) = result else {
            Issue.record("expected purchased result")
            return
        }
        #expect(entitlement.isPro)
        let current = await service.currentEntitlement
        #expect(current.isPro)
    }

    @Test("purchasing yearly elevates with longer expiry than monthly")
    func purchaseYearly() async throws {
        let service = InMemoryEntitlementService()
        let result = try await service.purchase(productId: "com.example.okimission.pro.yearly")
        guard case .purchased(let entitlement) = result else {
            Issue.record("expected purchased result")
            return
        }
        guard let expiry = entitlement.expiresAt else {
            Issue.record("expected expiry")
            return
        }
        let now = Date()
        let days = expiry.timeIntervalSince(now) / 86400
        #expect(days > 200)
    }

    @Test("unknown product throws")
    func unknownProductThrows() async {
        let service = InMemoryEntitlementService()
        await #expect(throws: EntitlementError.productNotFound("bogus")) {
            _ = try await service.purchase(productId: "bogus")
        }
    }
}
