import Foundation

@Observable
final class AuthenticationService {
    private(set) var accessToken: String?
    private(set) var tokenExpiry: Date?
    private(set) var isAuthenticated = false
    private(set) var error: String?
    private(set) var hasKeyFile: Bool = false

    private var serviceAccountKey: ServiceAccountKey?

    private static let gcsScope = "https://www.googleapis.com/auth/devstorage.full_control"
    private static let keyFileName = "service-account-key.json"

    init() {
        hasKeyFile = FileManager.default.fileExists(atPath: Self.appSupportDirectory.appendingPathComponent(Self.keyFileName).path)
    }

    var keyFileURL: URL {
        Self.appSupportDirectory.appendingPathComponent(Self.keyFileName)
    }

    private static var appSupportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("storagethis")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func importKeyFile(from sourceURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        // Validate it's a valid service account key
        let key = try JSONDecoder().decode(ServiceAccountKey.self, from: data)
        try data.write(to: keyFileURL, options: .atomic)
        serviceAccountKey = key
        hasKeyFile = true
        // Reset auth state
        accessToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        error = nil
    }

    func removeKeyFile() {
        try? FileManager.default.removeItem(at: keyFileURL)
        serviceAccountKey = nil
        hasKeyFile = false
        accessToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        error = nil
    }

    func loadKeyFile() throws {
        let data = try Data(contentsOf: keyFileURL)
        serviceAccountKey = try JSONDecoder().decode(ServiceAccountKey.self, from: data)
    }

    func authenticate() async throws {
        if let expiry = tokenExpiry, Date() < expiry.addingTimeInterval(-60) {
            return // Token still valid
        }

        if serviceAccountKey == nil {
            try loadKeyFile()
        }

        guard let key = serviceAccountKey else {
            throw AuthError.noKeyFile
        }

        let privateKey = try PEMParser.parsePrivateKey(pem: key.privateKey)

        let jwt = try JWTBuilder.buildSignedJWT(
            issuer: key.clientEmail,
            scope: Self.gcsScope,
            audience: key.tokenUri,
            privateKey: privateKey
        )

        let tokenResponse = try await exchangeJWTForToken(jwt: jwt, tokenUri: key.tokenUri)
        accessToken = tokenResponse.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        isAuthenticated = true
        error = nil
    }

    func getValidToken() async throws -> String {
        try await authenticate()
        guard let token = accessToken else {
            throw AuthError.noToken
        }
        return token
    }

    private func exchangeJWTForToken(jwt: String, tokenUri: String) async throws -> TokenResponse {
        guard let url = URL(string: tokenUri) else {
            throw AuthError.invalidTokenURI
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed(errorBody)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    enum AuthError: Error, LocalizedError {
        case noKeyFile
        case noToken
        case invalidTokenURI
        case tokenExchangeFailed(String)

        var errorDescription: String? {
            switch self {
            case .noKeyFile: return "No service account key file configured"
            case .noToken: return "No access token available"
            case .invalidTokenURI: return "Invalid token URI in service account key"
            case .tokenExchangeFailed(let detail): return "Token exchange failed: \(detail)"
            }
        }
    }

    private struct TokenResponse: Codable {
        let accessToken: String
        let expiresIn: Int
        let tokenType: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }
    }
}
