import Foundation
#if canImport(SwiftUI)
import SwiftUI

public struct AppCard<Content: View>: View {
    public let glassLevel: AppGlassLevel
    public let padding: CGFloat
    public let cornerRadius: CGFloat
    public let content: () -> Content

    public init(
        glassLevel: AppGlassLevel = .regular,
        padding: CGFloat = AppSpacing.md,
        cornerRadius: CGFloat = AppCornerRadius.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.glassLevel = glassLevel
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(glassLevel, cornerRadius: cornerRadius)
    }
}

public struct AppPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                LinearGradient(
                    colors: [AppColor.brand, AppColor.brandSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .appAnimation(AppAnimation.snappy, value: configuration.isPressed)
    }
}

public struct AppSecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headline)
            .foregroundStyle(AppColor.brand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                AppColor.brand.opacity(configuration.isPressed ? 0.18 : 0.1),
                in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .strokeBorder(AppColor.brand.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .appAnimation(AppAnimation.snappy, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AppPrimaryButtonStyle {
    static var appPrimary: AppPrimaryButtonStyle { AppPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == AppSecondaryButtonStyle {
    static var appSecondary: AppSecondaryButtonStyle { AppSecondaryButtonStyle() }
}
#endif
