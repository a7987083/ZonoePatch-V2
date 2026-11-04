# P10.5.1 debt remediation ledger

**Immutable starting point:** `26846167806023ea882c3eebc24f3fe1e86ab531` (P10.5.1, GitHub Actions `41757178282`, success).  
**Working branch:** `P10.5.1-debt-cleanup`.  
**Reference only:** `ZonoePatch-V3` P10.8 and `a7987083/mymenu`; never cherry-pick whole architecture without a scoped review.

## Policy
- No mixed-build features or new payload metadata protocols during debt cleanup.
- Preserve the historical commit, existing P9 static ON/OFF ABI, and all stored numeric type IDs.
- Separate *code changed*, *host tests*, *CI compiled*, *synthetic Mach-O*, and *iPhone/game verification*.
- Never silently rewrite or discard historical `features-v1.json` quarantine entries.
- Remove a debt item only after a reproducible targeted regression passes.

## Verified debt inventory from P10.5.1
| ID | Priority | Evidence | Status |
| --- | --- | --- | --- |
| D01 | P0 | `V3FeatureEditor.mm` splits Toggle export from single Numeric export | Open — defer until after debt cleanup |
| D02 | P0 | `V3StaticBuildPlanner.mm` rejects code-section Numeric as RW-only | Open — design once target binary supplied |
| D03 | P0 | `V3StaticBinaryExport.mm` declares typed metadata only, no runtime code patch | Open — intentional feature gate |
| D04 | P1 | `ZNTypedCustomerRuntime.mm` does not update an active numeric transaction | Implemented: active update + Original snapshot + fault injection; CI pending |
| D05 | P1 | `V3StaticDispatchRuntime.mm` allows one active saved feature only | Open — avoid unsafe concurrency workaround |
| D06 | P1 | `KNOWN_ISSUES.md` P6-C reports sequential non-atomic multi-rule pointer updates | Open — semantics and device tests required |
| D07 | P1 | `features-v1.json` does not persist pinned Mach-O UUID | Implemented: explicit-save pin, runtime/static checks; CI/device validation pending |
| D08 | P2 | Legacy numeric double fallback vs schema-v3 decimal-text precision | Open — preserve old formats; audit migration |
| D09 | P2 | Quarantined older JSON retained, but no repair/migration UI | Open — avoid destructive auto-conversion |
| D10 | P1 | `V3ConfigRepository.mm` accepted duplicate Feature ID or same-feature Rule ID | Code fixed (verify CI) |

D10 is a newly confirmed ownership collision issue observed while reviewing persistence; it was not counted in the prior nine-item high-level audit. Total tracked items: **10**, not a static estimate of all defects.

## First remediation
- `V3ConfigRepository.mm`: reject empty/oversized/duplicate saved feature identifiers and repeated/empty rule identifiers; same rule identifier across different features remains legal.
- On load: quarantine repeated feature IDs and repeated rule IDs *within the same feature*. Keep the complete original JSON entries unchanged for roundtrip preservation.
- `tests/v3_config_and_address_test.mm`: malformed/duplicate identities, quarantine count, no-loss save and legal cross-feature rule identity.
- Dedicated CI branch build gate added to existing workflow without changing SDK/toolchain or weakening tests.
- **Validation**: Github Actions `41861120081` queued when ledger was initially written. Recheck actual run before claiming compiled or tested.

### D07: expected behavior
- New or legacy unbound features remain editable and their old JSON is retained; execution/build is **fail-closed** until the user explicitly opens and saves the feature with the target Mach-O loaded.
- Explicit save computes the LC_UUID from each configured rule's actual loaded image, rejects inconsistent per-rule UUID and rejects silent cross-version rebinding of an existing feature. For a different game version create a separate feature.
- `boundImageUUID` is an optional additive field inside `features-v1.json`; no numeric type ID or top-level schema rewrite.
- Every Developer write path (Runtime Bytes, static Builder, static slot activation) checks that the persisted UUID matches the current image. Customer’s generated binary catalog remains independently validated by the pre-existing code.
- Regressions cover canonical UUID matching, persistence, draft copy, unbound legacy behavior and invalid JSON quarantine. **Real game device behavior remains unverified.**

### D04: transactional active numeric update
- `ZNTypedValueTransaction::update` preserves initial Original snapshots, validates unchanged target addresses and byte-identical typed descriptor encoding, validates numeric range, checks all currently applied values and verifies writes.
- Failed partial updates restore the **prior committed** values, never the first Original; a failed rollback latches RecoveryFailed and refuses later writes/restores.
- Existing `ZNTypedCustomerRuntime::applyValue` routes an already-active feature through guarded update; it remains one numeric feature per image. No extra mixed protocol or architecture imported from P10.8.
- Customer NumberInput button becomes Apply/Update, and Slider commits a pending value on touch release when enabled. Slider OFF still restores the first Original.
- New host regressions cover update, out-of-range, changed descriptor/address, multi-rule partial rollback, initial Original restore, external writer interference, and recovery-lock failure.
- **Verification**: newest D04 Actions `41883259215` queued at time of documentation; iPhone UI / real game not verified.
