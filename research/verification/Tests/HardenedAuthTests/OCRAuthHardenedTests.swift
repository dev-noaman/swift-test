//
//  OCRAuthHardenedTests.swift
//  OCRStudioSDK — hardening reference (authorized security research)
//
//  XCTest suite for VALIDATION_PACKAGE.md §8. It proves the vulnerable behavior
//  BEFORE the vendor patch and the hardened behavior AFTER it, against the
//  reference implementation in HardenedAuthWrapper.swift.
//
//  HONEST SCOPE — what these tests do and do NOT cover:
//    • They exercise the *reference* four-gate verifier (HardenedAuthVerifier),
//      the wrapper orchestration, and the EdDSA token format that
//      reference_server_mint.py emits. Tokens are minted in-process with a
//      CryptoKit test key whose public half is pinned into the config, so the
//      suite is fully self-contained and deterministic.
//    • The legacy RSA-1024 / raw-PKCS#1 verify path is NOT re-implemented in
//      Swift. Its real behavior (trial sig PASS, tampered/empty/malformed FAIL)
//      is proven by research/verify_static_auth_poc.py and check_binary_poc.py.
//      Here it is represented by `LegacyAuthModel`, a faithful stand-in used
//      only to express the pre-patch T1/T2 narrative.
//    • The shipped binary's real code-region hash / VCIH reads are represented
//      by injectable IntegrityChecking stubs (§6.2.4).
//
//  Target layout: Swift package `research/verification` (module HardenedAuth).
//  Run: `cd research/verification && swift test` (macOS / Codemagic).
//

import XCTest
import CryptoKit
@testable import HardenedAuth

// MARK: - Fixtures

private enum Fixtures {
    static let clientId = "ocrstudio_arafatgroup_trial"
    static let buildA = "1.3.1-ios-arm64-trial-2026Q3"
    static let buildB = "9.9.9-ios-arm64-attacker-build"
    static let audience = "ocrstudio-sdk"

    // Deterministic test clock: 2026-07-18T00:00:00Z (above the 2026-01-01 iatFloor).
    static let now = Date(timeIntervalSince1970: 1_784_332_800)
    static let dayA = Data("config-A bytes".utf8)
    static let dayB = Data("config-B bytes".utf8)

    // The real trial signature (doc/README.md) — the pre-patch T1 subject.
    static let trialSig =
        "2122df27f3d5cc5c0cf5ff02e651b2dde1b1dd49bfdd185a192092ee68c674b5" +
        "e138bfbe2e528d6926b5ee234b59929832555359d7a61544a626f04931a4d82f" +
        "727a088dd0ffd73009f28449780a407f74c068de29c7bd7b767f2c8006fae95a" +
        "918782bdb388a7caf492af8f44d3f973da66fc37f73f19f66e71848e93c6556e"
    // One-nibble flip (leading 2 -> 3), matching the PoC tamper vector.
    static let tamperedSig = "3" + String(trialSig.dropFirst())
}

// MARK: - Pre-patch legacy model (single offline gate — the vulnerability)

/// Models the shipped single-gate behavior: a session is authorized iff the
/// legacy RSA signature verifies, with NO app / build / expiry / config binding.
/// Real crypto is covered by verify_static_auth_poc.py; here we key off the one
/// known-valid trial signature so the T1 "works in any app" story is expressible.
private struct LegacyAuthModel {
    func accepts(_ signature: String) -> Bool { signature == Fixtures.trialSig }
}

// MARK: - In-process EdDSA token minter (mirrors reference_server_mint.py)

private struct TestTokenMinter {
    let key: Curve25519.Signing.PrivateKey

