from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'src/ZNNativeHookRuntime.mm').read_text()
# Protect public retirement from ever reclaiming a native callback's trampoline.
for public,private in [('removeAction:', 'zn_legacyDestroyActionAfterExternalQuiescence:'),('removeTemporaryHookForCandidate:', 'zn_legacyDestroyTemporaryHookAfterExternalQuiescence:')]:
 body=s[s.index('- (BOOL)'+public):s.index('- (BOOL)'+private)]
 assert 'enabled.store(0' in body
 for forbidden in ['destroyHookAtAddress','original.store(0','ZNNativeHookRegistryUnbind','ZNNativeStaticPrepatchClear']:
  assert forbidden not in body,forbidden
# Compatibility implementations remain present; no caller is added.
for selector in ['zn_legacyDestroyActionAfterExternalQuiescence:','zn_legacyDestroyTemporaryHookAfterExternalQuiescence:']:
 assert s.count(selector)==1
print('public retirement retains native callbacks; legacy destructive code preserved PASS')
