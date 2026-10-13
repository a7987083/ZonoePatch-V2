# H05 safe UI decomposition

Baseline: remote 5e7d1d4. ZNUnifiedUI.mm is now a 179-line composition root over 54 ordered source modules under src/ui/{core,shell,finder,execution,features,compat}.

The include expansion is byte-for-byte identical to the baseline UI source. Includes are intentionally one translation unit: historical static helpers, macros, category load ordering and original #line mapping are preserved. This is source/module ownership decomposition, not a claim that all modules are independent objects yet.

scripts/ui_source.py enforces unique ownership, exact inventory/order and expanded SHA256. Existing topology checks apply to the expansion: selectors, IMP exchange counts, activation stages remain identical. No compatibility selector or installer was removed in this commit.

Next safe step is removing provably redundant wrappers/categories after selector/install analysis and dedicated ObjC runtime tests; generic splitting across translation units is not safe until each section's static symbol dependencies have been exported or isolated.

## Independent presentation policy owner

`ZNInstallPublicCompactDefaultsDeferred` and its four file-private preference keys now compile independently in `ZNMenuPresentationDefaults.mm`. The original C entry point, class-name lookup, +shared call, typed BOOL/NSInteger setters, migration keys, repeated-launch preservation and log order are unchanged. The private class interface emits no second class implementation; the real controller remains in the UI. Foundation tests execute the actual policy with a surrogate of the same class/setter ABI, including class absent, first migration, repeat migration and preference restoration.

The composition module carries relocation markers. The audit stitches only the moved constants/function regions back into their original positions and checks the previous UI bytes (after removing opt-in performance scopes). An additional whole-file SHA gates the external owner, so the relocation does not hide unaudited extra code. This representation is for source auditing, not a claim of a second compiled UI owner. Menu defaults now have a real independent build/test boundary; UIKit render/swizzle code still shares one translation unit.
