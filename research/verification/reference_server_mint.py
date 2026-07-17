#!/usr/bin/env python3
"""
Reference vendor Auth Server — Ed25519 attestation JWT mint.

Authorized security-research reference implementation for the OCRStudioSDK
hardening design (VALIDATION_PACKAGE.md §6.4, §6.2). This is NOT the shipped
vendor server; it demonstrates the *shape* of the attestation the hardened
SDK path (§6.2.3) would consume so that HardenedAuthWrapper.swift and
OCRAuthHardenedTests.swift have a concrete, interoperable token format.

Design (VALIDATION_PACKAGE.md §6.2.2 / §6.4):
    POST /attest {app_id, build_id, device_nonce, config_sha256}
      -> {jwt, iat, exp}

The JWT is a compact, Ed25519-signed token (alg="EdDSA"). We build it by hand
with PyNaCl rather than leaning on PyJWT's provider stack so the exact bytes
that get signed are unambiguous and match the Swift verifier 1:1:

    signing_input = base64url(header) + "." + base64url(payload)
    signature     = Ed25519_sign(signing_input.encode("ascii"))   # raw 64 bytes
    jwt           = signing_input + "." + base64url(signature)

Claims (canonical order, VALIDATION_PACKAGE.md §6.2.2):
    sub, lib_build_id, platform, config_sha256, iat, exp, nonce, aud

SECURITY NOTES (reference only — a production server MUST):
  * hold the Ed25519 private key in an HSM / KMS, never on the app box;
  * persist issued nonces in a TTL store to block server-side replay (§6.10);
  * authenticate the caller (app_id + attested device) before minting;
  * bake the *next* rotation public key into every SDK build (§10 residual).

Usage:
  python reference_server_mint.py --gen-key [--seed <hex32>]     # print a keypair
  python reference_server_mint.py --mint --priv <hex64> \
        --build-id "1.3.1-ios-arm64-trial-2026Q3" \
        --config-sha256 <hex64> --now <epoch>                    # print one JWT
  python reference_server_mint.py --serve --priv <hex64>         # run Flask endpoint

`--now` is accepted so tests can mint deterministic tokens without a wall clock.
"""

from __future__ import annotations

import argparse
import base64
import json
import sys
import time
from typing import Any

try:
    from nacl import signing
except ImportError:  # pragma: no cover - dependency hint
    signing = None  # type: ignore

# --- Baked policy (mirrors HardenedAuthWrapper.swift HardenedAuthConfig) ------
CLIENT_ID = "ocrstudio_arafatgroup_trial"          # -> claim "sub"
DEFAULT_BUILD_ID = "1.3.1-ios-arm64-trial-2026Q3"   # -> claim "lib_build_id"
PLATFORM = "ios"                                     # -> claim "platform"
AUDIENCE = "ocrstudio-sdk"                           # -> claim "aud"
DEFAULT_TTL_SECONDS = 24 * 60 * 60                   # §6.2.3 exp = now + 24h
# §8.2 hard cap: server must never mint a token whose lifetime exceeds 48h.
MAX_TTL_SECONDS = 48 * 60 * 60


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _require_nacl() -> None:
    if signing is None:
        sys.exit("PyNaCl is required: pip install PyNaCl")


def gen_keypair(seed_hex: str | None = None) -> tuple[str, str]:
    """Return (private_hex[64], public_hex[64]). Deterministic when seed given."""
    _require_nacl()
    if seed_hex is not None:
        seed = bytes.fromhex(seed_hex)
        if len(seed) != 32:
            raise ValueError("seed must be 32 bytes (64 hex chars)")
        sk = signing.SigningKey(seed)
    else:
        sk = signing.SigningKey.generate()
    priv_hex = bytes(sk).hex()
    pub_hex = bytes(sk.verify_key).hex()
    return priv_hex, pub_hex


