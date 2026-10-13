#!/usr/bin/env python3
"""Verify final bytes, not execution or Apple trust acceptance."""
import hashlib,json,struct,sys
from pathlib import Path
p=Path(sys.argv[1]);b=p.read_bytes()
assert len(b)>=32
magic,cpu,sub,kind,ncmds,sizeofcmds,flags,reserved=struct.unpack_from('<8I',b)
assert (magic,cpu,kind)==(0xfeedfacf,0x100000c,6),'expected thin arm64 dylib'
assert sizeofcmds<=len(b)-32
cursor=32;sig=None;build=None;dependencies=[]
for _ in range(ncmds):
 assert cursor+8<=32+sizeofcmds
 cmd,size=struct.unpack_from('<II',b,cursor)
 assert size>=8 and size<=32+sizeofcmds-cursor
 if cmd==0x1d:
  assert size>=16
  sig=struct.unpack_from('<4I',b,cursor)[2:]
 if cmd==0x32:
  assert size>=24
  build=struct.unpack_from('<6I',b,cursor)[2:5]
 if cmd in (0xc,0x80000018,0x8000001f):
  assert size>=24
  nameoff=struct.unpack_from('<I',b,cursor+8)[0]
  assert 24<=nameoff<size
  name=b[cursor+nameoff:cursor+size].split(b'\0',1)[0].decode()
  dependencies.append(name)
 cursor+=size
assert cursor==32+sizeofcmds
assert build and build[0]==2 and build[1]==(14<<16) and build[2]==((18<<16)|(5<<8))
assert all('dobby' not in x.lower() and 'substrate' not in x.lower() for x in dependencies)
assert sig and sig[0]<=len(b) and sig[1]<=len(b)-sig[0]
sb=b[sig[0]:sig[0]+sig[1]]
smagic,length,count=struct.unpack_from('>III',sb)
assert smagic==0xfade0cc0 and length<=len(sb) and count<100
assert 12+count*8<=length
directories=[]
for i in range(count):
 slot,offset=struct.unpack_from('>II',sb,12+8*i)
 assert offset<=length-8
 cmagic,clength=struct.unpack_from('>II',sb,offset)
 assert clength>=8 and clength<=length-offset
 if cmagic!=0xfade0c02:continue
 assert clength>=44
 _,_,version,cflags,hoff,ident,special,slots,limit=struct.unpack_from('>9I',sb,offset)
 hs,ht,platform,pagepower=struct.unpack_from('>4B',sb,offset+36)
 assert ht in (1,2,3,4) and hs>0 and pagepower<32
 assert limit<=sig[0] and hoff<=clength and slots*hs<=clength-hoff
 page=1<<pagepower
 assert slots==(limit+page-1)//page
 algo={1:'sha1',2:'sha256',3:'sha256',4:'sha384'}[ht]
 for k in range(slots):
  digest=hashlib.new(algo,b[k*page:min((k+1)*page,limit)]).digest()[:hs]
  assert len(digest)==hs and digest==sb[offset+hoff+k*hs:offset+hoff+(k+1)*hs],f'CodeDirectory page {k} mismatch'
 directories.append({'slot':slot,'hash_type':ht,'pages':slots,'flags':cflags,'page_hashes_verified':True})
assert directories,'no CodeDirectory'
result={'file':p.name,'size':len(b),'sha256':hashlib.sha256(b).hexdigest(),'architecture':'arm64','platform':'iOS','minimum_os':'14.0','sdk':'18.5','dependencies':dependencies,'code_directories':directories,'device_verified':False,'trust_or_installation_verified':False}
print(json.dumps(result,indent=2))
