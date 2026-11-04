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
