import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionEngine
import OkiMissionDesignSystem

public struct MissionShellView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var state: ScreenState = .loading
    @State private var experience: MissionExperience?
    @State private var currentState: MissionState = .idle

    public enum ScreenState {
        case loading
        case ready(GeneratedMissionTemplate)
        case failed(String)
        case finished(MissionRunRecord)
    }

    public let templateId: UUID
    public let alarmId: UUID?

    public init(templateId: UUID, alarmId: UUID?) {
        self.templateId = templateId
        self.alarmId = alarmId
    }

    public var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            content
                .padding(AppSpacing.lg)
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView("ミッションを準備中…")
                .progressViewStyle(.circular)
        case .failed(let message):
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColor.warning)
                Text(message).multilineTextAlignment(.center)
                Button("閉じる") { dismiss() }
                    .buttonStyle(.appSecondary)
            }
        case .ready(let template):
            kindView(for: template)
        case .finished(let record):
            MissionResultView(record: record)
        }
    }

    @ViewBuilder
    private func kindView(for template: GeneratedMissionTemplate) -> some View {
        switch template.kind {
        case .math:
            if let experience {
                MathMissionView(experience: experience, state: $currentState)
                    .task { await observe(experience) }
            }
        case .pushup, .squat:
            PoseMissionView(template: template)
        case .shake:
            ShakeMissionView()
        case .objectHunt:
            ObjectHuntMissionView(template: template)
        case .barcode:
            BarcodeMissionView()
        }
    }

    private func load() async {
        // For brevity this draft assumes a stub: build a math template
        // matching templateId. In the real impl, you'd resolve the
        // template via your domain repository or fetch from the
        // missions-generate endpoint and seed MissionExperience.
        do {
            let params = MathParams(problemCount: 3, operatorTypes: [.add, .subtract], minOperand: 1, maxOperand: 10)
            let template = GeneratedMissionTemplate(
                id: templateId,
                kind: .math,
                difficulty: .easy,
                parametersJSON: try MissionParameterEncoder.encode(params),
                title: "計算 3 問",
                estimatedDurationSeconds: 30,
                locale: "ja-JP",
                source: "preview",
                contentHash: "preview"
            )
            let exp = try MissionExperience(template: template)
            await exp.start()
            await exp.reportCapability(.notifications, authorized: true)
            for _ in 0..<8 {
                await exp.reportFraming(progress: 1.0)
            }
            experience = exp
            state = .ready(template)
        } catch {
            state = .failed("ミッションを読み込めませんでした: \(error.localizedDescription)")
        }
    }

    private func observe(_ exp: MissionExperience) async {
        for await event in exp.events {
            if case .stateChanged(let next) = event {
                currentState = next
                if next.isTerminal {
                    let record = await exp.finalRecord(alarmId: alarmId)
                    state = .finished(record)
                    break
                }
            }
        }
    }
}
#endif
