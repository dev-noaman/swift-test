# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCRStudioSDK is an iOS framework for optical character recognition and document processing. Version 1.3.1 is a trial/research release that includes a native C++ engine with Objective-C++ wrappers and Swift bindings.

**Authorization Note:** This repository contains an official authorization document (`Official Authorization for Security Research_ocrstudio.pdf`) granting explicit permission for security research and testing activities.

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

## Key Files Reference

| Path | Purpose |
|------|---------|
| `doc/README.md` | API documentation, usage workflows, examples |
| `OCRStudioSDKCore/include/ocrstudiosdk/` | C++ header API |
| `OCRStudioSDKCore/wrap/objcocrstudiosdk/include/` | Objective-C++ headers |
| `OCRStudioSDK/` | Swift/iOS framework layer |
| `Samples/Swift/OCRStudioSDKSample/` | Complete working sample app |
| `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework/` | Compiled C++ engine binary |

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
