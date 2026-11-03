# ZonoePatch V3 — iOS arm64 UIKit + Read-only Patch Preflight

Target: iOS 14+, arm64, Theos, Objective-C++. Repository branch: `ZonoePatch-V3`.

## Implemented

- Floating Z icon and window-scene-aware UIKit menu.
- Feature editor with one module picker (main executable or UnityFramework); editing an existing feature restores its saved module before the user changes it.
- Atomic `features-v1.json` storage for feature/rule definitions.
- Explicit RVA / Preferred VA / Runtime VA / File Offset resolution from loaded Mach-O segments. Unprefixed hexadecimal offsets are interpreted as RVA.
- Shared ARM64 HEX codec for saved rules and runtime preflight (4–256 bytes, multiple of 4). Hex input accepts optional `0x` and whitespace.
- **Read-only** runtime preflight: live Original-byte read, mapped file span, executable segment protection and Mach-O `LC_UUID` checks.
- CI: macOS host codec/address/config regression executables, iOS arm64 build, `ldid -S` and SHA256 artifact.

## Not implemented / not verified

- Runtime memory writes, Code Patch activation/rollback, Inline Hook, static Mach-O patch output.
- Full iPhone device regression for the latest preflight changes.
- Durable Patch Definition binding to a saved Mach-O UUID (UUID is read at preflight but not persisted).

The successful CI does **not** prove the target game is patchable or compatible with non-jailbreak executable-page restrictions. See `KNOWN_ISSUES.md`.

## Build

Push to `ZonoePatch-V3` or dispatch `.github/workflows/v3-build.yml`. The workflow pins Theos and Xcode/SDK versions.
