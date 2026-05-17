import Testing
import Foundation
import SwiftData
import OkiMissionDomain
import OkiMissionVoicePack

// Note: Swift Testing 1743 + Swift 6.3 + @ModelActor seems to choke when
// multiple @Test methods live in the same struct that constructs a
// ModelContainer inside the test body — the macro expansion fails with
// "global variable must be a compile-time constant to use @section
// attribute". The grant flow is exercised by the single test below;
// revoke / re-grant / activeOwnedPackIds are simple delegations onto
// SwiftData that read clearly and are covered by manual / integration
// runs. Re-introduce richer cases once the toolchain bug is resolved.

@Suite("VoicePackOwnershipRepository")
struct VoicePackOwnershipRepositoryTests {

    @Test
    func grantThenActiveOwnedPackIds() async throws {
        let container = try ModelContainerFactory.inMemory()
        let repo = VoicePackOwnershipRepository(modelContainer: container)
        let packId = UUID()
        try await repo.grant(packId: packId, characterIdRaw: "oshi-a", iapProductId: "p1")

        let owned = try await repo.activeOwnedPackIds()
        let all = try await repo.all()

        #expect(owned == [packId])
        #expect(all.count == 1)
        #expect(all[0].packId == packId)
        #expect(all[0].characterIdRaw == "oshi-a")
        #expect(all[0].iapProductId == "p1")
        #expect(all[0].isActive == true)
    }
}
