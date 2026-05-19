import Foundation

public enum Difficulty: String, Codable, CaseIterable, Sendable, Comparable {
    case easy
    case medium
    case hard

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        }
    }
}
