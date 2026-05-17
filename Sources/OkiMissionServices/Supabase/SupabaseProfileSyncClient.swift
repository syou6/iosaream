import Foundation
import OkiMissionCore

public struct SupabaseProfileSyncClient: RemoteProfileSyncing {
    public typealias UserIdProvider = @Sendable () async throws -> String
    public typealias TokenProvider = @Sendable () async throws -> String

    private let httpClient: any HTTPClient
    private let configuration: SupabaseConfiguration
    private let userIdProvider: UserIdProvider
    private let tokenProvider: TokenProvider

    public init(
        httpClient: any HTTPClient,
        configuration: SupabaseConfiguration,
        userIdProvider: @escaping UserIdProvider,
        tokenProvider: @escaping TokenProvider
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.userIdProvider = userIdProvider
        self.tokenProvider = tokenProvider
    }

    public func push(_ snapshot: RemoteProfileSnapshot) async throws {
        let userId: String
        do {
            userId = try await userIdProvider()
        } catch {
            throw RemoteProfileSyncError.missingUser
        }
        let token = try await tokenProvider()

        let payload = ProfilePayload(snapshot: snapshot)
        if payload.isEmpty { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body: Data
        do {
            body = try encoder.encode(payload)
        } catch {
            throw RemoteProfileSyncError.encoding(String(describing: error))
        }

        var components = URLComponents(
            url: configuration.baseURL
                .appendingPathComponent(configuration.postgrestPath)
                .appendingPathComponent("profiles"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(userId)")]
        guard let url = components?.url else {
            throw RemoteProfileSyncError.encoding("invalid url")
        }

        let headers: [String: String] = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(token)",
            "apikey": configuration.anonKey,
            "Prefer": "return=minimal"
        ]
        let request = HTTPRequest(url: url, method: .patch, headers: headers, body: body)

        let response: HTTPResponse
        do {
            response = try await httpClient.send(request)
        } catch let error as HTTPError {
            switch error {
            case .rateLimited:
                throw RemoteProfileSyncError.rateLimited
            case .server(let status):
                throw RemoteProfileSyncError.serverError(status)
            default:
                throw RemoteProfileSyncError.transport(String(describing: error))
            }
        }

        guard response.isSuccess else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw RemoteProfileSyncError.unauthorized
            }
            throw RemoteProfileSyncError.serverError(response.statusCode)
        }
    }
}

private struct ProfilePayload: Encodable {
    let display_name: String?
    let preferred_locale: String?
    let apns_token: String?
    let apns_env: String?

    init(snapshot: RemoteProfileSnapshot) {
        self.display_name = snapshot.displayName
        self.preferred_locale = snapshot.preferredLocale
        self.apns_token = snapshot.apnsToken
        self.apns_env = snapshot.apnsEnv?.rawValue
    }

    var isEmpty: Bool {
        display_name == nil
            && preferred_locale == nil
            && apns_token == nil
            && apns_env == nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let value = display_name { try container.encode(value, forKey: .display_name) }
        if let value = preferred_locale { try container.encode(value, forKey: .preferred_locale) }
        if let value = apns_token { try container.encode(value, forKey: .apns_token) }
        if let value = apns_env { try container.encode(value, forKey: .apns_env) }
    }

    enum CodingKeys: String, CodingKey {
        case display_name, preferred_locale, apns_token, apns_env
    }
}
