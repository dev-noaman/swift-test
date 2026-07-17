//
//  HardenedAuthWrapper.swift
//  OCRStudioSDK — hardening reference (authorized security research)
//
//  Reference client-side integration for the hardened authorization design in
//  VALIDATION_PACKAGE.md §6. This is NOT shipped SDK code: `CreateSessionHardened`
//  (§6.6) does not exist in the trial xcframework yet. The wrapper is written
//  against a `HardenedSessionFactory` protocol so the vendor can drop in the real
//  ObjC++ entry point, and so OCRAuthHardenedTests.swift can drive it with a mock.
//
//  What this file provides:
//    • OCRAuthGateStatus          — mirrors the ObjC NS_ENUM in §6.6
//    • OCRAttestationClaims       — the JWT payload model in §6.7
//    • HardenedAuthVerifier       — the four-gate check in §6.8 (Ed25519 via CryptoKit)
//    • NonceLRU                    — client replay cache in §6.9/§6.10
//    • HardenedAuthWrapper        — fetch → cache(Keychain) → verify → create (§6.5)
//
//  Token format is the compact EdDSA JWT emitted by reference_server_mint.py:
//      signing_input = base64url(header) + "." + base64url(payload)
//      signature     = Ed25519(signing_input as ASCII)          // raw 64 bytes
//      jwt           = signing_input + "." + base64url(signature)
//
//  Requires iOS 13+ (CryptoKit). No third-party dependency.
//

import Foundation
import CryptoKit
import Security

// MARK: - Gate status (Swift mirror of OCRAuthGateStatus, §6.6)

public enum OCRAuthGateStatus: Int, Equatable {
    case ok               = 0
    case legacyFail       = 1
    case jwtSignatureBad  = 2
    case jwtExpired       = 3
    case buildMismatch    = 4
    case configMismatch   = 5
    case nonceReused      = 6
    case codeHashBad      = 7
    case vcihFail         = 8
}

public struct SessionAuthorizationError: Error, Equatable {
    public let status: OCRAuthGateStatus
    public let message: String
    public init(_ status: OCRAuthGateStatus, _ message: String) {
        self.status = status
        self.message = message
    }
}

// MARK: - Claims model (§6.7)

public struct OCRAttestationClaims: Codable, Equatable {
    public let sub: String            // client-id marker
    public let lib_build_id: String   // e.g. "1.3.1-ios-arm64-trial-2026Q3"
    public let platform: String       // "ios"
    public let config_sha256: String  // hex SHA-256 of config/*.ocr
    public let iat: Int               // epoch seconds
    public let exp: Int               // epoch seconds
    public let nonce: String          // UUID-format
    public let aud: String            // "ocrstudio-sdk"
}

// MARK: - Baked policy (what the shipped library would embed)

public struct HardenedAuthConfig {
    public let clientId: String                 // must equal claims.sub
    public let libBuildId: String               // must equal claims.lib_build_id
    public let platform: String                 // must equal claims.platform
    public let audience: String                 // must equal claims.aud
    public let serverPublicKey: Curve25519.Signing.PublicKey   // Ed25519 pubkey, pinned
    public let maxTokenLifetime: TimeInterval   // §8.2 48h cap
    public let clockSkewTolerance: TimeInterval // §6.10 ±300s
    public let iatFloor: Int                    // §8.2 reject iat < 2026-01-01
    public let offlineSKU: Bool                 // §6.2.3 offline SKUs skip JWT

    public init(clientId: String,
                libBuildId: String,
                platform: String = "ios",
                audience: String = "ocrstudio-sdk",
                serverPublicKey: Curve25519.Signing.PublicKey,
                maxTokenLifetime: TimeInterval = 48 * 60 * 60,
                clockSkewTolerance: TimeInterval = 300,
                iatFloor: Int = 1_767_225_600,   // 2026-01-01T00:00:00Z
                offlineSKU: Bool = false) {
        self.clientId = clientId
        self.libBuildId = libBuildId
        self.platform = platform
        self.audience = audience
        self.serverPublicKey = serverPublicKey
        self.maxTokenLifetime = maxTokenLifetime
        self.clockSkewTolerance = clockSkewTolerance
        self.iatFloor = iatFloor
        self.offlineSKU = offlineSKU
    }
}

// MARK: - base64url

enum Base64URL {
    static func decode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - t.count % 4) % 4
        t += String(repeating: "=", count: pad)
        return Data(base64Encoded: t)
    }
}

// MARK: - Replay cache (§6.9/§6.10)

public final class NonceLRU {
    private let capacity: Int
    private var order: [String] = []
    private var set: Set<String> = []
    private let lock = NSLock()

    public init(capacity: Int = 1_000_000) {
        self.capacity = max(1, capacity)
    }

