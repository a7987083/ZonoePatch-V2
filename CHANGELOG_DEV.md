# Development changes — P10.5.1 debt-only branch

## Initial remediation
- Created branch `P10.5.1-debt-cleanup` at historical P10.5.1 SHA `26846167806023ea882c3eebc24f3fe1e86ab531`.
- Added strict persisted Feature ID and per-feature Rule ID uniqueness; load quarantines malformed duplicate ownership without deleting original saved JSON.
- Added regression fixtures for duplicate IDs, legal cross-feature rule IDs, quarantine and save preservation.
- Activated the existing branch-specific macOS CI test+build workflow for the new branch.
- No change to P9 binary ABI, customer dylib execution protocol, ARM64 patch bytes or numeric type IDs.
