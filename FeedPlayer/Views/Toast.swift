import SwiftUI
import Observation

/// #22 Toast: short confirmations like "Saved for later" that rise from the bottom.
@MainActor @Observable
final class ToastCenter {
    struct Toast: Equatable { let id = UUID(); let text: String; let symbol: String }
    private(set) var current: Toast?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String, symbol: String) {
        current = Toast(text: text, symbol: symbol)
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }
}

struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()
            if let t = toasts.current {
                Label(t.text, systemImage: t.symbol)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.thickMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .id(t.id)
                    .transition(.toast)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .padding(.bottom, 140)
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : (toasts.current == nil ? Motion.toastClose : Motion.toastOpen),
                   value: toasts.current)
    }
}
