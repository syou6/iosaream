import Foundation

public enum DomainError: Error, Equatable, Sendable {
    case invalidAlarmConfig
    case unsupportedTemplateVersion(expected: Int, actual: Int)
    case missionAlreadyRunning
    case capabilityDenied(Capability)
    case noOfferingsAvailable
    case rateLimited(remaining: Int)
}

public enum Capability: String, Sendable, Codable, CaseIterable {
    case camera
    case motion
    case microphone
    case notifications
    case alarm
}
