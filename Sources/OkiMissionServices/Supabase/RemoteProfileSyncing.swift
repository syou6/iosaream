import Foundation
import OkiMissionCore

public enum APNsEnvironment: String, Sendable, Codable {
    case sandbox
    case production
}

public struct RemoteProfileSnapshot: Sendable, Equatable, Codable {
    public var displayName: String?
    public var preferredLocale: String?
    public var apnsToken: String?
    public var apnsEnv: APNsEnvironment?

    public init(
        displayName: String? = nil,
        preferredLocale: String? = nil,
        apnsToken: String? = nil,
        apnsEnv: APNsEnvironment? = nil
    ) {
        self.displayName = displayName
        self.preferredLocale = preferredLocale
        self.apnsToken = apnsToken
        self.apnsEnv = apnsEnv
    }
}

public enum RemoteProfileSyncError: Error, Equatable, Sendable {
    case unauthorized
    case rateLimited
    case serverError(Int)
    case transport(String)
    case encoding(String)
    case missingUser
}

public protocol RemoteProfileSyncing: Sendable {
    func push(_ snapshot: RemoteProfileSnapshot) async throws
}
