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
- CI: macOS host codec/address/config/**executor fault-injection**/static-build-plan/**generated Mach-O + signer** regression executables, iOS arm64 build, `ldid -S` and SHA256 artifact.

- P6-A read-only static build plan: validates file-backed spans, disk/loaded UUID and Original equality, disjoint RVA/file ranges; emits a schema-stable diagnostic manifest (`binaryGenerated=false`). P6-B/P6-C exports a standalone ad-hoc-signed Mach-O through the separate export action.

## Not implemented / not verified

- P6-C Static Dispatch runtime is wired to its own `启用预埋静态 Patch / 关闭预埋静态 Patch` control. It writes only the preinstalled RW `selectedTarget` slots after verifying a SHA-256 binding of the Mach-O UUID, saved rule ID, exact RVA and Patch bytes. The loaded game behavior is **not device verified**. The generated file is not automatically installed and still requires final IPA re-signing.
- P6-C intentionally supports one active saved feature per process (with up to 128 non-overlapping rules). Multiple independent features/variants sharing physical sites and concurrent activation are not implemented. Each 8-byte pointer write is atomic, not a global atomic switch across all sites.

- P6-B generates a complete thin ARM64 Mach-O using V2's owned `__ZNTEXT` + `__ZNDATA` static dispatch layout, relocation and ad-hoc signature rebuilding. Use the saved feature's `生成预埋二进制（初始 OFF）` action; it exports under Documents/ZonoePatchOutput. The embedded variant defaults OFF. P5.3 adds a confirmed **Apply Patch / Restore Original** action for saved features only. The edit button is not a runtime hook and cannot guarantee RX code-page write permissions.
- Full iPhone device regression for Runtime Bytes Patch, P6-C cold-boot OFF / ON / OFF, image identity and startup, code-signing, and concurrent execution.
- Durable Patch Definition binding to a saved Mach-O UUID (UUID is read at preflight but not persisted). The current process session requires on-disk Original equality before first write, retains a single active transaction, and does not persist ON state.

The successful CI does **not** prove the installed target game loads, runs its OFF path correctly or can switch ON/OFF under live execution. See `KNOWN_ISSUES.md`.

## Customer Menu (P7)

The same branch builds two independent dylibs:

- `ZonoePatchV3.dylib` — developer UI, persisted rule editor, static binary generator and runtime diagnostics.
- `ZonoePatchCustomer.dylib` — minimal customer UI. Auto-discovers P6-C static-dispatch descriptors from already loaded signed Mach-O images, displays embedded feature names, and toggles RW `selectedTarget` slots. It does **not** link the builder, `features-v1.json`, patch editor, or RX bytes writer.

For customer deployment, generate a **fresh** prepared Mach-O with the latest developer dylib, replace the app's corresponding binary, sign the complete package, and inject **only** the customer dylib. Do not load both menu dylibs simultaneously. See `P7_CUSTOMER_RUNTIME.md`.

Customer runtime discovery and actual ON/OFF on a jailbroken iPhone remain **unverified**. CI only establishes compile, synthetic output, signer and fault-injection tests.

## Build

Push to `ZonoePatch-V3` or dispatch `.github/workflows/v3-build.yml`. The workflow pins Theos and Xcode/SDK versions.
