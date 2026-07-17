# native_hardened

Vendor drop-in for `CreateSessionHardened` (VALIDATION_PACKAGE §6.6).

**Source of truth:** repo root [`CLAUDE.md`](../../CLAUDE.md) § **Native hardened kit (`research/native_hardened/`)**.  
Do not duplicate contract / backend / selftest details here — edit CLAUDE.md when facts change.

## Quick commands

```bash
make selftest                  # portable Ed25519 — zero external deps (default)
make selftest USE_LIBSODIUM=1  # optional libsodium backend
```

Merge steps: [`VENDOR_NATIVE_INTEGRATION.md`](VENDOR_NATIVE_INTEGRATION.md).