    /// Returns true if the nonce is fresh (and records it); false if already seen.
    @discardableResult
    public func admit(_ nonce: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if set.contains(nonce) { return false }
        set.insert(nonce)
        order.append(nonce)
        if order.count > capacity {
            let evicted = order.removeFirst()
            set.remove(evicted)
        }
        return true
    }
}

// MARK: - Injectable seams (so the vendor / tests can supply real impls)

/// Fetches an attestation JWT for this app+build+config from the vendor server.
public protocol AttestationProviding {
    func fetchToken(appId: String,
                    buildId: String,
                    deviceNonce: String,
                    configSHA256: String) throws -> String
}

/// Abstracts the not-yet-shipped ObjC++ `+createSessionHardened…` entry (§6.6).
public protocol HardenedSessionFactory {
    /// Returns an opaque session handle on success, or throws.
    func createSessionHardened(signature: String,
                               attestationJWT: String,
                               paramsJSON: String) throws -> AnyObject
}

/// P3 anti-patch seams (§6.2.4). In the shipped library these read real memory;
/// here they are injectable so tests can simulate a patched binary.
public protocol IntegrityChecking {
    /// SHA-256 over the .text region spanning VSA…pkcs1_verify vs baked value.
    func codeRegionHashMatches() -> Bool
    /// Hardened VCIH: hash of verify-region code + __const blob vs baked value.
    func vcihMatches() -> Bool
}

/// Always-good integrity check (reference default for an unpatched build).
public struct TrustedIntegrity: IntegrityChecking {
    public init() {}
    public func codeRegionHashMatches() -> Bool { true }
    public func vcihMatches() -> Bool { true }
}

// MARK: - The four-gate verifier (§6.8)

public struct HardenedAuthVerifier {
    public let config: HardenedAuthConfig
    public let nonces: NonceLRU
    public let integrity: IntegrityChecking

    public init(config: HardenedAuthConfig,
                nonces: NonceLRU = NonceLRU(),
                integrity: IntegrityChecking = TrustedIntegrity()) {
        self.config = config
        self.nonces = nonces
        self.integrity = integrity
    }

    /// Decode + verify a JWT against every gate. `now` and `configSHA256` are
    /// injected so tests are deterministic. Returns `.ok` only if all gates pass.
    public func verify(jwt: String, configSHA256: String, now: Date = Date()) -> OCRAuthGateStatus {
        // ---- Gate: Ed25519 signature over header.payload (§6.8) --------------
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return .jwtSignatureBad }
        let signingInput = "\(parts[0]).\(parts[1])"
        guard let sig = Base64URL.decode(String(parts[2])),
              let signedBytes = signingInput.data(using: .ascii),
              config.serverPublicKey.isValidSignature(sig, for: signedBytes) else {
            return .jwtSignatureBad
        }

        // ---- Decode claims ---------------------------------------------------
        guard let payloadData = Base64URL.decode(String(parts[1])),
              let claims = try? JSONDecoder().decode(OCRAttestationClaims.self, from: payloadData) else {
            return .jwtSignatureBad   // unparseable payload under a valid sig is still unusable
        }

        // ---- Gate: temporal validity (§6.8, §6.10, §8.2) ---------------------
        let nowSec = Int(now.timeIntervalSince1970)
        let skew = Int(config.clockSkewTolerance)
        if claims.iat < config.iatFloor { return .jwtExpired }             // device clock at 1970 (§8.2)
        if claims.iat - skew > nowSec { return .jwtExpired }               // minted too far in the future
        if claims.exp <= nowSec - skew { return .jwtExpired }              // already expired
        if TimeInterval(claims.exp - claims.iat) > config.maxTokenLifetime { return .jwtExpired } // >48h cap

        // ---- Gate: identity / binding (§6.8, §6.11) --------------------------
        // `sub` is asserted implicitly-and-explicitly alongside build id (§6.11).
        if claims.aud != config.audience { return .jwtSignatureBad }       // aud is covered by the sig (§8.2)
        if claims.sub != config.clientId { return .buildMismatch }
        if claims.platform != config.platform { return .buildMismatch }
        if claims.lib_build_id != config.libBuildId { return .buildMismatch }
        if claims.config_sha256.lowercased() != configSHA256.lowercased() { return .configMismatch }

        // ---- Gate: replay (§6.10) -------------------------------------------
        if !nonces.admit(claims.nonce) { return .nonceReused }

        // ---- Gate: anti-patch integrity (§6.2.4) ----------------------------
        if !integrity.codeRegionHashMatches() { return .codeHashBad }
        if !integrity.vcihMatches() { return .vcihFail }

        return .ok
    }
}

// MARK: - Config hashing helper (§6.8 config_sha256)

