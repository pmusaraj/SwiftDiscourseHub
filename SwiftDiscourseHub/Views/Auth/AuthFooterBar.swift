import SwiftUI

struct AuthFooterBar: View {
    let site: DiscourseSite
    let topicId: Int
    let username: String?
    @Binding var composerText: String
    @Binding var showComposer: Bool
    var onPostCreated: (() -> Void)?
    @Environment(AuthCoordinator.self) private var authCoordinator

    var body: some View {
        if site.hasApiKey {
            if showComposer {
                ComposerView(site: site, topicId: topicId, composerText: $composerText) {
                    showComposer = false
                    onPostCreated?()
                }
            } else {
                statusBar
            }
        } else {
            loginPrompt
        }
    }

    private var statusBar: some View {
        HStack {
            Label(username != nil ? "Logged in as **\(username!)**" : "Logged in", systemImage: "person.crop.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showComposer = true
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
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
            }

            Button("Log In") {
                Task { await authCoordinator.startAuth(for: site.baseURL) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(authCoordinator.isAuthenticating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
