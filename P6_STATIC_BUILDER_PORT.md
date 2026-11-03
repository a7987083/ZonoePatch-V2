# P6 Static Binary Builder V3 Port — Audit and Handoff

## Immutable baseline

- V3 branch: `ZonoePatch-V3`; preceding P5.3 baseline: `94a96d49efbbddc73864ec1f46a1cb934e675cad`.
- V2 reference branch: `dev/technical-debt-p0-p2-20261013`, read-only source of the original static generation design.
- H5GG reference: `H5GG/H5GG` `main`, `pluginDemo/h5frida15.1.24/static-inline.mm` for conceptual comparison only; layout and descriptor formats are not interchangeable.

## Completed in P6-A

- `V3StaticBuildPlan.h/mm` and `V3StaticBuildPlanner.mm` provide a read-only immutable plan, backed by runtime validation and on-disk Mach-O UUID + Original verification.
- Validate non-overlap of RVA and file offsets, lengths, source identity, UUID, alignment and rule identity.
- Host regression tests in `tests/v3_static_build_planner_test.mm`; editor action explicitly says read-only preflight.
- Manifest schema `com.zonoe.v3.static-build-plan` version 1, `binaryGenerated=false`. The manifest is a diagnostic object, not a generated file or serialized build output.

## V2 true implementation dependencies

Primary builder `iosruntimepatchmenu/src/ZNStaticBinaryBuilderV3.mm` is 1321 lines and depends on:
- `ZNBinaryPatchWorkspace.h`, `ZNPatchRuntimeValidator.h`, `ZNPatchCore.h` (V2 mutable session and row model, must be ADAPTED to immutable V3 plan).
- `ZNMachOFile.h`, `ZNStaticPatchFormat.h`, `ZNStaticPayloadProtectionV2.h` (checked file parsing, physical metadata, ARM64 relocation).
- `ZNBuildOutputIO`, `ZNBuildOutputTransaction`, `ZNBuildSession`, `ZNBuildExecutor`, `ZNGeneratedBinaryPostprocess`, `ZNAdhocMachOSigner`, `ZNBuildFault` (output staging, publishing, signing).
- Static-dispatch runtime reader/owner manager must understand V2's precise `ZN44StaticEntry` ABI before an ON/OFF toggle can be implemented.

## Migration order (no shortcut)

1. Adapt an immutable V3 build input to the old builder's logical/physical site model; do not import V2's global workspace or runtime state.
2. Port bounded thin ARM64 Mach-O parser and owned `__ZNTEXT`/`__ZNDATA` allocation. Reject insufficient LC header slack; no use of arbitrary gaps or moving original `__TEXT`.
3. Port PC-relative ARM64 instruction relocation, including conditional/test branches and range-limited far veneers; verify OFF path semantic equivalence and ON path.
4. Port static descriptor encoding, separate static-dispatch runtime activation, and deterministic conflict handling across multiple saved V3 features.
5. Stage output in an owned temporary directory, re-open and re-verify source UUID/size/Expected bytes, commit atomically on success; source TOCTOU check is mandatory.
6. Rebuild ad-hoc CodeDirectory before exporting; final installation/package signing stays external.
7. CI fixture tests for successful generation plus negative inputs (truncated Mach-O, wrong UUID, insufficient header slack, overlap, unsupported opcode, interrupted publish, corrupted signature).
8. Actual arm64 target-device loading, cold boot OFF, ON, OFF, feature interaction and repeated launch. Do not report device success based only on GitHub Actions.

## Explicit scope constraints

- The existing runtime RX Bytes Patch remains unchanged and remains exclusively for the jailbroken use case.
- No generated or patched Mach-O is produced by P6-A.
- Static-prepared binary format is NOT compatible with H5GG's `__HOOK_TEXT`/`__HOOK_DATA`; do not mix formats.
- Never claim that a successful host test or arm64 dylib compile proves a full binary generator works.
