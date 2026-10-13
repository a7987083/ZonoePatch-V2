# H05 safe UI decomposition

Baseline: remote 5e7d1d4. ZNUnifiedUI.mm is now a 179-line composition root over 54 ordered source modules under src/ui/{core,shell,finder,execution,features,compat}.

The include expansion is byte-for-byte identical to the baseline UI source. Includes are intentionally one translation unit: historical static helpers, macros, category load ordering and original #line mapping are preserved. This is source/module ownership decomposition, not a claim that all modules are independent objects yet.

scripts/ui_source.py enforces unique ownership, exact inventory/order and expanded SHA256. Existing topology checks apply to the expansion: selectors, IMP exchange counts, activation stages remain identical. No compatibility selector or installer was removed in this commit.

Next safe step is removing provably redundant wrappers/categories after selector/install analysis and dedicated ObjC runtime tests; generic splitting across translation units is not safe until each section's static symbol dependencies have been exported or isolated.
