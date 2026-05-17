import Testing
import Foundation
import OkiMissionCore
@testable import OkiMissionServices

private actor StubRemoteRunSync: RemoteRunSyncing {
    enum Outcome: Sendable {
        case success
        case failure(RemoteRunSyncError)
    }

    private(set) var calls: [[MissionRunRecord]] = []
    var outcome: Outcome = .success

    func setOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func upload(records: [MissionRunRecord]) async throws -> [UUID] {
        calls.append(records)
        switch outcome {
        case .success:
            return records.map(\.id)
        case .failure(let err):
            throw err
        }
    }
}

private actor FetchSpy {
    private(set) var callCount: Int = 0
    var records: [MissionRunRecord]

    init(records: [MissionRunRecord]) { self.records = records }

    func fetch() async -> [MissionRunRecord] {
        callCount += 1
        return records
    }

    func setRecords(_ records: [MissionRunRecord]) {
        self.records = records
    }
}

private actor MarkSpy {
    private(set) var marked: [UUID] = []
    private(set) var callCount: Int = 0

    func mark(_ ids: [UUID]) async {
        marked.append(contentsOf: ids)
        callCount += 1
    }
}

private func makeRecord(_ kind: MissionKind = .math) -> MissionRunRecord {
    MissionRunRecord(
        id: UUID(),
        missionKind: kind,
        startedAt: Date(),
        outcome: .success,
        durationSeconds: 12
    )
}

@Suite("MissionRunUploader")
struct MissionRunUploaderTests {
    @Test("empty fetch performs no upload and returns zero")
    func emptyFetch() async throws {
        let sync = StubRemoteRunSync()
        let fetch = FetchSpy(records: [])
        let mark = MarkSpy()
        let uploader = MissionRunUploader(
            syncing: sync,
            fetchUnsynced: { await fetch.fetch() },
            markSynced: { await mark.mark($0) }
        )
        let uploaded = try await uploader.runOnce()
        #expect(uploaded == 0)
        let markedCount = await mark.callCount
        #expect(markedCount == 0)
        let calls = await sync.calls
        #expect(calls.isEmpty)
    }

    @Test("single batch uploads and marks every record")
    func singleBatchSuccess() async throws {
        let records = (0..<3).map { _ in makeRecord() }
        let sync = StubRemoteRunSync()
        let fetch = FetchSpy(records: records)
        let mark = MarkSpy()
        let uploader = MissionRunUploader(
            syncing: sync,
            fetchUnsynced: { await fetch.fetch() },
            markSynced: { await mark.mark($0) }
        )
        let uploaded = try await uploader.runOnce()
        #expect(uploaded == 3)
        let marked = await mark.marked
        #expect(Set(marked) == Set(records.map(\.id)))
    }

    @Test("batches larger than batchSize are split")
    func chunkedUpload() async throws {
        let records = (0..<5).map { _ in makeRecord() }
        let sync = StubRemoteRunSync()
        let fetch = FetchSpy(records: records)
        let mark = MarkSpy()
        let uploader = MissionRunUploader(
            syncing: sync,
            fetchUnsynced: { await fetch.fetch() },
            markSynced: { await mark.mark($0) },
            configuration: .init(batchSize: 2)
        )
        let uploaded = try await uploader.runOnce()
        #expect(uploaded == 5)
        let calls = await sync.calls
        #expect(calls.map(\.count) == [2, 2, 1])
        let markedCalls = await mark.callCount
        #expect(markedCalls == 3)
    }

    @Test("upload failure propagates and does not mark anything")
    func uploadFailurePropagates() async {
        let records = (0..<2).map { _ in makeRecord() }
        let sync = StubRemoteRunSync()
        await sync.setOutcome(.failure(.unauthorized))
        let fetch = FetchSpy(records: records)
        let mark = MarkSpy()
        let uploader = MissionRunUploader(
            syncing: sync,
            fetchUnsynced: { await fetch.fetch() },
            markSynced: { await mark.mark($0) }
        )
        await #expect(throws: RemoteRunSyncError.unauthorized) {
            _ = try await uploader.runOnce()
        }
        let markedCount = await mark.callCount
        #expect(markedCount == 0)
    }
}
