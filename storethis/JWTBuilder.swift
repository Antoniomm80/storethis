import Foundation
import Security

enum JWTBuilder {
    enum JWTError: Error, LocalizedError {
        case encodingFailed
        case signingFailed

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode JWT"
            case .signingFailed: return "Failed to sign JWT"
            }
        }
    }

    static func buildSignedJWT(
        issuer: String,
        scope: String,
        audience: String,
        privateKey: SecKey
    ) throws -> String {
        let now = Date()
        let exp = now.addingTimeInterval(3600)

        let header: [String: String] = ["alg": "RS256", "typ": "JWT"]
        let payload: [String: Any] = [
            "iss": issuer,
            "scope": scope,
            "aud": audience,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(exp.timeIntervalSince1970),
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header, options: .sortedKeys)
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)

        let headerB64 = Base64URL.encode(headerData)
        let payloadB64 = Base64URL.encode(payloadData)

        let signingInput = "\(headerB64).\(payloadB64)"

        guard let signingData = signingInput.data(using: .utf8) else {
            throw JWTError.encodingFailed
        }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signingData as CFData,
            &error
        ) as Data? else {
            throw JWTError.signingFailed
        }

        let signatureB64 = Base64URL.encode(signature)
        return "\(signingInput).\(signatureB64)"
    }
}
