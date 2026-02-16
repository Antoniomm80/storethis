import Foundation
import Security

enum PEMParser {
    enum PEMError: Error, LocalizedError {
        case invalidPEM
        case invalidBase64
        case keyCreationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .invalidPEM: return "Invalid PEM format"
            case .invalidBase64: return "Invalid base64 data in PEM"
            case .keyCreationFailed(let status): return "SecKey creation failed: \(status)"
            }
        }
    }

    static func parsePrivateKey(pem: String) throws -> SecKey {
        let stripped = pem
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let derData = Data(base64Encoded: stripped) else {
            throw PEMError.invalidBase64
        }

        // If PKCS#8, strip the ASN.1 header to get raw PKCS#1 RSA key
        let keyData = stripPKCS8Header(derData) ?? derData

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: keyData.count * 8,
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw PEMError.keyCreationFailed(-1)
        }
        return secKey
    }

    /// Strip PKCS#8 wrapper to extract the inner PKCS#1 RSA private key.
    /// PKCS#8 structure: SEQUENCE { SEQUENCE { OID, NULL }, OCTET STRING { PKCS#1 key } }
    private static func stripPKCS8Header(_ data: Data) -> Data? {
        // PKCS#8 RSA OID prefix bytes we look for
        // 30 (SEQUENCE) xx 30 (SEQUENCE) 0d 06 09 2a 86 48 86 f7 0d 01 01 01 05 00 04
        let rsaOIDBytes: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]

        let bytes = [UInt8](data)

        // Find the OID in the data
        guard let oidRange = findSubsequence(rsaOIDBytes, in: bytes) else {
            return nil // Not PKCS#8 or not RSA
        }

        // After OID: optional NULL (05 00), then OCTET STRING tag (04)
        var idx = oidRange.upperBound
        if idx < bytes.count - 1 && bytes[idx] == 0x05 && bytes[idx + 1] == 0x00 {
            idx += 2 // skip NULL
        }

        guard idx < bytes.count && bytes[idx] == 0x04 else {
            return nil
        }
        idx += 1 // skip OCTET STRING tag

        // Parse length
        guard idx < bytes.count else { return nil }
        if bytes[idx] & 0x80 == 0 {
            idx += 1 // single-byte length
        } else {
            let lenBytes = Int(bytes[idx] & 0x7F)
            idx += 1 + lenBytes
        }

        guard idx < bytes.count else { return nil }
        return Data(bytes[idx...])
    }

    private static func findSubsequence(_ needle: [UInt8], in haystack: [UInt8]) -> Range<Int>? {
        guard needle.count <= haystack.count else { return nil }
        for i in 0...(haystack.count - needle.count) {
            if Array(haystack[i..<(i + needle.count)]) == needle {
                return i..<(i + needle.count)
            }
        }
        return nil
    }
}
