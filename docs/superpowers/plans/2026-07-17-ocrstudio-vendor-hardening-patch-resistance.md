# OCR Studio VENDOR_HARDENING Patch Resistance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `research/VENDOR_HARDENING.md` with a testing-engineer **Patch resistance** chapter (TR-01…TR-11, including binary-patch intents) plus P0–P2 contribution notes, and light disclosure pointers.

**Architecture:** Keep the existing P0–P3 priority model. Add short **Patch-resistance contribution** notes under P0–P2 and a pointer under P3; insert a new top-level chapter after P3. Update `DISCLOSURE_REPORT.md` §7 / T2 pointers only. No new research binaries or exploit content.

**Tech Stack:** Markdown editing; verification via Python 3.10+ structural checks and `research/verify_static_auth_poc.py`.

## Global Constraints

- No exploit code, patch bytes, NOP recipes, bypass scripts, or redistributable patched libraries.
- No signature-forging instructions or private-key recovery claims.
- All claims must be backed by artifacts already in the repository (`VERIFY_PATH_MAP.md`, verify PoC, existing hardening / disclosure text).
- Classification header and confidentiality handling in `DISCLOSURE_REPORT.md` must remain unchanged.
- Do not rewrite T2’s Scenario / Prerequisites / Impact / Observable indicators blocks — pointer updates only.
- Chapter heading must be exactly: `## Patch resistance (testing guide)`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `research/VENDOR_HARDENING.md` | Modified: P0–P2 notes, P3 pointer, new Patch resistance chapter. |
| `research/DISCLOSURE_REPORT.md` | Modified: §7 P3 row + T2 mapped-mitigations P3 bullet pointer. |
| `research/stil.md` | Modified at end: check off Expand VENDOR_HARDENING patch section. |
| `research/VERIFY_PATH_MAP.md` | Referenced only. |
| `research/verify_static_auth_poc.py` | Run only; do not change. |

---

### Task 1: Add P0–P2 patch-resistance notes and P3 pointer

**Files:**
- Modify: `research/VENDOR_HARDENING.md`

**Interfaces:**
- Consumes: Existing P0–P3 sections.
- Produces: Each of P0–P2 ends with a `**Patch-resistance contribution:**` paragraph; P3 gains a Details pointer to the (upcoming) chapter.

- [ ] **Step 1: Insert P0 contribution note**

Immediately after the P0 numbered list (after item 4 about versioning the auth blob), before `### P1`, insert:

```markdown

**Patch-resistance contribution:** Stronger crypto and a versioned auth blob do not stop an attacker from editing a local binary, but they remove weak raw-hash shortcuts and make patched old trial libraries cryptographically obsolete after migration. A testing engineer should treat P0 as enabling clean cutover: post-upgrade builds must reject auth blobs / keys from the trial 1.3.1 generation (see TR-07).
```

- [ ] **Step 2: Insert P1 contribution note**

Immediately after the P1 paragraph that ends with “Reject sessions when config hash ≠ license claim.”, before `### P2`, insert:

```markdown

**Patch-resistance contribution:** Structured claims (`library_build_id`, `config_sha256`, validity window) raise the cost of both signature theft and local verify-gate patches: even if one compare is forced true, session setup must still fail when build/config claims disagree. Map to TR-05 and TR-07 in § Patch resistance (testing guide).
```

- [ ] **Step 3: Insert P2 contribution note**

Immediately after the P2 numbered list (after item 3 about trial/production keypairs), before `### P3`, insert:

```markdown

**Patch-resistance contribution:** Short-lived server-delivered tokens bound offline success to a renewing online check. For production SKUs, a redistributed patched library (TR-11) should fail token renew even if local static auth is neutralized. Trial builds may remain offline; document the SKU policy under test.
```

- [ ] **Step 4: Update P3 with Details pointer**

Replace the current P3 block (three bullets + the “Concrete object-file anchors…” paragraph) with:

