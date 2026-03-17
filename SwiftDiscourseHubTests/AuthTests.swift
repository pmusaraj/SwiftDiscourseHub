import Testing
import Foundation

@testable import SwiftDiscourseHub

// UserDefaults is thread-safe but not marked Sendable in Swift 6
extension UserDefaults: @unchecked @retroactive Sendable {}

private func testDefaults() -> UserDefaults {
    UserDefaults(suiteName: "AuthTests.\(UUID().uuidString)")!
}

@Suite struct KeychainTests {
    @Test func saveAndRetrieveString() throws {
        let keychain = InMemoryKeychainService()
        try keychain.saveString(service: "test", account: "key1", value: "hello")
        let result = keychain.retrieveString(service: "test", account: "key1")
        #expect(result == "hello")
    }

    @Test func saveAndRetrieveData() throws {
        let keychain = InMemoryKeychainService()
        let data = Data([0x01, 0x02, 0x03])
        try keychain.save(service: "test", account: "data1", data: data)
        let result = keychain.retrieve(service: "test", account: "data1")
        #expect(result == data)
    }

    @Test func retrieveNonexistentReturnsNil() {
        let keychain = InMemoryKeychainService()
        let result = keychain.retrieveString(service: "test", account: "nope")
        #expect(result == nil)
    }

    @Test func deleteRemovesValue() throws {
        let keychain = InMemoryKeychainService()
        try keychain.saveString(service: "test", account: "key1", value: "hello")
        keychain.delete(service: "test", account: "key1")
        let result = keychain.retrieveString(service: "test", account: "key1")
        #expect(result == nil)
    }

    @Test func overwriteReplacesValue() throws {
        let keychain = InMemoryKeychainService()
        try keychain.saveString(service: "test", account: "key1", value: "first")
        try keychain.saveString(service: "test", account: "key1", value: "second")
        let result = keychain.retrieveString(service: "test", account: "key1")
        #expect(result == "second")
    }

    @Test func deleteNonexistentDoesNotThrow() {
        let keychain = InMemoryKeychainService()
        keychain.delete(service: "test", account: "nope")
    }
}

@Suite struct RSAKeyTests {
    @Test func generateKeypairSucceeds() async throws {
        let authService = AuthService(defaults: testDefaults())
        let pem = try await authService.publicKeyPEM(for: "https://test.example.com")
        #expect(!pem.isEmpty)
    }

    @Test func publicKeyIsPEMEncoded() async throws {
        let authService = AuthService(defaults: testDefaults())
        let pem = try await authService.publicKeyPEM(for: "https://test.example.com")
        #expect(pem.hasPrefix("-----BEGIN PUBLIC KEY-----"))
        #expect(pem.hasSuffix("-----END PUBLIC KEY-----\n") || pem.hasSuffix("-----END PUBLIC KEY-----"))

        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        let der = Data(base64Encoded: base64)
        #expect(der != nil, "PEM base64 content should decode")
        #expect(der![0] == 0x30, "PKCS#8 DER should start with SEQUENCE tag")
        #expect(der!.count > 290, "DER should be at least 290 bytes for RSA-2048")
    }

    @Test func encryptDecryptRoundtrip() async throws {
        let authService = AuthService(defaults: testDefaults())
        let baseURL = "https://test.example.com"

        let payload = #"{"key":"test-api-key","nonce":"abc123","push":false,"api":4}"#
        let payloadData = payload.data(using: .utf8)!

        let encrypted = try await authService.encryptTestPayload(payloadData, for: baseURL)
        let base64Payload = encrypted.base64EncodedString()
        let result = try await authService.decryptCallback(payload: base64Payload, for: baseURL, expectedNonce: "abc123")
        #expect(result.key == "test-api-key")
        #expect(result.nonce == "abc123")
    }

    @Test func nonceMismatchThrows() async throws {
        let authService = AuthService(defaults: testDefaults())
        let baseURL = "https://test.example.com"

        let payload = #"{"key":"k","nonce":"real-nonce","push":false,"api":4}"#
        let payloadData = payload.data(using: .utf8)!

        let encrypted = try await authService.encryptTestPayload(payloadData, for: baseURL)
        let base64Payload = encrypted.base64EncodedString()
        await #expect(throws: AuthError.nonceMismatch) {
            try await authService.decryptCallback(payload: base64Payload, for: baseURL, expectedNonce: "wrong-nonce")
        }
    }

    @Test func privateKeyPersistsAcrossInstances() async throws {
        let defaults = testDefaults()
        let baseURL = "https://test.example.com"

        let pem1 = try await AuthService(defaults: defaults).publicKeyPEM(for: baseURL)
        let pem2 = try await AuthService(defaults: defaults).publicKeyPEM(for: baseURL)
        #expect(pem1 == pem2, "Same defaults should produce same public key PEM")
    }
}

