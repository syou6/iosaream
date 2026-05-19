import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum AppFont {
    public static let largeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
    public static let title1: Font = .system(size: 28, weight: .semibold, design: .rounded)
    public static let title2: Font = .system(size: 22, weight: .semibold, design: .rounded)
    public static let title3: Font = .system(size: 20, weight: .semibold, design: .rounded)
    public static let headline: Font = .system(size: 17, weight: .semibold)
    public static let body: Font = .system(size: 17, weight: .regular)
    public static let bodyEmphasised: Font = .system(size: 17, weight: .medium)
    public static let callout: Font = .system(size: 16, weight: .regular)
    public static let subhead: Font = .system(size: 15, weight: .regular)
    public static let footnote: Font = .system(size: 13, weight: .regular)
    public static let caption: Font = .system(size: 12, weight: .regular)
    public static let caption2: Font = .system(size: 11, weight: .regular)

    public static let displayClock: Font = .system(size: 64, weight: .light, design: .rounded)
    public static let timerLarge: Font = .system(size: 44, weight: .semibold, design: .monospaced)
}
#endif
