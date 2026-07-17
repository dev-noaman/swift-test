# OCR Studio T1–T3 Disclosure Narrative — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the T1, T2, and T3 threat-class sections in `research/DISCLOSURE_REPORT.md` §6 with structured, non-weaponized narrative that maps each threat to specific remediations.

**Architecture:** In-place enrichment of the existing Markdown report. Each threat gains a consistent five-part subsection (Scenario, Prerequisites, Impact, Observable indicators, Mapped mitigations). No new files are created; cross-references point to existing `VERIFY_PATH_MAP.md` and `VENDOR_HARDENING.md` artifacts.

**Tech Stack:** Markdown editing; verification uses Python 3.10+ (`verify_static_auth_poc.py`) and manual link/render checks.

## Global Constraints

- No exploit code, patch bytes, or signature-forging instructions may be introduced.
- All claims must be backed by artifacts already in the repository.
- Classification header and confidentiality handling in `DISCLOSURE_REPORT.md` must remain unchanged.
- T4 (weak payload binding) is left as-is; only T1–T3 are expanded.
- The existing threat-class headings (`T1 — Signature theft / clone`, etc.) are preserved.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `research/DISCLOSURE_REPORT.md` | Modified: §6 T1–T3 sections expanded in-place. |
| `research/VERIFY_PATH_MAP.md` | Referenced only: provides descriptive object-file anchors for T2. |
| `research/VENDOR_HARDENING.md` | Referenced only: source of P0–P3 mitigations mapped in T1–T3. |
| `research/verify_static_auth_poc.py` | Verification-only artifact; run to confirm no factual drift after edits. |

---

### Task 1: Expand T1 — Signature theft / clone

**Files:**
- Modify: `research/DISCLOSURE_REPORT.md:132-137`

**Interfaces:**
- Consumes: Existing T1 paragraph, §7 remediation table, `VENDOR_HARDENING.md` P2 section.
- Produces: Expanded T1 subsection with Scenario / Prerequisites / Impact / Observable indicators / Mapped mitigations.

- [ ] **Step 1: Replace the T1 paragraph with the expanded subsection**

Replace the single paragraph under `### T1 — Signature theft / clone` with:

```markdown
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
```

- [ ] **Step 2: Verify the Markdown structure**

Run a built-in structural check to confirm the expected subsections exist:

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "import re; text=open('research/DISCLOSURE_REPORT.md').read(); required=['**Scenario:**','**Prerequisites:**','**Impact:**','**Observable indicators:**','**Mapped mitigations:**']; missing=[r for r in required if text.count(r) < 3]; print('missing:', missing)"
```

Expected: prints `missing: []` (each of the five subsection labels appears at least three times, once under T1, T2, and T3).

- [ ] **Step 3: Commit the T1 expansion**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/DISCLOSURE_REPORT.md
git commit -m "docs(disclosure): expand T1 signature theft/clone narrative"
```

Expected: commit succeeds; `git show --stat` shows `research/DISCLOSURE_REPORT.md` changed.

---

### Task 2: Expand T2 — Binary patch of verify path

**Files:**
- Modify: `research/DISCLOSURE_REPORT.md:138-144`

**Interfaces:**
- Consumes: Existing T2 paragraph, `VERIFY_PATH_MAP.md` symbol/object-file anchors, `VENDOR_HARDENING.md` P3 section.
- Produces: Expanded T2 subsection describing the patch surface conceptually without byte-level recipes.

- [ ] **Step 1: Replace the T2 paragraph with the expanded subsection**

Replace the single paragraph under `### T2 — Binary patch of verify path` with:

```markdown
### T2 — Binary patch of verify path

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
- **P3 — Anti-patch / integrity:** Bind `VCIH` (or its successor) to a code-region hash of the verify path, not only to the client-id string; diversify checks across multiple locations; avoid a single 20-byte constant compare at a fixed offset (see `VENDOR_HARDENING.md` §P3).
- **P2 — Online attestation:** For high-value SKUs, supplement offline auth with short-lived server-issued tokens so a patched binary cannot operate indefinitely offline (see `VENDOR_HARDENING.md` §P2).
```

- [ ] **Step 2: Verify cross-references**

Confirm these references resolve to existing artifacts:

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
grep -n "se::security::internal::VSA" research/VERIFY_PATH_MAP.md
grep -n "EXPECTED_HASH" research/VERIFY_PATH_MAP.md
grep -n "VCIH" research/VERIFY_PATH_MAP.md
grep -n "P3" research/VENDOR_HARDENING.md
```

Expected: each grep returns at least one match.

- [ ] **Step 3: Commit the T2 expansion**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/DISCLOSURE_REPORT.md
git commit -m "docs(disclosure): expand T2 binary patch narrative"
```

