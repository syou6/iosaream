import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum AppGlassLevel {
    case subtle
    case regular
    case prominent

    var fallbackMaterial: Material {
        switch self {
        case .subtle: return .thinMaterial
        case .regular: return .regularMaterial
        case .prominent: return .ultraThickMaterial
        }
    }
}

public struct AppGlassModifier: ViewModifier {
    public let level: AppGlassLevel
    public let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                level.fallbackMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}

public extension View {
    func appGlass(
        _ level: AppGlassLevel = .regular,
        cornerRadius: CGFloat = AppCornerRadius.md
    ) -> some View {
        modifier(AppGlassModifier(level: level, cornerRadius: cornerRadius))
    }
}
#endif
