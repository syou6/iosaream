import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionDesignSystem

public struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appDependencies) private var dependencies
    @State private var label: String
    @State private var hour: Int
    @State private var minute: Int
    @State private var selectedWeekdays: Set<Weekday>
    @State private var soundId: String
    @State private var attachMission: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    public init(alarmId: UUID? = nil) {
        // For brevity this draft uses initial defaults; real impl would
        // hydrate from an injected AlarmRepository fetch by alarmId.
        self._label = State(initialValue: "起床")
        self._hour = State(initialValue: 7)
        self._minute = State(initialValue: 0)
        self._selectedWeekdays = State(initialValue: Set(WeekdayMask.weekdays.decoded()))
        self._soundId = State(initialValue: "sunrise")
        self._attachMission = State(initialValue: true)
    }

    public var body: some View {
        Form {
            Section("時刻") {
                HStack {
                    Picker("時", selection: $hour) {
                        ForEach(0..<24, id: \.self) { Text("\($0)") }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 80)
                    Text(":")
                        .font(AppFont.displayClock)
                    Picker("分", selection: $minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: 80)
                }
            }

            Section("ラベル") {
                TextField("ラベル", text: $label)
            }

            Section("曜日") {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        WeekdayChip(
                            day: day,
                            isOn: selectedWeekdays.contains(day),
                            onToggle: { toggle(day) }
                        )
                    }
                }
            }

            Section("音") {
                Picker("サウンド", selection: $soundId) {
                    Text("Sunrise").tag("sunrise")
                    Text("Bell").tag("bell")
                    Text("Chime").tag("chime")
                    Text("Gentle").tag("gentle")
                }
            }

            Section {
                Toggle("ミッションを設定する", isOn: $attachMission)
                if attachMission {
                    Text("AI が毎日違うミッションを生成します")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(AppColor.danger)
                }
            }
        }
        .navigationTitle("アラーム")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "保存中…" : "保存") {
                    Task { await save() }
                }
                .disabled(isSaving)
            }
        }
    }

    private func toggle(_ day: Weekday) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let spec = AlarmSpec(
            label: label,
            scheduleKind: .recurringWeekly,
            timeOfDay: TimeOfDay(hour: hour, minute: minute),
            weekdayMask: WeekdayMask(selectedWeekdays),
            soundId: soundId
        )
        do {
            try spec.validate()
            _ = try await dependencies.alarmService.schedule(spec)
            await dependencies.analytics.track(AnalyticsEventName.alarmCreated, properties: [
                "schedule_kind": .string(spec.scheduleKind.rawValue)
            ])
            dismiss()
        } catch {
            errorMessage = (error as? DomainError).map(describe) ?? error.localizedDescription
        }
    }

    private func describe(_ error: DomainError) -> String {
        switch error {
        case .invalidAlarmConfig: return "アラーム設定が不完全です"
        case .capabilityDenied(.alarm): return "アラームを設定する権限がありません"
        default: return "保存できませんでした"
        }
    }
}

struct WeekdayChip: View {
    let day: Weekday
    let isOn: Bool
    let onToggle: () -> Void

    var label: String {
        switch day {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }

    var body: some View {
        Button(action: onToggle) {
            Text(label)
                .font(AppFont.subhead.weight(.semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(isOn ? .white : AppColor.textPrimary)
                .background(
                    Circle().fill(isOn ? AppColor.brand : AppColor.surface)
                )
        }
        .buttonStyle(.plain)
    }
}
#endif
