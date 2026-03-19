import Foundation
import Security
import AuthenticationServices
import _CryptoExtras
import os.log

private let log = Logger(subsystem: "com.pmusaraj.SwiftDiscourseHub", category: "Auth")

enum AuthError: Error, LocalizedError, Equatable {
    case keypairGenerationFailed
    case decryptionFailed
    case nonceMismatch
    case invalidPayload
    case noCredentials
    case missingPayload
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .keypairGenerationFailed: return "Failed to generate RSA keypair"
        case .decryptionFailed: return "Failed to decrypt auth payload"
        case .nonceMismatch: return "Auth nonce mismatch — possible replay attack"
        case .invalidPayload: return "Invalid auth payload"
        case .noCredentials: return "No credentials found"
        case .missingPayload: return "Missing payload in callback URL"
        case .serverError(let message): return message
        }
    }
}

struct AuthPayload: Codable {
    let key: String
    let nonce: String
    let push: Bool?
    let api: Int?
}

actor AuthService {
    private let defaults: UserDefaults
    private static let applicationName = "SwiftDiscourseHub"
    private static let scopes = "read,write"
    static let callbackScheme = "discourse"
    private static let authRedirect = "discourse://auth_redirect"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Client ID

    func getOrCreateClientId() -> String {
        let key = "discourse_client_id"
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        defaults.set(hex, forKey: key)
        log.info("Generated new client_id: \(hex.prefix(8))...")
        return hex
    }

    // MARK: - RSA Keypair (via swift-crypto _CryptoExtras)

    func getOrCreatePrivateKey(for baseURL: String) throws -> _RSA.Encryption.PrivateKey {
        let key = "discourse_rsa_private_pem|\(baseURL)"

        if let pem = defaults.string(forKey: key) {
            log.debug("Loading existing RSA key for \(baseURL)")
            return try _RSA.Encryption.PrivateKey(pemRepresentation: pem)
        }

        log.info("Generating new RSA-2048 keypair for \(baseURL)")
        let privateKey = try _RSA.Encryption.PrivateKey(keySize: .bits2048)
        defaults.set(privateKey.pemRepresentation, forKey: key)
        return privateKey
    }

    func publicKeyPEM(for baseURL: String) throws -> String {
        let privateKey = try getOrCreatePrivateKey(for: baseURL)
        let pem = privateKey.publicKey.pemRepresentation
        log.debug("Public key PEM (\(pem.count) chars):\n\(pem)")
        return pem
    }

    // MARK: - Auth URL

    func buildAuthURL(for baseURL: String, scopes: String = scopes) throws -> (url: URL, nonce: String) {
        let clientId = getOrCreateClientId()
        let publicKey = try publicKeyPEM(for: baseURL)
        let nonce = generateNonce()

        var components = URLComponents(string: baseURL + "/user-api-key/new")!
        components.queryItems = [
            URLQueryItem(name: "application_name", value: Self.applicationName),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scopes", value: scopes),
            URLQueryItem(name: "public_key", value: publicKey),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "auth_redirect", value: Self.authRedirect),
        ]
        // URLQueryItem doesn't encode '+' (valid in RFC 3986 query but interpreted as space by servers)
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacing("+", with: "%2B")

        guard let url = components.url else {
            throw AuthError.invalidPayload
        }
        log.info("Built auth URL for \(baseURL), nonce=\(nonce)")
        log.debug("Full auth URL: \(url.absoluteString.prefix(500))...")
        return (url, nonce)
    }

    // MARK: - Decrypt Callback

    func decryptCallback(payload: String, for baseURL: String, expectedNonce: String) throws -> AuthPayload {
        log.info("Decrypting callback payload (\(payload.count) chars) for \(baseURL)")

        guard let encryptedData = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
            log.error("Failed to base64-decode payload")
            throw AuthError.invalidPayload
        }
        log.debug("Encrypted data: \(encryptedData.count) bytes")

        let privateKey = try getOrCreatePrivateKey(for: baseURL)

        let decryptedData: Data
        do {
            decryptedData = Data(try privateKey.decrypt(encryptedData, padding: ._WEAK_AND_INSECURE_PKCS_V1_5))
        } catch let error {
            log.error("RSA decryption failed: \(error)")
            throw AuthError.decryptionFailed
        }

        if let jsonString = String(data: decryptedData, encoding: .utf8) {
            log.debug("Decrypted JSON: \(jsonString)")
        }

        let decoder = JSONDecoder()
        guard let authPayload = try? decoder.decode(AuthPayload.self, from: decryptedData) else {
            log.error("Failed to decode AuthPayload from decrypted data")
            throw AuthError.invalidPayload
        }

        guard authPayload.nonce == expectedNonce else {
            log.error("Nonce mismatch: expected=\(expectedNonce), got=\(authPayload.nonce)")
            throw AuthError.nonceMismatch
        }

        log.info("Auth payload decrypted successfully, API key length=\(authPayload.key.count)")
        return authPayload
    }

    // MARK: - Credential Storage

    func storeApiKey(_ key: String, for baseURL: String) {
        defaults.set(key, forKey: "discourse_api_key|\(baseURL)")
        logStoredCredentials(for: baseURL)
    }

    func getApiKey(for baseURL: String) -> String? {
        defaults.string(forKey: "discourse_api_key|\(baseURL)")
    }

    func removeCredentials(for baseURL: String) {
        let hadApiKey = defaults.string(forKey: "discourse_api_key|\(baseURL)") != nil
        let hadPrivateKey = defaults.string(forKey: "discourse_rsa_private_pem|\(baseURL)") != nil
        log.info("removeCredentials for \(baseURL): apiKey=\(hadApiKey), privateKey=\(hadPrivateKey)")

        defaults.removeObject(forKey: "discourse_api_key|\(baseURL)")
        defaults.removeObject(forKey: "discourse_rsa_private_pem|\(baseURL)")

        log.info("removeCredentials done for \(baseURL)")
    }

    // MARK: - Testing Helpers

    func encryptTestPayload(_ plaintext: Data, for baseURL: String) throws -> Data {
        let privateKey = try getOrCreatePrivateKey(for: baseURL)
        return Data(try privateKey.publicKey.encrypt(plaintext, padding: ._WEAK_AND_INSECURE_PKCS_V1_5))
    }

    // MARK: - Parse Callback URL

    static func parseCallbackPayload(from url: URL) throws -> String {
        log.info("Parsing callback URL: \(url.scheme ?? "nil")://\(url.host ?? "nil")?\(url.query?.prefix(50) ?? "nil")...")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payload = components.queryItems?.first(where: { $0.name == "payload" })?.value else {
            log.error("No 'payload' query parameter found in callback URL")
            throw AuthError.missingPayload
        }
        log.debug("Extracted payload: \(payload.count) chars")
        return payload
    }

    // MARK: - Private

    private func generateNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func logStoredCredentials(for baseURL: String) {
        let apiKey = defaults.string(forKey: "discourse_api_key|\(baseURL)")
        let privateKey = defaults.string(forKey: "discourse_rsa_private_pem|\(baseURL)")
        log.info("""
            [Credentials] for \(baseURL):
              api_key: \(apiKey != nil ? "\(apiKey!.prefix(12))... (\(apiKey!.count) chars)" : "nil")
              rsa_private_pem: \(privateKey != nil ? "set (\(privateKey!.count) chars)" : "nil")
            """)
    }
}

