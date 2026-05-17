import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct AppDependenciesKey: EnvironmentKey {
    @MainActor
    public static let defaultValue: AppDependencies = AppDependencies.previewStub()
}

public struct RouterKey: EnvironmentKey {
    @MainActor
    public static let defaultValue: Router = Router()
}

public extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }

    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}
#endif
