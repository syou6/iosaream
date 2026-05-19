import Foundation
#if canImport(SwiftUI)
import SwiftUI
import OkiMissionCore

@MainActor
@Observable
public final class Router {
    public var path: [AppRoute] = []
    public var modal: ModalRoute?
    public var fullScreen: FullScreenRoute?

    public init() {}

    public func push(_ route: AppRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        path.removeAll()
    }

    public func present(_ modal: ModalRoute) {
        self.modal = modal
    }

    public func dismiss() {
        self.modal = nil
    }

    public func openFullScreen(_ route: FullScreenRoute) {
        self.fullScreen = route
    }

    public func closeFullScreen() {
        self.fullScreen = nil
    }

    public func handleDeepLink(_ url: URL) -> Bool {
        guard url.scheme == "okimission" else { return false }
        let host = url.host ?? ""
        let components = url.pathComponents.filter { $0 != "/" }
        switch (host, components) {
        case ("mission", let parts) where parts.count == 1:
            guard let id = UUID(uuidString: parts[0]) else { return false }
            push(.missionRun(runId: id))
            return true
        case ("alarm", let parts) where parts.count == 1:
            guard let id = UUID(uuidString: parts[0]) else { return false }
            push(.alarmDetail(alarmId: id))
            return true
        case ("settings", _):
            push(.settings)
            return true
        case ("paywall", _):
            present(.paywall)
            return true
        default:
            return false
        }
    }
}
#endif
