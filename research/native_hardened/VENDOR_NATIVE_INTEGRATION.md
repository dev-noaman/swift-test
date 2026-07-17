# Vendor integration — native CreateSessionHardened

Authorized security-research drop-in for OCR Studio engine team.

**Source of truth** for layout, Ed25519 backends, selftest scope, and JWT contract:  
repo root `CLAUDE.md` § **Native hardened kit (`research/native_hardened/`)**.

## What this package is

| Path | Merge into |
|------|------------|
| `include/ocrstudiosdk/hardened_auth.h` | Public / internal C API next to `ocr_studio_instance.h` |
| `src/hardened_auth.cpp` | Engine security TU — calls `hardened_ed25519_verify` (backend-agnostic) |
| `src/ed25519_verify.h` / `src/ed25519_verify_portable.c` | Ed25519 verify: portable (default) or `-DUSE_LIBSODIUM`. Swap for your BearSSL/HACL* if preferred. |
| `src/ed25519_constants.h` | Machine-generated, Python-verified SHA-512 + Ed25519 constants (portable backend) |
| `include/objcocrstudiosdk/OCRStudioSDKInstance+Hardened.h` | ObjC++ wrap public headers |
| `src/OCRStudioSDKInstance+Hardened.mm` | ObjC++ wrap sources; bake real Ed25519 **server public key** |

### Ed25519 backend switch

```bash
make selftest                 # portable, no external deps (default)
make selftest USE_LIBSODIUM=1  # libsodium (brew install libsodium pkg-config)
```

The portable backend is a public-domain TweetNaCl-derived verify; its constants
are Python-verified against canonical TweetNaCl / `hashlib`, and the algorithm
was validated against PyNaCl before translation. Both backends satisfy the same
`hardened_ed25519_verify()` contract, so `hardened_auth.cpp` is unchanged either way.

Green CI evidence (assessor):

- Swift package: Codemagic workflow **Hardened auth XCTest**
- Native C++: Codemagic step `make -C research/native_hardened selftest` (portable)
  and, optionally, `make -C research/native_hardened selftest USE_LIBSODIUM=1`

## Wire contract (must match Swift / Python mint)

Compact JWS, `alg=EdDSA`, raw 64-byte Ed25519 over ASCII `header.payload`.  
Claims: `sub, lib_build_id, platform, config_sha256, iat, exp, nonce, aud`.  
Gate order: signature → temporal → identity → nonce → integrity hooks.

Source of truth: repo root `CLAUDE.md` § Hardened-Auth Reference Package.

## Merge steps (engine)

1. Add `hardened_auth.cpp` to the static library build; link Ed25519 verify.
2. Bake per-SKU: `client_id`, `lib_build_id`, Ed25519 pubkey, `iat_floor`.
3. Expose ObjC++ `createSessionHardenedWithSignature:attestation:…` (this category).
4. **Phase 1:** keep `createSession:` working; document hardened as preferred.
5. **Phase 3:** make `createSession:` call `ocr_create_session_hardened_check` with empty JWT → fail (or remove).
6. Wire integrity hooks to real code-region hash + hardened `VCIH` (P3).
7. Ship Auth Server that mints JWTs (`research/verification/reference_server_mint.py` shape).

## Host app call shape

```objc
NSString *cfgHash = /* SHA-256 hex of .ocr bytes */;
OCRAuthGateStatus st = OCRAuthGateStatusOK;
NSError *err = nil;
OBJCOCRStudioSDKSession *session =
  [instance createSessionHardenedWithSignature:legacySig
                                   attestation:jwt
                        withJsonSessionParams:params
                               configSHA256Hex:cfgHash
                                    gateStatus:&st
                                         error:&err
                                      delegate:nil];
if (!session) { /* st / err */ }
```

## Out of scope

This kit does **not** rewrite the closed trial `libocrstudiosdk.a`. You merge these sources into your internal engine tree and ship a new xcframework.
