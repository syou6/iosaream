import Foundation
import OkiMissionCore

public enum RemoteRunSyncError: Error, Equatable, Sendable {
    case unauthorized
    case rateLimited
    case serverError(Int)
    case transport(String)
    case encoding(String)
}

public protocol RemoteRunSyncing: Sendable {
    func upload(records: [MissionRunRecord]) async throws -> [UUID]
}
