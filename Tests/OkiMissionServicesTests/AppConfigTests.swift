import Testing
import Foundation
@testable import OkiMissionServices

@Suite("AppConfig")
struct AppConfigTests {
    private func validDict() -> [String: Any] {
        [
            "SupabaseURL": "https://example.supabase.co",
            "SupabaseAnonKey": "anon",
            "RevenueCatAPIKey": "appl_x",
            "PostHogAPIKey": "ph_x",
            "PostHogHost": "https://eu.posthog.com",
            "SentryDSN": "https://sentry.example/x",
            "CFBundleIdentifier": "com.example.OkiMission",
        ]
    }

    @Test("loads from a complete info dictionary")
    func loadComplete() throws {
        let config = try AppConfig.from(infoDictionary: validDict())
        #expect(config.supabaseURL == URL(string: "https://example.supabase.co"))
        #expect(config.posthogAPIKey == "ph_x")
        #expect(config.posthogHost == URL(string: "https://eu.posthog.com"))
        #expect(config.appBundleId == "com.example.OkiMission")
    }

    @Test("optional posthog host defaults to app.posthog.com when absent")
    func defaultPosthogHost() throws {
        var dict = validDict()
        dict.removeValue(forKey: "PostHogHost")
        let config = try AppConfig.from(infoDictionary: dict)
        #expect(config.posthogHost == URL(string: "https://app.posthog.com"))
    }

    @Test("missing supabase url throws missingKey")
    func missingURL() {
        var dict = validDict()
        dict.removeValue(forKey: "SupabaseURL")
        #expect(throws: AppConfig.LoadError.missingKey("SupabaseURL")) {
            _ = try AppConfig.from(infoDictionary: dict)
        }
    }

    @Test("optional sentry DSN is preserved when missing")
    func missingSentry() throws {
        var dict = validDict()
        dict.removeValue(forKey: "SentryDSN")
        let config = try AppConfig.from(infoDictionary: dict)
        #expect(config.sentryDSN == nil)
    }
}
