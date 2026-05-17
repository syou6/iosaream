import Foundation
#if canImport(SwiftUI)
import SwiftUI

// EnvironmentKey requires a nonisolated defaultValue but our injected
// types are @MainActor. SwiftUI accesses defaultValue only inside View
// body / preview evaluation, both of which run on MainActor, so
// `MainActor.assumeIsolated` is sound here. The cache avoids creating a
// new placeholder on every read.

public struct AppDependenciesKey: EnvironmentKey {
    nonisolated(unsafe) private static var cached: AppDependencies?
    public static var defaultValue: AppDependencies {
        MainActor.assumeIsolated {
            if let cached { return cached }
            let stub = AppDependencies.previewStub()
            cached = stub
            return stub
        }
    }
}

public struct RouterKey: EnvironmentKey {
    nonisolated(unsafe) private static var cached: Router?
    public static var defaultValue: Router {
        MainActor.assumeIsolated {
            if let cached { return cached }
            let stub = Router()
            cached = stub
            return stub
        }
    }
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
