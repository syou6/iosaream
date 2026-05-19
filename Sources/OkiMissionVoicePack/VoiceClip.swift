import Foundation

public struct VoiceClip: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let context: VoiceContext
    public let assetName: String
    public let transcript: String
    public let durationSeconds: Double

    public init(
        id: UUID = UUID(),
        context: VoiceContext,
        assetName: String,
        transcript: String,
        durationSeconds: Double
    ) {
        self.id = id
        self.context = context
        self.assetName = assetName
        self.transcript = transcript
        self.durationSeconds = durationSeconds
    }
}
