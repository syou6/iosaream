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
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: date)

        if let last = profile.lastSuccessDate {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today {
                return profile.streakCount
            }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if lastDay == yesterday {
                profile.streakCount += 1
            } else {
                profile.streakCount = 1
                profile.currentStreakStartDate = today
            }
        } else {
            profile.streakCount = 1
            profile.currentStreakStartDate = today
        }

        profile.lastSuccessDate = today
        profile.longestStreak = max(profile.longestStreak, profile.streakCount)
        profile.updatedAt = Date()
        try modelContext.save()
        return profile.streakCount
    }

    public func breakStreakIfStale(reference: Date) throws {
        let profile = try current()
        guard let last = profile.lastSuccessDate else { return }
        let calendar = Calendar(identifier: .gregorian)
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: reference)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if lastDay < yesterday {
            profile.streakCount = 0
            profile.currentStreakStartDate = nil
            profile.updatedAt = Date()
            try modelContext.save()
        }
    }
}