Expected: commit succeeds.

---

### Task 3: Expand T3 — Cryptographic weakness of the scheme

**Files:**
- Modify: `research/DISCLOSURE_REPORT.md:145-150`

**Interfaces:**
- Consumes: Existing T3 paragraph, `VENDOR_HARDENING.md` P0 section, public-key files.
- Produces: Expanded T3 subsection explaining the dated crypto parameters and their implications.

- [ ] **Step 1: Replace the T3 paragraph with the expanded subsection**

Replace the single paragraph under `### T3 — Cryptographic weakness of the scheme` with:

```markdown
### T3 — Cryptographic weakness of the scheme

**Vector:** The static-auth scheme relies on cryptographic primitives that are below current industry standards: RSA-1024, public exponent `e = 3`, SHA-1, and raw PKCS#1 v1.5 padding without an ASN.1 DigestInfo OID.

**Scenario:**
The signed payload is the raw 20-byte SHA-1 digest of the client-id marker. BearSSL verifies it with `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)`, meaning the padding block ends with `00 01 FF…FF 00 ‖ digest` rather than the standard PKCS#1 DigestInfo structure. Standard verifiers in common cryptographic libraries therefore reject these signatures, while a raw-hash unpad accepts them. RSA-1024 and `e = 3` are historically associated with padding-oracle and Bleichenbacher-class concerns, and SHA-1 no longer provides collision resistance. While forging a signature still requires the vendor private key or a successful cryptographic attack, the overall construction is dated and reduces the margin against future advances.

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
```

- [ ] **Step 2: Verify the PoC still reflects the described behavior**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python research/verify_static_auth_poc.py --self-test
```

Expected: output includes `PASS` / exit 0, confirming the SHA-1(client_id) and raw-hash model described in T3 is still accurate.

- [ ] **Step 3: Commit the T3 expansion**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/DISCLOSURE_REPORT.md
git commit -m "docs(disclosure): expand T3 cryptographic weakness narrative"
```

Expected: commit succeeds.

---

### Task 4: Consistency pass and final review

**Files:**
- Modify: `research/DISCLOSURE_REPORT.md` (light-touch edits only)

**Interfaces:**
- Consumes: Expanded T1, T2, T3 subsections.
- Produces: Consistent §6 with matching voice, tense, and cross-reference style.

- [ ] **Step 1: Read §6 end-to-end and normalize wording**

Check for:
- All five subsections present under T1, T2, and T3.
- T4 left unchanged except for any necessary cross-reference to T1/T2.
- Consistent use of `P0`, `P1`, `P2`, `P3` labels.
- All `VENDOR_HARDENING.md` and `VERIFY_PATH_MAP.md` references use the exact filenames.

Apply any minor edits directly in the file.

- [ ] **Step 2: Render and structural check**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "import re; text=open('research/DISCLOSURE_REPORT.md').read(); required=['**Scenario:**','**Prerequisites:**','**Impact:**','**Observable indicators:**','**Mapped mitigations:**']; missing=[r for r in required if text.count(r) < 3]; print('missing:', missing); print('t1-t3 word count:', len(re.findall(r'\b\w+\b', text[text.find('### T1'):text.find('### T4')])))"
```

Expected: `missing: []` and a word count larger than the original §6.

- [ ] **Step 3: Run the verification PoC one final time**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python research/verify_static_auth_poc.py
python research/verify_static_auth_poc.py --self-test
```

Expected: both commands exit 0 (PASS).

- [ ] **Step 4: Commit the consistency pass**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/DISCLOSURE_REPORT.md
git commit -m "docs(disclosure): consistency pass on expanded T1-T3 sections"
```

Expected: commit succeeds.

---

## Self-Review

**1. Spec coverage:**
- T1 expanded with scenario, prerequisites, impact, indicators, mitigations ✓
- T2 expanded with conceptual patch-surface description and `VERIFY_PATH_MAP.md` references ✓
- T3 expanded with cryptographic-weakness details and P0 mitigation mapping ✓
- T4 left unchanged ✓
- No exploit code, patch bytes, or forge instructions ✓

**2. Placeholder scan:**
- No TBD/TODO/fill-in-later language ✓
- Each step contains concrete text or commands ✓

**3. Type/consistency check:**
- File paths are exact: `research/DISCLOSURE_REPORT.md`, `research/VERIFY_PATH_MAP.md`, `research/VENDOR_HARDENING.md`, `research/verify_static_auth_poc.py` ✓
- P0–P3 labels match those in `VENDOR_HARDENING.md` ✓
- Section references (§6, §7) match the report structure ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-17-ocrstudio-t1-t3-disclosure-narrative.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach would you like?
