import SwiftUI
import OkiMissionCore
import OkiMissionServices
import OkiMissionVoicePack
import OkiMissionFeatureKit

@main
struct OkiMissionDemoApp: App {
    @State private var dependencies: AppDependencies
    @State private var router: Router
    @State private var catalog: VoicePackCatalog
    @State private var ownership: VoicePackOwnership
    @State private var showCharacterPicker = false
    @State private var showPaywall = false
    @State private var selectedPack: VoicePack?

    init() {
        let deps = AppDependencies.previewStub()
        _dependencies = State(initialValue: deps)
        _router = State(initialValue: Router())

        let freePack = VoicePackSamples.defaultPack()
        let paidPack = VoicePackSamples.samplePaidPack(
            characterId: CharacterId("oshi-a"),
            iapProductId: "com.okimission.voicepack.oshia"
        )
        let secondPaid = VoicePackSamples.samplePaidPack(
            characterId: CharacterId("oshi-b"),
            iapProductId: "com.okimission.voicepack.oshib"
        )
        _catalog = State(initialValue: VoicePackCatalog(packs: [freePack, paidPack, secondPaid]))
        _ownership = State(initialValue: VoicePackOwnership(ownedPackIds: [freePack.id]))
    }

    var body: some Scene {
        WindowGroup {
            DemoShell(
                catalog: catalog,
                ownership: ownership,
                selectedPack: $selectedPack,
                showCharacterPicker: $showCharacterPicker,
                showPaywall: $showPaywall
            )
            .environment(\.appDependencies, dependencies)
            .environment(\.router, router)
        }
    }
}

struct DemoShell: View {
    let catalog: VoicePackCatalog
    let ownership: VoicePackOwnership
    @Binding var selectedPack: VoicePack?
    @Binding var showCharacterPicker: Bool
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("OkiMission Demo") {
                    Text("Pattern B — Mission Alarm + Voice Pack")
                        .font(.headline)
                    Text("Phase 14 build")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("選択中の推し") {
                    if let pack = selectedPack {
                        HStack {
                            Circle().fill(.pink).frame(width: 36, height: 36)
                            VStack(alignment: .leading) {
                                Text(pack.displayName).font(.headline)
                                if let actor = pack.voiceActor {
                                    Text("CV: \(actor)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("未選択")
                            .foregroundStyle(.secondary)
                    }
                    Button("推しを選ぶ") { showCharacterPicker = true }
                    Button("Paywall プレビュー") {
                        if let firstPaid = catalog.packs.first(where: { $0.tier == .paidOneShot }) {
                            selectedPack = firstPaid
                            showPaywall = true
                        }
                    }
                }

                Section("アラーム (デモ)") {
                    AlarmRow(label: "起床", time: "07:00", days: "月火水木金", isOn: true)
                    AlarmRow(label: "二度寝防止", time: "07:15", days: "月火水木金", isOn: true)
                    AlarmRow(label: "休日", time: "09:30", days: "土日", isOn: false)
                }

                Section("カタログ (\(catalog.packs.count) パック)") {
                    ForEach(catalog.packs, id: \.id) { pack in
                        HStack {
                            Image(systemName: ownership.canPlay(pack) ? "checkmark.circle.fill" : "lock.fill")
                                .foregroundStyle(ownership.canPlay(pack) ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(pack.displayName)
                                Text(tierLabel(pack))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("OkiMission")
            .sheet(isPresented: $showCharacterPicker) {
                CharacterPickerView(
                    catalog: catalog,
                    ownership: ownership,
                    onSelect: { pack in selectedPack = pack }
                )
            }
            .sheet(isPresented: $showPaywall) {
                if let pack = selectedPack {
                    VoicePackPaywallView(pack: pack)
                }
            }
        }
    }

    private func tierLabel(_ pack: VoicePack) -> String {
        switch pack.tier {
        case .free: return "無料"
        case .paidOneShot: return ownership.canPlay(pack) ? "購入済み" : "¥980"
        case .subscriberBundled: return "Pro"
        }
    }
}

struct AlarmRow: View {
    let label: String
    let time: String
    let days: String
    let isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(time).font(.system(size: 34, weight: .light, design: .rounded))
                Text(label).font(.subheadline)
                Text(days).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: .constant(isOn)).labelsHidden()
        }
    }
}
