"""Compile exact production parse/layout routines without target App dependencies."""
from pathlib import Path
import sys,hashlib,json
s=Path(sys.argv[1]).read_text();out=Path(sys.argv[2]);parts=[];records=[]
a=s.index('static const uint64_t kZNV3Page');b=s.index('struct ZNV3Logical',a);parts.append(s[a:b])
a=s.index('struct ZNV3OwnedSegmentCommand');b=s.index('static_assert',a);parts.append(s[a:b])
for name in ['ZNV3Parse','ZNV3ShiftU32','ZNV3ShiftLinkeditReferences','ZNV3FillOwnedSegment','ZNV3InstallOwnedSegments']:
 marker=name+'('
 if marker not in s:
  assert name=='ZNV3ShiftU32';continue
 a=s.rfind('static ',0,s.index(marker));b=s.index('{',a);depth=1;e=b+1
 while depth:
  if s[e]=='{':depth+=1
  elif s[e]=='}':depth-=1
  e+=1
 code=s[a:e];parts.append(code);records.append(dict(symbol=name,sha256=hashlib.sha256(code.encode()).hexdigest()))
headers='''#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <mach/vm_prot.h>
#include <vector>
#include <algorithm>
#include <cassert>
#include "ZNMachOFile.h"
'''
fixture=(Path(__file__).resolve().parents[1]/'iosruntimepatchmenu/tests/macho_layout_fixture_main.inc').read_text()
out.write_text(headers+'\n'.join(parts)+'\n'+fixture)
out.with_suffix('.json').write_text(json.dumps(records,indent=2)+'\n')
