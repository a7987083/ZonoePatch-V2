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

## D04 active typed value update
- Added safe active `Transaction::update`: exact descriptor/address ownership, full-range preflight, external-writer detection, previous-applied atomic failure rollback and initial Original preservation.
- Wired Customer repeated Apply to active update, input Apply/Update button, slider TouchUp update while ON, OFF restores Original.
- Added fault-injected transaction tests including failed rollback latching recovery lock. No ZNM2/ZCB1/mixed Builder introduced.
- Corrected prior UUID regression test type error: `NSArray<ZNV3Feature *> *` for two typed arrays (`39dd2500`).

## D05 independent Developer static feature toggles
- Fixed P9 feature-specific resolution: select group-owned entries from a multi-feature static descriptor instead of requiring a feature to own every entry.
- Added a small, injectable `V3StaticFeatureCoordinator` to own feature/slot snapshots without duplicating the transaction backend.
- Added synthetic host regressions for A/B concurrent active state, individual restore, ownership conflict, injected partial failure and global recovery lock.
- Updated existing Theos Developer sources and CI, retaining P9 on-disk entry ABI and the Customer runtime unchanged.
- Remaining: actual P9 multi-feature Mach-O/dyld and real-device validation; D06 global multi-slot atomicity.
