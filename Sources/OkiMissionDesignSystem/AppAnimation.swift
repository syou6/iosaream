import Foundation
#if canImport(SwiftUI)
import SwiftUI

public enum AppAnimation {
    public static let gentle: Animation = .spring(response: 0.5, dampingFraction: 0.85)
    public static let snappy: Animation = .spring(response: 0.3, dampingFraction: 0.75)
    public static let bouncy: Animation = .spring(response: 0.6, dampingFraction: 0.6)
    public static let immediate: Animation = .easeInOut(duration: 0.12)

    public static func reduceMotionFallback(_ regular: Animation) -> Animation {
        return .easeInOut(duration: 0.1)
    }
}

public struct AppAnimatedModifier<Value: Equatable>: ViewModifier {
    public let animation: Animation
    public let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content.animation(reduceMotion ? AppAnimation.reduceMotionFallback(animation) : animation, value: value)
    }
}

public extension View {
    func appAnimation<Value: Equatable>(_ animation: Animation, value: Value) -> some View {
        modifier(AppAnimatedModifier(animation: animation, value: value))
    }
}
#endif
