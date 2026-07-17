# Security Assessment Disclosure — OCR Studio SDK (iOS Trial 1.3.1)

**Classification:** Confidential — for Iron Software / OCR Studio Security Team only  
**Prepared for:** Daniel Mahony, OCR Studio Security Team (`daniel.mahony@ocrstudio.ai`)  
**Prepared by:** Adel Noaman (`expert.winxp@gmail.com`)  
**Date:** 17 July 2026  
**Product:** OCRStudioSDK 1.3.1 iOS Trial (`ocrstudiosdk.xcframework`)  
**Authorization:** DocuSign envelope `E86EA6F7-B675-8E96-8194-18360D9FF672` — *Authorization Letter for Technical Assessment and Reverse Engineering Evaluation*, valid 13 July 2026 – 30 July 2026  

---

## 1. Purpose

This report documents findings from an authorized technical assessment of OCR Studio’s offline session-authorization (static auth / personalized signature) mechanism. The goal is responsible disclosure to enable product hardening. All work was performed in a controlled evaluation environment per the authorization letter.

**This package does not include weaponized license-bypass tools, binary patchers, or signature-forging utilities.** Attack classes are described at a technical level sufficient for remediation prioritization. A **verification-only** proof-of-concept is included to demonstrate correctness of the reverse-engineered model.

---

## 2. Scope

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

---

## 3. Executive summary

OCR Studio sessions require a **256-character hexadecimal personalized signature**, validated **fully offline** against a public key and expected digest **embedded in the native library**.

The implementation uses:

- **RSA-1024** with public exponent **e = 3**
- **SHA-1** over a client-id string
- **PKCS#1 v1.5** encoding with a **raw 20-byte SHA-1 digest** (no ASN.1 DigestInfo OID) — matching BearSSL `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)`
- Namespace / OEM lineage: `se::security` (Smart Engines–style licensing stack)

**Impact:** The design is cryptographically dated and weakly bound. A capable adversary with the library binary can (1) fully understand and reimplement verification, (2) attempt binary patching of the verify entry points, and (3) abuse a stolen trial signature for any app embedding the same library build. Private-key recovery was **not** demonstrated; forging still requires the vendor private key or a cryptographic attack beyond the scope of this engagement.

**Severity (assessor judgment):** **High** for license/IP protection and trial abuse; **not** a remote RCE or user-data confidentiality bug by itself.

---

## 4. Technical findings

### 4.1 Verification call chain

```
CreateSession(signature, …)
  → se::security::internal::VSA(signature)          // Verify Static Auth
      → se::security::pkcs1_verify(sig, PUBKEY, EXPECTED_HASH)
          → hex → 128-byte signature
          → br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)
          → compare recovered 20-byte digest to embedded EXPECTED_HASH
```

Related: `VCIH()` recomputes `SHA-1(client_id)` and compares to the same embedded constant (integrity / config-tie check).

### 4.2 Embedded constants (trial build)

| Constant | Value / notes |
|----------|----------------|
| Licensed client id (marker family) | `ocrstudio_arafatgroup_trial` (also referenced as `se_client_id__…` in minting tooling) |
| Expected SHA-1 | `25159e611dfa6f5f077a732a01d17ead8cc9770b` = `SHA-1("ocrstudio_arafatgroup_trial")` |
| RSA modulus `n` | 1024-bit (exported as `research/ocrstudio_pubkey_*.pem`) |
| RSA exponent `e` | `3` |
| Signature format | 256 hex chars → 128 bytes |

### 4.3 Padding mode (important for remediations)

Empirical verification of the trial signature shows PKCS#1 v1.5 structure:

```text
EM = 00 01 FF…FF 00 ‖ SHA-1_digest[20]
```

**No DigestInfo.** Standard “PKCS#1 v1.5 + SHA-1” verifiers in common libraries (e.g. Python `cryptography` with DigestInfo) **reject** these signatures, while a BearSSL-compatible raw-hash unpad **accepts** them. This is intentional OEM behavior, not a broken trial key.

### 4.4 License lifecycle (vendor side, from static analysis of minting objects)

Vendor-side objects (`keypair_generation`, `sign`, `activation`) indicate:

1. Generate RSA-1024 keypair (CRT private form ≈ 320 bytes; public ≈ 132 bytes)
2. Hash client marker → SHA-1
3. Embed `CreateStaticAuthData(pub ‖ marker ‖ hash)` into the shipped library
4. Issue customer signature = PKCS#1 sign(hash, priv) as 256 hex chars
5. Keep activation/private material secret (640 hex chars if hex-encoded)

Only the holder of the private activation material can mint new valid signatures for a given embedded public key / digest pair.

---

## 5. Evidence — verification PoC (reproducible)

**Artifact:** `research/verify_static_auth_poc.py`  
**Nature:** Independent reimplementation of the **verify** path only (public operation). No private key, no forge, no binary patch.