    static func b64url(_ d: Data) -> String {
        d.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func mint(sub: String = Fixtures.clientId,
              build: String = Fixtures.buildA,
              platform: String = "ios",
              configSHA256: String,
              iat: Int,
              exp: Int,
              nonce: String,
              aud: String = Fixtures.audience) -> String {
        let header = #"{"alg":"EdDSA","typ":"JWT"}"#
        let claims = OCRAttestationClaims(sub: sub, lib_build_id: build, platform: platform,
                                          config_sha256: configSHA256, iat: iat, exp: exp,
                                          nonce: nonce, aud: aud)
        let payloadData = try! JSONEncoder().encode(claims)
        let signingInput = "\(Self.b64url(Data(header.utf8))).\(Self.b64url(payloadData))"
        let sig = try! key.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(Self.b64url(sig))"
    }
}

// MARK: - Mocks for wrapper-level tests

private final class InMemoryCache: TokenCaching {
    private var jwt: String?
    private var exp: Int = 0
    func store(jwt: String, exp: Int) { self.jwt = jwt; self.exp = exp }
    func load(now: Date) -> String? {
        guard let jwt = jwt, Int(now.timeIntervalSince1970) < exp else { return nil }
        return jwt
    }
}

/// Provider that mints a well-formed token for whatever the wrapper asks for.
private struct MintingProvider: AttestationProviding {
    let minter: TestTokenMinter
    let now: Date
    var build = Fixtures.buildA
    func fetchToken(appId: String, buildId: String, deviceNonce: String, configSHA256: String) throws -> String {
        let iat = Int(now.timeIntervalSince1970)
        return minter.mint(build: build, configSHA256: configSHA256, iat: iat, exp: iat + 3600, nonce: deviceNonce)
    }
}

/// Provider that must never be consulted (offline SKU path).
private struct ExplodingProvider: AttestationProviding {
    func fetchToken(appId: String, buildId: String, deviceNonce: String, configSHA256: String) throws -> String {
        XCTFail("attestation server should not be contacted on the offline path")
        throw SessionAuthorizationError(.jwtSignatureBad, "unexpected network call")
    }
}

private final class RecordingFactory: HardenedSessionFactory {
    private(set) var lastSignature: String?
    private(set) var lastJWT: String?
    func createSessionHardened(signature: String, attestationJWT: String, paramsJSON: String) throws -> AnyObject {
        lastSignature = signature
        lastJWT = attestationJWT
        return NSObject()
    }
}

private struct PatchedCodeIntegrity: IntegrityChecking {
    var codeOK: Bool
    var vcihOK: Bool
    func codeRegionHashMatches() -> Bool { codeOK }
    func vcihMatches() -> Bool { vcihOK }
}

// MARK: - Test case

final class OCRAuthHardenedTests: XCTestCase {

    private let serverKey = Curve25519.Signing.PrivateKey()
    private lazy var minter = TestTokenMinter(key: serverKey)

    private func makeConfig(build: String = Fixtures.buildA,
                            offline: Bool = false,
                            integrity: IntegrityChecking = TrustedIntegrity(),
                            nonces: NonceLRU = NonceLRU()) -> (HardenedAuthConfig, HardenedAuthVerifier) {
        let cfg = HardenedAuthConfig(clientId: Fixtures.clientId,
                                     libBuildId: build,
                                     serverPublicKey: serverKey.publicKey,
                                     offlineSKU: offline)
        return (cfg, HardenedAuthVerifier(config: cfg, nonces: nonces, integrity: integrity))
    }

    private func hash(_ d: Data) -> String { ConfigDigest.sha256Hex(of: d) }
    private var iatNow: Int { Int(Fixtures.now.timeIntervalSince1970) }

    private func validToken(build: String = Fixtures.buildA,
                            config: Data = Fixtures.dayA,
                            nonce: String = UUID().uuidString,
                            iat: Int? = nil,
                            exp: Int? = nil) -> String {
        let i = iat ?? iatNow
        return minter.mint(build: build, configSHA256: hash(config), iat: i, exp: exp ?? (i + 86_400), nonce: nonce)
    }

    // T1 — trial signature accepted today; legacy-alone insufficient after patch.
    func testTrialSignatureAccepted() {
        XCTAssertTrue(LegacyAuthModel().accepts(Fixtures.trialSig), "pre-patch: trial sig accepted (vuln)")
        let (_, verifier) = makeConfig()
        // Post-patch: a legacy signature with no valid JWT cannot open a session.
        XCTAssertEqual(verifier.verify(jwt: "legacy.only.nojwt", configSHA256: hash(Fixtures.dayA), now: Fixtures.now),
                       .jwtSignatureBad)
    }

    // Tampered legacy signature is rejected pre- and post-patch.
    func testTamperedSignatureRejected() {
        XCTAssertFalse(LegacyAuthModel().accepts(Fixtures.tamperedSig))
    }

