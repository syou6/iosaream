import SwiftUI
import AVFoundation
import OkiMissionCore
import OkiMissionEngine
import OkiMissionServices
import OkiMissionVoicePack
import OkiMissionPlatformKit
import OkiMissionFeatureKit
#if canImport(UIKit)
import UIKit
#endif

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
    var pulseAccent: Bool = false

    var pack: VoicePack = VoicePackSamples.samplePaidPack(
        characterId: CharacterId("oshi-a"),
        iapProductId: "com.okimission.voicepack.oshia"
    )
    var ownership: VoicePackOwnership

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
        pulseAccent = true
        Task { await play(.alarmRinging) }
    }

    func acceptAlarm() {
        missionProgress = 0
        missionStartedAt = Date()
        screen = .mission
        pulseAccent = false
        Task { await play(.missionStart) }
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

// MARK: - Root

struct RootShell: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        ZStack {
            AppMeshBackground(pulse: model.pulseAccent || model.screen == .alarmFiring)
                .ignoresSafeArea()

            AmbientSparkles()
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(model.screen == .mission ? 0.35 : 0.7)

            Group {
                switch model.screen {
                case .bedtime: BedtimeScreen()
                case .alarmFiring: AlarmFiringScreen()
                case .mission: MissionScreen()
                case .shareCard: ShareCardScreen()
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: model.screen)
        .foregroundStyle(.white)
    }
}

struct AmbientSparkles: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                var rng = SeededRNG(seed: 42)
                for _ in 0..<28 {
                    let x = Double.random(in: 0...size.width, using: &rng)
                    let y0 = Double.random(in: 0...size.height, using: &rng)
                    let speed = Double.random(in: 6...22, using: &rng)
                    let phase = Double.random(in: 0...10, using: &rng)
                    let y = (y0 - speed * t.truncatingRemainder(dividingBy: 60))
                        .truncatingRemainder(dividingBy: size.height + 60)
                    let yWrapped = y < 0 ? y + size.height + 60 : y
                    let radius = Double.random(in: 1.2...2.6, using: &rng)
                    let twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2 + phase))
                    let dot = Path(ellipseIn: CGRect(x: x, y: yWrapped, width: radius * 2, height: radius * 2))
                    ctx.fill(dot, with: .color(Palette.glow.opacity(twinkle * 0.9)))
                }
            }
        }
    }
}

// MARK: - Background

struct AppMeshBackground: View {
    let pulse: Bool
    @State private var t: Double = 0

    var body: some View {
        let dy1 = 0.5 + 0.05 * sin(t)
        let dy2 = 0.5 + 0.05 * cos(t)
        let points: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, Float(dy1)), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, Float(dy2)),
            SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
        ]
        let colors: [Color] = [
            .black, .indigo.opacity(0.55), .black,
            Palette.accent.opacity(0.45), Palette.accent2.opacity(0.6), .purple.opacity(0.4),
            .black, Palette.accent.opacity(0.35), .black
        ]
        return ZStack {
            MeshGradient(width: 3, height: 3, points: points, colors: colors)
                .blur(radius: pulse ? 28 : 50)
                .overlay(Color.black.opacity(pulse ? 0.15 : 0.35))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: t)
                .onAppear { withAnimation { t = .pi } }
        }
    }
}

enum Palette {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.62)
    static let accent2 = Color(red: 0.96, green: 0.50, blue: 0.84)
    static let glow = Color(red: 1.0, green: 0.78, blue: 0.86)
}

// MARK: - Bedtime

struct BedtimeScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 8)
            VStack(spacing: 6) {
                LabelChip(text: "明日のアラーム")
                Text(model.nextAlarmLabel)
                    .font(.system(size: 130, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Palette.glow],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: Palette.accent.opacity(0.35), radius: 24)
            }

            OshiHeroCard(pack: model.pack)
                .padding(.horizontal, 22)

            MissionTeaseRow(target: model.missionTarget)
                .padding(.horizontal, 22)

            Spacer()

            VStack(spacing: 10) {
                GlowingButton(
                    label: buttonLabel,
                    enabled: model.sleepCountdownRemaining == 0
                ) {
                    haptic(.medium)
                    model.startSleep()
                }
                Text("タップして体験 — \(model.sleepCountdownSeconds)秒後にアラームが鳴る")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }

    private var buttonLabel: String {
        model.sleepCountdownRemaining > 0
            ? "起こすまで \(model.sleepCountdownRemaining)…"
            : "おやすみ — 推しに起こしてもらう"
    }
}

struct OshiHeroCard: View {
    let pack: VoicePack
    @State private var floating = false