// MARK: - AuthCoordinator

#if os(iOS)
private class AuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif

@Observable
@MainActor
final class AuthCoordinator {
    var isAuthenticating = false
    var authError: String?
    var pendingBaseURL: String?

    private let authService: AuthService
    private var pendingNonce: String?
    #if os(iOS)
    private let presentationContext = AuthPresentationContext()
    #endif

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    #if os(iOS)
    func startAuth(for baseURL: String) async {
        isAuthenticating = true
        authError = nil
        pendingBaseURL = baseURL

        do {
            log.info("[Coordinator] Starting auth for \(baseURL) (iOS)")
            let (authURL, nonce) = try await authService.buildAuthURL(for: baseURL)
            pendingNonce = nonce

            log.info("[Coordinator] Opening ASWebAuthenticationSession")
            let session = ASWebAuthenticationSession(
                url: authURL,
                callback: .customScheme(AuthService.callbackScheme)
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                Task { @MainActor in
                    if let callbackURL {
                        log.info("[Coordinator] Got callback URL")
                        await self.handleCallback(url: callbackURL)
                    } else if let error {
                        log.error("[Coordinator] ASWebAuth error: \(error.localizedDescription)")
                        self.authError = error.localizedDescription
                        self.isAuthenticating = false
                    }
                }
            }
            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        } catch {
            log.error("[Coordinator] startAuth error: \(error)")
            authError = error.localizedDescription
            isAuthenticating = false
        }
    }
    #else
    func startAuth(for baseURL: String) async {
        isAuthenticating = true
        authError = nil
        pendingBaseURL = baseURL

        do {
            log.info("[Coordinator] Starting auth for \(baseURL) (macOS)")
            let (authURL, nonce) = try await authService.buildAuthURL(for: baseURL)
            pendingNonce = nonce

            log.info("[Coordinator] Opening browser for auth")
            NSWorkspace.shared.open(authURL)
        } catch {
            log.error("[Coordinator] startAuth error: \(error)")
            authError = error.localizedDescription
            isAuthenticating = false
        }
    }
    #endif

