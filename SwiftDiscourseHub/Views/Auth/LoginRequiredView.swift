import SwiftUI

struct LoginRequiredView: View {
    let site: DiscourseSite
    @Environment(AuthCoordinator.self) private var authCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Login Required")
                .font(.title2.bold())

            Text("\(site.title) requires you to log in before browsing.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if authCoordinator.isAuthenticating {
                ProgressView("Authenticating...")
            } else {
                Button {
                    Task { await authCoordinator.startAuth(for: site.baseURL) }
                } label: {
                    Label("Log In", systemImage: "person.crop.circle")
                        .frame(maxWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let error = authCoordinator.authError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
    }
}
