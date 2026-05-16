import Foundation

public enum MissionKind: String, Codable, CaseIterable, Sendable, Hashable {
    case pushup
    case squat
    case math
    case shake
    case objectHunt
    case barcode
}

public extension MissionKind {
    var requiresCamera: Bool {
        switch self {
        case .pushup, .squat, .objectHunt, .barcode: return true
        case .math, .shake: return false
        }
    }

    var requiresMotion: Bool {
        self == .shake
    }
}
