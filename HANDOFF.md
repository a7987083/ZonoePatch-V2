# ZonoePatch-V3 developer handoff — P10.6.2

## Repository / baseline
- Repository: `a7987083/ZonoePatch-V2`.
- Active branch: `ZonoePatch-V3`; inspect `git rev-parse HEAD` before editing. Latest verified **source** commit: `7d522d0df2d502b450af1ce6f6833acfadc856a7`.
- Prior stable P10.5.1 baseline: `26846167806023ea882c3eebc24f3fe1e86ab531`; do not rewrite historical commits.
- CI: `https://github.com/a7987083/ZonoePatch-V2/actions/runs/41765604484`, completed/success on source commit above.
- Device/game runtime verification: **NOT PERFORMED**.

## Architecture and current data paths
- Config: `V3FeatureModels.h/.mm`, `V3ConfigRepository.mm`. Feature ID is a persisted UUID; do not derive it from display name.
- P10.6.1: `ZNUnifiedBuildPlan.hpp/.cpp` provides versioned read-only address/identity/conflict validation; `V3UnifiedBuildPlanner.mm` converts real saved Feature/Rule types and preflights loaded Mach-O identity, RW typed targets and static Patch rules.
- P9 legacy code path remains: `V3StaticBuildPlanner.mm` -> `V3StaticBinaryBuilder.mm` -> `V3StaticBinaryExport.mm` -> ad-hoc signer. Existing static entries stay 128 bytes; Customer P9 toggles unchanged.
- P10.3 standalone ZNT1 remains intact: `ZNTypedDescriptor.cpp` and `ZNTypedCustomerRuntime.mm`; old format may still be read independently.
- P10.6.2 ZNM2: `ZNMixedDescriptor.hpp/.cpp` stores independent numeric Feature IDs, real UTF-8 display names, contiguous first/count record ownership and a ZNT1 payload; unknown versions/overlap/duplicate IDs are rejected.
- Mixed image: `ZNTypedMachOBuilder.mm` exposes only an explicit `embedMixedDescriptorIntoPreparedStatic` pathway, validates P9 owned sections and static table, refuses repeated metadata and preserves old API fail-closed behavior.
- Opt-in production entry: `V3StaticBinaryExport.generateMixedMetadataForFeatures` requires both toggles and numeric features. It preflights combined writes, constructs one P9 image, appends ZNM2, performs one final CodeDirectory rebuild, verifies Static Table + metadata readback, then publishes to a unique staging-derived output directory. Numeric execution is explicitly disabled in its build report.
- **No UI wired to the mixed exporter**, and **Customer does not execute ZNM2 numeric features**. Avoid accidental feature exposure.

## Validation completed
- CI contract tests: `zn_unified_build_plan_test`, `zn_mixed_descriptor_test`, `v3_static_binary_smoke_test`, typed codec/runtime transaction tests, static slot transaction tests.
- Mixed smoke verifies two P9 toggles and two distinct numeric features, P9 initial OFF/group names, ZNM2 readback after signing, and malformed/duplicate/unprepared inputs rejected.
- CI rebuilt both arm64 Developer and Customer dylibs; do not equate this with installed IPA or actual iPhone validation.

## Boundaries / known risks
- Do not change P9 Static Entry ABI or reinterpret ZNM2 as ZNT1. Customer must explicitly opt into ZNM2 after P10.6.3 is tested.
- ZNM2 does not turn a data target into a code-hook. Number/Slider inputs currently require a file-backed aligned readable+writable data segment.
- The new mixed production entry is not yet device exercised. End-to-end testing against the target Mach-O and final re-signed IPA remains necessary.
- Maintain per-feature address ownership; reject overlapping numeric spans across all Feature IDs. A failed rollback must latch an error rather than claim Original restored.
- Some older README/KNOWN_ISSUES sections document P6 constraints and are historical; verify current source before relying on them.

## Next work
1. P10.6.3: Customer ZNM2 catalog, stable Feature ID and name binding, per-feature typed transactions, cross-feature address ownership, snapshot and recovery-failure latch. Keep old P9 and ZNT1 readers.
2. Add fault injection: concurrent feature attempts, overlapping widths, partial writes and rollback failure.
3. P10.6.4: only after Customer runtime regression, expose unified Builder in Developer UI, test layout, keyboard focus, and on-device ON/OFF/Original.

## P10.6.3 isolated Customer runtime (2026-11-04)

- Branch HEAD advances past the P10.6.2 baseline; verify current SHA and Actions after any documentation commit.
- Added `ZNMixedValueCoordinator.hpp/.cpp`: stores per-image/per-feature independent active transactions, reserves physical address spans, rejects overlaps (including across different images), and retains failed-rollback reservations with a global recovery latch. The actual byte reads/writes still occur through `ZNLiveTypedValue::Backend` and its live dyld/UUID/RW validation.
- Added `ZNMixedCustomerRuntime.h/.mm`: independent ZNM2 discovery from dyld, validates exact ARM64 image identity, P9 static dispatch segment/header, read-only ZNM2 section, Feature ID and descriptor snapshot; applies/restores per persisted Feature ID. The legacy `ZNTypedCustomerRuntime` (ZNT1) and P9 Customer runtime are unchanged.
- Customer Makefile now compiles ZNM2 decoder, coordinator and runtime. This API is **not connected to visible Customer UI**: no claim of actual user-facing numeric control or live device verification.
- Host CI `Test P10.6.3 Mixed Numeric Ownership and Recovery` performs fake-backend two-feature isolation, overlapping-span rejection, partial-write rollback, failed-rollback global lock and snapshot preservation; `Test P10.6.3 ZNM2 Customer API` confirms forged request rejection and no false lock. Existing typed transaction tests cover external-write detection. Synthetic tests cannot emulate actual dyld-loaded generated Mach-O or game runtime.
- Build verification: consult the latest `ZonoePatch-V3` workflow; do not infer from committed code. No real-device verification.
- Next: integrate new runtime with Customer UI only after explicit ZNM2 catalog verification on an actual target image; strengthen dynamic fault injection for mixed catalog, test cold boot, repeated ON/OFF and Original snapshot on target device. Then P10.6.4 UI and keyboard layout.
