# Design: Deepen T1–T3 Narrative in OCR Studio Disclosure Report

**Date:** 2026-07-17  
**Related task:** `research/stil.md` — `- [ ] Deepen disclosure T1–T3 narrative`  
**Target file:** `research/DISCLOSURE_REPORT.md`  
**Approach:** A — expand in-place in §6 (approved by user)

---

## Goal

Enhance the threat-class narrative in `research/DISCLOSURE_REPORT.md` §6 for **T1 — Signature theft / clone**, **T2 — Binary patch of verify path**, and **T3 — Cryptographic weakness of the scheme**. The expanded text should give the OEM security team enough technical context to prioritize remediations, while staying within the authorized, non-weaponized disclosure scope.

## Out of scope

- No exploit code, patch bytes, or bypass instructions.
- No signature-forging implementation or private-key recovery claims.
- T4 (weak payload binding) will be left as-is, used only as a cross-reference where relevant.
- The second `research/stil.md` item (`Expand VENDOR_HARDENING patch section`) is a follow-on task.

## Structure for each threat

For T1, T2, and T3, replace the current single-paragraph description with the following consistent subsections:

1. **Scenario** — concrete, non-weaponized walkthrough of how the weakness could be exploited.
2. **Prerequisites** — what an attacker must possess, access, or control.
3. **Impact** — what successful exploitation achieves.
4. **Observable indicators** — how abuse or tampering might be detected in the field.
5. **Mapped mitigations** — explicit pointer to relevant items in §7 and `research/VENDOR_HARDENING.md` (P0–P3).

## Content specifics

### T1 — Signature theft / clone

- Explain the offline nature of verification and why the 256-hex signature can be reused across apps embedding the same library build.
- Reference that the signature is not bound to bundle ID, device, time, or config hash.
- Map to P2 operational controls (server-delivered tokens, separate trial/production keypairs).

### T2 — Binary patch of verify path

- Reference descriptive anchors from `research/VERIFY_PATH_MAP.md` (object files, mangled symbol names, `__const` blob role).
- Explain that `VSA` / `VEA` are thin wrappers tail-branching into `pkcs1_verify`, and that `VCIH` reuses the same digest constant.
- Describe the patch surface conceptually (entry point, compare branches, constant blob) without providing byte-level patch recipes.
- Map to P3 anti-patch/integrity recommendations and P0 crypto upgrade.

### T3 — Cryptographic weakness of the scheme

- Detail why RSA-1024 / e=3 / SHA-1 / raw PKCS#1 v1.5 is dated relative to modern standards.
- Note the non-standard `hash_oid=NULL` raw-hash mode used with BearSSL.
- Reiterate that no practical forge was produced in this assessment and that forging still requires the private key or a cryptographic attack.
- Map to P0 crypto upgrade (RSA-2048+/PSS or Ed25519, SHA-256+).

## Style and policy constraints

- Keep classification header and confidentiality handling unchanged.
- Maintain factual, defensive-security tone.
- All claims must be backed by artifacts already in the repo (`VERIFY_PATH_MAP.md`, `VENDOR_HARDENING.md`, PoC output, recovered public key files).
- Do not introduce new threat classes or change severity ratings.

## Success criteria

- `DISCLOSURE_REPORT.md` §6 contains expanded T1, T2, and T3 sections with the five subsections each.
- Each threat maps explicitly to §7 / `VENDOR_HARDENING.md` priorities.
- No exploit code, patch bytes, or forge instructions are introduced.
- The file renders correctly as Markdown and internal cross-references remain valid.

## Files touched

- `research/DISCLOSURE_REPORT.md` (modified)
- `research/VERIFY_PATH_MAP.md` (referenced, not modified)
- `research/VENDOR_HARDENING.md` (referenced, not modified)
