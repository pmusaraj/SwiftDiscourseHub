import SwiftUI

struct AuthFooterBar: View {
    let site: DiscourseSite
    let topicId: Int
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
                } onCancel: {
                    composerText = ""
                    showComposer = false
                }
                .onKeyPress(.escape) {
                    composerText = ""
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

    private var avatarURL: URL? {
        URLHelpers.avatarURL(template: site.avatarTemplate, size: 48, baseURL: site.baseURL)
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if let username = site.username {
                CachedAsyncImage(url: avatarURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())

                Text(username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("Reply", systemImage: "arrowshape.turn.up.left")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.tint, in: .rect(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .onTapGesture { showComposer = true }
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

            Text("Log In")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.tint, in: .rect(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .onTapGesture {
            guard !authCoordinator.isAuthenticating else { return }
            Task { await authCoordinator.startAuth(for: site.baseURL) }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }
}
