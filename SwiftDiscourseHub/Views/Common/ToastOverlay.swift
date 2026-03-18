import SwiftUI

@Observable
@MainActor
final class ToastManager {
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let style: Style

        enum Style {
            case error, success, info
        }
    }

    private(set) var currentToast: Toast?

    func show(_ message: String, style: Toast.Style = .info, duration: TimeInterval = 4.0) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentToast = Toast(message: message, style: style)
        }
        Task {
            try? await Task.sleep(for: .seconds(duration))
            dismiss()
        }
    }

    func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentToast = nil
        }
    }
}

struct ToastOverlay: View {
    @Environment(ToastManager.self) private var toastManager

    var body: some View {
        if let toast = toastManager.currentToast {
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: toast.style))
                    Text(toast.message)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(backgroundColor(for: toast.style))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .onTapGesture(perform: toastManager.dismiss)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .allowsHitTesting(true)
        }
    }

    private func iconName(for style: ToastManager.Toast.Style) -> String {
        switch style {
        case .error: "xmark.circle.fill"
        case .success: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        }
    }

    private func backgroundColor(for style: ToastManager.Toast.Style) -> Color {
        switch style {
        case .error: .red
        case .success: .green
        case .info: .blue
        }
    }
}
