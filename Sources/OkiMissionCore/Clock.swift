import Foundation

public protocol AppClock: Sendable {
    func now() -> Date
    func uptime() -> TimeInterval
}

public struct SystemClock: AppClock {
    public init() {}
    public func now() -> Date { Date() }
    public func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
}
