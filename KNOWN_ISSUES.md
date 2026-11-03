# V3 Known Issues / Validation Gaps

Baseline before P5 debt remediation: `80569bf948c86cfca45d99cc7036420097a0038c`. Preserve history; do not force-reset.

## Open

- **DEVICE PENDING:** Latest module edit/preview/save, live byte capture, executable-segment and `LC_UUID` checks need repeat verification on the target iPhone and exact game binary. Prior user confirmation applied only to the single-module picker interaction.
- **P5.3 real-device verification pending:** The feature editor now provides explicit Apply Patch / Restore Original actions, requiring saved rules and on-disk Original equality. Non-jailbreak iOS signed code pages may refuse `mprotect`; no H5GG/static-prepared backend is implemented.
- **Runtime concurrency risk:** RX→RW→RX is not a stop-the-world patch operation; executing threads may race with live code modification. Runtime writes are user-confirmed and may fail or cause a process crash on the target device. Do not claim concurrency safety or production readiness without device evidence.
- **Trusted Expected Bytes:** Session derives expected bytes only when live capture equals on-disk Mach-O contents, and backend checks runtime UUID. This is a session-only trust boundary; it does not prove cross-version or cross-process compatibility.
- **Persisted binary identity:** Validator reads `LC_UUID` but `features-v1.json` does not yet persist version binding. Add before enabling runtime writes or static output.
- **Legacy JSON compatibility:** Incompatible legacy features are now quarantined and retained as original JSON values on subsequent saves. They are not executable/editable in the current UI; safe per-feature migration/editing remains a future task.
- **Device-level tests:** Host CI covers HEX parser, address text and JSON roundtrip. It does not simulate Mach-O page mappings, dyld loads, UIKit interaction or code-signing restrictions.

## Resolved in P5 debt work

- Existing feature edit no longer overwrites its stored target with the top-level picker default.
- One shared codec is used by save/load and runtime preflight, including code alignment.
- Runtime preflight rejects non-executable segments, compares exact Segment identity and captures Mach-O UUID.

Future validation must distinguish submitted, compiled, device-tested and game-behavior-tested states.

- **Recovery failure:** Executor latches `RecoveryFailed` if rollback fails or RX page permissions cannot be restored, even if bytes match. UI displays a locked button. This is fail-closed containment, not guaranteed repair of a damaged memory protection state.
