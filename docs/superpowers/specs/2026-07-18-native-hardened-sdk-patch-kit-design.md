# Native Hardened SDK Patch Kit (Approach B)

**Date:** 2026-07-18  
**Status:** Approved — implement  
**Audience:** OCR Studio / Iron Software engine team

## Goal

Deliver a vendor-mergeable native patch kit under `research/native_hardened/` that implements `CreateSessionHardened` (VALIDATION_PACKAGE §6.6) with the same JWT/gate contract as the green Swift package on Codemagic.

## Non-goals

- Binary-patching `libocrstudiosdk.a`
- Signature forgery or license bypass tooling

## Layout

| Path | Role |
|------|------|
| `include/ocrstudiosdk/hardened_auth.h` | C API: gate status + verify |
| `src/hardened_auth.cpp` | JWT parse + gate order (CLAUDE.md) |
| `src/ed25519_verify_portable.c` | Portable Ed25519 verify for CI / reference |
| `include/objcocrstudiosdk/OCRStudioSDKInstance+Hardened.h` | ObjC++ category API |
| `src/OCRStudioSDKInstance+Hardened.mm` | Calls C verify, then legacy `createSession` on success |
| `tests/hardened_auth_selftest.cpp` | Codemagic-compilable self-test |
| `VENDOR_NATIVE_INTEGRATION.md` | Merge steps into OEM tree |

## Gate order (must match Swift)

1. Ed25519 over `header.payload`  
2. Temporal (`iat`/`exp`/48h/`iatFloor`)  
3. Identity (`aud`/`sub`/`platform`/`lib_build_id`/`config_sha256`)  
4. Nonce LRU  
5. Integrity hooks (code hash + VCIH; stub-ok in reference)

## CI

Codemagic: keep Swift `swift test`; add `make -C research/native_hardened selftest`.
