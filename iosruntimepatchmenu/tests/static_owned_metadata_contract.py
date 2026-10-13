from pathlib import Path
s=Path('iosruntimepatchmenu/src/ZNStaticDispatchRuntime.mm').read_text()
assert 'ownedEntry,ownedDispatch' in s
assert 'ZN44StaticEntry *entries=ownedEntries.data()' in s
assert 'record.imageIncarnation=lease->incarnation()' in s
assert '__atomic_store_n((uintptr_t *)&record.dispatchEntry' not in s
assert '__atomic_load_n((uintptr_t *)&record.dispatchEntry' not in s
assert 'ZNLeaseForHeader(record.imageBase,record.imageIncarnation)' in s
assert 'scan.copy(cursor,&candidate,sizeof(candidate))' in s
print('record owned values / leased mapped selectedTarget / bounded fallback scan contract PASS')