def mint_jwt(
    priv_hex: str,
    *,
    build_id: str = DEFAULT_BUILD_ID,
    config_sha256: str,
    device_nonce: str,
    now: int | None = None,
    ttl: int = DEFAULT_TTL_SECONDS,
    sub: str = CLIENT_ID,
    platform: str = PLATFORM,
    aud: str = AUDIENCE,
) -> tuple[str, int, int]:
    """Build and Ed25519-sign one attestation JWT. Returns (jwt, iat, exp)."""
    _require_nacl()
    if ttl > MAX_TTL_SECONDS:
        raise ValueError(f"ttl {ttl}s exceeds {MAX_TTL_SECONDS}s hard cap")
    if len(bytes.fromhex(config_sha256)) != 32:
        raise ValueError("config_sha256 must be 32 bytes (64 hex chars)")

    iat = int(time.time()) if now is None else int(now)
    exp = iat + ttl

    sk = signing.SigningKey(bytes.fromhex(priv_hex))
    header = {"alg": "EdDSA", "typ": "JWT"}
    payload: dict[str, Any] = {
        "sub": sub,
        "lib_build_id": build_id,
        "platform": platform,
        "config_sha256": config_sha256,
        "iat": iat,
        "exp": exp,
        "nonce": device_nonce,
        "aud": aud,
    }
    # Compact, key-order-stable JSON so the signed bytes are reproducible.
    seg = lambda obj: b64url_encode(
        json.dumps(obj, separators=(",", ":"), sort_keys=False).encode("utf-8")
    )
    signing_input = f"{seg(header)}.{seg(payload)}"
    sig = sk.sign(signing_input.encode("ascii")).signature  # raw 64 bytes
    jwt = f"{signing_input}.{b64url_encode(sig)}"
    return jwt, iat, exp


def _build_flask_app(priv_hex: str):
    from flask import Flask, jsonify, request  # local import: optional dependency

    app = Flask(__name__)

    @app.post("/attest")
    def attest():
        body = request.get_json(silent=True) or {}
        missing = [k for k in ("app_id", "build_id", "device_nonce", "config_sha256") if k not in body]
        if missing:
            return jsonify(error=f"missing fields: {', '.join(missing)}"), 400
        try:
            jwt, iat, exp = mint_jwt(
                priv_hex,
                build_id=body["build_id"],
                config_sha256=body["config_sha256"],
                device_nonce=body["device_nonce"],
            )
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        # NOTE: production must record device_nonce in a TTL store here (§6.10).
        return jsonify(jwt=jwt, iat=iat, exp=exp)

    return app


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gen-key", action="store_true", help="print an Ed25519 keypair")
    p.add_argument("--seed", default=None, help="32-byte hex seed for deterministic --gen-key")
    p.add_argument("--mint", action="store_true", help="print one JWT and exit")
    p.add_argument("--serve", action="store_true", help="run the /attest Flask endpoint")
    p.add_argument("--priv", default=None, help="Ed25519 private key hex (64 bytes)")
    p.add_argument("--build-id", default=DEFAULT_BUILD_ID)
    p.add_argument("--config-sha256", default="00" * 32, help="hex SHA-256 of config/*.ocr")
    p.add_argument("--nonce", default="00000000-0000-4000-8000-000000000000")
    p.add_argument("--now", type=int, default=None, help="override iat (epoch seconds)")
    p.add_argument("--ttl", type=int, default=DEFAULT_TTL_SECONDS)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=8787)
    args = p.parse_args(argv)

    if args.gen_key:
        priv, pub = gen_keypair(args.seed)
        print(json.dumps({"private_hex": priv, "public_hex": pub}, indent=2))
        return 0

    if args.mint:
        if not args.priv:
            sys.exit("--mint requires --priv")
        jwt, iat, exp = mint_jwt(
            args.priv,
            build_id=args.build_id,
            config_sha256=args.config_sha256,
            device_nonce=args.nonce,
            now=args.now,
            ttl=args.ttl,
        )
        print(json.dumps({"jwt": jwt, "iat": iat, "exp": exp}, indent=2))
        return 0

    if args.serve:
        if not args.priv:
            sys.exit("--serve requires --priv")
        app = _build_flask_app(args.priv)
        app.run(host=args.host, port=args.port)
        return 0

    p.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
