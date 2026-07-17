# OCR Studio security research artifacts

Authorized research only (`Official Authorization for Security Research_ocrstudio.pdf`).

| File | Purpose |
|------|---------|
| `../CLAUDE.md` (§ Security Assessment Disclosure) | **Canonical disclosure (source of truth)** — send/export from there |
| `DISCLOSURE_REPORT.md` | Stub only — redirects to `CLAUDE.md` |
| `VERIFY_PATH_MAP.md` | Symbol/offset/reloc map of `VSA` → `pkcs1_verify` / `__const` (no patch tooling) |
| `verify_path_map.json` | Machine-readable dump from `map_verify_path.py` |
| `map_verify_path.py` | Regenerates the verify-path map from carved arm64 `.o` slices |
| `verify_static_auth_poc.py` | Offline PKCS#1 verify PoC — PASS/FAIL against trial signature |
| `ocrstudio_pubkey_spki.pem` / `ocrstudio_pubkey_pkcs1.pem` | Recovered RSA-1024 public key |
| `check_binary_poc.py` | Carves arm64 `static_auth.cpp.o` from the shipped `.a` and byte-compares `__const` vs PoC constants |
| `VENDOR_HARDENING.md` | OEM mitigation recommendations |
| `VALIDATION_PACKAGE.md` | Full authorization validation + remediation package (references the artifacts below) |
| `verification/reference_server_mint.py` | Reference vendor Ed25519 attestation-JWT mint (mint/serve/gen-key) |
| `verification/Package.swift` | SwiftPM package for Codemagic / `swift test` |
| `verification/Sources/HardenedAuth/HardenedAuthWrapper.swift` | Reference client wrapper: four-gate verifier + Keychain token cache (§6) |
| `verification/Tests/HardenedAuthTests/OCRAuthHardenedTests.swift` | XCTest suite proving vuln-before / hardened-after (§8) |

```bash
python verify_static_auth_poc.py
python verify_static_auth_poc.py --self-test

# Hardened-auth XCTest (macOS / Codemagic):
cd verification && swift test
```

End-to-end iOS: open `Samples/Swift/OCRStudioSDKSample.xcodeproj`, build on device/simulator. Trial signature is wired in `OCRStudioSDKSampleViewController.swift`; config comes from `OCRStudioSDKCore/config/*.ocr`.
