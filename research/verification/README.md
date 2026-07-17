# HardenedAuth (fully patched reference surface)

SwiftPM package that **implements and tests** the post-patch auth design
(`CreateSessionHardened`, Phase 3). Codemagic runs `swift test` on every push.

## Honest scope

| This package | The trial `libocrstudiosdk` binary |
|--------------|-------------------------------------|
| Phase-3 gates enforced in Swift | Still the old RSA-1024 `VSA` path |
| Proven on Codemagic | Not rewritten (closed source) |

Apps integrating this reference must call `CreateSessionHardened` / `HardenedAuthWrapper`
and **never** call legacy `CreateSession` directly. OEM shipping moves the same
gates into the native engine.

## Local / CI

```bash
cd research/verification
swift test
```
