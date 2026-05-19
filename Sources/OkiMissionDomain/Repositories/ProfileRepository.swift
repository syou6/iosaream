import Foundation
import SwiftData
import OkiMissionCore

@ModelActor
public actor ProfileRepository {
    public func current() throws -> ProfileEntity {
        let descriptor = FetchDescriptor<ProfileEntity>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let new = ProfileEntity()
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    public func updateSubscription(tier: SubscriptionTier, expiresAt: Date?) throws {
        let profile = try current()
        profile.subscriptionTier = tier
        profile.subscriptionExpiresAt = expiresAt
        profile.updatedAt = Date()
        try modelContext.save()
    }

    @discardableResult
    public func registerSuccess(on date: Date) throws -> Int {
        let profile = try current()
        let snapshot = StreakState(
            currentStreak: profile.streakCount,
            longestStreak: profile.longestStreak,
            lastSuccessDate: profile.lastSuccessDate,
            currentStreakStartDate: profile.currentStreakStartDate
        )
        let next = StreakCalculator.registerSuccess(state: snapshot, successDate: date)
        applyStreak(next, to: profile)
        try modelContext.save()
        return next.currentStreak
    }

    public func breakStreakIfStale(reference: Date) throws {
        let profile = try current()
        let snapshot = StreakState(
            currentStreak: profile.streakCount,
            longestStreak: profile.longestStreak,
            lastSuccessDate: profile.lastSuccessDate,
            currentStreakStartDate: profile.currentStreakStartDate
        )
        let next = StreakCalculator.breakIfStale(state: snapshot, reference: reference)
        guard next != snapshot else { return }
        applyStreak(next, to: profile)
        try modelContext.save()
    }

    private func applyStreak(_ state: StreakState, to profile: ProfileEntity) {
        profile.streakCount = state.currentStreak
        profile.longestStreak = state.longestStreak
        profile.lastSuccessDate = state.lastSuccessDate
        profile.currentStreakStartDate = state.currentStreakStartDate
        profile.updatedAt = Date()
    }
}
