import Foundation
import OkiMissionCore

public enum SampleProfiles {
    public static func freeUser(now: Date = Date()) -> ProfileEntity {
        ProfileEntity(
            id: UUID(uuidString: "22222222-0000-0000-0000-000000000001")!,
            displayName: "山田太郎",
            subscriptionTier: .free,
            streakCount: 2,
            longestStreak: 5,
            lastSuccessDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: now),
            currentStreakStartDate: Calendar(identifier: .gregorian).date(byAdding: .day, value: -2, to: now),
            preferredLocale: "ja-JP",
            createdAt: Calendar(identifier: .gregorian).date(byAdding: .month, value: -1, to: now) ?? now,
            updatedAt: now
        )
    }

    public static func proUser(streak: Int = 14, now: Date = Date()) -> ProfileEntity {
        let calendar = Calendar(identifier: .gregorian)
        return ProfileEntity(
            id: UUID(uuidString: "22222222-0000-0000-0000-000000000002")!,
            supabaseUserId: "sb-pro-user",
            displayName: "PRO ユーザー",
            subscriptionTier: .pro,
            subscriptionExpiresAt: calendar.date(byAdding: .day, value: 30, to: now),
            streakCount: streak,
            longestStreak: max(streak, 21),
            lastSuccessDate: now,
            currentStreakStartDate: calendar.date(byAdding: .day, value: -streak + 1, to: now),
            preferredLocale: "ja-JP",
            createdAt: calendar.date(byAdding: .month, value: -3, to: now) ?? now,
            updatedAt: now
        )
    }

    public static func brokenStreakUser(now: Date = Date()) -> ProfileEntity {
        let calendar = Calendar(identifier: .gregorian)
        return ProfileEntity(
            id: UUID(uuidString: "22222222-0000-0000-0000-000000000003")!,
            displayName: "途切れ気味",
            subscriptionTier: .free,
            streakCount: 0,
            longestStreak: 12,
            lastSuccessDate: calendar.date(byAdding: .day, value: -3, to: now),
            currentStreakStartDate: nil,
            preferredLocale: "ja-JP",
            createdAt: now,
            updatedAt: now
        )
    }
}
