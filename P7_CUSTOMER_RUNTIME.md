# P7 Customer Runtime Menu — Deployment Contract

## Build targets

- **Developer:** `ZonoePatchV3.dylib`, unchanged feature editor, Runtime Bytes Patch, P6-C static generator.
- **Customer:** `ZonoePatchCustomer.dylib`, contains only floating Z UI, read-only image discovery, embedded Static Dispatch toggles and rollback transaction. No generator, source patch editing, config JSON or runtime RX bytes writer.
- Both artifacts are built by `.github/workflows/v3-build.yml` on `ZonoePatch-V3`.
- **Use only one menu dylib per installed app.** Do not inject developer and customer targets into the same app.

## Static binary and customer menu deployment

1. In the developer build, save the feature name and rules and export a fresh P7-compatible P6-C static Mach-O. Older P6-B builds lack `P6C1:` bound metadata; older P6-C builds may show raw rule IDs rather than friendly names.
2. Replace the matching original binary in the target app package with the output generated Mach-O; preserve the required app framework/bundle structure.
3. Integrate the **Customer** dylib using the chosen supported jailbroken injection/package workflow and perform final application/package signing. The on-device menu does not generate, replace, or install Mach-O files.
4. Open the app and the floating Z: customer menu auto-discovers verified `__ZNTEXT`/`__ZNDATA` static descriptors in already loaded arm64 images and displays feature names plus rule counts. No `features-v1.json` required.
5. Each button switches the corresponding installed image's selectedTarget group through preflight, 8-byte atomic stores, readback, and rollback. OFF follows the relocated Original path.

## Explicit restrictions

- The current builder exports **one saved feature per generated target Mach-O**. Multiple prepared images may be listed, but competing physical sites, shared-site owner stacks, and dynamic simultaneous multi-feature merging are not yet implemented.
- One logical feature with multiple rules is updated sequentially. This is a rollback transaction, not a global stop-the-world atomic group update.
- The customer menu trusts the installed Mach-O's signed contents and validates the descriptor marker, table bounds, source UUID existence, executable and writable mappings, and legal target values. A `P6C1:` marker is a format check in customer mode, **not independent proof** of the developer's original Patch bytes.
- Runtime detection cannot guarantee an unloaded image will remain mapped through a write; real-device concurrency and dyld unload behavior remain unverified.
- Feature label in the fixed 48-byte `ZN44StaticEntry.title` may be truncated.
- Do not distribute the developer dylib to a customer expecting an automatically discovered no-config menu.
- **No real game/device install/run evidence** exists yet. Host CI and arm64 compilation are not real-device validation.

## Required device acceptance

- Original app cold start and patched app cold start (OFF) compared.
- Customer floating menu, feature discovery without config, ON behavior, OFF Original equivalence.
- Multiple rules, repeated ON/OFF, process kill and relaunch, UnityFramework image load timing.
- Invalid/missing descriptor, signature mismatch, page protection changes, duplicate/overlapping slots.
- User menu + developer menu never co-loaded.
