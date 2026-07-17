# Design: Expand VENDOR_HARDENING Patch Resistance (Testing Guide)

**Date:** 2026-07-17  
**Related task:** `research/stil.md` — `- [ ] Expand VENDOR_HARDENING patch section`  
**Approach:** New top-level **Patch resistance (testing guide)** chapter, plus short patch-resistance notes under P0–P2 (user-approved Approach 2 + testing-engineer scope)  
**Primary file:** `research/VENDOR_HARDENING.md`

---

## Goal

Give OEM engineers and a **testing engineer** a single place to plan and validate **binary-patch resistance** for the OCR Studio static-auth path, using artifacts already in the repository. The chapter must be actionable (test matrix, acceptance checklist, design patterns) without delivering a weaponized patcher.

## Out of scope

- Patch bytes, NOP recipes, bypass scripts, or redistributable patched libraries
- Signature-forging implementation or private-key recovery claims
- Rewriting `DISCLOSURE_REPORT.md` §6 T2 five-part narrative (pointers only)
- New reverse-engineering beyond `VERIFY_PATH_MAP.md`, the verify PoC, and current hardening notes

## Architecture (document structure)

Keep the existing P0–P3 priority model. Insert a new top-level chapter **after** `### P3 — Anti-patch / integrity` and **before** `## What this research does *not* claim`:

```markdown
## Patch resistance (testing guide)

### Audience & purpose
### Current patch surface (descriptive)
### Anchor → mitigation map
### Test matrix (pre-/post-hardening intents)
### Design patterns (VCIH successor & diversified checks)
### Acceptance criteria checklist
### Relationship to P0–P2
```

Also edit in-place:

- Under **P0**, **P1**, **P2**: add a short **Patch-resistance contribution** note (3–5 sentences each).
- Under **P3**: keep the three existing bullets; add a pointer: “Details: § Patch resistance (testing guide)”.
- In `DISCLOSURE_REPORT.md`: light updates to §7 P3 row and T2 mapped-mitigations so they name the new chapter.

## Content specifications

### Audience & purpose

State that the audience is OEM security/product engineering **and** a testing engineer validating hardening. Clarify that `research/verify_static_auth_poc.py` proves the verify model only; it is not a patch harness.

### Current patch surface (descriptive)

Describe conceptual targets only, citing `research/VERIFY_PATH_MAP.md`:

- `se::security::internal::VSA` / `VEA` — thin wrappers that tail-branch into `pkcs1_verify`
- `se::security::pkcs1_verify` — compare recovered digest to embedded expected hash
- `__const` blob — public key + `EXPECTED_HASH` at a fixed offset
- `se::security::internal::VCIH` — integrity check that reuses the same digest constant as verify

No byte-level edit instructions.

### Anchor → mitigation map

Table columns: Anchor (symbol/blob) | Weakness | Hardening action | Priority.

Rows must cover at least: `VSA`/`VEA`, `pkcs1_verify` compare, `EXPECTED_HASH` / `__const`, `VCIH`, stolen signature / same-build reuse (cross-link P1/P2).

### Test matrix

Intent-level rows with columns: ID | Test intent | Pre-hardening expectation (trial 1.3.1) | Post-hardening expectation | Evidence / how to observe.

Required IDs:

| ID | Intent summary |
|----|----------------|
| TR-01 | Valid trial signature + unmodified lib |
| TR-02 | Empty / null signature |
| TR-03 | Malformed / wrong-length hex |
| TR-04 | Well-formed wrong signature (e.g. 1-nibble flip) |
| TR-05 | Stolen valid signature on same library build |
| TR-06 | Integrity vs verify inconsistency (shared digest weakness) |
| TR-07 | Modified library build claiming old license |
| TR-08 | Binary patch — verify gate (conceptual) |
| TR-09 | Binary patch — expected digest blob (conceptual) |
| TR-10 | Binary patch — `VCIH` only / decoupled checks (conceptual) |
| TR-11 | Redistributed patched library vs online/build binding |

TR-08…TR-11 describe **what** is validated after a binary is altered; they must not include patch recipes. Byte-level exercises remain under NDA / private workshop (disclosure §8).

### Design patterns

Document recommended patterns:

1. Bind integrity to a **code-region hash** of the verify path (or equivalent), not only `SHA-1(client_id)`.
2. Diversify checks so a single fixed 20-byte compare is not the sole gate.
3. Ensure verify-gate failure and integrity failure are **independent** kill-switches.
4. Version the auth blob / keys so patched old trial libs cannot mix with new production keys (ties to P0).

### Acceptance criteria checklist

Tickable items an OEM hardening sprint can use, including:

- Invalid / empty / malformed signatures never open a session
- Integrity binds verify-path code (or equivalent), not only client-id string hash
- No single fixed 20-byte compare is the sole gate
- Auth blob / keys versioned
- Stolen signature cannot authorize a different product/build (P1) or requires short-lived server token where SKU demands it (P2)
- TR-01 still passes on legitimate builds
- TR-08…TR-11 documented with pass/fail observables (not exploit steps)
- No single binary edit to one of {wrapper, compare, `__const` digest, `VCIH`} keeps a production session alive when P0–P3 are claimed done
- Byte-level patch exercises, if any, stay under NDA / private workshop

### P0–P2 patch-resistance contribution notes

- **P0:** Stronger crypto does not stop patching, but removes weak raw-hash shortcuts and enables versioned migration so patched old libs become obsolete.
- **P1:** Structured binding (build/config/validity) makes cloned or locally forced-true verify fail claim checks.
- **P2:** Short-lived server tokens bound offline patch success to renewing online attestation.

### Relationship to P0–P2 (chapter subsection)

Short closing subsection that points readers back to the per-priority **Patch-resistance contribution** notes under P0–P2 and states that crypto/binding/ops are complementary to local integrity — not substitutes for TR-08…TR-11 validation.

### Disclosure report light touch

- §7 P3 cell: point to `VENDOR_HARDENING.md` § Patch resistance (testing guide).
- T2 **Mapped mitigations**: update the P3 bullet to name that chapter and state that detailed patch-resistance *test* guidance (TR-01…TR-11) lives there.
- Do not expand T2’s Scenario/Prerequisites blocks again.

## Style and policy constraints

- Maintain factual, defensive-security, testing-engineer tone.
- All claims must be backed by existing repo artifacts.
- Classification header and confidentiality handling in `DISCLOSURE_REPORT.md` remain unchanged.
- Do not introduce new threat classes or severity ratings beyond what disclosure already states.

## Success criteria

- `VENDOR_HARDENING.md` contains the new chapter with all subsections listed above.
- Test matrix includes TR-01…TR-11 (signature + binary-patch intents).
- P0–P2 each include a patch-resistance contribution note; P3 points to the chapter.
- `DISCLOSURE_REPORT.md` §7 / T2 pointers name the new chapter.
- No exploit code, patch bytes, or forge instructions.
- `python research/verify_static_auth_poc.py` and `--self-test` still PASS.
- After implementation, `research/stil.md` item is checked off.

## Files touched

| File | Role |
|------|------|
| `research/VENDOR_HARDENING.md` | Modified — primary expansion |
| `research/DISCLOSURE_REPORT.md` | Modified — light pointers only |
| `research/VERIFY_PATH_MAP.md` | Referenced only |
| `research/verify_static_auth_poc.py` | Verification only (run, do not change unless broken) |
| `research/stil.md` | Checked off at end of implementation |
