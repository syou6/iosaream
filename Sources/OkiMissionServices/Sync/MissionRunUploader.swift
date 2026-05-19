import Foundation
import OkiMissionCore

public actor MissionRunUploader {
    public typealias UnsyncedFetcher = @Sendable () async throws -> [MissionRunRecord]
    public typealias SyncedMarker = @Sendable ([UUID]) async throws -> Void

    public struct Configuration: Sendable {
        public var batchSize: Int
        public init(batchSize: Int = 25) {
            self.batchSize = max(1, batchSize)
        }
        public static let `default` = Configuration()
    }

    private let syncing: any RemoteRunSyncing
    private let fetchUnsynced: UnsyncedFetcher
    private let markSynced: SyncedMarker
    private let configuration: Configuration
    private var inflight: Bool = false

    public init(
        syncing: any RemoteRunSyncing,
        fetchUnsynced: @escaping UnsyncedFetcher,
        markSynced: @escaping SyncedMarker,
        configuration: Configuration = .default
    ) {
        self.syncing = syncing
        self.fetchUnsynced = fetchUnsynced
        self.markSynced = markSynced
        self.configuration = configuration
    }

    @discardableResult
    public func runOnce() async throws -> Int {
        guard !inflight else { return 0 }
        inflight = true
        defer { inflight = false }

        let pending = try await fetchUnsynced()
        guard !pending.isEmpty else { return 0 }

        var totalUploaded = 0
        for chunk in pending.chunked(into: configuration.batchSize) {
            let uploadedIds = try await syncing.upload(records: chunk)
            try await markSynced(uploadedIds)
            totalUploaded += uploadedIds.count
        }
        return totalUploaded
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
