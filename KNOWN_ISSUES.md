# V3 Known Issues / Validation Gaps

Baseline before P5 debt remediation: `80569bf948c86cfca45d99cc7036420097a0038c`. Preserve history; do not force-reset.

## Open

- **DEVICE PENDING:** Latest module edit/preview/save, live byte capture, executable-segment and `LC_UUID` checks need repeat verification on the target iPhone and exact game binary. Prior user confirmation applied only to the single-module picker interaction.
- **P5.3 jailbroken real-device verification pending:** The feature editor provides Apply Patch / Restore Original actions, requiring saved rules and Original equality. Its RX→RW→RX backend depends on the actual jailbreak kernel/page permissions.
- **P6-C real-device verification pending:** Static-prepared dispatch (not H5GG format) now has RW selectedTarget ON/OFF in V3. Validate cold boot, Original OFF equivalence, ON behavior, runtime writes on actual signed installation, repeated launch and failure recovery.
- **Runtime concurrency risk:** RX→RW→RX is not a stop-the-world patch operation; executing threads may race with live code modification. Runtime writes are user-confirmed and may fail or cause a process crash on the target device. Do not claim concurrency safety or production readiness without device evidence.
- **Trusted Expected Bytes:** Session derives expected bytes only when live capture equals on-disk Mach-O contents, and backend checks runtime UUID. This is a session-only trust boundary; it does not prove cross-version or cross-process compatibility.
- **Persisted binary identity:** Validator reads `LC_UUID` but `features-v1.json` does not yet persist version binding. Add before enabling runtime writes or static output.
- **Legacy JSON compatibility:** Incompatible legacy features are now quarantined and retained as original JSON values on subsequent saves. They are not executable/editable in the current UI; safe per-feature migration/editing remains a future task.
- **Device-level tests:** Host CI covers HEX parser, address/config, static descriptor binding, synthetic Mach-O generation + CodeDirectory signer, and injected static multi-slot transactions. It does not simulate live dyld mappings, UIKit, actual game execution or on-device installation.

- **P6-C multi-feature limitation:** One active saved feature per process; static shared-site ownership and independently toggled feature sets are not implemented.
- **P6-C concurrency:** Individual 8-byte pointer stores are atomic, but multi-rule ON/OFF consists of sequential writes; other execution threads may transiently observe mixed state.
- **P6-C backward compatibility:** Older P6-B builds lack the `P6C1:` rule identity binding and must be regenerated before static activation.

## Resolved in P5 debt work

- Existing feature edit no longer overwrites its stored target with the top-level picker default.
- One shared codec is used by save/load and runtime preflight, including code alignment.
- Runtime preflight rejects non-executable segments, compares exact Segment identity and captures Mach-O UUID.

Future validation must distinguish submitted, compiled, device-tested and game-behavior-tested states.

- **Recovery failure:** Executor latches `RecoveryFailed` if rollback fails or RX page permissions cannot be restored, even if bytes match. UI displays a locked button. This is fail-closed containment, not guaranteed repair of a damaged memory protection state.

## P10.6.2 — Mixed image status (2026-11-04)

- **SOURCE/CI VERIFIED, DEVICE PENDING:** The opt-in `V3StaticBinaryExport.generateMixedMetadataForFeatures` builds existing P9 toggles first, appends a versioned `ZNM2` feature-identity envelope in `__ZNTYPE`, re-signs once and reads back P9 static table plus ZNM2 bytes.
- **NOT CUSTOMER-EXECUTABLE:** Numeric ZNM2 features are metadata-only. The existing Customer ZNT1 reader rejects ZNM2. There is no mixed export UI action; do not market the output as multi-slider enabled.
- **ABI BOUNDARY:** Legacy P9 128-byte Static Entry ABI and standalone ZNT1 remain untouched. `ZNM2` is independent version 2 with IDs, names, typed-record ownership ranges and an embedded ZNT1 payload.
- **CONFLICT MODEL:** P10.6.1 validates combined RVA and file-offset spans. Runtime ownership/Original snapshots, partial-write recovery and process restart semantics are deferred to P10.6.3. Do not remove existing multi-transaction rejection until a global ownership manager is tested.
- **DEVICE PENDING:** Actual app/UnityFramework Mach-O build input, final IPA re-sign and installation, startup, P9 toggle ON/OFF alongside ZNM2 data, numeric Customer UI and fault recovery all require device evidence.
- **CI REFERENCE:** Run `41765604484` on source commit `7d522d0df2d502b450af1ce6f6833acfadc856a7` succeeded. Subsequent documentation commits require their own CI status confirmation.

## P10.6.3 Customer runtime limitations (2026-11-04)

