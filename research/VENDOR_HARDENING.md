# Vendor Hardening Notes — OCR Studio Static Auth

**Audience:** OEM (Smart Engines / OCR Studio)  
**Basis:** Authorized static analysis of trial iOS xcframework 1.3.1 (`static_auth.cpp.o`, `verify.cpp.o`, BearSSL)  
**Related PoC:** `research/verify_static_auth_poc.py` (verification only — does not forge or bypass)

## Findings (summary)

| Item | Current | Risk |
|------|---------|------|
| Algorithm | RSA-1024, public exponent **e = 3** | Weak key size; small `e` amplifies padding-oracle / Bleichenbacher-class concerns historically |
| Hash | SHA-1 | Broken for collision resistance; still used as the signed payload |
| Padding | PKCS#1 v1.5 with **raw** SHA-1 (no DigestInfo OID) | Non-standard; harder to use hardened crypto libraries as drop-in; easier to mis-audit |
| Binding | Signature over `SHA-1(client_id)` only | Does not bind app bundle ID, device, time, or config hash |
| Delivery | Offline verify of 256-hex signature in app binary | Signature often shipped beside the library; theft = full license clone for that build |
| Integrity | `VCIH()` re-hashes the same client_id string | Tamper check is weak if attacker can patch both hash compare and VSA |

## Recommended mitigations (priority order)

### P0 — Crypto upgrade (breaking, versioned)

1. **RSA-2048+** (or Ed25519) with a modern public exponent (`e = 65537` for RSA).  
2. **SHA-256** (or SHA-512) for the signed digest.  
3. Use **standard** PKCS#1 v1.5 DigestInfo **or** prefer **RSA-PSS** / Ed25519. Drop the BearSSL `hash_oid=NULL` raw-hash mode.  
4. Version the auth blob so old trial libraries and new keys cannot be mixed accidentally.

**Patch-resistance contribution:** Stronger crypto and a versioned auth blob do not stop an attacker from editing a local binary, but they remove weak raw-hash shortcuts and make patched old trial libraries cryptographically obsolete after migration. A testing engineer should treat P0 as enabling clean cutover: post-upgrade builds must reject auth blobs / keys from the trial 1.3.1 generation (see TR-07).

### P1 — Stronger license binding

Sign a structured payload, not a bare client id string, e.g.:

```text
client_id | product | platform | library_build_id | config_sha256 | not_before | not_after
```

Embed `library_build_id` and `config_sha256` expectations in the binary (or derive from the loaded `.ocr` file). Reject sessions when config hash ≠ license claim.

**Patch-resistance contribution:** Structured claims (`library_build_id`, `config_sha256`, validity window) raise the cost of both signature theft and local verify-gate patches: even if one compare is forced true, session setup must still fail when build/config claims disagree. Map to TR-05 and TR-07 in § Patch resistance (testing guide).

### P2 — Operational controls

1. Prefer **server-delivered short-lived tokens** (as README already suggests) over shipping the 256-hex string in the IPA.  
2. Rate-limit / revoke via online check for production SKUs if threat model allows.  
3. Separate **trial** and **production** keypairs; rotate trial keys per customer build.

**Patch-resistance contribution:** Short-lived server-delivered tokens bound offline success to a renewing online check. For production SKUs, a redistributed patched library (TR-11) should fail token renew even if local static auth is neutralized. Trial builds may remain offline; document the SKU policy under test.

### P3 — Anti-patch / integrity

1. Bind `VCIH` (or successor) to a **code-region hash** of the verify path, not only the client_id string.  
2. Avoid a single compare of a 20-byte constant at a fixed `__const` offset — diversify checks.  
3. Treat binary patching of `VSA` as expected; defense-in-depth is crypto + binding + ops, not obscurity alone.

Concrete object-file anchors for the current trial build (descriptive map only): see `research/VERIFY_PATH_MAP.md`. Notable: `VSA`/`VEA` are short wrappers that **tail-branch** into `pkcs1_verify`; `EXPECTED_HASH` sits at `__const+0xAF` beside the 132-byte pubkey; `VCIH` reuses the same digest constant.

**Details:** § Patch resistance (testing guide) — testing-engineer surface map, TR-01…TR-11 matrix (including binary-patch intents), design patterns, and acceptance checklist.

## What this research does *not* claim

- Private key recovery from the public modulus.  
- A practical padding forgery against this specific deployment (out of scope; do not attempt).  
- That trial signatures are “broken” — they verify correctly; the design is dated and weakly bound.

## Verification

```text
python research/verify_static_auth_poc.py          # PASS with trial signature
python research/verify_static_auth_poc.py --self-test
```

Swift sample (`Samples/Swift/.../OCRStudioSDKSampleViewController.swift`) embeds the trial signature so `CreateSession` can be exercised on device once the bundled `config/*.ocr` loads.
