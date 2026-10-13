int main(int argc,char **argv){@autoreleasepool{
 assert(argc==2);std::vector<uint8_t> image(0x8000,0);auto p=image.data();
 mach_header_64 h={};h.magic=MH_MAGIC_64;h.cputype=CPU_TYPE_ARM64;h.filetype=MH_DYLIB;h.ncmds=4;h.sizeofcmds=152+72+24+16;memcpy(p,&h,sizeof(h));
 ZNV3OwnedSegmentCommand text={};text.segment.cmd=LC_SEGMENT_64;text.segment.cmdsize=sizeof(text);strcpy(text.segment.segname,"__TEXT");text.segment.vmaddr=0x100000000;text.segment.vmsize=text.segment.filesize=0x4000;text.segment.nsects=1;text.segment.initprot=VM_PROT_READ|VM_PROT_EXECUTE;strcpy(text.section.sectname,"__text");text.section.addr=0x100001000;text.section.offset=0x1000;text.section.size=0x200;text.section.flags=S_REGULAR|S_ATTR_PURE_INSTRUCTIONS;memcpy(p+32,&text,sizeof(text));
 segment_command_64 link={};link.cmd=LC_SEGMENT_64;link.cmdsize=sizeof(link);strcpy(link.segname,"__LINKEDIT");link.vmaddr=0x100004000;link.vmsize=link.filesize=0x4000;link.fileoff=0x4000;memcpy(p+184,&link,sizeof(link));
 symtab_command sym={LC_SYMTAB,sizeof(sym),0x4000,1,0x4100,32};memcpy(p+256,&sym,sizeof(sym));linkedit_data_command sig={LC_CODE_SIGNATURE,sizeof(sig),0x7000,0x1000};memcpy(p+280,&sig,sizeof(sig));
 for(size_t i=0x1000;i<image.size();i++)p[i]=uint8_t(i*31+7);
 ZNV3Layout layout={};std::vector<ZNV3Segment> segments;NSString *error=nil;assert(ZNV3Parse(p,image.size(),segments,layout,&error));assert(layout.firstFileSectionOffset==0x1000);
 image.resize(0x10000);uint64_t cf=0,cr=0,df=0,dr=0;
 assert(ZNV3InstallOwnedSegments(image.data(),image.size(),layout,0x4000,0x4000,64,128,&cf,&cr,&df,&dr,&error));assert(cf==0x4000&&df==0x8000&&cr==0x4000&&dr==0x8000);
 znmacho::File verified;assert(znmacho::parse(image.data(),image.size(),verified));assert(verified.commands.size()==6);
 NSString *path=[NSString stringWithUTF8String:argv[1]];assert([[NSData dataWithBytes:image.data() length:image.size()] writeToFile:path atomically:YES]);
 NSLog(@"extracted production V3 layout parse/install fixture PASS");
}}