    func handleCallback(url: URL) async {
        log.info("[Coordinator] handleCallback: \(url)")
        do {
            let payload = try AuthService.parseCallbackPayload(from: url)
            guard let baseURL = pendingBaseURL, let nonce = pendingNonce else {
                log.error("[Coordinator] No pending baseURL or nonce")
                throw AuthError.noCredentials
            }
            log.info("[Coordinator] Decrypting payload for \(baseURL)")
            let authPayload = try await authService.decryptCallback(
                payload: payload, for: baseURL, expectedNonce: nonce
            )
            await authService.storeApiKey(authPayload.key, for: baseURL)
            log.info("[Coordinator] Auth succeeded, API key stored")
            pendingNonce = nil
            isAuthenticating = false
        } catch {
            log.error("[Coordinator] handleCallback error: \(error)")
            authError = error.localizedDescription
            isAuthenticating = false
        }
    }

    func logout(for baseURL: String) async {
        log.info("[Coordinator] logout called for \(baseURL)")
        // Try to revoke the key on the server (best-effort)
        try? await SwiftDiscourseHubApp.sharedAPIClient.revokeApiKey(baseURL: baseURL)
        await authService.removeCredentials(for: baseURL)
        log.info("[Coordinator] logout complete for \(baseURL)")
    }

    func removeSite(baseURL: String) async {
        log.info("[Coordinator] removeSite called for \(baseURL)")
        // Revoke key on server if we have one, then clean up all local auth data
        if await authService.getApiKey(for: baseURL) != nil {
            log.info("[Coordinator] Revoking API key on server for \(baseURL)")
            try? await SwiftDiscourseHubApp.sharedAPIClient.revokeApiKey(baseURL: baseURL)
        } else {
            log.info("[Coordinator] No API key found for \(baseURL), skipping revoke")
        }
        log.info("[Coordinator] Removing local credentials for \(baseURL)")
        await authService.removeCredentials(for: baseURL)
        log.info("[Coordinator] removeSite complete for \(baseURL)")
    }

    func apiKey(for baseURL: String) async -> String? {
        await authService.getApiKey(for: baseURL)
    }
}

// MARK: - AuthCredentialProvider

protocol AuthCredentialProvider: Sendable {
    func apiKey(for baseURL: String) async -> String?
}

final class AuthCoordinatorCredentialProvider: AuthCredentialProvider {
    private let coordinator: AuthCoordinator

    init(coordinator: AuthCoordinator) {
        self.coordinator = coordinator
    }

    func apiKey(for baseURL: String) async -> String? {
        await coordinator.apiKey(for: baseURL)
    }
}