@Suite struct AuthURLTests {
    @Test func authURLContainsRequiredParams() async throws {
        let authService = AuthService(defaults: testDefaults())
        let (url, nonce) = try await authService.buildAuthURL(for: "https://meta.discourse.org")

        let urlString = url.absoluteString
        #expect(urlString.contains("application_name=SwiftDiscourseHub"))
        #expect(urlString.contains("scopes=read"))
        #expect(urlString.contains("public_key="))
        #expect(urlString.contains("nonce="))
        #expect(urlString.contains("auth_redirect=discourse"))
        #expect(!nonce.isEmpty)
    }

    @Test func authURLContainsClientId() async throws {
        let authService = AuthService(defaults: testDefaults())
        let (url, _) = try await authService.buildAuthURL(for: "https://meta.discourse.org")

        let urlString = url.absoluteString
        #expect(urlString.contains("client_id="))
    }

    @Test func clientIdIsStableAcrossCalls() async throws {
        let defaults = testDefaults()
        let authService = AuthService(defaults: defaults)
        let id1 = await authService.getOrCreateClientId()
        let id2 = await authService.getOrCreateClientId()
        #expect(id1 == id2)
        #expect(id1.count == 64)
    }
}

@Suite struct CallbackParsingTests {
    @Test func callbackURLParsesPayload() throws {
        let url = URL(string: "discourse://auth_redirect?payload=dGVzdA==")!
        let payload = try AuthService.parseCallbackPayload(from: url)
        #expect(payload == "dGVzdA==")
    }

    @Test func missingPayloadThrows() {
        let url = URL(string: "discourse://auth_redirect")!
        #expect(throws: AuthError.missingPayload) {
            try AuthService.parseCallbackPayload(from: url)
        }
    }

    @Test func invalidBase64PayloadThrowsOnDecrypt() async throws {
        let authService = AuthService(defaults: testDefaults())
        let baseURL = "https://test.example.com"
        _ = try await authService.publicKeyPEM(for: baseURL)

        await #expect(throws: AuthError.self) {
            try await authService.decryptCallback(payload: "!!!not-base64!!!", for: baseURL, expectedNonce: "n")
        }
    }

    @Test func fullAuthFlowEndToEnd() async throws {
        let authService = AuthService(defaults: testDefaults())
        let baseURL = "https://test.example.com"

        let (url, nonce) = try await authService.buildAuthURL(for: baseURL)
        #expect(url.absoluteString.contains("user-api-key/new"))

        let fakePayload = """
        {"key":"my-secret-api-key","nonce":"\(nonce)","push":false,"api":4}
        """.data(using: .utf8)!
        let encrypted = try await authService.encryptTestPayload(fakePayload, for: baseURL)
        let base64 = encrypted.base64EncodedString()

        let callbackURL = URL(string: "discourse://auth_redirect?payload=\(base64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)")!
        let payload = try AuthService.parseCallbackPayload(from: callbackURL)

        let result = try await authService.decryptCallback(payload: payload, for: baseURL, expectedNonce: nonce)
        #expect(result.key == "my-secret-api-key")

        await authService.storeApiKey(result.key, for: baseURL)
        let storedKey = await authService.getApiKey(for: baseURL)
        #expect(storedKey == "my-secret-api-key")
    }
}

@Suite struct CreatePostModelTests {
    @Test func createPostRequestEncodesToSnakeCase() throws {
        let request = CreatePostRequest(topicId: 42, raw: "Hello world")
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["topic_id"] as? Int == 42)
        #expect(json["raw"] as? String == "Hello world")
        #expect(json["topicId"] == nil)
    }

    @Test func createPostResponseDecodes() throws {
        let json = """
        {"id":123,"topic_id":42,"post_number":5,"raw":"test","cooked":"<p>test</p>","created_at":"2026-01-01","username":"testuser"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(CreatePostResponse.self, from: json)
        #expect(response.id == 123)
        #expect(response.topicId == 42)
        #expect(response.postNumber == 5)
        #expect(response.username == "testuser")
    }
}
