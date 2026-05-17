import SwiftUI
import AVFoundation
import OkiMissionCore
import OkiMissionEngine
import OkiMissionServices
import OkiMissionVoicePack
import OkiMissionPlatformKit
import OkiMissionFeatureKit

@main
struct OkiMissionDemoApp: App {
    @State private var model: DemoModel

    init() {
        let m = DemoModel()
        DemoFlowRunner.apply(launchArgs: CommandLine.arguments, to: m)
        _model = State(initialValue: m)
    }

    var body: some Scene {
        WindowGroup {
            RootShell()
                .environment(model)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "okimission" else { return }
                    DemoFlowRunner.apply(host: url.host ?? "", to: model)
                }
        }
    }
}

enum DemoFlowRunner {
    @MainActor
    static func apply(launchArgs: [String], to model: DemoModel) {
        guard let idx = launchArgs.firstIndex(of: "-flow"),
              idx + 1 < launchArgs.count else { return }
        apply(host: launchArgs[idx + 1], to: model)
    }

    @MainActor
    static func apply(host: String, to model: DemoModel) {
        switch host {
        case "sleep": model.startSleep()
        case "fire": model.fireAlarm()
        case "accept": model.acceptAlarm()
        case "tick": model.tickMission()
        case "complete":
            while model.missionProgress < model.missionTarget {
                model.tickMission()
            }
        case "bedtime": model.dismissShare()
        default: break
        }
    }
}

@Observable
@MainActor
final class DemoModel {
    enum Screen: Equatable {
        case bedtime
        case alarmFiring
        case mission
        case shareCard
    }

    var screen: Screen = .bedtime
    var nextAlarmHour: Int = 7
    var nextAlarmMinute: Int = 0
    var streak: Int = 14
    var missionProgress: Int = 0
    var missionTarget: Int = 5
    var lastMissionDurationSeconds: Double = 0
    var sleepCountdownSeconds: Int = 3
    var sleepCountdownRemaining: Int = 0

    var pack: VoicePack = VoicePackSamples.samplePaidPack(
        characterId: CharacterId("oshi-a"),
        iapProductId: "com.okimission.voicepack.oshia"
    )
    var ownership: VoicePackOwnership

    private let player = AVFoundationVoicePlayer(
        locator: BundleVoiceAssetLocator(bundle: .main, subdirectory: "Voices")
    )
    private var alarmTask: Task<Void, Never>?
    private var missionStartedAt: Date?
    private let cue: MissionVoiceCue

    init() {
        let stub = VoicePackSamples.samplePaidPack(
            characterId: CharacterId("oshi-a"),
            iapProductId: "com.okimission.voicepack.oshia"
        )
        let owned = VoicePackOwnership(ownedPackIds: [stub.id])
        self.ownership = owned
        self.pack = stub
        self.cue = MissionVoiceCue(
            player: AVFoundationVoicePlayer(
                locator: BundleVoiceAssetLocator(bundle: .main, subdirectory: "Voices")
            ),
            pack: stub,
            ownership: owned
        )
    }

    var nextAlarmLabel: String {
        String(format: "%02d:%02d", nextAlarmHour, nextAlarmMinute)
    }

    func startSleep() {
        alarmTask?.cancel()
        screen = .bedtime
        sleepCountdownRemaining = sleepCountdownSeconds
        alarmTask = Task { [weak self] in
            guard let self else { return }
            while await self.sleepCountdownRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run { self.sleepCountdownRemaining -= 1 }
            }
            if Task.isCancelled { return }
            await MainActor.run { self.fireAlarm() }
        }
    }

    func cancelSleep() {
        alarmTask?.cancel()
        alarmTask = nil
    }

    func fireAlarm() {
        screen = .alarmFiring
        Task { await play(.alarmRinging) }
    }

    func acceptAlarm() {
        missionProgress = 0
        missionStartedAt = Date()
        screen = .mission
        Task {
            await play(.missionStart)
        }
    }

    func tickMission() {
        guard missionProgress < missionTarget else { return }
        missionProgress += 1
        if missionProgress == missionTarget {
            completeMission()
        } else if missionProgress == missionTarget / 2 {
            Task { await play(.missionEncouragement, pickIndex: 0) }
        } else if missionProgress == max(1, missionTarget - 1) {
            Task { await play(.missionEncouragement, pickIndex: 1) }
        }
    }

    private func completeMission() {
        if let start = missionStartedAt {
            lastMissionDurationSeconds = Date().timeIntervalSince(start)
        }
        streak += 1
        screen = .shareCard
        Task { await play(.missionSuccess) }
    }

    func dismissShare() {
        screen = .bedtime
    }

    private func play(_ context: VoiceContext, pickIndex: Int = 0) async {
        await cue.fire(context, pickIndex: pickIndex)
    }
}

