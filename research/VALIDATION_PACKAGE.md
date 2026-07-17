# OCRStudioSDK 1.3.1 — Authorization Validation & Remediation Package

**Classification:** Confidential — Iron Software / OCR Studio Security Team    
**Prepared for:** Daniel Mahony, OCR Studio Security Team (`daniel.mahony@ocrstudio.ai`)  
**Prepared by:** Adel Noaman (`expert.winxp@gmail.com`)  
**Date:** 17 July 2026  
**Product:** OCRStudioSDK 1.3.1 iOS Trial (`ocrstudiosdk.xcframework`)  
**Authorization:** DocuSign envelope `E86EA6F7-B675-8E96-8194-18360D9FF672` (valid 13 July 2026 – 30 July 2026)  
**Source of truth:** `CLAUDE.md` — every finding below references that document.

Companion artifacts:

| File | Role |
|------|------|
| `verify_static_auth_poc.py` | Verify  PoC (PASS/FAIL against trial signature) |
| `check_binary_poc.py` | Binary ↔ PoC constants cross-check (carves shipped `.a`) |
| `verification/Tests/HardenedAuthTests/OCRAuthHardenedTests.swift` | XCTest suite (proves vuln before patch, absence after) |
| `verification/Sources/HardenedAuth/HardenedAuthWrapper.swift` | Reference Swift wrapper integrating hardened auth |
| `verification/Package.swift` | SwiftPM package — `swift test` / Codemagic |
| `verification/reference_server_mint.py` | Reference server-side Ed25519/JWT mint (Python) |
| `VERIFY_PATH_MAP.md` | Symbol / offset / relocation map of verify path |
| `VENDOR_HARDENING.md` | Mitigation backlog + patch-resistance test guide |
| `ocrstudio_pubkey_spki.pem` | Recovered RSA-1024 public key (SPKI) |

---

## 1. Executive Summary

OCRStudioSDK 1.3.1 iOS Trial authorizes sessions offline using a **256-character hexadecimal personalized signature** validated against a public key and expected digest embedded in `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework` (CLAUDE.md §Signature Requirement, §License / Signature Validation Flow).

Four confirmed threat classes apply (§Disclosure §6):

