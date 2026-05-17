import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionVoicePack
import OkiMissionDesignSystem

public struct CharacterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    private let catalog: VoicePackCatalog
    private let ownership: VoicePackOwnership
    private let onSelect: (VoicePack) -> Void

    public init(
        catalog: VoicePackCatalog,
        ownership: VoicePackOwnership,
        onSelect: @escaping (VoicePack) -> Void
    ) {
        self.catalog = catalog
        self.ownership = ownership
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    ForEach(catalog.packs, id: \.id) { pack in
                        CharacterRow(
                            pack: pack,
                            isOwned: ownership.canPlay(pack),
                            onTap: { handleTap(pack) }
                        )
                    }
                }
                .padding(AppSpacing.lg)
            }
            .navigationTitle("推しを選ぶ")
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

    private func handleTap(_ pack: VoicePack) {
        if ownership.canPlay(pack) {
            onSelect(pack)
            dismiss()
        } else {
            router.present(.paywall)
        }
    }
}

private struct CharacterRow: View {
    let pack: VoicePack
    let isOwned: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                Circle()
                    .fill(themeColor)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(pack.displayName)
                        .font(AppFont.title3)
                        .foregroundStyle(AppColor.textPrimary)
                    if let actor = pack.voiceActor {
                        Text("CV: \(actor)")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Text(tierLabel)
                        .font(AppFont.caption)
                        .foregroundStyle(isOwned ? AppColor.success : AppColor.brand)
                }
                Spacer()
                Image(systemName: isOwned ? "checkmark.circle.fill" : "lock.fill")
                    .foregroundStyle(isOwned ? AppColor.success : AppColor.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))
        }
        .buttonStyle(.plain)
    }

    private var themeColor: Color {
        if let hex = pack.themeColorHex, let parsed = Color(hexString: hex) {
            return parsed
        }
        return AppColor.brand
    }

    private var tierLabel: String {
        switch pack.tier {
        case .free: return "無料"
        case .paidOneShot: return isOwned ? "購入済み" : "¥980 で解放"
        case .subscriberBundled: return isOwned ? "Pro 利用中" : "Pro 限定"
        }
    }
}
#endif
