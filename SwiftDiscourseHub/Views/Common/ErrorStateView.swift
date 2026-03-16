import SwiftUI

struct ErrorStateView: View {
    let title: String
    let message: String?
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.bordered)
            }
        }
    }
}
