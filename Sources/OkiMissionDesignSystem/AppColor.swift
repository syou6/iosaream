import Foundation
#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum AppColor {
    public static let brand = Color(red: 0.31, green: 0.56, blue: 0.94)
    public static let brandSecondary = Color(red: 0.55, green: 0.78, blue: 1.0)
    public static let accentSunrise = Color(red: 0.99, green: 0.66, blue: 0.36)
    public static let accentMint = Color(red: 0.36, green: 0.83, blue: 0.69)

    public static let success = Color(red: 0.18, green: 0.78, blue: 0.42)
    public static let warning = Color(red: 0.99, green: 0.71, blue: 0.18)
    public static let danger = Color(red: 0.93, green: 0.27, blue: 0.30)
    public static let info = Color(red: 0.36, green: 0.65, blue: 0.94)

    public static let streakActive = Color(red: 0.99, green: 0.55, blue: 0.27)

    #if canImport(UIKit)
    public static let background = Color(UIColor.systemBackground)
    public static let surface = Color(UIColor.secondarySystemBackground)
    public static let surfaceElevated = Color(UIColor.tertiarySystemBackground)
    public static let textPrimary = Color(UIColor.label)
    public static let textSecondary = Color(UIColor.secondaryLabel)
    public static let textTertiary = Color(UIColor.tertiaryLabel)
    public static let separator = Color(UIColor.separator)
    public static let streakInactive = Color(UIColor.tertiaryLabel)
    #elseif canImport(AppKit)
    public static let background = Color(NSColor.windowBackgroundColor)
    public static let surface = Color(NSColor.underPageBackgroundColor)
    public static let surfaceElevated = Color(NSColor.controlBackgroundColor)
    public static let textPrimary = Color(NSColor.labelColor)
    public static let textSecondary = Color(NSColor.secondaryLabelColor)
    public static let textTertiary = Color(NSColor.tertiaryLabelColor)
    public static let separator = Color(NSColor.separatorColor)
    public static let streakInactive = Color(NSColor.tertiaryLabelColor)
    #else
    public static let background = Color.white
    public static let surface = Color.white
    public static let surfaceElevated = Color.white
    public static let textPrimary = Color.black
    public static let textSecondary = Color.gray
    public static let textTertiary = Color.gray
    public static let separator = Color.gray
    public static let streakInactive = Color.gray
    #endif
}
#endif
