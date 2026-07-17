# Design: Offline Static-Auth Verification PoC

**Date:** 2026-07-17  
**Status:** Approved  
**Scope:** Research verification only (authorized). No license bypass, forging, or binary patching.

## Goal

Prove the reverse-engineered `se::security` static-auth model against the shipped trial signature and recovered RSA public key, with a single runnable PASS/FAIL harness.

## Non-goals

- Signature forging / private-key recovery
- Patching `VSA` / `pkcs1_verify` in the xcframework
- Unlocking OCR sessions without a vendor signature

## Components

| Path | Role |
|------|------|
| `research/verify_static_auth_poc.py` | CLI PoC — RSA-1024 PKCS#1 v1.5 (raw SHA-1) verify |
| `research/ocrstudio_pubkey_spki.pem` | Recovered public key (input) |
| `doc/README.md` trial signature | Default 256-hex signature under test |

## Algorithm (mirrors BearSSL path)

1. Hex-decode 256-char signature → 128 bytes  
2. `EM = sig^e mod n` (public op), 128-byte big-endian  
3. Unpad PKCS#1 v1.5: `00 01 FF…FF 00 ‖ H` where `H` is **raw 20-byte SHA-1** (no DigestInfo OID — matches `br_rsa_pkcs1_vrfy(..., hash_oid=NULL, hash_len=20)`)  
4. Compare `H` to expected digest `SHA-1("ocrstudio_arafatgroup_trial")` = `25159e611dfa6f5f077a732a01d17ead8cc9770b`  
5. Exit 0 on PASS, 1 on FAIL  

## Success criteria

- Running the script with defaults prints PASS and exits 0  
- Tampering the signature or expected digest prints FAIL and exits 1  
- No network; stdlib-only Python 3.10+

## Test plan

1. `python research/verify_static_auth_poc.py` → PASS  
2. `python research/verify_static_auth_poc.py --self-test` → VCIH-style hash check PASS  
3. Flip one hex nibble of the signature → FAIL  
