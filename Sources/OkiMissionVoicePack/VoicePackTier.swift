import Foundation

public enum VoicePackTier: String, Codable, Sendable, CaseIterable {
    case free
    case paidOneShot
    case subscriberBundled
}