| ID | Threat | Severity | Status today | Status after proposed patch |
|----|--------|----------|--------------|-----------------------------|
| T1 | Signature theft / clone | High | ✅ confirmed (PoC PASS) | Mitigated: structured claims bind sig to build + token |
| T2 | Binary patch of verify path | High | ✅ confirmed (single 20-byte compare + VCIH twin) | Mitigated: multi-site + code-hash + online attestation |
| T3 | Cryptographic weakness | High | ✅ confirmed (RSA-1024/e=3/SHA-1/raw-PKCS#1) | Mitigated: Ed25519 + SHA-256 + PSS-or-EdDSA |
| T4 | Weak payload binding | Medium | ✅ confirmed (signed payload = `SHA-1(client_id)`  ) | Mitigated: JWT carries build_id, config, expiry, nonce |

**This package does not include license-bypass tooling or signature-forge utilities.** Attack classes are described at a level sufficient for remediation. PoC proves the *verify* path   (public operation); forging requires the vendor's private activation material which was not recovered.

---

## 2. Architecture Analysis

### 2.1 Three-layer architecture (per CLAUDE.md §Architecture)

```
┌───────────────────────────────────────────────────────────────────┐
│  Swift Layer  (OCRStudioSDK/)                                      │
│    • OCRStudioSDKViewController                                    │
│    • Camera / video helper, UI                                     │
│    • Bridging-Header.h                                             │
├───────────────────────────────────────────────────────────────────┤
│  Objective-C++ Wrapper Layer  (OCRStudioSDKCore/wrap/objcocr…)     │
│    • OCRStudioSDKInstance, Session, Image, Result                  │
│    • Proxies to C++ layer; ARC-managed                             │
├───────────────────────────────────────────────────────────────────┤
│  C++ Core Layer  (OCRStudioSDKCore/include+lib)                    │
│    • ocrstudio:: namespace engine                                  │
│    • se::security  — licensing stack (Smart Engines OEM)           │
│    • BearSSL primitives                                            │
│    • Shipped as libocrstudiosdk-ios.a (~184 MB fat, 2787 objects)  │
└───────────────────────────────────────────────────────────────────┘
```

The authorization stack is entirely inside the C++ core. Swift and Objective-C++ layers are thin pass-throughs that accept the signature and forward it to `CreateSession`.

### 2.2 Trust boundaries

| Boundary | What's trusted today | What must be trusted after patch |
|----------|---------------------|----------------------------------|
| App ↔ SDK | App provides 256-hex sig; SDK trusts its own baked pubkey | App must additionally present fresh server-signed token |
| SDK ↔ device | SDK trusts its own `__const`; root/jailbreak can patch it | SDK still trusts itself but multi-site + code-hash raises cost |
| App ↔ server | None today | App must fetch short-lived attestation JWT from vendor server |
| SDK ↔ license server | None today | Optional heartbeat for high-value SKUs |

### 2.3 Security assumptions baked into shipped library

1. **Offline-  trust** — verification is performed entirely on device; no external call (CLAUDE.md §License / Signature Validation Flow: *"pure offline attestation — no network"*).
2. **Static embedding** — RSA pubkey + expected digest are baked into `__const` of `static_auth.cpp.o`; same blob is used by `VSA`, `VEA`, and `VCIH`.
3. **Single-gate verify** — `VSA` does a null-check then tail-calls `pkcs1_verify`. The boolean result is the entire authorization decision.
4. **Integrity-twin check** — `VCIH()` recomputes `SHA-1("ocrstudio_arafatgroup_trial")` and compares it to the same 20-byte constant that `pkcs1_verify` consumes (CLAUDE.md §License / Signature Validation Flow §VCIH).

### 2.4 Sensitive APIs and protected operations

| API | Sensitivity | Gate |
|-----|-------------|------|
| `CreateSession(signature, …)` | **Authorization boundary** | `VSA(signature)` (offline) |
| `se::security::internal::VSA` | Auth entry point | null-check + tail B to `pkcs1_verify` |
| `se::security::internal::VEA` | Alt auth entry | caller supplies hash ptr; same tail-call |
| `se::security::internal::VCIH` | Integrity self-check | same constant as VSA |
| `se::security::pkcs1_verify` | Crypto gate | BearSSL `br_rsa_pkcs1_vrfy` |
| `ProcessImage / ProcessData` | Protected operation | Requires successful CreateSession |

---

## 3. Authorization Flow Diagram

### 3.1 Current flow (as shipped — vulnerable)

```
  Host App                      ocrstudiosdk.xcframework (C++ core)
  ────────                      ────────────────────────────────────
       │
       │  CreateSession("2122df27…556e"   ← 256-hex trial sig
       │              , sessionParamsJSON
       │              , …)
       │ ─────────────────────► se::security::internal::VSA(sig)
       │                            │
       │                            │ ADRP+ADD → __const l001
       │                            │     (PUBKEY @ +0x00, EXPECTED_HASH @ +0xAF)
       │                            │
       │                            ▼
       │                      se::security::pkcs1_verify(sig, PUBKEY, EXPECTED_HASH)
       │                            │
       │                            ├─ hexstring_to_bytes(sig, 128B)
       │                            ├─ br_rsa_pkcs1_vrfy_get_default
       │                            ├─ vrfy(sig,128,NULL,20,&pubkey,&digest)
       │                            │     (hash_oid=NULL ⇒ raw SHA-1, no DigestInfo)
       │                            └─ memcmp(digest[20], EXPECTED_HASH[20])
       │                            │
       │                            ▼ return (digest==expected) ? OK : FAIL
       │ ◄───────────────────── OK / create session handle
       │
       │  ProcessImage(img)     → protected operation, allowed
       │
```

Integrity twin (CLAUDE.md §4.1):

```
       (somewhere during init / lazy check)
       VCIH() → get_hash("ocrstudio_arafatgroup_trial"[27]) → SHA-1
       compare to same EXPECTED_HASH @ __const+0xAF
       (if mismatch → likely abort or silent fail)
```

### 3.2 Proposed hardened flow (see §6)

```
  Host App                 ocrstudiosdk.xcframework         Vendor Auth Server
  ────────                 ──────────────────────────       ──────────────────
      │
      │  1. POST /attest {app_id, build_id, device_nonce}
      │ ─────────────────────────────────────────────────────►
      │  2. {jwt, iat, exp=(now+24h), claims:{build_id, config_sha256, nonce}}
      │ ◄─────────────────────────────────────────────────────
      │
      │  CreateSession(sig, token_jwt, params)
      │ ──────────────►  VSA(sig)             (legacy gate, keep as baseline)
      │                  + HardenedAuth.verify(token_jwt):
      │                      • check Ed25519 signature on JWT
      │                      • check exp > now
      │                      • check claims.build_id == LIBRARY_BUILD_ID
      │                      • check claims.config_sha256 == sha256(config/*.ocr)
      │                      • remember nonce (LRU cache) to block replay
      │                  + VCIH() integrity (legacy)
      │                  + code-region hash over VSA/pkcs1_verify (P3)
      │
      │ ◄────────────── OK   if ALL gates pass
      │
      │  ProcessImage(img) → allowed
```

---

## 4. Root Cause Analysis

### 4.1 Precise vulnerable components (with binary evidence)

| Component | Symbol | Object file | Evidence ref |
|-----------|--------|-------------|--------------|
| Static-auth entry | `se::security::internal::VSA(char const*)` | `static_auth.cpp.o` @ `__text+0xb4` | CLAUDE.md §Verify-path map; `VERIFY_PATH_MAP.md` |
| Alt-auth entry | `se::security::internal::VEA(char const*, unsigned char const*)` | `static_auth.cpp.o` @ `__text+0xcc` | same |
| Integrity twin | `se::security::internal::VCIH()` | `static_auth.cpp.o` @ `__text+0x0` | same |
| Crypto gate | `se::security::pkcs1_verify(…)` | `verify.cpp.o` @ `__text+0x0` | same |
| Hash function | `se::security::get_hash(…)` | `hashing.cpp.o` @ `__text+0x0` | same |

### 4.2 Missing authorization checks (per-threat)

#### T1 — Signature theft / clone

The verify path makes no assertion about:

- **which** app is using the signature (no app-identity / bundle-id claim),
- **when** the signature is valid (no expiry claim),
- **which** library build (no build-id claim),
- **what** config file the signature was issued against (no config hash claim).

Result: the 256-hex trial signature embedded in `Samples/Swift/OCRStudioSDKSample/OCRStudioSDKSampleViewController.swift` is copyable to any other app bundling the same `ocrstudiosdk.xcframework` build (CLAUDE.md §T1).

#### T2 — Binary patch of verify path

Vulnerable surface:

| Site | Why patchable |
|------|---------------|
| `VSA` +0xb4 .. +0xc8 | 20-byte function: CBZ null-check + ADRP+ADD + tail `B`. Patching the tail to NOP or to unconditional-success is trivial. |
| `pkcs1_verify` +0xa4 .. +0xc8 | Two `CMP_reg` + `B.cond`; flipping the branch condition or forcing `W0=1` bypasses the auth. |
| `__const` blob @ `l001`+0xAF (`EXPECTED_HASH`, 20 bytes) | Altering the digest to `SHA-1(<attacker-chosen-client-id>)` lets a custom signature verify. |
| `VCIH` +0x54 .. +0x90 | Twin of the above; must be patched in lockstep or VCIH triggers. Same single 20-byte constant — so a single `__const` patch fixes both if attacker owns it. |

#### T3 — Cryptographic weakness

The construction uses five deprecated elements stacked:

1. **RSA-1024** — below NIST / BSI / ANSSI minimums.
2. **Public exponent `e = 3`** — historically associated with padding-oracle and Bleichenbacher-class concerns.
3. **SHA-1** — broken for collision resistance (SHAttered 2017).
4. **PKCS#1 v1.5 without DigestInfo ASN.1 OID** — BearSSL invoked as `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)` (CLAUDE.md §4.3). Standard PKCS#1 verifiers reject these signatures.
5. **Raw 20-byte digest** — no structured claims, no versioning.

#### T4 — Weak payload binding

The signed payload is `SHA-1("ocrstudio_arafatgroup_trial")` (27 bytes) — nothing else (CLAUDE.md §License §Embedded constants). The license does **not** cryptographically assert config, library build, platform, or validity window.

### 4.3 Data flow leading to the vulnerability

```
CreateSession(sig_hex, …)
        │  [Swift/ObjC pass-through; no checks]
        ▼
VSA(sig_hex)                          ← auth entry point
        │  CBZ x0 → skip if NULL
        │  ADRP+ADD loads &l001 (__const)
        │         pub = __const + 0x00   (n[128] || e[4])
        │        hash = __const + 0xAF   (20 B EXPECTED_HASH)
        ▼
pkcs1_verify(sig_hex, pub, hash)
        │  hexstring_to_bytes(sig_hex, sig[128])
        │  br_rsa_pkcs1_vrfy_get_default → vrfy
        │  vrfy(sig,128,NULL,20,&pubkey,&recovered)
        │     // PKCS#1 unpad: 00 01 FF...FF 00 ‖ recovered[20]
        │  CMP_reg / B.cond  recovered == hash ?
        ▼
return (1 = auth OK, 0 = auth FAIL)   ← entire auth decision
```

Single 20-byte memory compare. One branch. One boolean. The whole authorization surface is reducible to a patch target of **2 bytes** (the conditional branch instruction) or a **20-byte overwrite** (the EXPECTED_HASH blob).

---

## 5. Validation PoC

### 5.1 Prerequisites

| Item | How to obtain |
|------|---------------|
| Python 3.10+ | `C:\Users\NN\AppData\Local\Programs\Python\Python310\python.exe` (CLAUDE.md §Reverse-Engineering Workflow) |
| `python-cryptography` (optional, for PEM load) | `pip install cryptography` — PoC falls back to hardcoded modulus |
| Shipped library | `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework/ios-arm64_armv7_armv7s/libocrstudiosdk-ios.a` |
| Research folder | `research/` of this repository |

No Xcode, no device, no network connection required for offline PoC.

### 5.2 Environment setup

```bash
python -V                              # expect Python 3.10+
pip install cryptography                # optional; PoC tolerates ImportError
ls research/ocrstudio_pubkey_spki.pem   # must exist
```

### 5.3 Exact reproduction procedure

#### 5.3.1 Offline verification (PASS on trial signature)

```bash
python research/verify_static_auth_poc.py
```

**Expected output:**

```
=== OCR Studio static-auth verify PoC ===
  modulus   : ocrstudio_pubkey_spki.pem (1024 bit)
  exponent  : 3
  client_id : 'ocrstudio_arafatgroup_trial'
  expected  : 25159e611dfa6f5f077a732a01d17ead8cc9770b
  sig[0:16] : 2122df27f3d5cc5c…
  detail    : ok
  result    : PASS
```

**Exit code:** 0.

#### 5.3.2 Self-check (VCIH-equivalent hash equality)

```bash
python research/verify_static_auth_poc.py --self-test
```

**Expected output:**

```
=== VCIH-style self-check ===
  client_id : 'ocrstudio_arafatgroup_trial'
  SHA-1     : 25159e611dfa6f5f077a732a01d17ead8cc9770b
  expected  : 25159e611dfa6f5f077a732a01d17ead8cc9770b
  result    : PASS
```

**Exit code:** 0.

#### 5.3.3 Tampered signature (FAIL — proves check is real)

```bash
python research/verify_static_auth_poc.py --signature \
  3122df27f3d5cc5c0cf5ff02e651b2dde1b1dd49bfdd185a192092ee68c674b5\
e138bfbe2e528d6926b5ee234b59929832555359d7a61544a626f04931a4d82f\
727a088dd0ffd73009f28449780a407f74c068de29c7bd7b767f2c8006fae95a\
918782bdb388a7caf492af8f44d3f973da66fc37f73f19f66e71848e93c6556e
```

**Expected output:**

```
  detail    : bad PKCS#1 header: 6bb7
  result    : FAIL
```

**Exit code:** 1.

#### 5.3.4 Binary cross-check (PoC constants faithfully mirror shipped .a)

```bash
python research/check_binary_poc.py
```

**Expected output (abbreviated):**

```
FOUND 'static_auth.cpp.o' size=1736 arm64-MachO
Mach-O: magic=0xFEEDFACF ncmds=5
  __TEXT,__text:    vma=0x0  size=228 fileoff=464
  __TEXT,__const:   vma=0xe4 size=195 fileoff=692
  __LD,__compact_unwind: vma=0x1a8 size=160 fileoff=888

__const blob (195 bytes)
  RSA n       : aa81d3f7…cea1bf39
  RSA e       : 00000003
  EXPECTED_H  : 25159e611dfa6f5f077a732a01d17ead8cc9770b
  marker idx  : offset 147
  SHA1(client): 25159e611dfa6f5f077a732a01d17ead8cc9770b

=== binary vs PoC cross-check ===
  n  match  : True
  e  match  : True
  hash match: True
  client_in : True
  hash == SHA1(client) : True

*** BINARY CROSS-CHECK: ALL MATCH ***
```

**Exit code:** 0.

### 5.4 Expected observable behavior in a live iOS build

In `Samples/Swift/OCRStudioSDKSample/OCRStudioSDKSampleViewController.swift` the trial signature is already wired:

1. Build for device/simulator on iOS 14+ (CLAUDE.md §Building & Running).
2. Launch; `CreateSession` is called with the documented trial signature plus the bundled `OCRStudioSDKCore/config/*.ocr`.
3. Session is created successfully → `ProcessImage` works on the sample document. **This is the vulnerable observable behavior** — the signature is a static string, so the same string in a second unrelated IPA would also produce a session.

### 5.5 Validation steps

| Step | Command | Pass criterion |
|------|---------|----------------|
| 1 | `python research/verify_static_auth_poc.py` | `result : PASS`, exit 0 |
| 2 | `python research/verify_static_auth_poc.py --self-test` | `result : PASS`, exit 0 |
| 3 | `python research/verify_static_auth_poc.py --signature <1-nibble-flip>` | `result : FAIL`, exit 1 |
| 4 | `python research/check_binary_poc.py` | `ALL MATCH`, exit 0 |
| 5 | Build sample app, run `CreateSession(trial_sig)` | session created, ProcessImage succeeds |
| 6 | Clone trial sig into a fresh unrelated project linking the same xcframework | session created (confirms T1) |

### 5.6 Cleanup

No persistent state is created. Remove research scratch (`%TEMP%\kilo\*`) if any were generated during the session. The shipped `.a` is not modified by any of these scripts — the PoC is **read- ** against the library.

---

## 6. Complete Patch

> **Scope note:** Iron Software / OCR Studio owns the binary. This section specifies the remediation design the vendor should implement. We provide reference Swift-side integration and a reference server-side mint; the C++ core changes are a detailed engineering spec, not a patch we can ship.

### 6.1 Architecture improvements

| Layer | Change |
|-------|--------|
| **C++ core** | Upgrade scheme; multi-site verification; code-hash of verify region; version the `__const` blob |
| **ObjC++ wrapper** | Expose a new `CreateSessionHardened(signature, tokenJWT, params)` entry; retain `CreateSession` for compatibility window   |
| **Swift layer** | Reference wrapper `HardenedAuthWrapper` fetches short-lived server JWT and passes it into `CreateSessionHardened` |
| **External** | Vendor Auth Server issues Ed25519-signed JWTs bound to build_id + config_sha256 + expiry + nonce |

### 6.2 Secure authorization design (post-patch)

#### 6.2.1 Cryptographic upgrade (P0)

Replace the shipped scheme:

| Property | Today | Target |
|----------|-------|--------|
| Scheme | RSA-1024 PKCS#1 v1.5 (raw SHA-1, no DigestInfo) | **Ed25519** with SHA-512 / 32-byte signatures |
| Public key size | 128-byte modulus + 4-byte e | 32-byte Ed25519 public key |
| Signature size | 128-byte (256 hex) | 64-byte (128 hex) |
| Hash | SHA-1 (raw, 20 B) | SHA-512 internally (Ed25519 standard) |
| Padding | Custom PKCS#1 v1.5 without OID | Ed25519 (no padding concerns) |
| Keygen source | `/dev/urandom` via `std::random_device` → `mt19937`-seeded → `br_rsa_keygen(1024, 3)` (CLAUDE.md §License §Vendor) | libsodium / TweetNaCl-style Ed25519 keygen with strong CSPRNG |

#### 6.2.2 Structured signed claims (P1)

JWT payload (canonical):

```json
{
  "sub": "ocrstudio_arafatgroup_trial",
  "lib_build_id": "1.3.1-ios-arm64-trial-2026Q3",
  "platform": "ios",
  "config_sha256": "c9d1…4a22",
  "iat": 1721234567,
  "exp": 1721320967,
  "nonce": "a3f1bc9e-…",
  "aud": "ocrstudio-sdk"
}
```

The SDK verifies all fields: `sub` must match the baked client-id; `lib_build_id` must match the baked build-id; `config_sha256` must match `SHA-256(config/*.ocr)`; `exp` must be in the future; `nonce` must not be in the LRU.

#### 6.2.3 Server-delivered short-lived tokens (P2)

- Host app contacts vendor server at session-creation time.
- Server issues JWT with `exp = now + 24h` (configurable per SKU).
- SDK refuses session when `exp < now`.
- High-value SKUs additionally call `heartbeat` every N minutes; SDK aborts session if heartbeat fails for >M minutes (optional; offline SKUs skip this).

#### 6.2.4 Integrity / anti-patch (P3)

- **Code-region hash:** at init, SDK computes `SHA-256` of the `.text` region spanning `VSA` through `pkcs1_verify`. The hash is baked into the `__const` blob; mismatch → abort. Rotates with every build.
- **Multi-site verify:** distribute the auth boolean across ≥3 separate functions in ≥3 translation units to force multiple patch points.
- **`VCIH` hardening:** `VCIH()` must compute a hash of the verify-region code and of the `__const` blob, not   the client-id string.

### 6.3 Corrected authorization flow

See §3.2. Flow:

1. Host app fetches short-lived JWT from vendor server (signed with Ed25519).
2. Host app passes `(legacy_sig[256hex], jwt, params)` to `CreateSessionHardened`.
3. SDK:
   a. Runs legacy `VSA(legacy_sig)` as a smoke-test (reject obviously-bad payloads early).
   b. Runs `HardenedAuth.verify(jwt)`:
      - Ed25519 signature OK?
      - `sub`, `lib_build_id`, `platform`, `config_sha256`, `exp`, `nonce` all valid?
      - Nonce fresh (not in LRU)?
   c. Computes code-region hash; compares to baked value.
   d. Runs `VCIH()` (hardened variant — also covers verify-region code + const blob).
4. Session created   if **all four gates** pass.

### 6.4 Server-side mint (reference)

See `verification/reference_server_mint.py`. Reference Ed25519 JWT mint endpoint:

- Endpoint: `POST /attest {app_id, build_id, device_nonce, config_sha256}`
- Response: `{ jwt, iat, exp }`
- Server holds Ed25519 private key in HSM/KMS; signs with `iat`/`exp`/claims; returns JWT to app.

### 6.5 Client-side changes (reference)

See `verification/Sources/HardenedAuth/HardenedAuthWrapper.swift`. Reference Swift wrapper:

- Fetches JWT from vendor server on cold start and caches until `exp`.
- Re-signs request with `device_nonce` to prevent server-MITM.
- Passes JWT to `CreateSessionHardened`.
- Surfaces `SessionAuthorizationError` to host app for any gate failure.

### 6.6 Updated interfaces (Objective-C++)

```objc
// OCRStudioSDKSession+Hardened.h
typedef NS_ENUM(NSInteger, OCRAuthGateStatus) {
    OCRAuthGateStatusOK              = 0,
    OCRAuthGateStatusLegacyFail      = 1,
    OCRAuthGateStatusJWTSignatureBad = 2,
    OCRAuthGateStatusJWTExpired      = 3,
    OCRAuthGateStatusBuildMismatch   = 4,
    OCRAuthGateStatusConfigMismatch  = 5,
    OCRAuthGateStatusNonceReused     = 6,
    OCRAuthGateStatusCodeHashBad     = 7,
    OCRAuthGateStatusVCIHFail        = 8,
};

@interface OCRStudioSDKSession (Hardened)
+ (nullable instancetype)createSessionHardenedWithSignature:(NSString *)legacySig
                                                attestation:(NSString *)jwt
                                                     params:(NSString *)paramsJSON
                                                 gateStatus:(OCRAuthGateStatus *)outStatus
                                                      error:(NSError **)error;
@end
```

### 6.7 Updated data models

```swift
public struct OCRAttestationClaims: Codable {
    public let sub: String                  // client-id marker
    public let lib_build_id: String         // e.g. "1.3.1-ios-arm64-trial-2026Q3"
    public let platform: String             // "ios"
    public let config_sha256: String        // hex
    public let iat: Int                     // epoch seconds
    public let exp: Int                     // epoch seconds
    public let nonce: String                // UUID-format
    public let aud: String                  // "ocrstudio-sdk"
}
```

### 6.8 Validation logic

- `exp > now`; reject with `.JWTExpired`.
- `sub == baked client_id`; implicit via `lib_build_id` match.
- `lib_build_id == baked build_id`; if not, `.BuildMismatch`.
- `config_sha256 == sha256(config file on disk)`; if not, `.ConfigMismatch`.
- Ed25519 signature valid over header.payload; if not, `.JWTSignatureBad`.
- `nonce` not in LRU cache (LRU size ≈ 1,000,000 entries, evicting oldest); if reused, `.NonceReused`.
- Code-region hash matches baked; if not, `.CodeHashBad`.
- VCIH passes (hardened variant); if not, `.VCIHFail`.

### 6.9 Secure state management

- Nonce LRU: in-memory, cleared on process restart (acceptable — server JWT is short-lived, so post-restart nonces are already expired).
- Attestation JWT cache: stored in iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDevice `) to survive background transitions but NOT iCloud backup.
- No persistence of secrets to disk outside Keychain.

### 6.10 Replay protection

- Nonce bound to (device_id, lib_build_id) tuple.
- Server-side: nonce DB with TTL = max(jwt_exp - jwt_iat) + drift.
- Client-side: LRU cache rejects any nonce it has seen in the process lifetime.
- Timestamp bound: reject tokens older than `now - 60s` and newer than `now + 300s` (clock skew tolerance).

### 6.11 Ownership verification

`sub == "ocrstudio_arafatgroup_trial"` AND `lib_build_id` must match the baked build-id. Together these assert that the token was minted *for this specific customer and this specific build*.

### 6.12 Error handling

All gate failures map to the `OCRAuthGateStatus` enum above. Host app receives a single `(session, status, error)` tuple; `status != 0` means the session was **not** created and `error` carries a localized description safe for crash-reporting (no secrets, no signatures).

### 6.13 Backward compatibility

- **Phase 1 (0–3 months):** ship hardened path as opt-in via new `CreateSessionHardened` entry; original `CreateSession` keeps working (legacy customers have transition window).
- **Phase 2 (3–6 months):** legacy `CreateSession` logs a deprecation warning and rejects tokens older than Phase-1 mint date.
- **Phase 3 (6+ months):** legacy entry retired;   hardened path accepted.
- Server returns HTTP 410 Gone for legacy mint requests after Phase 3.

---

## 7. Updated Source Code

> **Source of truth:** the authoritative JWT wire contract, baked constants, verifier gate order, and hard-won build/validation notes for these artifacts live in **`CLAUDE.md` § Hardened-Auth Reference Package**. The rows below are a pointer only — do not duplicate contract details here.

Reference implementations live in `research/verification/`:

| File | Description |
|------|-------------|
| `HardenedAuthWrapper.swift` | Client-side Swift wrapper: JWT fetch + cache + dispatch to `CreateSessionHardened` |
| `OCRAuthHardenedTests.swift` | XCTest suite proving vuln-before-patch and absence-after-patch |
| `reference_server_mint.py` | Server-side Ed25519 JWT mint reference (Python/Flask) |

The C++ core changes are an engineering spec (§6.1, §6.2) —   the vendor can modify the shipped `ocrstudiosdk.xcframework`.

---

## 8. Test Suite

See `research/verification/Tests/HardenedAuthTests/OCRAuthHardenedTests.swift`.

### 8.1 Coverage matrix

| Test | Status pre-patch | Status post-patch | Threat class addressed |
|------|------------------|-------------------|------------------------|
| `testTrialSignatureAccepted` | PASS (vuln) | FAIL (legacy gate alone insufficient without JWT) | T1 |
| `testTamperedSignatureRejected` | FAIL (good) | FAIL (good) | — |
| `testStolenSignatureAcrossApps` | PASS-on-both (vuln) | FAIL-on-app-B (build_id mismatch) | T1, T4 |
| `testExpiredAttestationRejected` | N/A | PASS | T1 replay |
| `testBuildIdMismatchRejected` | N/A | PASS | T4 |
| `testConfigHashMismatchRejected` | N/A | PASS | T4 |
| `testNonceReplayRejected` | N/A | PASS | T1 replay |
| `testJWTSignatureForgeRejected` | N/A | PASS | T3 |
| `testCodeRegionPatchDetected` | N/A | PASS | T2 |
| `testVCIHFailOnConstBlobTamper` | N/A | PASS | T2 |
| `testClockSkewTolerance` | N/A | PASS | — |
| `testBackwardCompat_LegacyPathStillAcceptsValidLegacySig` | PASS | PASS (during Phase 1) | — |
| `testOfflineFallback` | — | Configurable: offline SKUs skip JWT | — |
| `testEmptySignatureRejected` | FAIL (CBZ null-check) | FAIL (good) | — |
| `testMalformed256HexRejected` | FAIL (bad PKCS#1 header) | FAIL (good) | — |

### 8.2 Negative / edge cases (all post-patch)

- **Malformed JWT (header/payload):** `.JWTSignatureBad`.
- **Wrong `aud`:** `.JWTSignatureBad` (aud is covered by Ed25519 sig).
- **Future `exp` beyond 48h cap:** `.JWTExpired` (cap prevents overlong tokens).
- **`lib_build_id` missing:** `.BuildMismatch`.
- **`config_sha256` shorter than 64 hex chars:** `.ConfigMismatch`.
- **Server unreachable (offline SKU configured):** graceful fallback to legacy path with telemetry.
- **Device clock set to 1970:** reject tokens with `iat < 2026-01-01` anchor.

---

## 9. Security Verification

### 9.1 Why the patch is effective

| Threat | Pre-patch | Post-patch | Why patch blocks it |
|--------|-----------|------------|---------------------|
| T1 — sig theft | Sig alone → session | Sig + JWT (build-bound, short-lived) | Stolen sig + stale JWT → `.JWTExpired` or `.BuildMismatch` |
| T2 — binary patch | One 2-B branch or 20-B blob → bypass | 4 gates (legacy, JWT, code-hash, VCIH-code); single patch no longer enough | Attackers must patch ≥4 sites across ≥3 translation units AND defeat code-hash binding |
| T3 — crypto weakness | RSA-1024/e=3/SHA-1/raw-PKCS#1 | Ed25519 + SHA-512 | 128-bit security level, no padding surface, no weak modulus |
| T4 — weak binding | `SHA-1(client_id)`   | JWT with (sub, lib_build_id, platform, config_sha256, exp, nonce, aud) | Signature now carries structured claims that lock it to build, config, and time |

### 9.2 Defense-in-depth summary

1. **Crypto** — Ed25519 is 128-bit secure, modern, and padding-free.
2. **Claims** — Structured JWT binds the auth to build, config, platform, and expiry.
3. **Online attestation** — Short-lived JWT means a stolen token is worthless after `exp`.
4. **Code-region hash** — Raising cost of static binary patch.
5. **Multi-site verify** — Forces ≥3 patches across multiple translation units.
6. **Nonce** — Replay protection both client (LRU) and server (TTL DB).

---

## 10. Residual Risks

| Risk | Reason | Mitigation |
|------|--------|------------|
| Patcher with write-access to shipped binary can still bypass auth | Code-region hash is just a higher bar, not a silver bullet | P3 mitigations + assume-breach: require server heartbeat for high-value SKUs |
| Server outage blocks session creation | Online attestation needs network | Configurable offline fallback per SKU; Phase-1 ships hardened path as opt-in   |
| Private key compromise on vendor server | Ed25519 key must live in HSM/KMS; rotation plan required | Key-rotation: bake *next* public key into every build; on revocation, old key stops being accepted after `exp` window drains |
| Clock skew on device | Token `exp` may be in the future relative to server | 300-second skew tolerance baked in |
| Legacy customer migration friction | Some customers rely on static sig | Phase-1/2/3 rollout (see §6.13) |
| `VCIH` twin still lives in same .cpp.o | Single TU still patchable as unit | Split across TUs in next release |

---

## 11. Hardening Recommendations

See `research/VENDOR_HARDENING.md` for the full mitigation backlog and patch-resistance testing guide. Summary priority:

| Priority | Action |
|----------|--------|
| **P0** | Upgrade crypto: Ed25519 (or RSA-2048+ with `e=65537` + SHA-256 + RSA-PSS); version the `__const` auth blob; refuse to load old blobs. |
| **P1** | Structured signed claims: client_id + `lib_build_id` + `config_sha256` + `platform` + expiry window. Mismatch → reject session. |
| **P2** | Server-issued short-lived JWTs for production; separate trial vs production keypairs; rotate trial keys per customer build. |
| **P3** | Multi-site verify; code-region hash binding; `VCIH` hardened to cover verify-region code + const blob; assume binary patching will be attempted and test for it (see `VENDOR_HARDENING.md` §Patch resistance — testing guide, TR-01…TR-11). |

**Patch-resistance test guide (vendor QA)** — the vendor MUST execute the TR-01…TR-11 intents listed in `VENDOR_HARDENING.md` before shipping the hardened build. The test intents include: flipping the VSA-tail branch, overwriting EXPECTED_HASH, bypassing `pkcs1_verify`'s `CMP_reg`, re-running VCIH against an unmodified blob, and injecting a fake code-region hash.

---

## Appendix A — Reproduction checklist

Vendor QA should run the following in order, from a clean working tree:

1. `python -V` — Python 3.10+
2. `pip install cryptography Flask PyNaCl PyJWT`
3. `python research/verify_static_auth_poc.py` — **PASS**, exit 0
4. `python research/verify_static_auth_poc.py --self-test` — **PASS**, exit 0
5. `python research/verify_static_auth_poc.py --signature <1-nibble-flip>` — **FAIL**, exit 1
6. `python research/check_binary_poc.py` — **ALL MATCH**, exit 0
7. `xcodebuild -project Samples/Swift/OCRStudioSDKSample/OCRStudioSDKSample.xcodeproj -scheme OCRStudioSDKSample` — builds clean
8. Run sample app on simulator → session created with trial signature (vuln observable)
9. Run `xcodebuild test -scheme OCRAuthHardenedTests` — pre-patch tests: **T1 tests PASS (i.e., vuln demonstrable)**, post-patch tests: **SKIP** until hardened library shipped
10. After vendor ships hardened library: re-run step 9 — **all post-patch tests PASS**

## Appendix B — Assumptions clearly labeled

| # | Assumption | Rationale |
|---|-----------|-----------|
| A1 | Vendor Auth Server will be added for production SKUs | Needed for online attestation (§6.2.3). Trial/offline SKUs can opt out (configurable). |
| A2 | Ed25519 chosen over RSA-PSS | Smaller key, smaller sig, no padding concerns, well-supported on modern BearSSL alternatives (e.g., HACL*, libsodium). Vendor may choose RSA-PSS instead; claims structure remains the same. |
| A3 | iOS Keychain chosen for JWT cache | Standard secure-storage primitive; survives background, not iCloud backup. |
| A4 | Nonce LRU size 1,000,000 covers burst usage | Empirical; tune based on per-app session volume. |
| A5 | 24-hour JWT lifetime is the default | Configurable per SKU; shorter lifetimes reduce replay window at cost of server load. |

All other facts in this document are **confirmed from binary / source evidence** (CLAUDE.md §License, §Disclosure, `VERIFY_PATH_MAP.md`, `verify_static_auth_poc.py`).

---

*End of validation package.*