    var body: some View {
        HStack(spacing: 16) {
            OshiAvatar(seed: pack.characterId.rawValue, size: 64)
                .offset(y: floating ? -3 : 3)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: floating)
                .onAppear { floating = true }

            VStack(alignment: .leading, spacing: 4) {
                LabelChip(text: "選択中の推し", small: true)
                Text(pack.displayName)
                    .font(.system(size: 20, weight: .bold))
                Text("CV: " + (pack.voiceActor ?? "—"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(18)
        .background(GlassPanel())
    }
}

struct MissionTeaseRow: View {
    let target: Int
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Palette.accent, Palette.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image(systemName: "eye.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                LabelChip(text: "明日のミッション", small: true)
                Text("青いものを探せ")
                    .font(.system(size: 17, weight: .bold))
                Text("\(target) 個 カメラで撮影")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.accent)
        }
        .padding(16)
        .background(GlassPanel())
    }
}

// MARK: - Alarm firing

struct AlarmFiringScreen: View {
    @Environment(DemoModel.self) private var model
    @State private var ringScale = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Palette.accent.opacity(0.6 - Double(i) * 0.18), lineWidth: 2)
                        .frame(width: 220 + CGFloat(i) * 60, height: 220 + CGFloat(i) * 60)
                        .scaleEffect(ringScale ? 1.05 : 0.95)
                        .opacity(ringScale ? 0.4 : 1)
                        .animation(
                            .easeInOut(duration: 1.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.2),
                            value: ringScale
                        )
                }

                OshiAvatar(seed: model.pack.characterId.rawValue, size: 200)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 3))
                    .shadow(color: Palette.accent, radius: 30)
                    .scaleEffect(ringScale ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: ringScale)
            }

            VStack(spacing: 12) {
                LabelChip(text: model.pack.displayName)
                Text("「起きて、もう朝だよ」")
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Text("ミッションをクリアするまで止まらない")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))

            GlowingButton(label: "起きる", enabled: true, big: true) {
                haptic(.heavy)
                model.acceptAlarm()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
        .onAppear { ringScale = true }
    }
}

// MARK: - Mission

struct MissionScreen: View {
    @Environment(DemoModel.self) private var model

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                LabelChip(text: "ミッション", small: true)
                Spacer()
                Text("\(model.missionProgress) / \(model.missionTarget)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            VStack(spacing: 8) {
                Text("青いものを探せ")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Palette.glow], startPoint: .top, endPoint: .bottom)
                    )
                Text("カメラに青い物体を \(model.missionTarget) 個映してね")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 22)

            // Camera mock with animated focus brackets
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.25), .indigo.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                FocusBrackets()
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 130, height: 130)
                Text("(カメラ視界モック)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .offset(y: 90)
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(0..<model.missionTarget, id: \.self) { i in
                            let done = i < model.missionProgress
                            Capsule()
                                .fill(done ? Palette.accent : .white.opacity(0.12))
                                .frame(width: done ? 26 : 16, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: model.missionProgress)
                        }
                    }
                    .padding(.bottom, 22)
                }
            }
            .padding(.horizontal, 22)

            GlowingButton(label: "青いもの発見", enabled: true, big: true) {
                haptic(.light)
                model.tickMission()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
        }
    }
}

struct FocusBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len: CGFloat = 24
        var p = Path()
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len)); p.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - len)); p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        return p
    }
}

// MARK: - Share card

struct ShareCardScreen: View {
    @Environment(DemoModel.self) private var model
    @State private var burstTick: Date = .now

