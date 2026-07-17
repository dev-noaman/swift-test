//
//  CreateSessionHardened.swift
//  OCRStudioSDK — hardening reference (authorized security research)
//
//  In-repo stand-in for the vendor's post-patch native entry (§6.6 / Phase 3).
//  This is NOT a binary patch of libocrstudiosdk — it is the enforceable auth
//  surface that Codemagic proves. A real OEM release must move the same gates
//  into the closed-source engine; until then, apps must route ALL session
//  creation through this API (never call legacy CreateSession directly).
//

import Foundation

/// Deployment phase for the reference patched surface (VALIDATION_PACKAGE §6.13).
public enum OCRAuthPhase: String, Sendable {
    /// Hardened path opt-in; legacy CreateSession still accepted (transition).
    case phase1Compat
    /// Legacy CreateSession retired — JWT gates mandatory (fully patched).
    case phase3Patched
}

/// Opaque session produced only after hardened gates pass.
public final class HardenedSession: NSObject {
    public let createdAt: Date
    public let attestationBound: Bool
    public init(createdAt: Date = Date(), attestationBound: Bool) {
        self.createdAt = createdAt
        self.attestationBound = attestationBound
    }
}

/// Native-side gate that mirrors `+createSessionHardened:…` (§6.6).
///
/// Fully patched (`phase3Patched`) behaviour:
///   1. Legacy signature must be well-formed 256-hex (smoke test).
///   2. Attestation JWT must pass every HardenedAuthVerifier gate.
///   3. Empty / missing JWT → reject (legacy-alone is dead).
///
/// Legacy `CreateSession(signature)` is represented by `createSessionLegacy`
/// and always fails under `phase3Patched`.
public struct CreateSessionHardened {
    public let config: HardenedAuthConfig
    public let phase: OCRAuthPhase
    public let verifier: HardenedAuthVerifier

    public init(config: HardenedAuthConfig,
                phase: OCRAuthPhase = .phase3Patched,
                nonces: NonceLRU = NonceLRU(),
                integrity: IntegrityChecking = TrustedIntegrity()) {
        self.config = config
        self.phase = phase
        self.verifier = HardenedAuthVerifier(config: config, nonces: nonces, integrity: integrity)
    }

    /// §6.6 hardened entry. Returns session + `.ok`, or throws `SessionAuthorizationError`.
    @discardableResult
    public func create(signature: String,
                       attestationJWT: String,
                       paramsJSON: String,
                       configSHA256: String,
                       now: Date = Date()) throws -> HardenedSession {
        _ = paramsJSON
        guard isHex256(signature) else {
            throw SessionAuthorizationError(.legacyFail, "legacy signature empty or malformed")
        }

        if attestationJWT.isEmpty {
            if phase == .phase3Patched && !config.offlineSKU {
                throw SessionAuthorizationError(.jwtSignatureBad,
                    "fully patched: attestation JWT required (legacy-alone rejected)")
            }
            if config.offlineSKU {
                return HardenedSession(attestationBound: false)
            }
            throw SessionAuthorizationError(.jwtSignatureBad, "attestation JWT required")
        }

        let status = verifier.verify(jwt: attestationJWT, configSHA256: configSHA256, now: now)
        guard status == .ok else {
            throw SessionAuthorizationError(status, "hardened gate failed: \(status)")
        }
        return HardenedSession(attestationBound: true)
    }

    /// Retired legacy entry (§6.13 Phase 3). Always fails when fully patched.
    public func createSessionLegacy(signature: String) throws -> HardenedSession {
        if phase == .phase3Patched {
            throw SessionAuthorizationError(.legacyFail,
                "CreateSession retired: use CreateSessionHardened (phase 3 patched)")
        }
        // phase1Compat: format smoke only — mirrors weak pre-hardening path for demos
        guard isHex256(signature) else {
            throw SessionAuthorizationError(.legacyFail, "legacy signature empty or malformed")
        }
        return HardenedSession(attestationBound: false)
    }

    private func isHex256(_ s: String) -> Bool {
        s.count == 256 && s.allSatisfy { $0.isHexDigit }
    }
}

/// Default factory used by HardenedAuthWrapper — routes through CreateSessionHardened.
public struct PatchedSessionFactory: HardenedSessionFactory {
    public let gate: CreateSessionHardened
    public let configSHA256: String
    public let now: Date

    public init(gate: CreateSessionHardened, configSHA256: String, now: Date = Date()) {
        self.gate = gate
        self.configSHA256 = configSHA256
        self.now = now
    }

    public func createSessionHardened(signature: String,
                                      attestationJWT: String,
                                      paramsJSON: String) throws -> AnyObject {
        try gate.create(signature: signature,
                        attestationJWT: attestationJWT,
                        paramsJSON: paramsJSON,
                        configSHA256: configSHA256,
                        now: now)
    }
}
