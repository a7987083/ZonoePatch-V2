# P10.5.1 debt cleanup handoff

- **Repository:** `a7987083/ZonoePatch-V2`.
- **New branch:** `P10.5.1-debt-cleanup`, forked **exactly** from immutable baseline `26846167806023ea882c3eebc24f3fe1e86ab531`.
- **Reference branch:** `ZonoePatch-V3` (P10.8); not merged and not modified by this work.
- **Stable historical Actions/artifact:** `41757178282` / `ZonoePatch-V3-26846167806023ea882c3eebc24f3fe1e86ab531`, success.
- **Changes made:** unique Feature/Rule ownership validation and reversible quarantine on legacy JSON load; tests. `.github/workflows/v3-build.yml` enables the dedicated branch's CI with identical 18.5 SDK toolchain.
- **Source of truth:** `TECH_DEBT_P1051.md` ledger; `KNOWN_ISSUES.md` for original platform/device risks.
- **Build status:** CI Run `41861120081` was queued when this handoff was prepared, not yet verified compiled.
- **Real device:** not tested. **Mixed Builder:** intentionally unchanged/unsupported. **No merge to P10.8.**
- **Next:** verify CI first failure/build/artifact; next independently remediate version-pinned Mach-O UUID persistence and active numeric transaction updates. Do not combine with R-X code-cell feature development.

## D07 continuation
- UUID persistence commit `4482d1d6`; additional malformed JSON test `c5a61be5`; Developer static slot gate `795bf7af`.
- Newly saved Feature ID is pinned in `V3FeatureEditor.mm` to actual loaded Mach-O UUID, stored by `V3ConfigRepository.mm`, carried in draft by `V3FeatureModels.mm`.
- Missing/mismatched saved UUID fails closed in `V3PatchSession.mm`, `V3StaticBuildPlanner.mm`, and `V3StaticDispatchRuntime.mm`.
- The branch's Actions for D07 may still be queued. Recheck newest HEAD's Actions build/test before concluding D07 done. No iPhone execution or image version-switch test has been performed.

## D04 active numeric transaction integration
- Source changes at `e345dbcd`; additional rollback fault injection at `9f707c4e`.
- Core `ZNTypedValueTransaction.{hpp,cpp}` now supports `update` with exact descriptor/addresses and previous-applied rollback, preserving first Original. Customer `ZNTypedCustomerRuntime.mm` routes repeated apply of same active feature to `update`; `V3CustomerMenuController.mm` wires slider release and number-input Update.
- D07 previous CI failed in `Test Address and Configuration` because `NSArray *` test variables accessed typed `boundImageUUID`; fixed in commit `39dd2500`. CI `41883105271` reached dylib Build at latest check; **do not confuse this old-HEAD run with current**.
- New D04 HEAD run: `41883259215` (initially queued). Recheck jobs and first compiler error before claiming pass or device readiness. No real iPhone validation; P10.5.1 and P10.8 historical refs untouched.
