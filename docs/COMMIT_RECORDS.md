# Remote Commit records

No amend/rebase/force-push. Full branch history is authoritative.

- `aa12054c9b19ef8b2e90ce66d2158b8c5687e1e1` chore: initialize independent development repository
- `ae631f4ff17658e747016d596a71b11deab5450f` baseline: import unchanged 1.zip menu source with pinned CI build harness
- `71795f613e2d97447ac147a5bde3674c61b6ffb4` fix(P0 H01): cancel stale hook retries after explicit teardown; add scheduler regression
- `0623bde46103c6d0b06b29cb415b90bbe75c4e61` fix(P0 H02): isolate prepare and emit in a captured build session; deep-copy static rows
- `781a4e04f8b7a9f82698ed2714aaea1ec0aaf254` fix(P0 H03): unique owned output staging and checked report writes; add I/O fault regression
- `e1c917b4882014a353e103c3a2ad49ef1be44f35` test: match production GNU Objective-C++ dialect for scheduler regression
- `f73dbc2b0ad192d9781ee39adc5de8cdb3b3ab5c` fix(P0 H03): propagate static report and validation I/O errors without false success
- `e6607c89c6a0ad30b0b6ece98dc1a29bd44bb81b` fix(P0 H04): retire hooks without reclaiming in-flight trampolines; preserve legacy destruction privately
- `d17a650440e076a0b456951c89a4888f977e4b8a` fix(P0 H06): gate raw receiver compatibility and revalidate its bounded lease; keep GCHandle path
- `839ae2234f15b5e0a3c632cec9e0b748b4d710df` test(P0 H07): preserve historical topology baseline and enforce exact imported UI digests
- `733971226a3a81f796380fee7205128808c54e2e` fix(P0 H02): transfer synchronous build results through owned block locals
- `b63b3bd6dcfeb54375a3822c58ffbb673692497c` fix(P1 M01): retain in-flight lifecycle requests and compare against scanned image count
- `3ddc39dd2c3f3ce5734eccba8450735b9d27f201` fix(P1 M04): key runtime caches by dyld add/remove generation instead of image count alone
- `1bbba24c1e0199ad55168ea20fff9aa27d29ba08` fix(P0 H03): remove superseded serialization temporaries caught by compiler warnings
- `f9eab4135cc789f8ba43a76e9e11af1ce63872bf` fix(P1 M02): identity-scoped Hook persistence, inventory removal and ordered desired commands
- `4cf2e0a48987ad11238f8f44c172502d72e7be1d` fix(P1 M03): use one production scalar parser and reject negative unsigned/non-finite inputs
- `3b14df55e290b582abe408838097a8d70bb13006` fix(P1 M03): make parser control flow warning-clean; portable boundary tests pass
- `c4cb55a1e242927e156adc7a851d64d313047bd9` build(P1 M05): pin baseline Xcode/SDK and Actions revisions; record dependency/toolchain identities
- `749941b10b57c643000f48a5d5d0022aad229d94` refactor(P0 H05): checked activation dependencies without changing historical selector/IMP topology
- `6cb57859575af97716ab55a4a925a19d106e5e82` refactor(P1 M10): shared checked byte views; fuzz production layout with sanitizers; cover Static cache generation — Metadata-only commit with unchanged tree; actual M10 source is cdcc759d05a60843d7bcc966fa59763a8022fa91.
- `cdcc759d05a60843d7bcc966fa59763a8022fa91` refactor(P1 M10): apply checked byte views and sanitizer malformed-layout regression
- `43f77afe0c5a8539950681b82a40e94a82f7c46b` test(P1 M07): production build-session isolation, ABI and format tests; extract row/snapshot owners
- `e8bafb206e67a7db251b385b3da0ff197e7cdc96` fix(P1 M02): reject identity reuse even after retirement and include codec/ABI binding fields
- `658c1865d1c40a86b94e829883cb3442736c0044` perf(P2 L01): extract bounded logger ring and remove per-line formatter/array shifting
- `babc9c348644006a3805563e7d46721bd405e4e6` perf(P1 M11): skip inactive/fully-hidden polling and redundant view reordering; preserve fallback timer
- `d2c933ffb7dc29969158d17403b567a107728818` test(P1 M07): protect Objective-C dictionary literals from C assert macro comma parsing
- `849fc4445ec56f82d9ec8932622aef2ad43ee995` build(P2 L03): strict warnings on new owners; document authoring/build/runtime model boundaries
- `69125a46db9be3fb7cf25f1391659cea758a7e9a` docs(P1 M09): protect retained compatibility paths and record hashes/references in CI
- `3f9cc8e578ca6b62fadeda20b5c77e0c5a6087d8` test(P1 M07): declare snapshot category owner and complete codec test linkage with explicit policy stubs
- `974cf073cd81ce62340fe86b1670b0e7582bbe5b` refactor(P2 L04): typed build context, frozen slider preferences and fail-closed provider collection
- `701e43c3acbd3ddd302819f149c0c43b1c02b6ff` build: capture production regression logs, native ARM64 fixture and complete source/commit artifacts
- `7cd6c1f3eecbdd5bfabc0abc42d7c2dfe99e778a` fix(P1 M01): lifecycle owns scheduler reconciliation even when capability discovery is cached
- `53c1dbcf54fae17bf2809b726f27d0ac8ac31914` fix(P0 H03): fail postprocess on missing/malformed reports instead of claiming success
- `3a53fbb992dad885476a14eb0c18e97b6a0c722b` fix(P0 H02): capture both action stores under a fixed lock order before preparing build copies
- `d91c8d0be8d60232d738d5db0b7449688c0a9d6e` build: verify final Mach-O dependencies/platform and both CodeDirectory page-hash tables

## H05/M10/L02/M11 continuation

- `6de908d5c586bcf95ddde775fa3a1a3818074cf4` refactor(H05): decompose UI into ordered byte-equivalent source modules
- `802256df7fcdc33c95026b75671785a1cb851693` fix(H05): preserve implementation diagnostic scope across UI includes
- `32c839e5a86282df498876090d377a11b516ada5` refactor(M10): share checked Mach-O file parsing and transactional LINKEDIT edits
- `582557fb60a400519a1c9d3a4f8b2acd8eaed6c2` test(M10): compare production signing output against stable baseline bytes
- `e2ec0c74a580a1fbaca05e9598d9f2ab500025ac` feat(M11): add bounded opt-in production spans and reproducible performance harness
- `f0f718784aeefd519d9493bb4c2014724109f27c` refactor(L02): remove four proven unreferenced file-local alignment helpers
- `1ccb74267d497f701e9b2fdfabb301d6318bc615` fix(M10): validate owner sections and remaining active file pipelines before writes
- `273966cbbe7ad313b1d7c906c7d55343e7d43110` refactor(H05): isolate presentation defaults with production Foundation regressions
- `84d7c1c9e3ced9ce4c5b9a3018772ee75eb7910b` refactor(M10): retain legacy builder while adopting shared checked file view
- `2bcb98bf8dcbba29a39c871feefeb646e141a8b4` test(M10): verify actual owned-segment layout against baseline and guard allocation overflow
- `770db3f7669ac054d748537bc86710d5c7a856ca` docs(H05): inventory concrete cross-section and dynamic UI dependencies
- `0c2e02d5d22a875b15b363afa1016d227b891100` test(M10): compare actual runtime-only target generation bytes against baseline
- `3e18504de52fe2e316c09826c1c350e6a6cba3a2` ci(M10): retain production binary-equivalence logs in delivery artifacts
