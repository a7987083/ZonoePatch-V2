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

## P10.6.4 — Developer mixed-export UI wiring (2026-11-04)

- Source commit `2e687c0e67a6264d2a2c0342dc44c47323a078b0`; CI `41830592913` completed successfully (tests, both arm64 dylibs, uploaded artifact).
- `V3HookPage.mm` now preserves multi-selection across Toggle, NumberInput and Slider; it no longer resets selection when a numeric feature is picked.
- `V3FeatureEditor.mm` dynamically offers mixed export only for at least one Toggle plus one Numeric, same Mach-O module, no draft in progress and no active Runtime/Static Patch. Calls existing `V3StaticBinaryExport.generateMixedMetadataForFeatures` asynchronously. The preflight still validates UUID, RVA/file spans and numeric RW constraints. Legacy Toggle-only and single Numeric paths remain distinct.
- Explicit limitation: two-or-more purely numeric features without a Toggle remain unsupported by the exporter, and mixed Customer numeric controls are not yet connected to visible Customer UI. The mixed image contains executable P9 toggle state and metadata-only ZNM2 numeric features; do not claim full playable mixed features.
- Device work: install Developer dylib on a test IPA; save one Toggle and one Numeric in the **same** Mach-O, select both, generate, inspect `P10-Mixed-Metadata-*/build_report.json` and verify signed output before IPA re-sign. Test 1 Toggle+1 Input+1 Slider; reject differing modules and overlapping spans. Customer visible numeric controls still pending.
- CI cannot validate UIKit layout/keyboard, actual dyld-loaded target identity or final IPA installation. Those remain device pending.

## P10.7.1–P10.7.2 — ARM64 numeric instruction groundwork (2026-11-04)

- Verified source commit `ed09fdf11080a84ab529f4e3e30fd903aa8d9486`. GitHub Actions `41841402094` completed successfully; Developer and Customer arm64 dylibs compiled and artifact uploaded. No real device test.
- `ZNArm64NumericInstruction.hpp/.cpp`: bounded read-only classifier for scalar `FMOV S/D,#imm`, `MOVZ W/X`, `MOVN W/X`, and contiguous same-register `MOVK` chains (max 4 instructions). Rejects orphan MOVK, MOV register aliases (register dependency), `BL`, wrong width/type and malformed chains. Fixtures assembled with `clang -target aarch64-apple-darwin`; CI unit test gates actual encodings.
- `ZNArm64ValueCellPlan.hpp/.cpp`: pure encoder for `LDR S/D/W/X` PC-relative literal, NOP remainder and 4-/8-byte little-endian initial cell content. Requires naturally aligned cell and a signed 19-bit scaled displacement (−1 MiB to +1 MiB−4); refuses overlap and invalid instruction families. CI tests opcode fixtures, bounds and rejection paths.
- `V3StaticBuildPlanner.mm` now diagnoses selected code-type offsets using the exact disk-backed, UUID-matched ARM64 instructions and reports the classified family/register. **It deliberately still refuses R-X targets in the legacy RW-only numeric descriptor.**
- **NOT IMPLEMENTED:** Value Cell physical allocation in `__ZNDATA`, regeneration and relocation of P9 `__ZNTEXT` branch-safe variant payloads, ZNM3/compatible typed cell ownership metadata, Customer code Value Cell runtime/UI, complete mixed Mach-O execution or iPhone integration. These files are a tested *decoder/encoder core* only, not a working ARM64 numeric Patch Builder.
- Existing P9 `V3StaticBinaryBuilder.mm` checks `ZNV3InboundInterior` for branch entries into overwritten windows and uses Protection V2 fragmented variants; future integration must preserve that check and adapt its variant relocation, not blindly postprocess an existing signed Mach-O.
- The main source Offset (e.g. `0x35EDD20`) may be farther than ±1 MiB from `__ZNDATA`; any generated LDR must reside in an appropriately located, verified executable variant adjacent to its RW cell or use a separately validated bridge. Do not emit LDR blindly at the original source RVA.
- **Next:** implement code-type numeric site planning against *actual* loaded/disk UUID and Original instruction bytes, reserve Value Cells during owned segment layout, emit variant LDR through existing builder relocation and sign/read back; version metadata and Customer UI only after verified execution. First try `FMOV S0,#1.0` with exact target bytes and preserve P9 OFF/ON and rollbacks.

## P10.7.3–P10.7.4 — Code-window staging and synthetic P9 Value Cells (2026-11-04)

