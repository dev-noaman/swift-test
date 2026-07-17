# Verify-path binary map (arm64 object files)

**Date:** 17 July 2026  
**Source:** carved arm64 slices from `OCRStudioSDKCore/lib/ocrstudiosdk.xcframework/ios-arm64_armv7_armv7s/libocrstudiosdk-ios.a`  
**Generator:** `research/map_verify_path.py` (+ relocation dump)  
**Authorization:** DocuSign `E86EA6F7-B675-8E96-8194-18360D9FF672`

**Scope:** descriptive symbol / offset / relocation map for remediation planning.  
**Does not include** patch bytes, bypass tooling, or signature-forge utilities.

Machine-readable dump: `research/verify_path_map.json`  
Auto-generated companion (may be thinner): `research/VERIFY_PATH_MAP.auto.md`

---

## Call chain

```
CreateSession(signature, …)
  → se::security::internal::VSA(const char*)          [static_auth.cpp.o @ 0xb4]
       ADRP+ADD → l001 (__const @ 0xe4)               // PUBKEY + EXPECTED_HASH blob
       B  (tail) → se::security::pkcs1_verify         [verify.cpp.o @ 0x0]
            BL → hexstring_to_bytes(256 hex → 128 B)
            BL → br_rsa_pkcs1_vrfy_get_default()
            → br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)
            → compare recovered digest[20] == EXPECTED_HASH[20]

  se::security::internal::VEA(sig, hash)              [static_auth.cpp.o @ 0xcc]
       same tail-call to pkcs1_verify (caller supplies hash ptr)

  se::security::internal::VCIH()                      [static_auth.cpp.o @ 0x0]
       BL → se::security::get_hash(...)               [hashing.cpp.o]
            BL → br_sha1_init / update / out
       compare to EXPECTED_HASH in same __const blob
```

---

## `static_auth.cpp.o.arm64.macho` (1736 bytes)

### Sections

| Segment | Section | VMA | Size | File off |
|---------|---------|-----|------|----------|
| `__TEXT` | `__text` | `0x0` | 228 | `0x1d0` |
| `__TEXT` | `__const` | `0xe4` | 195 | `0x2b4` |
| `__LD` | `__compact_unwind` | `0x1a8` | 160 | `0x378` |

### Defined symbols (entry points)

| Demangled | Mangled | Text VMA | Size (approx, to next) | Role |
|-----------|---------|----------|------------------------|------|
| `se::security::internal::VCIH()` | `__ZN2se8security8internal4VCIHEv` | `0x0` | ~0xa4 | Integrity: re-hash client id, compare to embedded digest |
| `se::security::internal::VGH()` | `__ZN2se8security8internal3VGHEv` | `0xa4` | ~8 | Related helper (tiny) |
| `se::security::internal::IDB()` | `__ZN2se8security8internal3IDBEv` | `0xac` | ~8 | Related helper (tiny) |
| `se::security::internal::VSA(char const*)` | `__ZN2se8security8internal3VSAEPKc` | `0xb4` | ~0x18 | **Primary static-auth entry** |
| `se::security::internal::VEA(char const*, uchar const*)` | `__ZN2se8security8internal3VEAEPKcPKh` | `0xcc` | ~0x18 | Auth with caller-supplied expected hash |
| `l001` | `l001` | `0xe4` | — | Label for embedded `__const` auth blob |

### Relocation-resolved calls / data refs (`__text`)

| At VMA | Reloc type | Target | Meaning |
|--------|------------|--------|---------|
| `0x24` / `0x28` | ADRP/ADD → `l001` | `__const` base | VCIH loads auth blob |
| `0x34` | BL | `se::security::get_hash` | SHA-1 for VCIH |
| `0xb8` / `0xbc` | ADRP/ADD → `l001` | `__const` | VSA loads PUBKEY + EXPECTED_HASH |
| `0xc4` | **B (tail)** | `se::security::pkcs1_verify` | VSA → verify |
| `0xd4` / `0xd8` | ADRP/ADD → `l001` | `__const` | VEA loads blob |
| `0xdc` | **B (tail)** | `se::security::pkcs1_verify` | VEA → verify |

Also: stack-canary refs (`___stack_chk_guard` / `___stack_chk_fail`) at several sites — not auth logic.

### Compare / branch sites in `__text`

| VMA | Kind | Context |
|-----|------|---------|
| `0x54`, `0x8c` | `CMP_reg` | Inside VCIH digest compare path |
| `0x90` | `B.cond` (ne) | VCIH fail/success branch |
| `0xb4` | `CBZ x0` | VSA: null signature → skip |
| `0xcc` | `CBZ x0` | VEA: null signature → skip |

Digest equality for PKCS#1 success is inside `pkcs1_verify` (see below), not a separate `memcmp` export from this object.

