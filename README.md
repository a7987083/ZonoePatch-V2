# ZonoePatch V3 — iOS arm64 UIKit + Runtime Bytes Patch

Target: iOS 14+, arm64, Theos, Objective-C++. Repository branch: `ZonoePatch-V3`.

## Implemented

- Floating Z icon and window-scene-aware UIKit menu.
- Feature editor with one module picker (main executable or UnityFramework); editing an existing feature restores its saved module before the user changes it.
- Atomic `features-v1.json` storage for feature/rule definitions.
- Explicit RVA / Preferred VA / Runtime VA / File Offset resolution from loaded Mach-O segments. Unprefixed hexadecimal offsets are interpreted as RVA.
- Shared ARM64 HEX codec for saved rules and runtime preflight (4–256 bytes, multiple of 4). Hex input accepts optional `0x` and whitespace.
- **Read-only** runtime preflight: live Original-byte read, mapped file span, executable segment protection and Mach-O `LC_UUID` checks.
- P5.2 **isolated** Runtime Patch Executor: multi-action preflight, byte conflict checks, bounded code spans, per-write verification, rollback, explicit `RecoveryFailed` latch. Independent backend interface plus experimental RX→RW→RX Bytes writer. This backend is wired to the edit screen from P5.3, but success on non-jailbreak devices is **not verified**.
- CI: macOS host codec/address/config/**executor fault-injection**/static-build-plan regression executables, iOS arm64 build, `ldid -S` and SHA256 artifact.

- P6-A read-only static build plan: validates file-backed spans, disk/loaded UUID and Original equality, disjoint RVA/file ranges; emits a schema-stable diagnostic manifest (`binaryGenerated=false`). **No modified Mach-O is generated yet.**

## Not implemented / not verified

- Inline Hook and static Mach-O patch output (P6-A only establishes the verified build input; V2 Builder V3 port, code relocation and signing still pending). P5.3 adds a confirmed **Apply Patch / Restore Original** action for saved features only. The edit button is not a runtime hook and cannot guarantee RX code-page write permissions.
- Full iPhone device regression for actual applying/restoring bytes, code-signing and concurrent execution.
- Durable Patch Definition binding to a saved Mach-O UUID (UUID is read at preflight but not persisted). The current process session requires on-disk Original equality before first write, retains a single active transaction, and does not persist ON state.

The successful CI does **not** prove the target game is patchable or compatible with non-jailbreak executable-page restrictions. See `KNOWN_ISSUES.md`.

## Build

Push to `ZonoePatch-V3` or dispatch `.github/workflows/v3-build.yml`. The workflow pins Theos and Xcode/SDK versions.
