# V3 Known Issues / Validation Gaps

Baseline before P5 debt remediation: `80569bf948c86cfca45d99cc7036420097a0038c`. Preserve history; do not force-reset.

## Open

- **DEVICE PENDING:** Latest module edit/preview/save, live byte capture, executable-segment and `LC_UUID` checks need repeat verification on the target iPhone and exact game binary. Prior user confirmation applied only to the single-module picker interaction.
- **Runtime Executor integration pending:** P5.2 implemented a private transaction core and RX Bytes backend, but menu activation and device-level page-write verification are deliberately disabled. Non-jailbreak iOS signed code pages may refuse `mprotect`; no H5GG/static-prepared backend is implemented.
- **Runtime concurrency risk:** RX→RW→RX is not a stop-the-world patch operation; executing threads may race with live code modification. Do not activate executable writes in the UI until target-device concurrency and code-signing behavior are validated.
- **Trusted Expected Bytes:** Executor requires an explicit `expectedBytes` value and backend UUID matching; do not treat a one-time live capture alone as a trusted cross-version baseline.
- **Persisted binary identity:** Validator reads `LC_UUID` but `features-v1.json` does not yet persist version binding. Add before enabling runtime writes or static output.
- **Legacy JSON compatibility:** Historic P3 rules that saved invalid ARM64 code lengths or >256 bytes are now rejected on load by stricter shared codec. Raw file remains on disk; before broad rollout, add a non-destructive legacy migration/read-only recovery path.
- **Device-level tests:** Host CI covers HEX parser, address text and JSON roundtrip. It does not simulate Mach-O page mappings, dyld loads, UIKit interaction or code-signing restrictions.

## Resolved in P5 debt work

- Existing feature edit no longer overwrites its stored target with the top-level picker default.
- One shared codec is used by save/load and runtime preflight, including code alignment.
- Runtime preflight rejects non-executable segments, compares exact Segment identity and captures Mach-O UUID.

Future validation must distinguish submitted, compiled, device-tested and game-behavior-tested states.
