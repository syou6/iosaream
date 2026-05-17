import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore
import OkiMissionDesignSystem

public struct RootView: View {
    @State private var router: Router
    @State private var selectedTab: Tab = .alarms
    @Environment(\.appDependencies) private var dependencies

    public enum Tab: Hashable {
        case alarms, history, settings
    }

    public init(router: Router = Router()) {
        self._router = State(initialValue: router)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $router.path) {
                AlarmListView()
                    .navigationDestination(for: AppRoute.self, destination: destinationView)
            }
            .tabItem {
                Label("アラーム", systemImage: "alarm.fill")
            }
            .tag(Tab.alarms)

            NavigationStack {
                MissionHistoryView()
            }
            .tabItem {
                Label("履歴", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(Tab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("設定", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .tint(AppColor.brand)
        .sheet(item: $router.modal, content: modalView)
        .fullScreenCover(item: $router.fullScreen, content: fullScreenView)
        .onOpenURL { url in
            _ = router.handleDeepLink(url)
        }
        .environment(\.router, router)
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .alarmEditor(let alarmId):
            AlarmEditorView(alarmId: alarmId)
        case .settings:
            SettingsView()
        default:
            Text("Coming soon")
        }
    }

    @ViewBuilder
    private func modalView(for route: ModalRoute) -> some View {
        switch route {
        case .paywall:
            PaywallView()
        case .tokushohoSheet:
            NavigationStack { TokushohoView() }
        case .onboarding:
            OnboardingView()
        case .missionResult(let record):
            MissionResultView(record: record)
        }
    }

    @ViewBuilder
    private func fullScreenView(for route: FullScreenRoute) -> some View {
        switch route {
        case .missionRunner(let templateId, let alarmId):
            MissionShellView(templateId: templateId, alarmId: alarmId)
        case .onboarding:
            OnboardingView()
        }
    }
}
#endif