public enum ConfigDigest {
    /// SHA-256 of the on-disk config bytes, lowercase hex — compared to claims.
    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(ofFileAt url: URL) throws -> String {
        sha256Hex(of: try Data(contentsOf: url))
    }
}

// MARK: - Token cache (§6.9)

/// Seam so the wrapper can cache tokens without the tests touching the Keychain.
public protocol TokenCaching {
    func store(jwt: String, exp: Int)
    func load(now: Date) -> String?
}

/// Reference cache: stores the JWT until `exp`, in the Keychain, device-only,
/// excluded from iCloud backup (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly).
public final class AttestationTokenCache: TokenCaching {
    private let account: String
    private let service = "ai.ocrstudio.sdk.attestation"

    public init(account: String) { self.account = account }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func store(jwt: String, exp: Int) {
        var q = baseQuery
        q[kSecValueData as String] = Data(jwt.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        // exp piggybacks in the generic attribute so load() can pre-expire.
        q[kSecAttrGeneric as String] = Data(String(exp).utf8)
        SecItemDelete(baseQuery as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    /// Returns a cached JWT only if it is still valid at `now`.
    public func load(now: Date = Date()) -> String? {
        var q = baseQuery
        q[kSecReturnData as String] = true
        q[kSecReturnAttributes as String] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let item = out as? [String: Any],
              let data = item[kSecValueData as String] as? Data,
              let jwt = String(data: data, encoding: .utf8) else { return nil }
        if let gen = item[kSecAttrGeneric as String] as? Data,
           let expStr = String(data: gen, encoding: .utf8),
           let exp = Int(expStr),
           Int(now.timeIntervalSince1970) >= exp {
            SecItemDelete(baseQuery as CFDictionary)   // drop stale token
            return nil
        }
        return jwt
    }
}

// MARK: - Orchestrating wrapper (§6.5)

public final class HardenedAuthWrapper {
    private let config: HardenedAuthConfig
    private let provider: AttestationProviding
    private let verifier: HardenedAuthVerifier
    private let factory: HardenedSessionFactory
    private let cache: TokenCaching

    public init(config: HardenedAuthConfig,
                provider: AttestationProviding,
                factory: HardenedSessionFactory,
                verifier: HardenedAuthVerifier? = nil,
                cache: TokenCaching? = nil) {
        self.config = config
        self.provider = provider
        self.factory = factory
        self.verifier = verifier ?? HardenedAuthVerifier(config: config)
        self.cache = cache ?? AttestationTokenCache(account: config.libBuildId)
    }

    /// End-to-end hardened session creation (VALIDATION_PACKAGE.md §6.3):
    ///   1. offline SKU → skip JWT, legacy gate only.
    ///   2. otherwise fetch/cache a fresh JWT, verify all gates, then create.
    public func createSession(legacySignature: String,
                              appId: String,
                              configData: Data,
                              paramsJSON: String,
                              now: Date = Date()) throws -> AnyObject {
        // Legacy smoke-test first (§6.3a): obviously-bad payloads die early.
        guard !legacySignature.isEmpty, isHex256(legacySignature) else {
            throw SessionAuthorizationError(.legacyFail, "legacy signature empty or malformed")
        }

        if config.offlineSKU {
            // §6.2.3 / §8.2: offline SKUs fall back to the legacy path with telemetry.
            return try factory.createSessionHardened(signature: legacySignature,
                                                     attestationJWT: "",
                                                     paramsJSON: paramsJSON)
        }

        let configHash = ConfigDigest.sha256Hex(of: configData)
        let jwt = try obtainToken(appId: appId, configHash: configHash, now: now)

        let status = verifier.verify(jwt: jwt, configSHA256: configHash, now: now)
        guard status == .ok else {
            throw SessionAuthorizationError(status, "hardened gate failed: \(status)")
        }
        return try factory.createSessionHardened(signature: legacySignature,
                                                 attestationJWT: jwt,
                                                 paramsJSON: paramsJSON)
    }

    private func obtainToken(appId: String, configHash: String, now: Date) throws -> String {
        if let cached = cache.load(now: now) { return cached }
        let nonce = UUID().uuidString
        let jwt = try provider.fetchToken(appId: appId,
                                          buildId: config.libBuildId,
                                          deviceNonce: nonce,
                                          configSHA256: configHash)
        if let payload = jwt.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first,
           let data = Base64URL.decode(String(payload)),
           let claims = try? JSONDecoder().decode(OCRAttestationClaims.self, from: data) {
            cache.store(jwt: jwt, exp: claims.exp)
        }
        return jwt
    }

    private func isHex256(_ s: String) -> Bool {
        s.count == 256 && s.allSatisfy { $0.isHexDigit }
    }
}
