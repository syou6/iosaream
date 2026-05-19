import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionServices
import OkiMissionDesignSystem

public struct SettingsView: View {
    @Environment(\.appDependencies) private var dependencies
    @Environment(\.router) private var router
    @State private var entitlement: Entitlement = .free

    public init() {}

    public var body: some View {
        Form {
            Section("サブスクリプション") {
                HStack {
                    Text("プラン")
                    Spacer()
                    Text(entitlement.isPro ? "Pro" : "Free")
                        .foregroundStyle(entitlement.isPro ? AppColor.brand : AppColor.textSecondary)
                }
                if entitlement.isPro, let expiresAt = entitlement.expiresAt {
                    HStack {
                        Text("次回更新")
                        Spacer()
                        Text(expiresAt.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                if !entitlement.isPro {
                    Button("Pro にアップグレード") {
                        router.present(.paywall)
                    }
                }
            }

            Section("法務") {
                NavigationLink("プライバシーポリシー", value: AppRoute.privacyPolicy)
                NavigationLink("利用規約", value: AppRoute.terms)
                NavigationLink("特定商取引法に基づく表記", value: AppRoute.tokushoho)
            }

            Section("サポート") {
                Link("お問い合わせ", destination: URL(string: "mailto:support@oki-mission.app")!)
                Link("Web サイト", destination: URL(string: "https://oki-mission.app")!)
            }

            Section("アカウント") {
                Button("ログアウト") {
                    Task { try? await dependencies.authService.signOut() }
                }
                Button("アカウントを削除", role: .destructive) {
                    Task { try? await dependencies.authService.deleteAccount() }
                }
            }

            Section("ビルド情報") {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .navigationTitle("設定")
        .task {
            entitlement = await dependencies.entitlementService.currentEntitlement
        }
    }
}

public struct MissionHistoryView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.textTertiary)
            Text("履歴を表示するには SwiftData クエリを追加してください")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
        .padding(AppSpacing.xl)
        .navigationTitle("履歴")
    }
}

public struct TokushohoView: View {
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("特定商取引法に基づく表記")
                    .font(AppFont.title2)
                Text("実際の表記内容は docs/legal/tokushoho.ja.md から HTML 化してください")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(AppSpacing.lg)
        }
        .navigationTitle("特商法")
    }
}
#endif
