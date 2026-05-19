import Foundation
import OkiMissionCore

public struct GeminiProxyConfiguration: Sendable {
    public var baseURL: URL
    public var generatePath: String
    public var anonKey: String?

    public init(baseURL: URL, generatePath: String = "/functions/v1/missions-generate", anonKey: String? = nil) {
        self.baseURL = baseURL
        self.generatePath = generatePath
        self.anonKey = anonKey
    }
}

public struct GeminiProxyClient: MissionGenerating {
    public typealias AccessTokenProvider = @Sendable () async throws -> String

    private let httpClient: any HTTPClient
    private let configuration: GeminiProxyConfiguration
    private let tokenProvider: AccessTokenProvider
    nonisolated(unsafe) private let dateFormatter: ISO8601DateFormatter

    public init(
        httpClient: any HTTPClient,
        configuration: GeminiProxyConfiguration,
        tokenProvider: @escaping AccessTokenProvider
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
    }

    public func generate(_ request: MissionGenerationRequest) async throws -> GeneratedMissionTemplate {
        let body = GenerateRequestWire(
            targetDate: GeminiProxyClient.dateOnlyString(for: request.targetDate),
            difficultyHint: request.difficultyHint.rawValue,
            recentKinds: request.recentKinds.map(\.rawValue),
            preferredKinds: request.preferredKinds?.map(\.rawValue),
            disabledKinds: request.disabledKinds?.map(\.rawValue),
            locale: request.locale
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(body)

        let url = configuration.baseURL.appendingPathComponent(configuration.generatePath)
        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]
        let token = try await tokenProvider()
        headers["Authorization"] = "Bearer \(token)"
        if let anonKey = configuration.anonKey {
            headers["apikey"] = anonKey
        }

        let httpRequest = HTTPRequest(url: url, method: .post, headers: headers, body: payload)
        let response: HTTPResponse
        do {
            response = try await httpClient.send(httpRequest)
        } catch let error as HTTPError {
            switch error {
            case .rateLimited:
                throw MissionGenerationError.rateLimited(remaining: 0)
            default:
                throw MissionGenerationError.providerUnavailable
            }
        }

        guard response.isSuccess else {
            if response.statusCode == 429 {
                throw MissionGenerationError.rateLimited(remaining: 0)
            }
            throw MissionGenerationError.providerUnavailable
        }

        let decoder = JSONDecoder()
        do {
            let parsed = try decoder.decode(GenerateResponseWire.self, from: response.body)
            return try parsed.template.toDomain(generatedAt: Date())
        } catch let error as MissionGenerationError {
            throw error
        } catch {
            throw MissionGenerationError.decodingFailed(String(describing: error))
        }
    }

    private static func dateOnlyString(for date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 1970,
                      components.month ?? 1,
                      components.day ?? 1)
    }
}

struct GenerateRequestWire: Encodable, Equatable {
    let targetDate: String
    let difficultyHint: String
    let recentKinds: [String]
    let preferredKinds: [String]?
    let disabledKinds: [String]?
    let locale: String
}

struct GenerateResponseWire: Decodable, Equatable {
    let template: TemplateWire
    let ttlSec: Int?
    let cached: Bool?
}

struct TemplateWire: Decodable, Equatable {
    let kind: String
    let difficulty: String
    let title: String
    let subtitle: String?
    let description: String?
    let encouragement: String?
    let estimatedDurationSec: Double
    let parametersJSON: String
    let locale: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case kind, difficulty, title, subtitle, description
        case encouragement
        case estimatedDurationSec
        case parameters
        case locale, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.difficulty = try container.decode(String.self, forKey: .difficulty)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.encouragement = try container.decodeIfPresent(String.self, forKey: .encouragement)
        self.estimatedDurationSec = try container.decode(Double.self, forKey: .estimatedDurationSec)
        let params = try container.decode(JSONValue.self, forKey: .parameters)
        self.parametersJSON = try params.encodedString(sortKeys: true)
        self.locale = try container.decodeIfPresent(String.self, forKey: .locale)
        self.source = try container.decodeIfPresent(String.self, forKey: .source)
    }

    func toDomain(generatedAt: Date) throws -> GeneratedMissionTemplate {
        guard let kindEnum = MissionKind(rawValue: kind) else {
            throw MissionGenerationError.decodingFailed("unknown kind: \(kind)")
        }
        guard let difficultyEnum = Difficulty(rawValue: difficulty) else {
            throw MissionGenerationError.decodingFailed("unknown difficulty: \(difficulty)")
        }
        let hashInput = "\(kind)|\(difficulty)|\(parametersJSON)|\(title)"
        var hasher = Hasher()
        hasher.combine(hashInput)
        let hash = String(UInt(bitPattern: hasher.finalize()), radix: 16)
        return GeneratedMissionTemplate(
            kind: kindEnum,
            difficulty: difficultyEnum,
            parametersJSON: parametersJSON,
            title: title,
            subtitle: subtitle ?? description,
            encouragement: encouragement,
            estimatedDurationSeconds: estimatedDurationSec,
            locale: locale ?? "ja-JP",
            source: source ?? "gemini",
            generatedAt: generatedAt,
            contentHash: hash
        )
    }
}