    var body: some View {
        ZStack {
            Confetti(seed: burstTick)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Spacer(minLength: 12)
                Text("おはよう、起きれたね")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                ZStack {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Palette.accent.opacity(0.35), Palette.accent2.opacity(0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(spacing: 18) {
                        HStack(spacing: 12) {
                            OshiAvatar(seed: model.pack.characterId.rawValue, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.pack.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                Text("CV: " + (model.pack.voiceActor ?? "—"))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "flame.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Palette.accent)
                        }
                        Divider().background(.white.opacity(0.1))
                        VStack(spacing: 0) {
                            Text("\(model.streak)")
                                .font(.system(size: 96, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    LinearGradient(colors: [.white, Palette.glow], startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: Palette.accent.opacity(0.5), radius: 20)
                            Text("DAY STREAK")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        HStack(spacing: 18) {
                            StatBlock(label: "起床", value: model.nextAlarmLabel)
                            StatBlock(label: "クリア", value: String(format: "%.0f秒", max(1, model.lastMissionDurationSeconds)))
                            StatBlock(label: "ミッション", value: "\(model.missionTarget)")
                        }
                    }
                    .padding(26)
                }
                .padding(.horizontal, 22)

                Spacer()

                HStack(spacing: 12) {
                    ShareIconBtn(systemImage: "music.note", label: "TikTok")
                    ShareIconBtn(systemImage: "xmark", label: "X")
                    ShareIconBtn(systemImage: "square.and.arrow.up", label: "保存")
                }
                .padding(.horizontal, 22)

                Button {
                    haptic(.light)
                    model.dismissShare()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 14)
                }
                .padding(.bottom, 18)
            }
        }
        .onAppear { burstTick = .now }
    }
}

struct StatBlock: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareIconBtn: View {
    let systemImage: String
    let label: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(GlassPanel())
        .foregroundStyle(.white)
    }
}

// MARK: - Avatar (deterministic gradient with face glyph)

struct OshiAvatar: View {
    let seed: String
    var size: CGFloat = 64

    private static let emojis = ["🌸", "✨", "🦋", "💖", "🍑", "⭐️", "🌷", "🍀", "🎀", "🌙"]

    var body: some View {
        let pair = palette(from: seed)
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [pair.0, pair.1, pair.0.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            Circle()
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: size * 0.04
                )
                .blur(radius: 2)
            Text(emoji)
                .font(.system(size: size * 0.55))
                .shadow(color: .white.opacity(0.4), radius: 4)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5))
        .shadow(color: pair.0.opacity(0.7), radius: size * 0.25)
    }

    private var emoji: String {
        var hash: UInt32 = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ UInt32(byte) }
        return Self.emojis[Int(hash) % Self.emojis.count]
    }

    private func palette(from seed: String) -> (Color, Color) {
        var hash: UInt32 = 5381
        for byte in seed.utf8 { hash = (hash &* 33) &+ UInt32(byte) }
        let h1 = Double(hash % 360) / 360.0
        let h2 = (h1 + 0.08).truncatingRemainder(dividingBy: 1.0)
        let c1 = Color(hue: h1, saturation: 0.55, brightness: 0.95)
        let c2 = Color(hue: h2, saturation: 0.65, brightness: 0.88)
        return (c1, c2)
    }
}

// MARK: - Reusables

struct LabelChip: View {
    let text: String
    var small: Bool = false
    var body: some View {
        Text(text)
            .font(.system(size: small ? 10 : 12, weight: .heavy))
            .tracking(small ? 2 : 3)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.55))
    }
}

struct GlassPanel: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct GlowingButton: View {
    let label: String
    let enabled: Bool
    var big: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: big ? 20 : 17, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, big ? 22 : 18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: enabled ? [Palette.accent, Palette.accent2] : [Color.white.opacity(0.15), Color.white.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: enabled ? Palette.accent.opacity(0.55) : .clear, radius: 20, y: 8)
                )
                .foregroundStyle(enabled ? Color.black : .white.opacity(0.5))
        }
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .disabled(!enabled)
    }
}

// MARK: - Confetti via Canvas

struct Confetti: View, Animatable {
    let seed: Date
    @State private var animate = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { context in
            Canvas { ctx, size in
                let elapsed = context.date.timeIntervalSince(seed)
                guard elapsed < 4 else { return }
                let pieces = 70
                var rng = SeededRNG(seed: UInt64(seed.timeIntervalSince1970.bitPattern))
                for i in 0..<pieces {
                    let dx = Double.random(in: -120...120, using: &rng) * (1 + elapsed * 0.3)
                    let baseX = Double.random(in: 0...size.width, using: &rng)
                    let x = baseX + dx
                    let speed = Double.random(in: 100...260, using: &rng)
                    let y = -30 + speed * elapsed
                    let rot = Double.random(in: 0...(.pi * 2), using: &rng) + elapsed * 6
                    let size2 = Double.random(in: 4...11, using: &rng)
                    let hue = Double((i * 47) % 360) / 360.0
                    let color = Color(hue: hue, saturation: 0.85, brightness: 0.95).opacity(max(0, 1 - elapsed / 4))
                    var path = Path()
                    path.addRect(CGRect(x: -size2/2, y: -size2/2, width: size2, height: size2 * 0.4))
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(rot))
                    ctx.fill(path, with: .color(color))
                    ctx.rotate(by: .radians(-rot))
                    ctx.translateBy(x: -x, y: -y)
                }
            }
        }
    }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Haptic

@MainActor
func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    #if canImport(UIKit)
    UIImpactFeedbackGenerator(style: style).impactOccurred()
    #endif
}
