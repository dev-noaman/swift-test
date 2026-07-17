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

## Patch resistance (testing guide)

### Audience & purpose

This chapter is for OEM security/product engineering **and** a testing engineer validating hardening of the offline static-auth path. It turns the descriptive map in `research/VERIFY_PATH_MAP.md` into test intents and acceptance criteria.

`research/verify_static_auth_poc.py` proves the **verify** model (public operation) only. It is **not** a binary-patch harness and must not be extended into one in this repository.

### Current patch surface (descriptive)

Conceptual targets on trial iOS xcframework 1.3.1 (no edit recipes):

- `se::security::internal::VSA` / `VEA` — thin wrappers that load the `__const` auth blob and **tail-branch** into `pkcs1_verify`.
- `se::security::pkcs1_verify` — hex-decode signature, BearSSL PKCS#1 verify with raw SHA-1 (`hash_oid=NULL`), compare recovered digest to embedded expected hash.
- `__const` auth blob — 132-byte public key material + `EXPECTED_HASH` (20 bytes) at `__const+0xAF`.
- `se::security::internal::VCIH` — re-hashes the client-id string and compares to the **same** digest constant used by verify.

Full symbol / reloc detail: `research/VERIFY_PATH_MAP.md`.

### Anchor → mitigation map

| Anchor (symbol / blob) | Weakness | Hardening action | Priority |
|------------------------|----------|------------------|----------|
| `VSA` / `VEA` wrappers | Single entry can be skipped or forced | Diversify gates; do not rely on one wrapper | P3 |
| `pkcs1_verify` compare | One success/fail branch | Multiple independent checks; fail closed | P3 |
| `EXPECTED_HASH` in `__const` | Fixed 20-byte constant beside pubkey | Stop using digest-only integrity; version blob | P0, P3 |
| `VCIH` | Same digest as verify; not code-bound | Bind to verify-path code-region hash | P3 |
| Stolen 256-hex signature | Offline reuse on same library build | Structured claims + tokens | P1, P2 |
| Patched / substituted library | Offline SKU may run indefinitely | Online attest + build-id binding | P1, P2 |

### Test matrix (pre-/post-hardening intents)

Intent-level only. TR-08…TR-11 describe **what** to validate after a binary is altered; they do **not** provide patch bytes. Byte-level exercises stay under NDA / private workshop (see disclosure report §8).

| ID | Test intent | Pre-hardening expectation (trial 1.3.1) | Post-hardening expectation | Evidence / how to observe |
|----|-------------|----------------------------------------|----------------------------|---------------------------|
| TR-01 | Valid trial signature + unmodified lib | `CreateSession` / verify PoC **PASS** | Still **PASS** on legitimate builds | `python research/verify_static_auth_poc.py`; sample app session |
| TR-02 | Empty / null signature | May skip or fail (`CBZ` on null) | Must **FAIL** closed (no session) | Session error / PoC FAIL |
| TR-03 | Malformed / wrong-length hex | Fail verify | Must **FAIL** | PoC / session |
| TR-04 | Well-formed wrong signature (1-nibble flip) | **FAIL** | Must remain **FAIL** | PoC with flipped nibble |
| TR-05 | Stolen valid signature on *same* library build | **PASS** (T1) | **FAIL** or scoped reject when P1/P2 land | Bundle/build/config mismatch; token policy |
| TR-06 | Integrity vs verify share one digest constant | Both weak / coupled | Integrity must fail if verify-path code changes; digest-only check insufficient | Design review + hash of verify objects |
| TR-07 | Modified library build claiming old license | May still pass if only client_id signed | Must **FAIL** when build-id / auth-blob version / code-region hash enforced | Build-id + versioned blob checks |
| TR-08 | Binary patch — verify gate (conceptual: neutralize `VSA`/`VEA`/`pkcs1_verify` success path) | Session may succeed with invalid signature if gate neutralized | Must **FAIL** via remaining diversified or remote checks | Session denied; verify-path object hashes |
| TR-09 | Binary patch — expected digest blob (conceptual: alter `__const` `EXPECTED_HASH`) | Local verify can track attacker-chosen digest if blob + compare co-controlled | Must **FAIL** if code-region integrity or versioned blob disagrees | Integrity + blob version mismatch |
| TR-10 | Binary patch — `VCIH` only / decouple checks | Shared digest ⇒ weak coupling | Defeating integrity must not auto-defeat verify (and vice versa) | Independent failure modes in test plan |
| TR-11 | Redistributed patched library | Offline SKU may run indefinitely if patch succeeds | Production: token renew / online attest fails (P2); build-id mismatch (P1) | Token renew failures; build inventory |

### Design patterns (VCIH successor & diversified checks)

1. Bind integrity to a **code-region hash** of the verify path (or equivalent), not only `SHA-1(client_id)`.
2. Diversify checks so a single fixed 20-byte compare is not the sole gate.
3. Ensure verify-gate failure and integrity failure are **independent** kill-switches.
4. Version the auth blob / keys so patched old trial libs cannot mix with new production keys (P0).

### Acceptance criteria checklist

- [ ] Invalid / empty / malformed signatures never open a session (TR-02…TR-04)
- [ ] Integrity binds verify-path code (or equivalent), not only client-id string hash (TR-06, TR-10)
- [ ] No single fixed 20-byte compare is the sole gate (TR-08, TR-09)
- [ ] Auth blob / keys are versioned (TR-07, P0)
- [ ] Stolen signature cannot authorize a different product/build (P1) or requires short-lived server token where the SKU demands it (P2) (TR-05, TR-11)
- [ ] TR-01 still passes on legitimate builds
- [ ] TR-08…TR-11 documented with pass/fail observables (not exploit steps)
- [ ] No single binary edit to one of {wrapper, compare, `__const` digest, `VCIH`} keeps a production session alive when P0–P3 are claimed done
- [ ] Byte-level patch exercises, if any, stay under NDA / private workshop

### Relationship to P0–P2

Crypto upgrade (P0), structured binding (P1), and operational tokens (P2) are **complementary** to local integrity (P3). They change what a testing engineer can still break offline after a conceptual binary patch (see contribution notes under each priority). Completing P0–P2 without TR-08…TR-11 validation is not sufficient to claim patch resistance.

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
