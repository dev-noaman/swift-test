# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCRStudioSDK is an iOS framework for optical character recognition and document processing. Version 1.3.1 is a trial/research release that includes a native C++ engine with Objective-C++ wrappers and Swift bindings.

**Authorization Note:** This repository contains an official authorization document (`Official Authorization for Security Research_ocrstudio.pdf`) granting explicit permission for security research and testing activities. DocuSign envelope `E86EA6F7-B675-8E96-8194-18360D9FF672` (valid 13 July 2026 – 30 July 2026).

**Security disclosure source of truth:** The formal assessment disclosure (threats, remediations, evidence, confidentiality) lives in this file under [Security Assessment Disclosure](#security-assessment-disclosure-source-of-truth). Do not treat `research/DISCLOSURE_REPORT.md` as authoritative — it is a stub that points here.

## Architecture

The SDK uses a three-layer architecture:

1. **C++ Core Layer** (`OCRStudioSDKCore/`): Contains the main recognition engine
   - Located in `OCRStudioSDKCore/include/ocrstudiosdk/` with headers for core classes
   - Uses namespace `ocrstudio::` for all C++ types
   - Compiled as xcframework bundle at `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework`

2. **Objective-C++ Wrapper Layer** (`OCRStudioSDKCore/wrap/objcocrstudiosdk/`)
   - Bridges C++ engine to Objective-C runtime
   - Classes prefixed with `OCRStudioSDK` (e.g., `OCRStudioSDKInstance`)
   - Implementation files in `include_impl/` directory contain proxy classes wrapping C++ objects

3. **Swift Layer** (`OCRStudioSDK/`)
   - High-level iOS framework components
   - UI controllers: `OCRStudioSDKViewController`
   - Helper classes for camera management, video preview, UI elements
   - Uses `OCRStudioSDK-Bridging-Header.h` to expose Objective-C++ to Swift

## Core API Components

### Main Classes (Objective-C++/C++)

- **OCRStudioSDKInstance** (`ocr_studio_instance.h`): Factory for creating recognition sessions
  - `CreateFromPath()` - Load engine from `.ocr` config file
  - `CreateFromBuffer()` - Load from in-memory config
  - `CreateStandalone()` - Use embedded config if available
  - Supports lazy/delayed initialization via JSON params

- **OCRStudioSDKSession** (`ocr_studio_session.h`): Main recognition interface
  - `ProcessImage()` - Process single image
  - `ProcessData()` - Process structured data (e.g., RFID data)
  - `CurrentResult()` - Retrieve recognition results

- **OCRStudioSDKImage** (`ocr_studio_image.h`): Image container
  - `CreateFromFile()` - Load from file path
  - Used as input to recognition sessions

- **OCRStudioSDKResult** (`ocr_studio_result.h`): Output container
  - `TargetsCount()` / `TargetByIndex()` - Access recognized document types
  - `AllTargetsFinal()` - Check if recognition completed

- **OCRStudioSDKDelegate** (`ocr_studio_delegate.h`): Optional callbacks during processing

### Session Configuration

Sessions are created with JSON parameters specifying:
- `session_type`: `"document_recognition"`, `"video_recognition"`, `"video_authentication"`, or `"face_matching"`
- `target_group_type`: Engine variant (typically `"default"`)
- `target_masks`: Document types to recognize (supports wildcards, e.g., `"*.id.*"`)
- `output_modes`: Optional output (e.g., `"character_alternatives"`, `"field_geometry"`)
- `options`: Overrides (e.g., `"enableMultiThreading"`, `"sessionTimeout"`)

Example session params in `Samples/Swift/OCRStudioSDKSample/OCRStudioSDKSampleViewController.swift` show iOS-specific usage.

## Signature Requirement

All sessions require a **personalized signature** (256-character hex string) passed to `CreateSession()`. This signature is validated offline and locks to the engine library copy. The trial signature is embedded in `doc/README.md`. Store signatures in code, not asset files; production deployments should load via secure server channel.

## License / Signature Validation Flow (Reverse-Engineered)

> Recovered under the security-research authorization (`Official Authorization for Security Research_ocrstudio.pdf`) by static analysis of `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework/ios-arm64_armv7_armv7s/libocrstudiosdk-ios.a` in Ghidra. Recovered artifacts live in `research/`.

**Summary:** The 256-hex-char signature is an **RSA-1024 PKCS#1 v1.5 signature** verified fully offline against a public key baked into the library. Crypto is **BearSSL**; the security code lives in the C++ namespace `se::security` (Smart Engines — the OEM behind OCR Studio / SmartID).

### Object files that implement it (in the static lib)

| Object | Mangled symbol | Role |
|--------|----------------|------|
| `static_auth.cpp.o` | `se::security::internal::VSA(const char*)` | **Entry point** — verifies the signature (Verify Static Auth) |
| `static_auth.cpp.o` | `se::security::internal::VEA(const char*, const unsigned char*)` | Same but caller supplies the expected hash |
| `static_auth.cpp.o` | `se::security::internal::VCIH()` | Integrity self-check (Verify Code Integrity Hash) |
| `verify.cpp.o` | `se::security::pkcs1_verify(const char*, const unsigned char*, const unsigned char*)` | RSA PKCS#1 verify core |
| `hashing.cpp.o` | `se::security::get_hash(...)` | SHA-1 (`br_sha1_*`) |
| `sign.cpp.o`, `activation.cpp.o`, `keypair_generation.cpp.o` | — | Marker/activation generation (RSA-OAEP, `CreateMarker`) — not on the verify path |

### The verify logic (decompiled)

```c
// VSA — what CreateSession ultimately calls
void VSA(const char* signature) {
    if (signature) pkcs1_verify(signature, PUBKEY /*__const+0x00*/, EXPECTED_HASH /*__const+0xAF*/);
}

// pkcs1_verify
hexstring_to_bytes(sigbuf, signature, 256);              // 256 hex chars -> 128-byte signature
vrfy = br_rsa_pkcs1_vrfy_get_default();
vrfy(sigbuf, 128, NULL, 20 /*SHA-1*/, &pubkey, &recovered_digest);
return (recovered_digest == *EXPECTED_HASH);             // 20-byte compare
```

`pubkey` is a BearSSL `br_rsa_public_key { n, nlen=128, e, elen=4 }`.

### Embedded constants (from the `__const` blob at file offset `0xe4`)

- **RSA modulus `n`** (128 bytes): `aa81d3f7eb1996c8ffd6d119451d60554d1d2924d2a6fd8e035dff9fcf29b3d59046835374fab7dfa823c02c4f553ebe21e34277aa12c1cbf1df3e18d6e1eea676f1628520b80db807e8b1a911c19797b7cd4c3c66eab2dab0daaafbe765c372b62d0825b8e2023a1fd2e88a22df338fa2e267a67bbf89613ac1d836cea1bf39`
- **RSA exponent `e` = 3** (`00 00 00 03`)
- **Licensed client-id marker** (embedded string): `se_client_id__ocrstudio_arafatgroup_trial`
- **Expected SHA-1 digest** (`__const+0xAF`, 20 bytes): `25159e611dfa6f5f077a732a01d17ead8cc9770b` = `SHA-1("ocrstudio_arafatgroup_trial")`
- `VCIH()` recomputes `SHA-1("ocrstudio_arafatgroup_trial")` (27 bytes) and compares against the **same** hardcoded constant — a tamper check tying the config to this licensed build.

### What "locks to the library copy" means

OCR Studio signs `SHA-1(client_id)` with their **private** RSA key. The library embeds the matching **public** key + expected digest. A signature verifies only if BearSSL recovers exactly `SHA-1("ocrstudio_arafatgroup_trial")` from it. This is a pure offline attestation — no network. (`e=3` + SHA-1 is cryptographically weak by modern standards, but forging still requires either the private key or a PKCS#1 padding forgery — do not attempt; out of scope.)

### Recovered public key

`research/ocrstudio_pubkey_pkcs1.pem` (PKCS#1) and `research/ocrstudio_pubkey_spki.pem` (X.509 SubjectPublicKeyInfo). Inspect with `openssl rsa -pubin -in research/ocrstudio_pubkey_spki.pem -text -noout`.

### Marker / activation-data generation (vendor side)

`keypair_generation.cpp.o` contains the OEM's license-minting toolkit (not used at runtime by the shipped verify path, but it reveals the whole scheme). Decompiled functions in `se::security`:

| Function | Behaviour |
|----------|-----------|
| `generate_key_pair(seed1, seed2, out priv[320], out pub[132])` | If no seed given, reads **`/dev/urandom`** via `std::random_device` → 4×uint32 → `seed_seq` → `mt19937` → `gen_string(10)` (10-char random seed). Then `br_hmac_drbg_init(SHA-1, seed)` and **`br_rsa_keygen(..., 1024, 0)`** (RSA-1024, default exponent 3). |
| `CreateMarker(id)` | Returns `"\0" + "se_client_id__" + id + "\0"`. This is the marker whose SHA-1 is the signed payload. |
| `CreateStaticAuthData(pub[132], marker, hash[20])` | Concatenates `pub(132) ‖ marker ‖ hash(20)` → **the exact `__const` blob** embedded in `static_auth.cpp.o` and consumed by `pkcs1_verify`. |
| `CreateActivationData(priv[320], id)` | `priv(320) ‖ id`. |
| `CreateActivationDataHex(priv[320])` | `bytes_to_hexstring(priv, 320)` = **640 hex chars** — the vendor's secret "activation data". |
| `check_key_pair(priv, pub)` | RSA-OAEP encrypt (pub) / decrypt (priv) roundtrip of test string `"a1B_&"`, `memcmp` — keypair-consistency check. |
| `pkcs1_sign(out_hex, hash[20], priv[320])` (`sign.cpp.o`) | Builds `br_rsa_private_key` from the 320-byte buffer as **5 CRT params p,q,dp,dq,iq (64 bytes each)**, `br_rsa_pkcs1_sign(SHA-1)`, hex-encodes → **256 hex chars** = the customer signature. |

**Key-material sizes (important):**
- **320-byte "activation data" = RSA-1024 private key** — 5 CRT components × 64 bytes (`p, q, dp, dq, iq`). Secret; the vendor keeps it. `CreateActivationDataHex` → 640-hex string.
- **132-byte "static auth key" = RSA-1024 public key** — modulus (128) + exponent (4). Public; embedded in the shipped library.

### End-to-end license lifecycle

```
VENDOR (offline, once per client)                         CLIENT (shipped library, runtime)
────────────────────────────────────────                 ─────────────────────────────────────────
generate_key_pair()  ->  priv[320], pub[132]
marker  = CreateMarker(client_id)                         CreateSession(signature)
hash    = SHA-1(marker)          [20 bytes]                 -> VSA(signature)
static  = CreateStaticAuthData(pub, marker, hash) ──embed──>  -> pkcs1_verify(signature, pub@const, hash@const)
signature = pkcs1_sign(hash, priv)  [256 hex] ──give to──>       recovered = RSA_pub(signature)   [SHA-1]
activation_hex = hex(priv)  [640 hex, SECRET]                    return (recovered == embedded hash)
                                                          VCIH(): SHA-1(marker) == embedded const (tamper check)
```

The signature is thus OCR Studio's RSA-1024 signature over `SHA-1("se_client_id__<client_id>")`. Only the holder of the 320-byte private "activation data" can mint valid signatures. **Crypto is dated (RSA-1024, e=3, SHA-1) but forging still requires the private key or a padding-forgery attack — out of scope; documented for understanding only.**

## Reverse-Engineering Workflow (hard-won lessons)

Tooling notes for continuing binary analysis of this SDK — these cost real time to figure out:

- **This is native ARM64 Mach-O, not .NET.** Use **Ghidra**, not ILSpy/dnSpy (those are for CIL/managed assemblies and will not open these `.a` files).
- **Do NOT import the 184 MB fat static library whole** — it has **2787 member objects** and Ghidra auto-analysis on it is impractical. Instead, carve out the handful of relevant sub-2 KB object files and import only those arm64 slices. The parser scripts are in the session scratchpad (`ar_parse.py`, `extract.py`, `make_pem.py`).
- **No binutils in this environment** (no `nm`/`objdump`/`lipo`/`strings`, no `openssl` guaranteed). Python 3.10 is at `C:\Users\NN\AppData\Local\Programs\Python\Python310\python.exe`. The `ar` + Mach-O + ASN.1/DER parsing was all done in pure Python.
- **Locate targets by member-object name first.** Grepping the 2787 `ar` member names for `sign|licen|auth|verif|crypt|hash|activ` instantly surfaces `static_auth.cpp.o`, `verify.cpp.o`, `activation.cpp.o`, etc. — far faster than symbol-diving.
- **Apple `ar` uses the BSD variant**: long names are stored inline as `#1/<len>` immediately after the 60-byte header; account for that when computing the member data offset/size.
- **Imported relocatable `.o` files show `function_count: 0`.** Ghidra's Mach-O loader places code in an overlay and does not auto-create functions. You must `create_function` at each symbol address (get them from `get_entry_points`) **before** `decompile_function` returns anything.
- **Ghidra MCP connection:** `list_instances` returned empty even with Ghidra open; `connect_instance("ocrstudio")` succeeded via the **TCP fallback** at `http://127.0.0.1:8089`. If discovery shows no instances, just call `connect_instance` with the project name directly.
- **Relocation-resolved pointer args** (e.g. `pkcs1_verify(sig, 0xe4, 0x193)`) point into the `__const` section; read those addresses with `read_memory` to dump embedded keys/hashes. Offsets are relative to the const section base (`0xe4` here).

## Hardened-Auth Reference Package (source of truth)

> Reference remediation artifacts implementing the P0–P3 hardening design. The narrative package `research/VALIDATION_PACKAGE.md` defers to **this section** as source of truth. Artifacts live in `research/verification/`. **These are reference/spec code, NOT shipped SDK code** — `CreateSessionHardened` does not exist in the trial xcframework; the wrapper is written against protocols so the vendor can drop in the real ObjC++ entry.

### Artifacts (`research/verification/`)

| File | Role |
|------|------|
| `reference_server_mint.py` | Vendor-side Ed25519 attestation-JWT mint (`--gen-key` / `--mint` / `--serve`). PyNaCl, manual JWT. |
| `Sources/HardenedAuth/HardenedAuthWrapper.swift` | Client wrapper + four-gate `HardenedAuthVerifier` (CryptoKit `Curve25519.Signing`), `NonceLRU`, Keychain token cache. |
| `Tests/HardenedAuthTests/OCRAuthHardenedTests.swift` | XCTest suite for the §8 coverage matrix; mints tokens in-process with a pinned CryptoKit key. |
| `Package.swift` | SwiftPM package — `cd research/verification && swift test` (Codemagic workflow `hardened-auth-tests`). |

### Attestation JWT wire contract (MUST match across Python mint ↔ Swift verify)

- Compact JWS, `alg="EdDSA"`; header is **exactly** `{"alg":"EdDSA","typ":"JWT"}`.
- `signing_input = base64url(header) + "." + base64url(payload)` — base64url, **no `=` padding**.
- Signature = **raw 64-byte Ed25519** over the **ASCII** bytes of `signing_input` (not DER, no JOSE-lib wrapping).
- `jwt = signing_input + "." + base64url(signature)`.
- Python signs with **PyNaCl `SigningKey`** (chosen over PyJWT for byte-exactness). Swift verifies with CryptoKit `publicKey.isValidSignature(sig, for: signingInputASCII)`.
- Claims (8, this order): `sub, lib_build_id, platform, config_sha256, iat, exp, nonce, aud`. Decode is by name (JSONDecoder), so emit order only affects the signed bytes, not parsing.

### Baked policy constants (reference build)

| Field | Value |
|-------|-------|
| `sub` / client-id | `ocrstudio_arafatgroup_trial` |
| `lib_build_id` | `1.3.1-ios-arm64-trial-2026Q3` |
| `platform` / `aud` | `ios` / `ocrstudio-sdk` |
| `config_sha256` | lowercase hex `SHA-256(config/*.ocr)` |
| Max token lifetime | 48 h hard cap (`exp − iat`) |
| Clock-skew tolerance | ±300 s |
| `iatFloor` | `1767225600` = 2026-01-01Z — reject older `iat` |

**Gotcha:** the `iat 1721234567` example in `VALIDATION_PACKAGE.md` §6.2.2 is actually **2024-07-17** (illustrative only, and *below* `iatFloor`). The test suite uses a deterministic clock `now = 1784332800` (2026-07-18Z).

### Verifier gate order (`HardenedAuthVerifier.verify` — do not reorder)

1. Ed25519 signature over `header.payload`
2. temporal: `iat ≥ iatFloor`, `iat ≤ now+skew`, `exp > now−skew`, `(exp−iat) ≤ 48h`
3. identity: `aud`, `sub`, `platform`, `lib_build_id`, `config_sha256`
4. nonce replay (`NonceLRU`, ~1e6 entries)
5. integrity: code-region hash, then hardened `VCIH`

Result maps to `OCRAuthGateStatus { ok=0, legacyFail, jwtSignatureBad, jwtExpired, buildMismatch, configMismatch, nonceReused, codeHashBad, vcihFail }` (mirrors the ObjC `NS_ENUM` in `VALIDATION_PACKAGE.md` §6.6).

### Validation (hard-won)

- Mint + JWT contract need **no Xcode**:
  ```bash
  PY="C:\Users\NN\AppData\Local\Programs\Python\Python310\python.exe"
  "$PY" research/verification/reference_server_mint.py --gen-key --seed <64-hex>
  "$PY" research/verification/reference_server_mint.py --mint --priv <64-hex> --config-sha256 <64-hex> --now <epoch>
  ```
- **Swift will not compile on this Windows host.** Run XCTest on Codemagic (`codemagic.yaml` → workflow `hardened-auth-tests`) or any Mac: `cd research/verification && swift test`. The Python↔Swift contract was also proven by reimplementing the verifier's steps in Python (PyNaCl) against a minted token. A green run against a *shipped* hardened library (`VALIDATION_PACKAGE.md` Appendix A steps 9–10) still requires the vendor binary — do not claim that passed here.
- `reference_server_mint.py` depends on **Flask + PyNaCl** (not PyJWT, despite Appendix A step 2 listing it). Deterministic keygen/mint via `--seed` / `--now` for reproducible tests.

## Building & Running

### Sample iOS App

The repository includes a complete Swift sample app at `Samples/Swift/OCRStudioSDKSample/`:
- Open `OCRStudioSDKSample.xcodeproj` in Xcode
- Requires iOS 14+ (iOS 15+ for RFID/NFC features)
- Uses `UIImagePickerController` for photo library access and live camera capture
- Main controller: `SampleViewController` (extends `UIViewController`, conforms to `OCRStudioSDKInitializationDelegate`)

### Configuration Files

Training/config files (`.ocr` format) are required for engine initialization. These are project-specific and must be provided separately. Load via `OCRStudioSDKInstance::CreateFromPath()`.

### RFID/NFC Support (iOS 15+)

The SDK supports reading NFC passports and identity documents:
- Requires `#if __RFID__` compile flag to enable
- Uses external `NFCPassportReader` library (via SPM/CocoaPods)
- Requires entitlements: `com.apple.developer.nfc.readersession.iso7816.select-identifiers` in Info.plist
- NFC workflow: scan document → read NFC chip → compare data for fraud detection
- Classes: `PassportData`, `PassportKey`, `PassportReader` for NFC handling

## Memory Management

**C++ Layer**: Factory methods return heap-allocated objects; use `std::unique_ptr<T>` for automatic cleanup.

**Objective-C++ Layer**: Same as C++; wrapper objects manage underlying C++ lifetime.

**Swift Layer**: Objective-C++ objects are reference-counted by ARC, but manually call `.delete()` on large wrapped objects (image, instance, session) when done to ensure timely deallocation of underlying C++ heap memory. The garbage collector may not see the large native allocations.

## Testing & Verification

- No test framework included in trial distribution
- Sample app is the primary integration test
- UI testing would require device or simulator with camera permissions
- Core C++ engine tests are internal (not included)

## Security Notes

- Signatures contain personalized tokens and must be kept confidential
- Configuration files are proprietary binary format
- RFID/NFC operations involve sensitive document data
- All operations are performed on-device; no external API calls required
- Formal disclosure, threat classes, and remediation summary: [Security Assessment Disclosure](#security-assessment-disclosure-source-of-truth) below
- Detailed OEM mitigation backlog / patch-resistance test guide: `research/VENDOR_HARDENING.md`
- Verify-path symbol map: `research/VERIFY_PATH_MAP.md`

## Security Assessment Disclosure (source of truth)

> Canonical copy of the confidential security assessment formerly maintained in `research/DISCLOSURE_REPORT.md`. Edit **only this section** (and the License / Signature Validation Flow section above) when disclosure facts change. Supporting artifacts remain under `research/` (PoC, keys, hardening, verify-path map).

**Classification:** Confidential — for Iron Software / OCR Studio Security Team only  
**Prepared for:** Daniel Mahony, OCR Studio Security Team (`daniel.mahony@ocrstudio.ai`)  
**Prepared by:** Adel Noaman (`expert.winxp@gmail.com`)  
**Date:** 17 July 2026  
**Product:** OCRStudioSDK 1.3.1 iOS Trial (`ocrstudiosdk.xcframework`)  
**Authorization:** DocuSign envelope `E86EA6F7-B675-8E96-8194-18360D9FF672` — *Authorization Letter for Technical Assessment and Reverse Engineering Evaluation*, valid 13 July 2026 – 30 July 2026  

### 1. Purpose

This report documents findings from an authorized technical assessment of OCR Studio's offline session-authorization (static auth / personalized signature) mechanism. The goal is responsible disclosure to enable product hardening. All work was performed in a controlled evaluation environment per the authorization letter.

**This package does not include weaponized license-bypass tools, binary patchers, or signature-forging utilities.** Attack classes are described at a technical level sufficient for remediation prioritization. A **verification-only** proof-of-concept is included to demonstrate correctness of the reverse-engineered model.

### 2. Scope

| In scope | Out of scope |
|----------|----------------|
| Static analysis of iOS ARM64 static library members related to licensing | Production customer deployments |
| Offline signature verification crypto (`se::security`) | Network services / online activation backends |
| Trial personalized signature validation model | Forging signatures or distributing patched libraries |
| Documentation of weaknesses and remediations | Commercial exploitation / redistribution |

**Primary artifacts analyzed**

- `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework` (iOS static archive)
- Object members: `static_auth.cpp.o`, `verify.cpp.o`, related BearSSL / `se::security` objects
- Public documentation: `doc/README.md` (trial signature)
- Sample app: `Samples/Swift/OCRStudioSDKSample`

### 3. Executive summary

OCR Studio sessions require a **256-character hexadecimal personalized signature**, validated **fully offline** against a public key and expected digest **embedded in the native library**.

The implementation uses:

- **RSA-1024** with public exponent **e = 3**
- **SHA-1** over a client-id string
- **PKCS#1 v1.5** encoding with a **raw 20-byte SHA-1 digest** (no ASN.1 DigestInfo OID) — matching BearSSL `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)`
- Namespace / OEM lineage: `se::security` (Smart Engines-style licensing stack)

**Impact:** The design is cryptographically dated and weakly bound. A capable adversary with the library binary can (1) fully understand and reimplement verification, (2) attempt binary patching of the verify entry points, and (3) abuse a stolen trial signature for any app embedding the same library build. Private-key recovery was **not** demonstrated; forging still requires the vendor private key or a cryptographic attack beyond the scope of this engagement.

**Severity (assessor judgment):** **High** for license/IP protection and trial abuse; **not** a remote RCE or user-data confidentiality bug by itself.

### 4. Technical findings

Deep reverse-engineering narrative (object files, decompiled verify logic, embedded constants, vendor minting lifecycle) is maintained in [License / Signature Validation Flow (Reverse-Engineered)](#license--signature-validation-flow-reverse-engineered) above. Summary for disclosure readers:

#### 4.1 Verification call chain

```
CreateSession(signature, ...)
  → se::security::internal::VSA(signature)          // Verify Static Auth
      → se::security::pkcs1_verify(sig, PUBKEY, EXPECTED_HASH)
          → hex → 128-byte signature
          → br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)
          → compare recovered 20-byte digest to embedded EXPECTED_HASH
```

Related: `VCIH()` recomputes `SHA-1(client_id)` and compares to the same embedded constant (integrity / config-tie check).

#### 4.2 Embedded constants (trial build)

| Constant | Value / notes |
|----------|----------------|
| Licensed client id (marker family) | `ocrstudio_arafatgroup_trial` (also referenced as `se_client_id__...` in minting tooling) |
| Expected SHA-1 | `25159e611dfa6f5f077a732a01d17ead8cc9770b` = `SHA-1("ocrstudio_arafatgroup_trial")` |
| RSA modulus `n` | 1024-bit (exported as `research/ocrstudio_pubkey_*.pem`) |
| RSA exponent `e` | `3` |
| Signature format | 256 hex chars → 128 bytes |

#### 4.3 Padding mode (important for remediations)

Empirical verification of the trial signature shows PKCS#1 v1.5 structure:

```text
EM = 00 01 FF...FF 00 ‖ SHA-1_digest[20]
```

**No DigestInfo.** Standard "PKCS#1 v1.5 + SHA-1" verifiers in common libraries (e.g. Python `cryptography` with DigestInfo) **reject** these signatures, while a BearSSL-compatible raw-hash unpad **accepts** them. This is intentional OEM behavior, not a broken trial key.

#### 4.4 License lifecycle (vendor side, from static analysis of minting objects)

Vendor-side objects (`keypair_generation`, `sign`, `activation`) indicate:

1. Generate RSA-1024 keypair (CRT private form ~ 320 bytes; public ~ 132 bytes)
2. Hash client marker → SHA-1
3. Embed `CreateStaticAuthData(pub ‖ marker ‖ hash)` into the shipped library
4. Issue customer signature = PKCS#1 sign(hash, priv) as 256 hex chars
5. Keep activation/private material secret (640 hex chars if hex-encoded)

Only the holder of the private activation material can mint new valid signatures for a given embedded public key / digest pair.

### 5. Evidence — verification PoC (reproducible)

**Artifact:** `research/verify_static_auth_poc.py`  
**Nature:** Independent reimplementation of the **verify** path only (public operation). No private key, no forge, no binary patch.

#### 5.1 Results obtained 17 July 2026

| Test | Command / input | Result |
|------|-----------------|--------|
| Trial signature (from `doc/README.md`) | `python research/verify_static_auth_poc.py` | **PASS** (exit 0) |
| Client-id hash self-check | `python research/verify_static_auth_poc.py --self-test` | **PASS** |
| Tampered signature (1 nibble flip) | `--signature 3122df27...` | **FAIL** (exit 1) |

#### 5.2 Binary ↔ PoC cross-check validation (17 July 2026)

Direct carve of `static_auth.cpp.o` (1736 bytes, arm64 slice, MH_MAGIC `0xFEEDFACF`) from the shipped `libocrstudiosdk-ios.a` confirms every constant the Python PoC embeds actually lives in the binary `__TEXT,__const` section at vma `0xe4` (195 bytes):

| Field | Size | PoC embeds | Binary `__const` | Match |
|-------|------|-----------|------------------|-------|
| RSA modulus `n` | 128 B | hardcoded hex | offset `+0x00` | ✅ identical (byte-for-byte) |
| RSA exponent `e` | 4 B | `00000003` (big-endian) | offset `+0x80` | ✅ identical |
| Client-id marker | var | `ocrstudio_arafatgroup_trial` | offset `+0x93` inside marker | ✅ present |
| `EXPECTED_HASH` | 20 B | `25159e611dfa6f5f077a732a01d17ead8cc9770b` | offset `+0xAF` | ✅ identical |
| `SHA-1(client_id) == EXPECTED_HASH` | — | verified | verified | ✅ |

Reproducer: `python check_binary_poc.py` (lives in repo as `research/check_binary_poc.py`) — parses the BSD `ar` archive, locates the arm64 `static_auth.cpp.o` slice by MH_MAGIC, parses Mach-O `LC_SEGMENT_64`, extracts `__TEXT,__const`, compares all five fields, and prints `BINARY CROSS-CHECK: ALL MATCH`. Exit `0` only if every field matches.

Also verified negative behaviour of the PoC: empty/null sigs would be skipped by the `CBZ x0` at `VSA+0x0`, malformed sigs (≠256 hex chars) are rejected upstream before BearSSL, and random 256-hex payloads produce `bad PKCS#1 header` (the tampered-sig test returns `6bb7…` at the first 2 bytes — well off the `00 01` required start).

#### 5.3 Supporting artifacts

| Path | Description |
|------|-------------|
| `research/ocrstudio_pubkey_spki.pem` | Recovered public key (SPKI) |
| `research/ocrstudio_pubkey_pkcs1.pem` | Recovered public key (PKCS#1) |
| `research/VENDOR_HARDENING.md` | Detailed mitigation backlog + patch-resistance testing guide |
| `research/VERIFY_PATH_MAP.md` | Symbol/offset/reloc map of the verify path |
| `research/check_binary_poc.py` | Carves arm64 `static_auth.cpp.o` from shipped `libocrstudiosdk-ios.a` and byte-compares its `__const` blob against PoC embed constants |
| `research/VALIDATION_PACKAGE.md` | Full authorization validation + remediation narrative (defers to CLAUDE.md as source of truth) |
| `research/verification/reference_server_mint.py` | Reference Ed25519 attestation-JWT mint (see § Hardened-Auth Reference Package) |
| `research/verification/Sources/HardenedAuth/HardenedAuthWrapper.swift` | Reference client wrapper + four-gate verifier |
| `research/verification/Tests/HardenedAuthTests/OCRAuthHardenedTests.swift` | Reference XCTest suite (§8 matrix) |
| `research/verification/Package.swift` | SwiftPM entry for `swift test` / Codemagic |
| `Samples/Swift/.../OCRStudioSDKSampleViewController.swift` | Trial signature wired for authorized end-to-end session testing |

### 6. Threat classes (for remediation planning)

Described without exploit code. Severity assumes a motivated integrator or attacker with the trial/production xcframework.

#### T1 — Signature theft / clone

**Vector:** Extract the 256-hex personalized signature from an app binary or source tree and reuse it with the same library build.

**Scenario:**
An integrator or attacker who has access to a shipped IPA or source repository can locate the signature string passed to `CreateSession`. Because verification is performed entirely offline, the same string can be copied into another app that embeds the identical `ocrstudiosdk.xcframework` build. The second app will then pass static auth without any relationship to the original licensee.

**Prerequisites:**
- Access to a compiled app binary or source that contains the trial/production signature.
- The destination app must embed the same library build (same embedded public key and expected digest).
- No online entitlement check is enforced by the SDK.

**Impact:**
- License cloning across unrelated apps or organizations for the same library build.
- Trial signatures can be redistributed and used past intended evaluation scope.
- Loss of license inventory control for the OEM.

**Observable indicators:**
- Identical 256-hex signatures appearing in unrelated app bundles.
- Session success on devices or builds not associated with the licensed customer.
- Absence of any server-side license telemetry or revocation capability.

**Mapped mitigations:**
- **P2 — Operational controls:** Prefer server-delivered short-lived tokens over shipping the signature in the binary (see `VENDOR_HARDENING.md` §P2).
- **P1 — Stronger license binding:** Sign a structured payload that includes `library_build_id`, platform, and validity window so a stolen signature cannot be replayed onto a different product or build (see §7 and `VENDOR_HARDENING.md` §P1).
- **P2 — Key separation:** Use separate trial and production keypairs, and rotate trial keys per customer build (see `VENDOR_HARDENING.md` §P2).

#### T2 — Binary patch of verify path

**Vector:** Modify the static library or linked binary so that the offline authentication check always succeeds, regardless of the supplied signature.

**Scenario:**
An attacker with the xcframework binary identifies the static-auth entry points in `static_auth.cpp.o` — `se::security::internal::VSA` and `se::security::internal::VEA`. Both are thin wrappers that load the embedded public-key / expected-digest blob from `__const` and tail-branch into `se::security::pkcs1_verify`. The attacker could patch any of three conceptual locations: the entry wrappers to skip verification, the compare logic inside `pkcs1_verify`, or the 20-byte expected digest in the `__const` blob. Because the companion integrity check `VCIH()` recomputes `SHA-1(client_id)` and compares it to the same embedded digest, an attacker who controls both the verify gate and the integrity constant can defeat both checks simultaneously.

**Prerequisites:**
- Write access to the shipped static library or the linked app binary.
- Ability to locate the auth functions (mangled symbols are present in the archive).
- Understanding that `VSA`/`VEA` tail-branch into `pkcs1_verify` and that `EXPECTED_HASH` sits adjacent to the public key in the `__const` blob (see `research/VERIFY_PATH_MAP.md`).

**Impact:**
- Complete bypass of offline license validation for the patched binary.
- A single modified library build can be redistributed to disable authentication across all apps that link it.

**Observable indicators:**
- Modified `libocrstudiosdk-ios.a` or app binary with altered bytes in the `se::security::internal::VSA` / `pkcs1_verify` code regions.
- App succeeds at `CreateSession` with an empty, malformed, or known-invalid signature.
- Unexpected changes to the `__const` auth blob near the expected digest offset.

**Mapped mitigations:**
- **P0 — Crypto upgrade:** A modern signature scheme raises the cost of any patch-based downgrade, but patching must still be assumed possible (see `VENDOR_HARDENING.md` §P0).
- **P3 — Anti-patch / integrity:** Bind `VCIH` (or its successor) to a code-region hash of the verify path, not only to the client-id string; diversify checks across multiple locations; avoid a single 20-byte constant compare at a fixed offset (see `VENDOR_HARDENING.md` §P3 and § Patch resistance (testing guide) for TR-01…TR-11 test intents).
- **P2 — Online attestation:** For high-value SKUs, supplement offline auth with short-lived server-issued tokens so a patched binary cannot operate indefinitely offline (see `VENDOR_HARDENING.md` §P2).

#### T3 — Cryptographic weakness of the scheme

**Vector:** The static-auth scheme relies on cryptographic primitives that are below current industry standards: RSA-1024, public exponent `e = 3`, SHA-1, and raw PKCS#1 v1.5 padding without an ASN.1 DigestInfo OID.

**Scenario:**
The signed payload is the raw 20-byte SHA-1 digest of the client-id marker. BearSSL verifies it with `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)`, meaning the padding block ends with `00 01 FF...FF 00 ‖ digest` rather than the standard PKCS#1 DigestInfo structure. Standard verifiers in common cryptographic libraries therefore reject these signatures, while a raw-hash unpad accepts them. RSA-1024 and `e = 3` are historically associated with padding-oracle and Bleichenbacher-class concerns, and SHA-1 no longer provides collision resistance. While forging a signature still requires the vendor private key or a successful cryptographic attack, the overall construction is dated and reduces the margin against future advances.

**Prerequisites:**
- Cryptanalytic capability or access to the vendor private key (neither was obtained in this assessment).
- Ability to craft a PKCS#1 v1.5 message block that the raw-hash verifier accepts.

**Impact:**
- A successful cryptographic attack could mint arbitrary valid signatures for the embedded public key.
- Even without a practical forge today, the weak construction accelerates risk as attacks on RSA-1024 and SHA-1 improve.

**Observable indicators:**
- N/A for a pure cryptographic break; detection requires key rotation and monitoring for signatures that do not match issued license records.

**Mapped mitigations:**
- **P0 — Crypto upgrade:** Migrate to RSA-2048+ with public exponent `e = 65537` (or Ed25519), use SHA-256 or SHA-512, and replace raw PKCS#1 v1.5 with standard DigestInfo PKCS#1 v1.5 or RSA-PSS (see `VENDOR_HARDENING.md` §P0).
- **P0 — Version the auth blob:** Ensure old trial libraries and new keys cannot be mixed, enabling clean cryptographic migration (see `VENDOR_HARDENING.md` §P0).

#### T4 — Weak payload binding

**Vector:** Signed data is effectively `SHA-1(client_id)` only.  
**Impact:** License does not cryptographically assert config file identity, library build, platform, or expiry.  
**Mitigation:** Structured signed claims (client, product, platform, build id, config hash, validity window).

### 7. Recommended remediations

Priority order (summary). Full detail: `research/VENDOR_HARDENING.md`.

| Priority | Action |
|----------|--------|
| **P0** | Upgrade to RSA-2048+ (e=65537) or Ed25519; SHA-256+; RSA-PSS or standard DigestInfo PKCS#1; version the auth blob |
| **P1** | Sign structured claims including `library_build_id` and `config_sha256`; reject mismatch |
| **P2** | Prefer server-issued short-lived tokens for production; separate trial vs production keypairs; rotate trial keys per customer build |
| **P3** | Strengthen integrity beyond client-id string hash; assume binary patching will be attempted — test guide: `VENDOR_HARDENING.md` § Patch resistance (testing guide) |

### 8. What was explicitly not delivered

Per responsible-disclosure practice and tooling policy for this report package:

- No private-key material (none recovered)

Iron Software / OCR Studio may request a **private technical workshop** under NDA to discuss patch resistance testing methodology without circulating exploit tooling.

### 9. Reproduction steps (vendor QA)

1. Extract this assessment tree including `research/`.  
2. Python 3.10+:  
   `python research/verify_static_auth_poc.py` → expect **PASS**  
   `python research/verify_static_auth_poc.py --self-test` → expect **PASS**  
3. Binary cross-check (carves the arm64 static-auth object slice from the shipped `.a` and compares its `__const` blob against every PoC embed):  
   `python research/check_binary_poc.py` → expect **BINARY CROSS-CHECK: ALL MATCH** (exit 0).  
4. Optional: open `Samples/Swift/OCRStudioSDKSample.xcodeproj`, build on device, confirm `CreateSession` accepts the documented trial signature with bundled `config/*.ocr`.

### 10. Confidentiality & handling

Per authorization letter:

- Findings are confidential to Iron Software / OCR Studio unless written approval is given for third-party disclosure.  
- Validity window of assessment authorization: **13 July 2026 – 30 July 2026** (extend in writing if needed).  
- No unauthorized redistribution or commercial misuse of Iron Software IP.

### 11. Contact

**Assessor:** Adel Noaman — `expert.winxp@gmail.com`  
**Vendor contact (from authorization):** Daniel Mahony — `daniel.mahony@ocrstudio.ai`  
**Envelope ID:** `E86EA6F7-B675-8E96-8194-18360D9FF672`

---

## Key Files Reference

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Agent guidance + **canonical security disclosure** (this file) |
| `doc/README.md` | API documentation, usage workflows, examples |
| `OCRStudioSDKCore/include/ocrstudiosdk/` | C++ header API |
| `OCRStudioSDKCore/wrap/objcocrstudiosdk/include/` | Objective-C++ headers |
| `OCRStudioSDK/` | Swift/iOS framework layer |
| `Samples/Swift/OCRStudioSDKSample/` | Complete working sample app |
| `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework/` | Compiled C++ engine binary |
| `research/VENDOR_HARDENING.md` | OEM mitigations + patch-resistance testing guide |
| `research/VERIFY_PATH_MAP.md` | Verify-path symbol/offset map |
| `research/verify_static_auth_poc.py` | Verification-only PoC |
| `research/check_binary_poc.py` | Binary ↔ PoC constants cross-check (parses `libocrstudiosdk-ios.a` arm64 slice) |
| `research/VALIDATION_PACKAGE.md` | Validation + remediation narrative (defers to CLAUDE.md § Hardened-Auth Reference Package) |
| `research/verification/reference_server_mint.py` | Reference Ed25519 attestation-JWT mint |
| `research/verification/Sources/HardenedAuth/HardenedAuthWrapper.swift` | Reference client wrapper + four-gate verifier |
| `research/verification/Tests/HardenedAuthTests/OCRAuthHardenedTests.swift` | Reference XCTest suite (§8 matrix) |
| `research/verification/Package.swift` | SwiftPM entry for `swift test` / Codemagic |
| `research/DISCLOSURE_REPORT.md` | Stub → points to this file's disclosure section |

## Common Tasks

**Integrate into new iOS app:**
1. Link `ocrstudiosdk.xcframework` in Xcode build phases
2. Import Objective-C++ headers via bridging header
3. Create `OCRStudioSDKInstance` with `.ocr` config file path
4. Create session with signature and session params JSON
5. Call `ProcessImage()` with `OCRStudioSDKImage`
6. Extract results from `OCRStudioSDKResult`

**Debug recognition issues:**
- Check `Description()` methods output (JSON format) for schema details
- Verify session params match config file's supported targets
- Enable verbose output modes in session params for additional data
- Monitor `target.IsFinal()` to detect incomplete recognition

**Enable RFID support:**
- Set `__RFID__` preprocessor flag
- Add NFCPassportReader SPM dependency
- Configure Info.plist with required NFC identifiers
- Add "Near Field Communication Tag Reading" capability in Xcode
