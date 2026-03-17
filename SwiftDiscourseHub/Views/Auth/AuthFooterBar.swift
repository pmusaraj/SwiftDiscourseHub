import SwiftUI

struct AuthFooterBar: View {
    let site: DiscourseSite
    let topicId: Int
    @Binding var composerText: String
    var onPostCreated: (() -> Void)?
    @Environment(AuthCoordinator.self) private var authCoordinator

    var body: some View {
        if site.hasApiKey {
            ComposerView(site: site, topicId: topicId, composerText: $composerText, onPostCreated: onPostCreated)
        } else {
            loginPrompt
        }
    }

    private var loginPrompt: some View {
        HStack(spacing: 12) {
            if let iconURL = site.iconURL, let url = URL(string: iconURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text("Sign up or log in to interact on **\(site.title)**")
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if authCoordinator.isAuthenticating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Log In") {
                    Task { await authCoordinator.startAuth(for: site.baseURL) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
