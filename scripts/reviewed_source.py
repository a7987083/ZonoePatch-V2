"""Exact pre-change reconstruction for one reviewed header-read adapter.
No hash baseline is refreshed and every other byte remains pinned.
"""
def m56_before_owned_header(text):
    include='#include "ZNLoadedImageApple.h"\n'
    before='const struct mach_header_64 *mh=(const struct mach_header_64 *)record.imageBase;'
    after='auto headerOwner=ZNCaptureLoadedImage(record.imageBase);if(!headerOwner){if(error)*error=@"value-cell image invalidated";return 0;}const struct mach_header_64 *mh=(const struct mach_header_64 *)headerOwner->bytes();'
    assert text.startswith(include) and text.count(after)==1,'M56 adapter provenance mismatch'
    return text[len(include):].replace(after,before)
