# Development changes — P10.5.1 debt-only branch

## Initial remediation
- Created branch `P10.5.1-debt-cleanup` at historical P10.5.1 SHA `26846167806023ea882c3eebc24f3fe1e86ab531`.
- Added strict persisted Feature ID and per-feature Rule ID uniqueness; load quarantines malformed duplicate ownership without deleting original saved JSON.
- Added regression fixtures for duplicate IDs, legal cross-feature rule IDs, quarantine and save preservation.
- Activated the existing branch-specific macOS CI test+build workflow for the new branch.
- No change to P9 binary ABI, customer dylib execution protocol, ARM64 patch bytes or numeric type IDs.

## D07: Mach-O UUID persistence and execution pinning
- Added optional `boundImageUUID` field and strict canonical UUID validation with case-insensitive matching.
- Explicit editor save binds each Offset to the real loaded LC_UUID, and rejects silently rebinding previously pinned features to another image version.
- Developer runtime patch, static Builder and static runtime entry points reject missing/mismatched UUIDs.
- Added UUID JSON/draft persistence, invalid-UUID, legacy-unbound tests; no changes to original P10.5.1 or P10.8 refs.
