import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionEngine
import OkiMissionDesignSystem

public struct MathMissionView: View {
    public let experience: MissionExperience
    @Binding public var state: MissionState
    @State private var problems: [MathProblem] = []
    @State private var index: Int = 0
    @State private var inputText: String = ""
    @State private var feedback: Feedback = .none

    enum Feedback: Equatable {
        case none
        case correct
        case wrong
    }

    public init(experience: MissionExperience, state: Binding<MissionState>) {
        self.experience = experience
        self._state = state
    }

    public var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            Text("\(index + 1) / \(problems.count)")
                .font(AppFont.subhead)
                .foregroundStyle(AppColor.textSecondary)

            if let problem = problems.indices.contains(index) ? problems[index] : nil {
                Text(problem.prompt)
                    .font(AppFont.displayClock.weight(.regular))
                    .foregroundStyle(AppColor.textPrimary)

                TextField("答え", text: $inputText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(AppFont.title1)
                    .padding(AppSpacing.md)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppCornerRadius.md))

                Button("確定") { Task { await submit() } }
                    .buttonStyle(.appPrimary)
                    .disabled(inputText.isEmpty)
            }

            switch feedback {
            case .none:
                EmptyView()
            case .correct:
                Label("正解", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.success)
                    .font(AppFont.headline)
            case .wrong:
                Label("もう一度", systemImage: "xmark.circle.fill")
                    .foregroundStyle(AppColor.danger)
                    .font(AppFont.headline)
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
        .task {
            problems = await experience.problems
        }
    }

    private func submit() async {
        guard let answer = Int(inputText), problems.indices.contains(index) else { return }
        let correct = await experience.submitMathAnswer(answer, at: index)
        feedback = correct ? .correct : .wrong
        if correct {
            inputText = ""
            try? await Task.sleep(nanoseconds: 300_000_000)
            if index < problems.count - 1 {
                index += 1
            }
            feedback = .none
        }
    }
}
#endif
