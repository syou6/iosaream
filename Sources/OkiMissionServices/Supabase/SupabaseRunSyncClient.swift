import Foundation
import OkiMissionCore

public struct SupabaseConfiguration: Sendable {
    public var baseURL: URL
    public var anonKey: String
    public var postgrestPath: String

    public init(baseURL: URL, anonKey: String, postgrestPath: String = "/rest/v1") {
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.postgrestPath = postgrestPath
    }
}

public struct SupabaseRunSyncClient: RemoteRunSyncing {
    public typealias UserIdProvider = @Sendable () async throws -> String
    public typealias TokenProvider = @Sendable () async throws -> String

    private let httpClient: any HTTPClient
    private let configuration: SupabaseConfiguration
    private let userIdProvider: UserIdProvider
    private let tokenProvider: TokenProvider
    private let dateFormatter: ISO8601DateFormatter

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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    public func upload(records: [MissionRunRecord]) async throws -> [UUID] {
        guard !records.isEmpty else { return [] }
        let userId = try await userIdProvider()
        let token = try await tokenProvider()

        let payload = records.map { RunPayload(record: $0, userId: userId, formatter: dateFormatter) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body: Data
        do {
            body = try encoder.encode(payload)
        } catch {
            throw RemoteRunSyncError.encoding(String(describing: error))
        }

        let url = configuration.baseURL
            .appendingPathComponent(configuration.postgrestPath)
            .appendingPathComponent("mission_runs")

        let headers: [String: String] = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(token)",
            "apikey": configuration.anonKey,
            "Prefer": "return=representation,resolution=ignore-duplicates"
        ]
        let request = HTTPRequest(url: url, method: .post, headers: headers, body: body)

        let response: HTTPResponse
        do {
            response = try await httpClient.send(request)
        } catch let error as HTTPError {
            switch error {
            case .rateLimited:
                throw RemoteRunSyncError.rateLimited
            case .server(let status):
                throw RemoteRunSyncError.serverError(status)
            default:
                throw RemoteRunSyncError.transport(String(describing: error))
            }
        }

        guard response.isSuccess else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw RemoteRunSyncError.unauthorized
            }
            throw RemoteRunSyncError.serverError(response.statusCode)
        }

        return records.map(\.id)
    }
}

struct RunPayload: Encodable {
    let id: UUID
    let user_id: String
    let alarm_id: UUID?
    let template_id: UUID?
    let mission_kind: String
    let started_at: String
    let completed_at: String?
    let outcome: String
    let failure_reason: String?
    let duration_seconds: Double
    let reps_completed: Int
    let anti_cheat_score: Int
    let signals: JSONValue?
    let network_latency_ms: Int?

    init(record: MissionRunRecord, userId: String, formatter: ISO8601DateFormatter) {
        self.id = record.id
        self.user_id = userId
        self.alarm_id = record.alarmId
        self.template_id = record.templateId
        self.mission_kind = record.missionKind.rawValue
        self.started_at = formatter.string(from: record.startedAt)
        self.completed_at = record.completedAt.map { formatter.string(from: $0) }
        self.outcome = record.outcome.rawValue
        self.failure_reason = record.failureReason?.rawValue
        self.duration_seconds = record.durationSeconds
        self.reps_completed = record.repsCompleted
        self.anti_cheat_score = record.antiCheatScore
        self.network_latency_ms = record.networkLatencyMs
        if record.signals.isEmpty {
            self.signals = nil
        } else {
            let array = record.signals.compactMap { signal -> JSONValue? in
                guard let data = try? JSONEncoder().encode(signal),
                      let value = try? JSONDecoder().decode(JSONValue.self, from: data) else {
                    return nil
                }
                return value
            }
            self.signals = .array(array)
        }
    }
}
