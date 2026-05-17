import Foundation
import OkiMissionServices

// Wraps the PostHog iOS SDK. Add PostHog as a SPM dependency in the App
// target, then this adapter compiles automatically.

#if canImport(PostHog) && os(iOS)
import PostHog

public actor PostHogAnalyticsTracker: AnalyticsTracking {
    public init(apiKey: String, host: URL) {
        let config = PostHogConfig(apiKey: apiKey, host: host.absoluteString)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
    }

    public func track(_ event: AnalyticsEvent) async {
        PostHogSDK.shared.capture(event.name, properties: Self.translate(event.properties))
    }

    public func identify(userId: String, traits: [String: AnalyticsValue]) async {
        PostHogSDK.shared.identify(userId, userProperties: Self.translate(traits))
    }

    public func reset() async {
        PostHogSDK.shared.reset()
    }

    public func flush() async {
        PostHogSDK.shared.flush()
    }

    private static func translate(_ values: [String: AnalyticsValue]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in values {
            switch value {
            case .string(let s): out[key] = s
            case .int(let i): out[key] = i
            case .double(let d): out[key] = d
            case .bool(let b): out[key] = b
            }
        }
        return out
    }
}
#endif