### Embedded `__const` layout (`l001` @ VMA `0xe4`, 195 bytes)

Matches vendor `CreateStaticAuthData(pub[132] ‖ marker ‖ hash[20])`:

| Offset | VMA | Size | Content |
|--------|-----|------|---------|
| `+0x00` | `0xe4` | 128 | RSA modulus `n` |
| `+0x80` | `0x164` | 4 | RSA exponent `e` = `00 00 00 03` |
| `+0x84` | `0x168` | 43 | Marker: `\0` + `se_client_id__ocrstudio_arafatgroup_trial` + `\0` |
| `+0xAF` | `0x193` | 20 | `EXPECTED_HASH` = `25159e611dfa6f5f077a732a01d17ead8cc9770b` |

Notes:

- Pubkey material for BearSSL is `n` (128) + `e` (4) = **132 bytes** at `+0x00`.
- Substring `ocrstudio_arafatgroup_trial` begins at `__const+0x93` (inside marker).
- `EXPECTED_HASH` = `SHA-1("ocrstudio_arafatgroup_trial")` (27 ASCII bytes) — confirmed by `verify_static_auth_poc.py --self-test`.

---

## `verify.cpp.o.arm64.macho` (1000 bytes)

### Sections

| Segment | Section | VMA | Size | File off |
|---------|---------|-----|------|----------|
| `__TEXT` | `__text` | `0x0` | 224 | `0x180` |
| `__LD` | `__compact_unwind` | `0xe0` | 32 | `0x260` |

### Defined symbol

| Demangled | Mangled | VMA |
|-----------|---------|-----|
| `se::security::pkcs1_verify(char const*, uchar const*, uchar const*)` | `__ZN2se8security12pkcs1_verifyEPKcPKhS4_` | `0x0` |

Args (from prior decompilation + call sites): `(signature_hex, pubkey_blob, expected_hash)`.

### Relocation-resolved calls

| At VMA | Target | Role |
|--------|--------|------|
| `0x60` | `se::security::hexstring_to_bytes` | 256 hex chars → 128-byte signature buffer |
| `0x68` | `br_rsa_pkcs1_vrfy_get_default` | BearSSL verifier factory |

Indirect: returned vrfy fn invoked with `hash_oid=NULL`, `hash_len=20` (raw SHA-1, no DigestInfo).

### Compare / branch sites

| VMA | Kind | Context |
|-----|------|---------|
| `0x28`, `0x2c`, `0x34` | `CBZ` | Null checks on args → early fail @ `0xb4` |
| `0xa4`, `0xc4` | `CMP_reg` | Post-verify / digest compare |
| `0xc8` | `B.cond` | Success vs fail |

---

## `hashing.cpp.o.arm64.macho` (888 bytes)

### Defined symbol

| Demangled | Mangled | VMA |
|-----------|---------|-----|
| `se::security::get_hash(...)` | `__ZN2se8security8get_hashEPKhNS0_10StrongTypeINS0_11ByteSizeTagEEE` | `0x0` |

### Relocation-resolved calls

| At VMA | Target |
|--------|--------|
| `0x34` | `br_sha1_init` |
| `0x44` | `br_sha1_update` |
| `0x50` | `br_sha1_out` |

Compare/branch at `0x64` / `0x68` — length / error path around SHA-1.

---

## Patch-surface summary (vendor hardening — not exploit steps)

| Priority for OEM | Site | Why it matters |
|------------------|------|----------------|
| P0 | Crypto upgrade (algo/key size) | RSA-1024 / e=3 / SHA-1 / raw PKCS#1 is the root weakness |
| P1 | `VSA` / `VEA` entry | Single offline gate; null-check + tail to verify |
| P1 | `pkcs1_verify` digest compare (`~0xa4`–`0xc8`) | Final boolean of auth |
| P2 | `VCIH` compare (`~0x54`–`0x90`) | Twin of auth hash; same constant — weak if both altered |
| P2 | `__const` blob @ `l001` | Fixed pubkey + expected digest; must version/rotate with keys |
| P3 | BearSSL `br_rsa_pkcs1_vrfy*` | Non-standard `hash_oid=NULL` mode |

Stable references for linked binaries: **use mangled symbol names**, not object-file VMAs (relocatable; shift after static link).

---

## Related artifacts

| Path | Role |
|------|------|
| `research/verify_static_auth_poc.py` | Offline verify-only PoC (PASS/FAIL) |
| `research/ocrstudio_pubkey_*.pem` | Recovered RSA-1024 public key |
| `research/VENDOR_HARDENING.md` | Mitigation backlog |
| `research/DISCLOSURE_REPORT.md` | Formal disclosure (§4 / §6 T2) |

---

*End of verify-path map.*