- Verified source state `a84e952652bf235ce72064965599c9190bdc2175` (branch `ZonoePatch-V3`); preceding P10.7.3 tested source `e176251ee7611501511d929257a7084e360caf4e`. Do not rewrite historical P9/P10 commits.
- `ZNArm64CodeSitePlan.hpp/.cpp`: read-only staging plan for bounded FMOV/MOVZ/MOVN/MOVK instruction windows, checked against byte-identical original executable section content. Rejects direct B/BL, B.cond, CBZ/CBNZ, TBZ/TBNZ branches targeting any interior instruction, duplicate ownership or RVA/file-offset overlap with P9 entries. Outputs Original and temporary NOP placeholder bytes for the existing P9 relocation path; it does not modify production code.
- `ZNArm64ValueCellPostprocess.hpp/.cpp`: **STAGING-ONLY**, invoked solely by synthetic Mach-O smoke tests, not any Developer exporter. Validates LC_UUID, exact owned P9 sections and header, matching selectedTarget OFF, original OFF fragment-chain bytes, NOP ON fragment-chain bytes, writable file-backed `__ZNDATA` tail slack, typed LDR range and cell alignment. After complete validation, inserts LDR S/W/D/X at first ON fragment, installs original typed value in a reserved independent RW cell, sets static value-cell marker bits, and requires external code signature regeneration.
- Synthetic smoke test now constructs P9 toggle + code-type FMOV Float32 slider + MOVZ Int32 input. Both cells have distinct RVAs; OFF fragment chains retain original code. ZNM2 owns both exact Feature IDs and points its numeric records at generated **RW cells**, not original R-X source addresses. Mach-O embedding, descriptor readback, regenerated CodeDirectory and readback checks are tested in CI. These tests do **not** prove runtime dispatch ON/OFF or real-device game behavior.
- **NOT PRODUCTION READY:** `V3StaticBinaryExport.generateMixedMetadataForFeatures` still only accepts numeric RW offsets; `V3UnifiedBuildPlanner` does not create code-type entries yet. The code-cell postprocessor is intentionally unused by this exporter and Customer UI remains unconnected. Do not suggest the new Developer dylib can generate R-X slider/input binaries.
- **NEXT:** design explicit code-cell Feature ownership/enable protocol (separate from existing P9 toggle UI and ZNM2 RW runtime), wire verified code-site plans into Developer export as a single transaction with staging and signatures, and connect Customer number/slider controls to P9 selectedTarget and ZNM2 cell transactions. Maintain fail-closed rollback and validate real iPhone target Mach-O UUID/Original bytes before device testing.
- **RISK:** indirect branch/exception/alternative entrypoints into a MOVK chain are not conclusively excluded by a direct-branch scan; additional static+dynamic confirmation is needed. Value-cell layout currently requires unused `__ZNDATA` file-backed slack and `LDR literal` ±1 MiB proximity; production must explicitly reserve capacity, not assume spare bytes. No real game input used for the synthetic CI.

## P10.7.5 — ZCB1 explicit code-cell ownership + Customer P9 visibility isolation (2026-11-04)

- Source code commit `9ec13524342e7bdbde1ae1ac5eaa4e62cf413fa1` (branch `ZonoePatch-V3`). Pure C++ `ZNCodeCellBinding.hpp/.cpp` introduces ZCB1 separate versioned data format, **not a modification of ZNM2 or P9 ABI**. Canonical LC_UUID, persisted numeric Feature ID, P9 one-based patchID, source instruction RVA, generated RW Cell RVA, numeric type and instruction count are required.
- ZCB1 validates length, canonical UUID, unique P9 slot IDs, unique nonoverlapping RW cells and original instruction windows. Multiple patch bindings may share one Feature ID (a single slider/input can own several Offset rules). Cross-catalog validator fail-closes unless each binding maps to exactly one P9 Value Cell-marked entry and one matching ZNM2 numeric record. Test suite covers multi-rule ownership, mismatch, duplicate slots, wrong UUID, malformed/trailing metadata and overlapping spans.
- Synthetic P9+Float32 Slider+Int32 Input Mach-O smoke now constructs ZCB1, validates it against **read-back** P9 Static Entries and independently encoded ZNM2 numeric records, and rejects missing P9 Value Cell flags. This is a synthetic static build test, not a dynamic Customer state transition.
- `ZNStaticEntryVisibility.hpp` and `V3CustomerRuntime.mm` hide P9 internal entries with `ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1` or `OFFSET_HOOK_V1` from ordinary Toggle rows, after validating owned slot and original catalog. Host visibility tests and both dylib builds gate this. Existing P9 Toggle entries remain visible.
- **Critical limitation:** ZCB1 is **not yet embedded** in the shipped Mach-O; no Customer ZCB1 discovery/validator/activation runtime is connected to the visible number/slider controls. The Developer R-X numeric export remains fail-closed, and no production mixed code-cell action can be claimed. The synthetic smoke constructs ZCB1 solely in test memory.
- Next integration must (1) reserve cells and export code-site entries transactionally, (2) embed signed ZCB1 sidecar/owned metadata section with immutable UUID and exact P9/ZNM2 bindings, (3) discover/verify all catalogs in Customer, (4) transact Cell value + selectedTarget ON/OFF and fail-closed recovery, and (5) render numeric controls with explicit per-image identity and verify device behavior. Do **not** infer ownership from UI names or blindly enable P9 synthetic toggle rows.
