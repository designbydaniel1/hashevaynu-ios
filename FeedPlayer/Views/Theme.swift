import SwiftUI
import UIKit

extension Color {
    /// Warm off-white in light mode, near-black in dark mode, instead of pure white.
    static let appBackground = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0x0E / 255, green: 0x11 / 255, blue: 0x16 / 255, alpha: 1)
        : UIColor(red: 0xF8 / 255, green: 0xF6 / 255, blue: 0xF1 / 255, alpha: 1) })
    /// Cards and grouped rows sit a touch lighter than the background.
    static let appSurface = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0x1A / 255, green: 0x1E / 255, blue: 0x25 / 255, alpha: 1)
        : UIColor(red: 0xFF / 255, green: 0xFD / 255, blue: 0xF9 / 255, alpha: 1) })
}

extension View {
    /// The app's off-white page background, for scroll views and lists.
    func appBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.appBackground)
    }

    /// iOS 26 Liquid Glass in a shape, with a material fallback on earlier versions.
    @ViewBuilder func glass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.35), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        }
    }
}
