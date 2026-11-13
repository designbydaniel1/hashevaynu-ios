import SwiftUI

// Motion tokens ported from transitions.dev (https://transitions.dev),
// used under the Transitions.dev License. Durations, curves, blur and scale
// values match the CSS originals; every transition respects Reduce Motion.

enum Motion {
    /// cubic-bezier(0.22, 1, 0.36, 1): the "ease-out" used across transitions.dev.
    static func easeOut(_ seconds: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: seconds)
    }

    /// Icon swap: 250ms ease-in-out, blur 2px, start scale 0.25.
    static let iconSwap = Animation.easeInOut(duration: 0.25)
    /// Text states swap: 150ms ease-in-out, 4px rise, blur 2px.
    static let textSwap = Animation.easeInOut(duration: 0.15)
    /// Like button: 350ms pop with overshoot, cubic-bezier(0.34, 1.96, 0.64, 1).
    static let likePop = Animation.timingCurve(0.34, 1.96, 0.64, 1, duration: 0.35)
    /// Like particles: 600ms ease-out, 20pt travel.
    static let particles = easeOut(0.6)
    /// Toast: opens on 350ms, closes on 250ms, 16pt rise, scale 0.97, blur 2px.
    static let toastOpen = easeOut(0.35)
    static let toastClose = easeOut(0.25)
    /// Modal / sheet content: 250ms open, scale 0.96.
    static let modalOpen = easeOut(0.25)
    /// Skeleton reveal: 400ms ease-in-out cross-fade with 2px blur.
    static let reveal = Animation.easeInOut(duration: 0.4)
    /// Success check: 500ms, rotate from 80°, blur from 10px, springy Y bob.
    static let check = Animation.timingCurve(0.34, 1.35, 0.64, 1, duration: 0.5)
}

/// Blur + scale + opacity, the building block for most transitions.dev effects.
private struct BlurScaleModifier: ViewModifier {
    var blur: CGFloat, scale: CGFloat, opacity: Double, y: CGFloat, rotation: Double
    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(y: y)
            .opacity(opacity)
    }
}

extension AnyTransition {
    private static func blurScale(blur: CGFloat, scale: CGFloat = 1, y: CGFloat = 0,
                                  rotation: Double = 0) -> AnyTransition {
        .modifier(active: BlurScaleModifier(blur: blur, scale: scale, opacity: 0, y: y, rotation: rotation),
                  identity: BlurScaleModifier(blur: 0, scale: 1, opacity: 1, y: 0, rotation: 0))
    }

    /// #09 Icon swap: the new icon grows from 25% out of a blur.
    static let iconSwap = blurScale(blur: 2, scale: 0.25)

    /// #04 Text states swap: old text leaves upward, new text arrives from below.
    static let textSwap = AnyTransition.asymmetric(
        insertion: blurScale(blur: 2, y: 4),
        removal: blurScale(blur: 2, y: -4))

    /// #22 Toast: rises 16pt with a slight scale and cross-blur.
    static let toast = blurScale(blur: 2, scale: 0.97, y: 16)

    /// #14 Skeleton reveal: cross-fade with a matching cross-blur.
    static let reveal = blurScale(blur: 2)

    /// #10 Success check: fades in while rotating from 80° out of a heavy blur.
    static let successCheck = blurScale(blur: 10, scale: 0.6, y: 8, rotation: 80)
}

extension View {
    /// Applies `animation` unless the user turned on Reduce Motion.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation, value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

// MARK: - Reusable animated pieces

/// An SF Symbol that swaps with the transitions.dev icon-swap effect.
struct SwapIcon: View {
    let name: String
    var body: some View {
        ZStack {
            Image(systemName: name)
                .id(name)
                .transition(.iconSwap)
        }
        .motion(Motion.iconSwap, value: name)
    }
}

/// Text that swaps in place with the text-states-swap effect.
struct SwapText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        ZStack {
            Text(text).id(text).transition(.textSwap)
        }
        .motion(Motion.textSwap, value: text)
    }
}

/// #23 Like button, adapted for "Save for later": the bookmark pops with an
/// overshoot and eight particles sprinkle outward when it becomes saved.
struct SaveButton: View {
    let isSaved: Bool
    var color: Color = .orange
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = 0

    var body: some View {
        Button {
            let willSave = !isSaved
            action()
            guard willSave, !reduceMotion else { return }
            burst += 1
        } label: {
            ZStack {
                if burst > 0 { Particles(color: color).id(burst) }
                SwapIcon(name: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? color : Color.accentColor)
                    // Pop: dip to 60%, then overshoot back to full size (350ms).
                    .keyframeAnimator(initialValue: 1.0, trigger: burst) { icon, scale in
                        icon.scaleEffect(scale)
                    } keyframes: { _ in
                        LinearKeyframe(0.6, duration: 0.04)
                        CubicKeyframe(1.18, duration: 0.17)
                        CubicKeyframe(1.0, duration: 0.14)
                    }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
        .accessibilityLabel(isSaved ? "Remove from Saved" : "Save for Later")
    }

    private struct Particles: View {
        let color: Color
        @State private var out = false
        var body: some View {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) / 8 * 2 * .pi
                    Circle()
                        .fill(color)
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: out ? cos(angle) * 20 : 0, y: out ? sin(angle) * 20 : 0)
                        .opacity(out ? 0 : 1)
                        .scaleEffect(out ? 0.4 : 1)
                }
            }
            .allowsHitTesting(false)
            .onAppear { withAnimation(Motion.particles) { out = true } }
        }
    }
}

/// #14 Skeleton row: pulses, then the real list cross-fades in with blur.
struct SkeletonRow: View {
    @State private var dim = false
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).frame(width: 140, height: 10)
            }
        }
        .foregroundStyle(.secondary.opacity(0.18))
        .opacity(dim ? 0.5 : 1)
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { dim = true }
        }
        .accessibilityHidden(true)
    }
}