### 5.1 Results obtained 17 July 2026

| Test | Command / input | Result |
|------|-----------------|--------|
| Trial signature (from `doc/README.md`) | `python research/verify_static_auth_poc.py` | **PASS** (exit 0) |
| Client-id hash self-check | `python research/verify_static_auth_poc.py --self-test` | **PASS** |
| Tampered signature (1 nibble flip) | `--signature 3122df27…` | **FAIL** (exit 1) |

### 5.2 Supporting artifacts

| Path | Description |
|------|-------------|
| `research/ocrstudio_pubkey_spki.pem` | Recovered public key (SPKI) |
| `research/ocrstudio_pubkey_pkcs1.pem` | Recovered public key (PKCS#1) |
| `research/VENDOR_HARDENING.md` | Detailed mitigation backlog |
| `Samples/Swift/.../OCRStudioSDKSampleViewController.swift` | Trial signature wired for authorized end-to-end session testing |

---

## 6. Threat classes (for remediation planning)

Described without exploit code. Severity assumes a motivated integrator or attacker with the trial/production xcframework.

### T1 — Signature theft / clone

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

### T2 — Binary patch of verify path

**Vector:** Patch `VSA` / `pkcs1_verify` / compare sites in the static library or linked binary so auth always succeeds.  
**Why it is realistic:** Single offline gate; integrity check (`VCIH`) is a weak related constant compare.  
**Evidence map:** Symbol VMAs, relocation-resolved call sites, and `__const` blob layout are documented in `research/VERIFY_PATH_MAP.md` (descriptive only — no patch tooling). Key object-file anchors: `VSA` @ `static_auth` text `0xb4` (tail-`B` to `pkcs1_verify`); digest compare branches in `verify` text `~0xa4`–`0xc8`; `EXPECTED_HASH` at `__const+0xAF`.  
**Mitigation:** Stronger integrity over the verify region; diversify checks; prefer online attestation for high-value SKUs; do not rely on obscurity.

### T3 — Cryptographic weakness of the scheme

**Vector:** RSA-1024 + e=3 + SHA-1 + PKCS#1 v1.5 (raw hash).  
**Status:** No successful forge was produced in this assessment. Residual risk remains versus modern crypto standards and future cryptanalysis.  
**Mitigation:** Migrate to RSA-2048+/PSS or Ed25519 + SHA-256; drop raw-hash PKCS#1 mode.

### T4 — Weak payload binding

**Vector:** Signed data is effectively `SHA-1(client_id)` only.  
**Impact:** License does not cryptographically assert config file identity, library build, platform, or expiry.  
**Mitigation:** Structured signed claims (client, product, platform, build id, config hash, validity window).

---

## 7. Recommended remediations

Priority order (summary). Full detail: `research/VENDOR_HARDENING.md`.

| Priority | Action |
|----------|--------|
| **P0** | Upgrade to RSA-2048+ (e=65537) or Ed25519; SHA-256+; RSA-PSS or standard DigestInfo PKCS#1; version the auth blob |
| **P1** | Sign structured claims including `library_build_id` and `config_sha256`; reject mismatch |
| **P2** | Prefer server-issued short-lived tokens for production; separate trial vs production keypairs; rotate trial keys per customer build |
| **P3** | Strengthen integrity beyond client-id string hash; assume binary patching will be attempted |

---

## 8. What was explicitly not delivered

Per responsible-disclosure practice and tooling policy for this report package:

- No working binary patch that disables `VSA`
- No signature-forging implementation
- No redistribution of patched libraries
- No private-key material (none recovered)

Iron Software / OCR Studio may request a **private technical workshop** under NDA to discuss patch resistance testing methodology without circulating exploit tooling.

---

## 9. Reproduction steps (vendor QA)

1. Extract this assessment tree including `research/`.  
2. Python 3.10+:  
   `python research/verify_static_auth_poc.py` → expect **PASS**  
   `python research/verify_static_auth_poc.py --self-test` → expect **PASS**  
3. Optional: open `Samples/Swift/OCRStudioSDKSample.xcodeproj`, build on device, confirm `CreateSession` accepts the documented trial signature with bundled `config/*.ocr`.

---

## 10. Confidentiality & handling

Per authorization letter:

- Findings are confidential to Iron Software / OCR Studio unless written approval is given for third-party disclosure.  
- Validity window of assessment authorization: **13 July 2026 – 30 July 2026** (extend in writing if needed).  
- No unauthorized redistribution or commercial misuse of Iron Software IP.

---

## 11. Contact

**Assessor:** Adel Noaman — `expert.winxp@gmail.com`  
**Vendor contact (from authorization):** Daniel Mahony — `daniel.mahony@ocrstudio.ai`  
**Envelope ID:** `E86EA6F7-B675-8E96-8194-18360D9FF672`

---

*End of disclosure report.*
