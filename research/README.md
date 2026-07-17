# OCR Studio security research artifacts

Authorized research only (`Official Authorization for Security Research_ocrstudio.pdf`).

| File | Purpose |
|------|---------|
| `DISCLOSURE_REPORT.md` | **Send this to OCR Studio** — formal confidential disclosure |
| `VERIFY_PATH_MAP.md` | Symbol/offset/reloc map of `VSA` → `pkcs1_verify` / `__const` (no patch tooling) |
| `verify_path_map.json` | Machine-readable dump from `map_verify_path.py` |
| `map_verify_path.py` | Regenerates the verify-path map from carved arm64 `.o` slices |
| `verify_static_auth_poc.py` | Offline PKCS#1 verify PoC — PASS/FAIL against trial signature |
| `ocrstudio_pubkey_spki.pem` / `ocrstudio_pubkey_pkcs1.pem` | Recovered RSA-1024 public key |
| `VENDOR_HARDENING.md` | OEM mitigation recommendations |

```bash
python verify_static_auth_poc.py
python verify_static_auth_poc.py --self-test
```

End-to-end iOS: open `Samples/Swift/OCRStudioSDKSample.xcodeproj`, build on device/simulator. Trial signature is wired in `OCRStudioSDKSampleViewController.swift`; config comes from `OCRStudioSDKCore/config/*.ocr`.
