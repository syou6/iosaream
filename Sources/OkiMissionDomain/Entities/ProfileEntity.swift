import Foundation
import SwiftData
import OkiMissionCore

@Model
public final class ProfileEntity {
    @Attribute(.unique) public var id: UUID
    public var supabaseUserId: String?
    public var displayName: String?
    public var avatarRemoteURL: URL?
    public var subscriptionTier: SubscriptionTier
    public var subscriptionExpiresAt: Date?
    public var streakCount: Int
    public var longestStreak: Int
    public var lastSuccessDate: Date?
    public var currentStreakStartDate: Date?
    public var prefersHaptics: Bool
    public var prefersReduceMotion: Bool
    public var preferredLocale: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        supabaseUserId: String? = nil,
        displayName: String? = nil,
        avatarRemoteURL: URL? = nil,
        subscriptionTier: SubscriptionTier = .free,
        subscriptionExpiresAt: Date? = nil,
        streakCount: Int = 0,
        longestStreak: Int = 0,
        lastSuccessDate: Date? = nil,
        currentStreakStartDate: Date? = nil,
        prefersHaptics: Bool = true,
        prefersReduceMotion: Bool = false,
        preferredLocale: String = "ja-JP",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.supabaseUserId = supabaseUserId
        self.displayName = displayName
        self.avatarRemoteURL = avatarRemoteURL
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.streakCount = streakCount
        self.longestStreak = longestStreak
        self.lastSuccessDate = lastSuccessDate
        self.currentStreakStartDate = currentStreakStartDate
        self.prefersHaptics = prefersHaptics
        self.prefersReduceMotion = prefersReduceMotion
        self.preferredLocale = preferredLocale
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
