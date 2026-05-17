import Foundation
#if canImport(SwiftUI)
import SwiftUI
import SwiftData
import OkiMissionCore
import OkiMissionDomain
import OkiMissionDesignSystem
import OkiMissionEngine

public struct AlarmListView: View {
    @Environment(\.router) private var router
    @Environment(\.appDependencies) private var dependencies
    @Query(sort: [
        SortDescriptor(\AlarmEntity.timeOfDayHour),
        SortDescriptor(\AlarmEntity.timeOfDayMinute)
    ]) private var alarms: [AlarmEntity]

    public init() {}

    public var body: some View {
        Group {
            if alarms.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(alarms) { alarm in
                        AlarmRow(alarm: alarm) {
                            router.push(.alarmEditor(alarmId: alarm.id))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("アラーム")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.push(.alarmEditor(alarmId: nil))
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.textTertiary)
            Text("アラームを追加して目覚めよう")
                .font(AppFont.title3)
                .foregroundStyle(AppColor.textPrimary)
            Text("ミッションをクリアしないと止まらない目覚ましアラームです")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button("追加する") {
                router.push(.alarmEditor(alarmId: nil))
            }
            .buttonStyle(.appPrimary)
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(AppSpacing.xl)
    }
}

struct AlarmRow: View {
    let alarm: AlarmEntity
    let onTap: () -> Void

    var nextFire: Date? {
        let spec = AlarmSpec(entity: alarm)
        return AlarmFireResolver.nextFireDate(for: spec, after: Date())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(alarm.label)
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    if let h = alarm.timeOfDayHour, let m = alarm.timeOfDayMinute {
                        Text(String(format: "%02d:%02d", h, m))
                            .font(AppFont.displayClock.weight(.regular))
                            .foregroundStyle(alarm.isEnabled ? AppColor.textPrimary : AppColor.textTertiary)
                    } else if let date = alarm.fireDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(AppFont.bodyEmphasised)
                            .foregroundStyle(alarm.isEnabled ? AppColor.textPrimary : AppColor.textTertiary)
                    } else if let secs = alarm.countdownSeconds {
                        Text("\(secs / 60) 分")
                            .font(AppFont.bodyEmphasised)
                            .foregroundStyle(alarm.isEnabled ? AppColor.textPrimary : AppColor.textTertiary)
                    }
                    if let next = nextFire {
                        Text("次回 \(next.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}
#endif
