# Ship package — patched OCRStudioSDK (for OCR Studio / Iron Software)

**Commit / CI:** see latest green Codemagic on `swift-test` (`Hardened auth XCTest`).  
**Assessor:** Adel Noaman (`expert.winxp@gmail.com`)  
**Authorization:** DocuSign `E86EA6F7-B675-8E96-8194-18360D9FF672`

## What you are receiving

A **complete patched SDK integration tree** ready to merge and rebuild:

| Layer | Location | Status |
|-------|----------|--------|
| High-level iOS SDK | `OCRStudioSDK/Hardened/` + `OCRStudioSDKInstance` | **Enforced:** `initVideoSession` runs JWT gates before `createSession` (`hardenedAuthEnabled=YES` by default) |
| ObjC++ wrap | `OCRStudioSDKCore/wrap/.../OCRStudioSDKInstance+Hardened.*` | Drop-in `createSessionHardened…` |
| C engine API | `OCRStudioSDKCore/include/ocrstudiosdk/hardened_auth.h` + `hardened_auth.cpp` | Same gates (libsodium Ed25519) |
| Reference + CI | `research/verification`, `research/native_hardened` | Green on Codemagic |
| Sample | `Samples/Swift/OCRStudioSDKSample` | Links hardened Swift gate |

## What still requires your engine rebuild

The closed binary `libocrstudiosdk.a` / `ocrstudiosdk.xcframework` is **not** rewritten in this package (no private engine sources). After you merge `hardened_auth` into `se::security` and ship a new xcframework, move the same gates **inside** `CreateSession` / retire legacy.

Until then, apps built from **this tree** are protected at the `OCRStudioSDKInstance` layer (cannot start a video session without passing JWT gates).

## How to verify locally (Mac)

```bash
# Reference CI suite
cd research/verification && swift test
cd research/native_hardened && brew install libsodium && make selftest

# Sample app
open Samples/Swift/OCRStudioSDKSample.xcodeproj
# Build OCRStudioSDKSample — session init must log "Hardened auth OK"
```

## Vendor merge checklist

1. Merge `hardened_auth.*` into the static library build; link Ed25519.
2. Bake production Ed25519 **server public key** (remove trial auto-mint seed from `OCRStudioSDKHardenedAuth.swift`).
3. Point host apps at Auth Server mint (`research/verification/reference_server_mint.py` contract).
4. Phase out legacy-only `createSession:` (see `VALIDATION_PACKAGE.md` §6.13).
5. Wire P3 integrity hooks (code-region hash + hardened VCIH).

## Contact

- Assessor: `expert.winxp@gmail.com`
- Vendor contact: `daniel.mahony@ocrstudio.ai`
