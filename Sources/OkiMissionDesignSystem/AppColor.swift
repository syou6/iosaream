import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum AppColor {
    public static let brand = Color(red: 0.31, green: 0.56, blue: 0.94)
    public static let brandSecondary = Color(red: 0.55, green: 0.78, blue: 1.0)
    public static let accentSunrise = Color(red: 0.99, green: 0.66, blue: 0.36)
    public static let accentMint = Color(red: 0.36, green: 0.83, blue: 0.69)

    public static let background = Color(.systemBackground)
    public static let surface = Color(.secondarySystemBackground)
    public static let surfaceElevated = Color(.tertiarySystemBackground)

    public static let textPrimary = Color(.label)
    public static let textSecondary = Color(.secondaryLabel)
    public static let textTertiary = Color(.tertiaryLabel)
    public static let separator = Color(.separator)

    public static let success = Color(red: 0.18, green: 0.78, blue: 0.42)
    public static let warning = Color(red: 0.99, green: 0.71, blue: 0.18)
    public static let danger = Color(red: 0.93, green: 0.27, blue: 0.30)
    public static let info = Color(red: 0.36, green: 0.65, blue: 0.94)

    public static let streakActive = Color(red: 0.99, green: 0.55, blue: 0.27)
    public static let streakInactive = Color(.tertiaryLabel)
}
#endif
