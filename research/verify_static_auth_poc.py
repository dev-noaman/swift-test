#!/usr/bin/env python3
"""
OCR Studio static-auth verification PoC (authorized security research).

Reimplements the offline verify path discovered in the trial xcframework:
  VSA(signature) -> pkcs1_verify(sig, PUBKEY, EXPECTED_HASH)

BearSSL is called as:
  br_rsa_pkcs1_vrfy(sig, 128, hash_oid=NULL, hash_len=20, &pubkey, &digest)

With hash_oid=NULL, PKCS#1 v1.5 padding carries a *raw* 20-byte SHA-1 digest
(no ASN.1 DigestInfo). That is intentional OEM behaviour — standard
cryptography PKCS1v15+SHA1 verify will reject these signatures.

Usage:
  python verify_static_auth_poc.py
  python verify_static_auth_poc.py --self-test
  python verify_static_auth_poc.py --signature <256-hex>
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

# Embedded constants recovered from static_auth.cpp.o __const (see CLAUDE.md)
RSA_N_HEX = (
    "aa81d3f7eb1996c8ffd6d119451d60554d1d2924d2a6fd8e035dff9fcf29b3d5"
    "9046835374fab7dfa823c02c4f553ebe21e34277aa12c1cbf1df3e18d6e1eea6"
    "76f1628520b80db807e8b1a911c19797b7cd4c3c66eab2dab0daaafbe765c372"
    "b62d0825b8e2023a1fd2e88a22df338fa2e267a67bbf89613ac1d836cea1bf39"
)
RSA_E = 3
CLIENT_ID = "ocrstudio_arafatgroup_trial"
EXPECTED_HASH_HEX = "25159e611dfa6f5f077a732a01d17ead8cc9770b"

# Trial signature from doc/README.md (locks to this library copy)
TRIAL_SIGNATURE_HEX = (
    "2122df27f3d5cc5c0cf5ff02e651b2dde1b1dd49bfdd185a192092ee68c674b5"
    "e138bfbe2e528d6926b5ee234b59929832555359d7a61544a626f04931a4d82f"
    "727a088dd0ffd73009f28449780a407f74c068de29c7bd7b767f2c8006fae95a"
    "918782bdb388a7caf492af8f44d3f973da66fc37f73f19f66e71848e93c6556e"
)

RESEARCH_DIR = Path(__file__).resolve().parent
MODULUS_BYTES = 128
HASH_LEN = 20


def expected_digest() -> bytes:
    return hashlib.sha1(CLIENT_ID.encode("ascii")).digest()


def load_n_from_pem() -> int | None:
    """Prefer recovered SPKI PEM if present; fall back to hardcoded n."""
    spki = RESEARCH_DIR / "ocrstudio_pubkey_spki.pem"
    if not spki.is_file():
        return None
    try:
        from cryptography.hazmat.primitives import serialization
    except ImportError:
        return None
    pub = serialization.load_pem_public_key(spki.read_bytes())
    return pub.public_numbers().n


def pkcs1_v15_raw_sha1_verify(signature: bytes, n: int, e: int, expected: bytes) -> tuple[bool, str]:
    """BearSSL-compatible PKCS#1 v1.5 verify with raw SHA-1 (no DigestInfo)."""
    if len(signature) != MODULUS_BYTES:
        return False, f"signature length {len(signature)} != {MODULUS_BYTES}"
    if len(expected) != HASH_LEN:
        return False, f"expected digest length {len(expected)} != {HASH_LEN}"

    em = pow(int.from_bytes(signature, "big"), e, n).to_bytes(MODULUS_BYTES, "big")

    if em[0] != 0x00 or em[1] != 0x01:
        return False, f"bad PKCS#1 header: {em[:2].hex()}"

    # PS must be at least 8 FF bytes; then 00 separator; then hash
    sep = em.find(b"\x00", 2)
    if sep < 0:
        return False, "missing 0x00 separator after PS"
    if sep < 10:  # indices 2..9 inclusive => 8 bytes minimum PS
        return False, f"PS too short (sep at {sep})"
    if any(b != 0xFF for b in em[2:sep]):
        return False, "non-FF byte in PS"

    digest = em[sep + 1 :]
    if len(digest) != HASH_LEN:
        return False, f"recovered digest length {len(digest)} != {HASH_LEN}"
    if digest != expected:
        return False, f"digest mismatch: got {digest.hex()} want {expected.hex()}"
    return True, "ok"


def parse_signature_hex(text: str) -> bytes:
    cleaned = "".join(text.split())
    if len(cleaned) != 256:
        raise ValueError(f"signature must be 256 hex chars, got {len(cleaned)}")
    return bytes.fromhex(cleaned)


def run_self_test() -> int:
    digest = expected_digest()
    ok = digest.hex() == EXPECTED_HASH_HEX
    print("=== VCIH-style self-check ===")
    print(f"  client_id : {CLIENT_ID!r}")
    print(f"  SHA-1     : {digest.hex()}")
    print(f"  expected  : {EXPECTED_HASH_HEX}")
    print(f"  result    : {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--signature",
        default=TRIAL_SIGNATURE_HEX,
        help="256-hex PKCS#1 signature (default: trial signature from doc/README.md)",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Only check SHA-1(client_id) against embedded expected digest",
    )
    parser.add_argument(
        "--n-hex",
        default=None,
        help="Override RSA modulus as hex (default: PEM or embedded constant)",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return run_self_test()

    expected = expected_digest()
    if expected.hex() != EXPECTED_HASH_HEX:
        print("FAIL: local SHA-1(client_id) does not match embedded constant")
        return 1

    if args.n_hex:
        n = int(args.n_hex, 16)
        n_source = "--n-hex"
    else:
        pem_n = load_n_from_pem()
        n = pem_n if pem_n is not None else int(RSA_N_HEX, 16)
        n_source = "ocrstudio_pubkey_spki.pem" if pem_n is not None else "embedded RSA_N_HEX"

    if n != int(RSA_N_HEX, 16):
        print(f"WARN: modulus from {n_source} differs from embedded constant")

    try:
        signature = parse_signature_hex(args.signature)
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    ok, detail = pkcs1_v15_raw_sha1_verify(signature, n, RSA_E, expected)

    print("=== OCR Studio static-auth verify PoC ===")
    print(f"  modulus   : {n_source} ({n.bit_length()} bit)")
    print(f"  exponent  : {RSA_E}")
    print(f"  client_id : {CLIENT_ID!r}")
    print(f"  expected  : {expected.hex()}")
    print(f"  sig[0:16] : {signature[:8].hex()}…")
    print(f"  detail    : {detail}")
    print(f"  result    : {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
