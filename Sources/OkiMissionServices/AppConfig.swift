import Foundation

public struct AppConfig: Sendable, Equatable {
    public var supabaseURL: URL
    public var supabaseAnonKey: String
    public var revenueCatAPIKey: String
    public var posthogAPIKey: String?
    public var posthogHost: URL
    public var sentryDSN: String?
    public var appBundleId: String

    public init(
        supabaseURL: URL,
        supabaseAnonKey: String,
        revenueCatAPIKey: String,
        posthogAPIKey: String? = nil,
        posthogHost: URL = URL(string: "https://app.posthog.com")!,
        sentryDSN: String? = nil,
        appBundleId: String
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.revenueCatAPIKey = revenueCatAPIKey
        self.posthogAPIKey = posthogAPIKey
        self.posthogHost = posthogHost
        self.sentryDSN = sentryDSN
        self.appBundleId = appBundleId
    }

    public enum LoadError: Error, Equatable, Sendable {
        case missingKey(String)
        case invalidURL(String)
    }

    public static func from(infoDictionary: [String: Any]) throws -> AppConfig {
        func required(_ key: String) throws -> String {
            guard let value = infoDictionary[key] as? String, !value.isEmpty else {
                throw LoadError.missingKey(key)
            }
            return value
        }
        func optional(_ key: String) -> String? {
            guard let value = infoDictionary[key] as? String, !value.isEmpty else { return nil }
            return value
        }
        func url(_ value: String, key: String) throws -> URL {
            guard let parsed = URL(string: value) else {
                throw LoadError.invalidURL(key)
            }
            return parsed
        }

        let supabaseURL = try url(try required("SupabaseURL"), key: "SupabaseURL")
        let supabaseAnonKey = try required("SupabaseAnonKey")
        let rcKey = try required("RevenueCatAPIKey")
        let posthogKey = optional("PostHogAPIKey")
        let posthogHostString = optional("PostHogHost") ?? "https://app.posthog.com"
        let posthogHost = try url(posthogHostString, key: "PostHogHost")
        let sentryDSN = optional("SentryDSN")
        let bundleId = try required("CFBundleIdentifier")

        return AppConfig(
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey,
            revenueCatAPIKey: rcKey,
            posthogAPIKey: posthogKey,
            posthogHost: posthogHost,
            sentryDSN: sentryDSN,
            appBundleId: bundleId
        )
    }
}