    // T1/T4 — stolen sig works in any app today; build binding stops it after patch.
    func testStolenSignatureAcrossApps() {
        // Pre-patch: legacy accepts the same sig regardless of which app hosts it.
        XCTAssertTrue(LegacyAuthModel().accepts(Fixtures.trialSig))  // app A
        XCTAssertTrue(LegacyAuthModel().accepts(Fixtures.trialSig))  // app B (clone)

        // Post-patch: a token minted for build A verifies in A, fails in B.
        let token = validToken(build: Fixtures.buildA)
        let (_, appA) = makeConfig(build: Fixtures.buildA)
        let (_, appB) = makeConfig(build: Fixtures.buildB)
        XCTAssertEqual(appA.verify(jwt: token, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .ok)
        XCTAssertEqual(appB.verify(jwt: token, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .buildMismatch)
    }

    func testExpiredAttestationRejected() {
        let expired = validToken(iat: iatNow - 172_800, exp: iatNow - 86_400) // exp 1 day ago
        let (_, verifier) = makeConfig()
        XCTAssertEqual(verifier.verify(jwt: expired, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .jwtExpired)
    }

    func testBuildIdMismatchRejected() {
        let token = validToken(build: Fixtures.buildB)          // claims build B
        let (_, verifier) = makeConfig(build: Fixtures.buildA)  // baked build A
        XCTAssertEqual(verifier.verify(jwt: token, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .buildMismatch)
    }

    func testConfigHashMismatchRejected() {
        let token = validToken(config: Fixtures.dayA)           // token binds config A
        let (_, verifier) = makeConfig()
        // On-disk config is B → mismatch.
        XCTAssertEqual(verifier.verify(jwt: token, configSHA256: hash(Fixtures.dayB), now: Fixtures.now), .configMismatch)
    }

    func testNonceReplayRejected() {
        let nonces = NonceLRU()
        let (_, verifier) = makeConfig(nonces: nonces)
        let nonce = "a3f1bc9e-0000-4000-8000-000000000001"
        let first = validToken(nonce: nonce)
        let second = validToken(nonce: nonce, iat: iatNow + 1)  // distinct token, same nonce
        XCTAssertEqual(verifier.verify(jwt: first, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .ok)
        XCTAssertEqual(verifier.verify(jwt: second, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .nonceReused)
    }

    // T3 — a token forged under a different key must not verify.
    func testJWTSignatureForgeRejected() {
        let attacker = TestTokenMinter(key: Curve25519.Signing.PrivateKey())
        let forged = attacker.mint(configSHA256: hash(Fixtures.dayA), iat: iatNow, exp: iatNow + 86_400,
                                   nonce: UUID().uuidString)
        let (_, verifier) = makeConfig()  // pins the *real* server key
        XCTAssertEqual(verifier.verify(jwt: forged, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .jwtSignatureBad)
    }

    // T2 — simulated .text patch of the verify region is caught by code-region hash.
    func testCodeRegionPatchDetected() {
        let (_, verifier) = makeConfig(integrity: PatchedCodeIntegrity(codeOK: false, vcihOK: true))
        XCTAssertEqual(verifier.verify(jwt: validToken(), configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .codeHashBad)
    }

    // T2 — simulated __const blob tamper is caught by the hardened VCIH twin.
    func testVCIHFailOnConstBlobTamper() {
        let (_, verifier) = makeConfig(integrity: PatchedCodeIntegrity(codeOK: true, vcihOK: false))
        XCTAssertEqual(verifier.verify(jwt: validToken(), configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .vcihFail)
    }

    func testClockSkewTolerance() {
        let (_, verifier) = makeConfig()
        // iat 200s in the future is within the 300s tolerance.
        let withinSkew = validToken(iat: iatNow + 200)
        XCTAssertEqual(verifier.verify(jwt: withinSkew, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .ok)
        // iat 400s in the future is beyond tolerance → treated as not-yet-valid.
        let beyondSkew = validToken(iat: iatNow + 400, exp: iatNow + 400 + 86_400)
        XCTAssertEqual(verifier.verify(jwt: beyondSkew, configSHA256: hash(Fixtures.dayA), now: Fixtures.now), .jwtExpired)
    }

    // Phase-1 backward compatibility: legacy path still honors a valid legacy sig.
    func testBackwardCompat_LegacyPathStillAcceptsValidLegacySig() {
        XCTAssertTrue(LegacyAuthModel().accepts(Fixtures.trialSig))
    }

    // Offline SKU: the wrapper must skip the server and create via the legacy path.
    func testOfflineFallback() throws {
        let (cfg, _) = makeConfig(offline: true)
        let factory = RecordingFactory()
        let wrapper = HardenedAuthWrapper(config: cfg, provider: ExplodingProvider(), factory: factory,
                                          cache: InMemoryCache())
        _ = try wrapper.createSession(legacySignature: Fixtures.trialSig, appId: "app.A",
                                      configData: Fixtures.dayA, paramsJSON: "{}", now: Fixtures.now)
        XCTAssertEqual(factory.lastSignature, Fixtures.trialSig)
        XCTAssertEqual(factory.lastJWT, "", "offline path must pass an empty JWT")
    }

    func testEmptySignatureRejected() {
        let (cfg, _) = makeConfig()
        let wrapper = HardenedAuthWrapper(config: cfg,
                                          provider: MintingProvider(minter: minter, now: Fixtures.now),
                                          factory: RecordingFactory(), cache: InMemoryCache())
        XCTAssertThrowsError(try wrapper.createSession(legacySignature: "", appId: "app.A",
                                                       configData: Fixtures.dayA, paramsJSON: "{}", now: Fixtures.now)) {
            XCTAssertEqual(($0 as? SessionAuthorizationError)?.status, .legacyFail)
        }
    }

    func testMalformed256HexRejected() {
        let (cfg, _) = makeConfig()
        let wrapper = HardenedAuthWrapper(config: cfg,
                                          provider: MintingProvider(minter: minter, now: Fixtures.now),
                                          factory: RecordingFactory(), cache: InMemoryCache())
        XCTAssertThrowsError(try wrapper.createSession(legacySignature: "not-hex-and-too-short", appId: "app.A",
                                                       configData: Fixtures.dayA, paramsJSON: "{}", now: Fixtures.now)) {
            XCTAssertEqual(($0 as? SessionAuthorizationError)?.status, .legacyFail)
        }
    }

    // Full hardened happy path through the wrapper: fetch → verify → create.
    func testHardenedHappyPath_createsSession() throws {
        let (cfg, _) = makeConfig()
        let factory = RecordingFactory()
        let wrapper = HardenedAuthWrapper(config: cfg,
                                          provider: MintingProvider(minter: minter, now: Fixtures.now),
                                          factory: factory, cache: InMemoryCache())
        _ = try wrapper.createSession(legacySignature: Fixtures.trialSig, appId: "app.A",
                                      configData: Fixtures.dayA, paramsJSON: "{}", now: Fixtures.now)
        XCTAssertEqual(factory.lastSignature, Fixtures.trialSig)
        XCTAssertFalse(factory.lastJWT?.isEmpty ?? true, "hardened path must pass a real JWT")
    }

    // MARK: - Fully patched (Phase 3) — CreateSessionHardened is mandatory

    private func patchedGate(offline: Bool = false) -> CreateSessionHardened {
        let (cfg, _) = makeConfig(offline: offline)
        return CreateSessionHardened(config: cfg, phase: .phase3Patched)
    }

    /// Fully patched: stolen trial signature alone cannot open a session.
    func testFullyPatched_trialSignatureAloneRejected() {
        let gate = patchedGate()
        XCTAssertThrowsError(try gate.create(signature: Fixtures.trialSig,
                                             attestationJWT: "",
                                             paramsJSON: "{}",
                                             configSHA256: hash(Fixtures.dayA),
                                             now: Fixtures.now)) {
            XCTAssertEqual(($0 as? SessionAuthorizationError)?.status, .jwtSignatureBad)
        }
    }

    /// Fully patched: legacy CreateSession entry is retired.
    func testFullyPatched_legacyCreateSessionRetired() {
        let gate = patchedGate()
        XCTAssertThrowsError(try gate.createSessionLegacy(signature: Fixtures.trialSig)) {
            XCTAssertEqual(($0 as? SessionAuthorizationError)?.status, .legacyFail)
        }
    }

    /// Fully patched: valid JWT + trial sig creates an attestation-bound session.
    func testFullyPatched_happyPath() throws {
        let gate = patchedGate()
        let jwt = validToken()
        let session = try gate.create(signature: Fixtures.trialSig,
                                      attestationJWT: jwt,
                                      paramsJSON: "{}",
                                      configSHA256: hash(Fixtures.dayA),
                                      now: Fixtures.now)
        XCTAssertTrue(session.attestationBound)
    }

    /// Fully patched: stolen token for another build cannot open a session.
    func testFullyPatched_stolenTokenWrongBuildRejected() {
        let gate = patchedGate() // baked build A
        let jwtForB = validToken(build: Fixtures.buildB)
        XCTAssertThrowsError(try gate.create(signature: Fixtures.trialSig,
                                             attestationJWT: jwtForB,
                                             paramsJSON: "{}",
                                             configSHA256: hash(Fixtures.dayA),
                                             now: Fixtures.now)) {
            XCTAssertEqual(($0 as? SessionAuthorizationError)?.status, .buildMismatch)
        }
    }

    /// End-to-end: wrapper + PatchedSessionFactory (what Codemagic proves).
    func testFullyPatched_wrapperUsesNativeGate() throws {
        let (cfg, _) = makeConfig()
        let gate = CreateSessionHardened(config: cfg, phase: .phase3Patched)
        let factory = PatchedSessionFactory(gate: gate,
                                            configSHA256: hash(Fixtures.dayA),
                                            now: Fixtures.now)
        let wrapper = HardenedAuthWrapper(config: cfg,
                                          provider: MintingProvider(minter: minter, now: Fixtures.now),
                                          factory: factory,
                                          cache: InMemoryCache())
        let session = try wrapper.createSession(legacySignature: Fixtures.trialSig,
                                                appId: "app.A",
                                                configData: Fixtures.dayA,
                                                paramsJSON: "{}",
                                                now: Fixtures.now)
        XCTAssertTrue((session as? HardenedSession)?.attestationBound ?? false)
    }
}
