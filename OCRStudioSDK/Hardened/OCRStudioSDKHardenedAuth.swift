//
//  OCRStudioSDKHardenedAuth.swift
//  Patched SDK surface — JWT gates before createSession (authorized research).
//
//  Uses CryptoKit Ed25519; trial build auto-mints with a baked demo key so the
//  sample runs offline. Vendor must replace minting with their Auth Server and
//  bake only the server public key.
//

import Foundation
import CryptoKit

@objc public enum OCRStudioSDKAuthGate: Int {
    case ok = 0
    case legacyFail = 1
    case jwtSignatureBad = 2
    case jwtExpired = 3
    case buildMismatch = 4
    case configMismatch = 5
    case nonceReused = 6
    case codeHashBad = 7
    case vcihFail = 8
}

@objcMembers
public final class OCRStudioSDKHardenedAuth: NSObject {

    public static let defaultBuildId = "1.3.1-ios-arm64-trial-2026Q3"
    public static let clientId = "ocrstudio_arafatgroup_trial"
    public static let audience = "ocrstudio-sdk"
    public static let platform = "ios"

    /// Deterministic trial seed (64 hex) — DEMO ONLY; vendor replaces with server mint.
    private static let trialSeedHex =
        "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"

    private static var nonces = Set<String>()
    private static let lock = NSLock()

    private static var trialPrivateKey: Curve25519.Signing.PrivateKey {
        var bytes = [UInt8]()
        var s = trialSeedHex
        while s.count >= 2 {
            bytes.append(UInt8(s.prefix(2), radix: 16)!)
            s.removeFirst(2)
        }
        return try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(bytes))
    }

    private static var trialPublicKey: Curve25519.Signing.PublicKey {
        trialPrivateKey.publicKey
    }

    // MARK: - Public API used from OCRStudioSDKInstance.mm

    /// SHA-256 hex of config file at path.
    @objc public static func configSHA256Hex(ofFileAt path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return sha256Hex(data)
    }

    /// Mint a short-lived trial JWT bound to build + config (offline demo).
    @objc public static func mintTrialAttestation(configSHA256Hex: String,
                                                   buildId: String,
                                                   now: TimeInterval) -> String {
        let iat = Int(now)
        let exp = iat + 24 * 60 * 60
        let nonce = UUID().uuidString
        let header = #"{"alg":"EdDSA","typ":"JWT"}"#
        // Stable key order for signing (matches reference_server_mint.py).
        let ordered = #"{"sub":"\#(clientId)","lib_build_id":"\#(buildId)","platform":"\#(platform)","config_sha256":"\#(configSHA256Hex)","iat":\#(iat),"exp":\#(exp),"nonce":"\#(nonce)","aud":"\#(audience)"}"#
        let signingInput = "\(b64url(Data(header.utf8))).\(b64url(Data(ordered.utf8)))"
        let sig = try! trialPrivateKey.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(b64url(sig))"
    }

    /// Four-gate verify. Returns OCRStudioSDKAuthGate raw value.
    @objc public static func verify(jwt: String,
                                    configSHA256Hex: String,
                                    buildId: String,
                                    now: TimeInterval) -> Int {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue }
        let signingInput = "\(parts[0]).\(parts[1])"
        guard let sig = b64urlDecode(String(parts[2])),
              let msg = signingInput.data(using: .ascii),
              trialPublicKey.isValidSignature(sig, for: msg) else {
            return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue
        }
        guard let payloadData = b64urlDecode(String(parts[1])),
              let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue
        }
        let nowSec = Int(now)
        let skew = 300
        let iatFloor = 1_767_225_600
        guard let iat = obj["iat"] as? Int, let exp = obj["exp"] as? Int else {
            return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue
        }
        if iat < iatFloor { return OCRStudioSDKAuthGate.jwtExpired.rawValue }
        if iat - skew > nowSec { return OCRStudioSDKAuthGate.jwtExpired.rawValue }
        if exp <= nowSec - skew { return OCRStudioSDKAuthGate.jwtExpired.rawValue }
        if (exp - iat) > 48 * 60 * 60 { return OCRStudioSDKAuthGate.jwtExpired.rawValue }

        guard let aud = obj["aud"] as? String, aud == audience else {
            return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue
        }
        guard let sub = obj["sub"] as? String, sub == clientId else {
            return OCRStudioSDKAuthGate.buildMismatch.rawValue
        }
        guard let plat = obj["platform"] as? String, plat == platform else {
            return OCRStudioSDKAuthGate.buildMismatch.rawValue
        }
        guard let lib = obj["lib_build_id"] as? String, lib == buildId else {
            return OCRStudioSDKAuthGate.buildMismatch.rawValue
        }
        guard let cfg = obj["config_sha256"] as? String,
              cfg.lowercased() == configSHA256Hex.lowercased() else {
            return OCRStudioSDKAuthGate.configMismatch.rawValue
        }
        guard let nonce = obj["nonce"] as? String else {
            return OCRStudioSDKAuthGate.jwtSignatureBad.rawValue
        }
        lock.lock()
        defer { lock.unlock() }
        if nonces.contains(nonce) { return OCRStudioSDKAuthGate.nonceReused.rawValue }
        nonces.insert(nonce)
        return OCRStudioSDKAuthGate.ok.rawValue
    }

    /// End-to-end: mint (trial) + verify. Returns 0 on OK; fills outJWT.
    @objc public static func authorizeSession(configPath: String,
                                              buildId: String,
                                              outJWT: AutoreleasingUnsafeMutablePointer<NSString?>?,
                                              error: NSErrorPointer) -> Int {
        guard let cfgHash = configSHA256Hex(ofFileAt: configPath) else {
            error?.pointee = NSError(domain: "ai.ocrstudio.sdk.auth", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "cannot hash config"])
            return OCRStudioSDKAuthGate.legacyFail.rawValue
        }
        let now = Date().timeIntervalSince1970
        let jwt = mintTrialAttestation(configSHA256Hex: cfgHash, buildId: buildId, now: now)
        let st = verify(jwt: jwt, configSHA256Hex: cfgHash, buildId: buildId, now: now)
        if st != 0 {
            error?.pointee = NSError(domain: "ai.ocrstudio.sdk.auth", code: st,
                                     userInfo: [NSLocalizedDescriptionKey: "hardened gate \(st)"])
            return st
        }
        outJWT?.pointee = jwt as NSString
        return 0
    }

    // MARK: - helpers

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func b64url(_ d: Data) -> String {
        d.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func b64urlDecode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - t.count % 4) % 4
        t += String(repeating: "=", count: pad)
        return Data(base64Encoded: t)
    }
}
