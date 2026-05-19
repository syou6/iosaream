import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionServices
import OkiMissionVoicePack
import OkiMissionDesignSystem

public struct VoicePackPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies

    private let pack: VoicePack
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    public init(pack: VoicePack) {
        self.pack = pack
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                    sampleClipsList
                    purchaseButton
                    legalLine
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle(pack.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(themeColor)
                .frame(width: 96, height: 96)
            if let actor = pack.voiceActor {
                Text("CV: \(actor)")
                    .font(AppFont.subhead)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Text("起床ボイス・ミッション中の応援・クリア時のおはようをお届け")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var sampleClipsList: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(displayedClips, id: \.id) { clip in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: iconName(for: clip.context))
                            .foregroundStyle(AppColor.brand)
                        Text(clip.transcript)
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var displayedClips: [VoiceClip] {
        Array(pack.clips.prefix(6))
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Text(isPurchasing ? "処理中…" : purchaseLabel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.appPrimary)
        .disabled(isPurchasing)
    }

    private var purchaseLabel: String {
        switch pack.tier {
        case .free: return "ダウンロード"
        case .paidOneShot: return "購入する"
        case .subscriberBundled: return "Pro に登録"
        }
    }

    private var legalLine: some View {
        VStack(spacing: AppSpacing.xs) {
            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.danger)
            }
            Text("購入後30日以内に出演者の書面要求があった場合、本ボイスは削除されます")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var themeColor: Color {
        if let hex = pack.themeColorHex, let parsed = Color(hexString: hex) {
            return parsed
        }
        return AppColor.brand
    }

    private func iconName(for context: VoiceContext) -> String {
        switch context {
        case .alarmRinging: return "alarm.fill"
        case .missionStart: return "play.fill"
        case .missionEncouragement: return "hands.clap.fill"
        case .missionSuccess: return "sun.max.fill"
        case .missionFailure: return "moon.zzz.fill"
        case .missionRetry: return "arrow.clockwise"
        case .streakNewRecord: return "flame.fill"
        case .streakDailyGreeting: return "hand.wave.fill"
        }
    }

    private func purchase() async {
        guard let productId = pack.iapProductId else {
            dismiss()
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }

        await dependencies.analytics.track(
            AnalyticsEventName.purchaseStarted,
            properties: ["product_id": .string(productId), "pack_id": .string(pack.id.uuidString)]
        )

        do {
            try await dependencies.entitlementService.purchase(productId: productId)
            await dependencies.analytics.track(
                AnalyticsEventName.purchaseSucceeded,
                properties: ["product_id": .string(productId), "pack_id": .string(pack.id.uuidString)]
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            await dependencies.analytics.track(
                AnalyticsEventName.purchaseFailed,
                properties: ["product_id": .string(productId), "error": .string(error.localizedDescription)]
            )
        }
    }
}
#endif