struct RootShell: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.screen {
            case .bedtime: BedtimeScreen()
            case .alarmFiring: AlarmFiringScreen()
            case .mission: MissionScreen()
            case .shareCard: ShareCardScreen()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: model.screen)
        .foregroundStyle(.white)
    }
}

struct BedtimeScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Text("明日のアラーム")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(2)
                Text(model.nextAlarmLabel)
                    .font(.system(size: 120, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            OshiCard(pack: model.pack, isFreemiumRow: false)
                .padding(.horizontal, 24)

            MissionPreviewCard()
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    haptic(.medium)
                    model.startSleep()
                } label: {
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(WaykColors.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(model.sleepCountdownRemaining > 0)
                Text("タップして体験 — \(model.sleepCountdownSeconds)秒後にアラームが鳴る")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var buttonLabel: String {
        model.sleepCountdownRemaining > 0
            ? "起こすまで \(model.sleepCountdownRemaining)…"
            : "おやすみ — 推しに起こしてもらう"
    }
}

@MainActor
func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: style).impactOccurred()
    #endif
}

#if canImport(UIKit)
import UIKit
#endif

struct AlarmFiringScreen: View {
    @Environment(DemoModel.self) private var model
    @State private var pulse = false

    var body: some View {
        ZStack {
            WaykColors.accent.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 48) {
                Spacer()
                Circle()
                    .fill(WaykColors.accent.opacity(pulse ? 0.6 : 0.3))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                    )
                    .scaleEffect(pulse ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                        value: pulse
                    )

                VStack(spacing: 6) {
                    Text(model.pack.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(2)
                    Text("「起きて、もう朝だよ」")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("ミッションをクリアするまで止まらない")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Button {
                    haptic(.heavy)
                    model.acceptAlarm()
                } label: {
                    Text("起きる")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(WaykColors.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulse = true }
    }
}

struct MissionScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("ミッション")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(2)
                Spacer()
                Text("\(model.missionProgress) / \(model.missionTarget)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            VStack(spacing: 16) {
                Text("青いものを探せ")
                    .font(.system(size: 36, weight: .bold))
                Text("カメラに青い物体を \(model.missionTarget) 個映してね")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // Mock camera viewport
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                VStack(spacing: 14) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("(カメラ視界モック)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                // dot progress
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<model.missionTarget, id: \.self) { i in
                            Circle()
                                .fill(i < model.missionProgress ? WaykColors.accent : Color.white.opacity(0.15))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 24)

            Button {
                haptic(.light)
                model.tickMission()
            } label: {
                Text("青いもの発見 (タップでカウント)")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(WaykColors.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct ShareCardScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("おはよう、起きれたね")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            // share card (designed to be exported / screenshot for SNS)
            VStack(spacing: 18) {
                HStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [WaykColors.accent, .pink],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.pack.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("CV: " + (model.pack.voiceActor ?? "—"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .foregroundStyle(WaykColors.accent)
                }

                Divider().background(Color.white.opacity(0.1))

                VStack(spacing: 6) {
                    Text("\(model.streak)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("DAY STREAK")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)
                }

                HStack(spacing: 24) {
                    StatBlock(label: "起床", value: model.nextAlarmLabel)
                    StatBlock(label: "クリア", value: String(format: "%.0f秒", max(1, model.lastMissionDurationSeconds)))
                    StatBlock(label: "ミッション", value: "\(model.missionTarget)")
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            HStack(spacing: 14) {
                ShareButton(systemImage: "music.note", label: "TikTok")
                ShareButton(systemImage: "xmark", label: "X")
                ShareButton(systemImage: "square.and.arrow.up", label: "保存")
            }
            .padding(.horizontal, 24)

            Button {
                haptic(.light)
                model.dismissShare()
            } label: {
                Text("閉じる")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareButton: View {
    let systemImage: String
    let label: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
            Text(label)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct OshiCard: View {
    let pack: VoicePack
    let isFreemiumRow: Bool
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(
                    colors: [WaykColors.accent, .pink],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("選択中の推し")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                Text(pack.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text("CV: " + (pack.voiceActor ?? "—"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct MissionPreviewCard: View {
    @Environment(DemoModel.self) private var model
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "eye.fill")
                    .foregroundStyle(WaykColors.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("明日のミッション")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                Text("青いものを探せ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(model.missionTarget) 個 カメラで撮影")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

enum WaykColors {
    static let accent = Color(red: 1.0, green: 0.44, blue: 0.57)
}