```markdown
### P3 — Anti-patch / integrity

1. Bind `VCIH` (or successor) to a **code-region hash** of the verify path, not only the client_id string.  
2. Avoid a single compare of a 20-byte constant at a fixed `__const` offset — diversify checks.  
3. Treat binary patching of `VSA` as expected; defense-in-depth is crypto + binding + ops, not obscurity alone.

Concrete object-file anchors for the current trial build (descriptive map only): see `research/VERIFY_PATH_MAP.md`. Notable: `VSA`/`VEA` are short wrappers that **tail-branch** into `pkcs1_verify`; `EXPECTED_HASH` sits at `__const+0xAF` beside the 132-byte pubkey; `VCIH` reuses the same digest constant.

**Details:** § Patch resistance (testing guide) — testing-engineer surface map, TR-01…TR-11 matrix (including binary-patch intents), design patterns, and acceptance checklist.
```

- [ ] **Step 5: Structural check for contribution markers**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "text=open('research/VENDOR_HARDENING.md',encoding='utf-8').read(); assert text.count('**Patch-resistance contribution:**')==3; assert '**Details:** § Patch resistance (testing guide)' in text; print('Task1 markers OK')"
```

Expected: prints `Task1 markers OK`.

- [ ] **Step 6: Commit**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/VENDOR_HARDENING.md
git commit -m "docs(hardening): add P0-P2 patch-resistance notes and P3 pointer"
```

Expected: commit succeeds.

---

### Task 2: Insert Patch resistance (testing guide) chapter

**Files:**
- Modify: `research/VENDOR_HARDENING.md`

**Interfaces:**
- Consumes: Task 1 P3 pointer; `VERIFY_PATH_MAP.md` anchors; TR-01…TR-11 from the design spec.
- Produces: Full chapter between P3 block and `## What this research does *not* claim`.

- [ ] **Step 1: Insert the chapter**

Insert the following block **immediately before** the line `## What this research does *not* claim`:

```markdown
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

```

- [ ] **Step 2: Structural check for chapter and TR IDs**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "import re; t=open('research/VENDOR_HARDENING.md',encoding='utf-8').read(); assert '## Patch resistance (testing guide)' in t; ids=[f'TR-{i:02d}' for i in range(1,12)]; missing=[i for i in ids if i not in t]; print('missing TR:', missing); assert not missing; assert t.index('## Patch resistance (testing guide)') < t.index('## What this research does *not* claim'); print('Task2 chapter OK')"
```

Expected: `missing TR: []` then `Task2 chapter OK`.

- [ ] **Step 3: Commit**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/VENDOR_HARDENING.md
git commit -m "docs(hardening): add patch resistance testing guide chapter"
```

Expected: commit succeeds.

---

### Task 3: Update disclosure pointers

**Files:**
- Modify: `research/DISCLOSURE_REPORT.md`

**Interfaces:**
- Consumes: New chapter heading from Task 2.
- Produces: §7 P3 row and T2 P3 mapped-mitigation bullet name the chapter.

- [ ] **Step 1: Update T2 mapped mitigations P3 bullet**

Replace this exact line under T2 **Mapped mitigations:**

```markdown
- **P3 — Anti-patch / integrity:** Bind `VCIH` (or its successor) to a code-region hash of the verify path, not only to the client-id string; diversify checks across multiple locations; avoid a single 20-byte constant compare at a fixed offset (see `VENDOR_HARDENING.md` §P3).
```

with:

```markdown
- **P3 — Anti-patch / integrity:** Bind `VCIH` (or its successor) to a code-region hash of the verify path, not only to the client-id string; diversify checks across multiple locations; avoid a single 20-byte constant compare at a fixed offset (see `VENDOR_HARDENING.md` §P3 and § Patch resistance (testing guide) for TR-01…TR-11 test intents).
```

- [ ] **Step 2: Update §7 P3 table row**

Replace this exact table row:

```markdown
| **P3** | Strengthen integrity beyond client-id string hash; assume binary patching will be attempted |
```

with:

```markdown
| **P3** | Strengthen integrity beyond client-id string hash; assume binary patching will be attempted — test guide: `VENDOR_HARDENING.md` § Patch resistance (testing guide) |
```

- [ ] **Step 3: Confirm classification header unchanged**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "lines=open('research/DISCLOSURE_REPORT.md',encoding='utf-8').read().splitlines(); assert 'Confidential' in lines[2] and 'Iron Software' in lines[2]; assert 'Patch resistance (testing guide)' in open('research/DISCLOSURE_REPORT.md',encoding='utf-8').read(); print('Task3 pointers OK')"
```

Expected: prints `Task3 pointers OK`.

- [ ] **Step 4: Commit**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/DISCLOSURE_REPORT.md
git commit -m "docs(disclosure): point T2/P3 at patch resistance testing guide"
```

Expected: commit succeeds.

---

### Task 4: Verify PoC, check stil.md, consistency pass

**Files:**
- Modify: `research/stil.md`
- Verify: `research/VENDOR_HARDENING.md`, `research/DISCLOSURE_REPORT.md`

**Interfaces:**
- Consumes: Tasks 1–3 complete content.
- Produces: stil item checked; final verification green.

- [ ] **Step 1: Run verification PoC**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python research/verify_static_auth_poc.py
python research/verify_static_auth_poc.py --self-test
```

Expected: both exit 0 with `result: PASS`.

- [ ] **Step 2: Full structural gate**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
python -c "t=open('research/VENDOR_HARDENING.md',encoding='utf-8').read(); d=open('research/DISCLOSURE_REPORT.md',encoding='utf-8').read(); assert t.count('**Patch-resistance contribution:**')==3; assert '## Patch resistance (testing guide)' in t; assert all(f'TR-{i:02d}' in t for i in range(1,12)); assert 'Binary patch — verify gate' in t; assert 'Patch resistance (testing guide)' in d; banned=['NOP VSA','patch bytes','\\x90\\x90']; assert not any(b.lower() in t.lower() for b in ['nop vsa']); print('structural gate OK')"
```

Expected: prints `structural gate OK`.

- [ ] **Step 3: Check off stil.md item**

Replace:

```markdown
- [ ] Expand VENDOR_HARDENING patch section 
```

with:

```markdown
- [x] Expand VENDOR_HARDENING patch section 
```

- [ ] **Step 4: Commit**

```bash
cd "D:\\Copy\\ocr studio\\OCRStudioSDK-1.3.1-iOS-Trial"
git add research/stil.md
git commit -m "docs(research): mark VENDOR_HARDENING patch section complete in stil"
```

Expected: commit succeeds. If `stil.md` has other unrelated dirty changes, commit only the checkbox line change (or include the already-completed T1–T3 checkbox if it was left unstaged from earlier work).

---

## Self-Review

**1. Spec coverage:**
- New chapter with all subsections ✓ (Task 2)
- TR-01…TR-11 including binary-patch TR-08…TR-11 ✓ (Task 2)
- P0–P2 contribution notes + P3 pointer ✓ (Task 1)
- Design patterns + acceptance checklist ✓ (Task 2)
- Disclosure light pointers ✓ (Task 3)
- stil check-off + PoC verify ✓ (Task 4)
- No patch bytes / forge tooling ✓ (Global Constraints + Task 4 gate)

**2. Placeholder scan:**
- No TBD/TODO/fill-in-later language ✓
- Each step has concrete markdown or commands ✓

**3. Consistency check:**
- Chapter heading exact: `## Patch resistance (testing guide)` ✓
- Paths: `research/VENDOR_HARDENING.md`, `research/DISCLOSURE_REPORT.md`, `research/VERIFY_PATH_MAP.md`, `research/verify_static_auth_poc.py`, `research/stil.md` ✓
- Spec file: `docs/superpowers/specs/2026-07-17-ocrstudio-vendor-hardening-patch-resistance-design.md` ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-17-ocrstudio-vendor-hardening-patch-resistance.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach would you like?