- **NOT DEVICE VERIFIED:** Independent ZNM2 Customer runtime is compiled via the Customer target, but has not been exercised on a loaded mixed Mach-O on iPhone. Host API tests only verify rejecting forged metadata. Do not mark feature execution ready for end users.
- **NOT UI-INTEGRATED:** `V3CustomerMenuController` still uses its previous catalog; the new `ZNMixedCustomerRuntime` is a separate entry point. Developer UI does not invoke the mixed export automatically.
- **Recovery protection:** `ZNMixedValue::Coordinator` retains ownership on a failed rollback and globally latches writes/restores. On external third-party memory changes, `Transaction::restore` refuses overwriting and retains ownership; manual inspection may be required.
- **Concurrency:** Individual scalar atomic writes do not provide global multi-address atomic commit. UI runtime calls are serialized by `@synchronized`; external game threads remain uncontrolled.
- **Format separation:** Legacy ZNT1 and P9 are unchanged. ZNM2 carries independently named numeric features and is accepted only through the new runtime.

## P10.6.4 Developer UI (2026-11-04)

- **DEVICE PENDING:** Mixed P9+ZNM2 Developer export is now reachable via multi-selection UI, but host CI only compiles the UIKit path and tests synthetic Mach-O fixtures; no on-device mixed output has yet been produced or exercised.
- **NUMERIC UI PENDING:** Customer ZNM2 controls are not rendered yet. Mixed output numeric features are metadata-only until the Customer UI and runtime integration is validated.
- **SELECTION CONSTRAINT:** Same Mach-O, at least one Toggle and one Input/Slider, no active patch and no unsaved edit. Pure multiple-numeric builds are deliberately rejected pending an explicit numeric-only protocol decision.

## P10.7 ARM64 numeric code support limitation (2026-11-04)

- Current Developer recognizes limited code candidates (FMOV S/D, MOVZ/MOVN + MOVK) and provides a more precise rejection explanation. **No R-X numeric site is yet accepted for binary generation.**
- LDR literal encoding is tested on synthetic assembler instructions but *no Value Cell has been inserted into a real Mach-O*. Customer input and slider cannot control R-X code through this version; existing RW numeric path and P9 toggle behavior remain unchanged.
- Relocation, inbound branch targets, selectedTarget dispatch, cell placement relative to __ZNTEXT, readback and post-signing integrity require next-stage integration tests and device verification.

## P10.7.4 staging-only numeric code emitter (2026-11-04)

- Added generated-Mach-O staging helper and synthetic Float32 slider + Int32 input + P9 toggle smoke. It verifies byte-identical OFF variants, LDR ON variants, distinct writable cells, ZNM2 names/IDs/RVAs and signature readback. The helper is NOT invoked by production Developer or Customer UI; only synthetic test coverage is claimed.
- Must establish a persistent, versioned ownership link between each code-cell ZNM2 numeric feature and its P9 selectedTarget dispatch slot; otherwise modifying a cell while the code dispatch is OFF has no observable effect. Avoid displaying internal synthetic code entries as ordinary P9 toggles.
- Production must reserve Value Cell capacity before owned segment construction, validate all indirect control flow and nontrivial MOVK chains, and restore code dispatch to Original OFF when disabling numeric controls. Until implemented and device-verified, R-X slider/input generation remains unsupported.

## P10.7.5 protocol and Customer isolation (2026-11-04)

- ZCB1 pure encoder/decoder + ownership validator have host CI coverage but **no on-disk ZCB1 embedding** yet; the synthetic test-only ZCB1 object does not authorize runtime activation. Customer cannot find an authenticated code-cell-to-P9 dispatch binding on a real image until a dedicated segment/section or otherwise verified metadata is emitted.
- P9 internal entries marked VALUE_CELL_V1 or OFFSET_HOOK_V1 are now excluded from ordinary Customer toggles, avoiding an unsafe pseudo-feature. This isolation does not make ZNM2 code-type sliders or inputs visible or executable.
- ZNM2 Customer UI remains unconnected. If the project returns a production export before ZCB1 embedding plus atomic activation/restore is validated, it must still refuse code-type numeric Offset and report numeric code execution unavailable. Real iOS device test remains pending.

## P10.8 current blockers (2026-11-05)

- CI macOS job queueing prevents claiming the new Customer integration compiled. Track head of `ZonoePatch-V3` and the newest GitHub Actions result; prior P10.7 green runs do not validate these commits.
- ZNM2 Customer UI now routes RW numeric features but original `generateMixedMetadataForFeatures` explicitly reports `numericMetadataOnly:YES` and `numericExecutionAvailable:NO`. Do not relabel it production-ready until real generated RW mixed binaries have been exercised against new Customer.
- No approved live ARM64 code-type numeric offsets can pass current production preflight; replacing the RW-only check without backend-generated cell placement/typed ownership would corrupt semantics. Code-type mixed Builder+Customer remains a blocker.
- Live slider committed-update paths were added with rollback-preserving snapshot semantics; iPhone UI layout, slider behavior and race/collision cases remain unverified.
