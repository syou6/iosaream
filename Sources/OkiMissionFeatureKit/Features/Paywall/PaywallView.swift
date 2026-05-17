import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionServices
import OkiMissionDesignSystem

public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.router) private var router
    @State private var offerings: [ProductOffering] = []
    @State private var selected: ProductOffering?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var didConfirmTokushoho = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                    benefits
                    offeringsList
                    purchaseButton
                    legalLinks
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("OkiMission Pro")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: dismiss.callAsFunction)
                }
            }
            .task { await load() }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(AppColor.brand)
            Text("Pro でもっと自由に")
                .font(AppFont.title1)
            Text("AI ミッション、ストリーク無制限、カスタマイズ機能を解放")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                benefitRow("checkmark", "毎朝 AI が新しいミッションを生成")
                benefitRow("flame.fill", "ストリーク無制限")
                benefitRow("paintbrush.fill", "サウンドとテーマのカスタマイズ")
                benefitRow("icloud.fill", "デバイス間で同期")
            }
        }
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.brand)
            Text(text).font(AppFont.body)
        }
    }

    private var offeringsList: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(offerings) { offering in
                OfferingRow(
                    offering: offering,
                    isSelected: selected?.id == offering.id,
                    onTap: { selected = offering }
                )
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColor.danger)
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Text(isPurchasing ? "処理中…" : "Pro に登録")
        }
        .buttonStyle(.appPrimary)
        .disabled(selected == nil || isPurchasing)
    }

    private var legalLinks: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("登録すると自動更新されます。いつでも解約できます。")
                .font(AppFont.caption)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: AppSpacing.md) {
                Button("特商法") { router.present(.tokushohoSheet) }
                Text("·").foregroundStyle(AppColor.textTertiary)
                Button("プライバシー") { router.push(.privacyPolicy) }
                Text("·").foregroundStyle(AppColor.textTertiary)
                Button("利用規約") { router.push(.terms) }
            }
            .font(AppFont.caption)
        }
    }

    private func load() async {
        do {
            offerings = try await dependencies.entitlementService.loadOfferings()
            selected = offerings.first { $0.id.contains("yearly") } ?? offerings.first
        } catch {
            errorMessage = "プランを読み込めませんでした"
        }
    }

    private func purchase() async {
        guard let offering = selected else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            await dependencies.analytics.track(AnalyticsEventName.purchaseStarted, properties: [
                "product_id": .string(offering.id)
            ])
            let result = try await dependencies.entitlementService.purchase(productId: offering.id)
            switch result {
            case .purchased:
                await dependencies.analytics.track(AnalyticsEventName.purchaseSucceeded, properties: [
                    "product_id": .string(offering.id)
                ])
                dismiss()
            case .cancelled:
                await dependencies.analytics.track(AnalyticsEventName.purchaseCancelled)
            case .pending:
                errorMessage = "決済が保留中です"
            }
        } catch {
            errorMessage = error.localizedDescription
            await dependencies.analytics.track(AnalyticsEventName.purchaseFailed, properties: [
                "product_id": .string(offering.id),
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

struct OfferingRow: View {
    let offering: ProductOffering
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(offering.displayName)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    if offering.hasIntroOffer, let intro = offering.introOfferDescription {
                        Text(intro)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.success)
                    }
                }
                Spacer()
                Text(offering.localizedPrice)
                    .font(AppFont.title3)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? AppColor.brand : AppColor.separator, lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                            .fill(AppColor.surface.opacity(isSelected ? 1 : 0.6))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

public struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    public init() {}
    public var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppColor.brand)
            Text("OkiMission")
                .font(AppFont.largeTitle)
            Text("ミッションをクリアしないと止まらない目覚まし")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            Button("はじめる") { dismiss() }
                .buttonStyle(.appPrimary)
                .padding(.horizontal, AppSpacing.xl)
            Button("ログイン") {}
                .buttonStyle(.appSecondary)
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.bottom, AppSpacing.xl)
    }
}
#endif
