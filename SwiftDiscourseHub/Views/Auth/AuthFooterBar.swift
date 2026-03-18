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
                .onKeyPress(.escape) {
                    showComposer = false
                    return .handled
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
            Group {
                if let username {
                    Label("Logged in as **\(username)**", systemImage: "person.crop.circle")
                } else {
                    Label("Logged in", systemImage: "person.crop.circle")
                }
            }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
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
                .clipShape(.rect(cornerRadius: 4))
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}
