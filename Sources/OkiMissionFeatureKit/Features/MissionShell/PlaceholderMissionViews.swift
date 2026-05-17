import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionDesignSystem

public struct PoseMissionView: View {
    public let template: GeneratedMissionTemplate
    public init(template: GeneratedMissionTemplate) { self.template = template }
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.brand)
            Text(template.title).font(AppFont.title2)
            Text("カメラに体を映してください")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
    }
}

public struct ShakeMissionView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.brand)
            Text("シェイク！").font(AppFont.title1)
            Text("端末を振ってください")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.lg)
    }
}

public struct ObjectHuntMissionView: View {
    public let template: GeneratedMissionTemplate
    public init(template: GeneratedMissionTemplate) { self.template = template }
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.brand)
            Text(template.title).font(AppFont.title2)
            Text("身の回りのアイテムを探してかざしてください")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
    }
}

public struct BarcodeMissionView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.brand)
            Text("バーコードをスキャン").font(AppFont.title2)
            Text("商品やパッケージのバーコードをかざしてください")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
    }
}

public struct MissionResultView: View {
    public let record: MissionRunRecord
    public init(record: MissionRunRecord) { self.record = record }
    public var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(tint)
            Text(headline).font(AppFont.title1)
            Text("所要時間 \(Int(record.durationSeconds)) 秒")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    private var icon: String {
        switch record.outcome {
        case .success: return "checkmark.seal.fill"
        case .failure: return "xmark.octagon.fill"
        case .cancelled: return "minus.circle.fill"
        case .cheated: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch record.outcome {
        case .success: return AppColor.success
        case .failure: return AppColor.danger
        case .cancelled: return AppColor.textSecondary
        case .cheated: return AppColor.warning
        }
    }

    private var headline: String {
        switch record.outcome {
        case .success: return "ミッション成功"
        case .failure: return "ミッション失敗"
        case .cancelled: return "中断しました"
        case .cheated: return "不正検出"
        }
    }
}
#endif
