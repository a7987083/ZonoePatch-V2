#pragma once
#import "ZNStaticPatchRecordInternal.h"
#import "ZNValueTypeModel.h"
#include "ZNImageOperationLease.h"
inline uintptr_t ZNStaticValueCellAddressForRecord(ZNStaticPatchRecord *record,ZNImageOperationLease &lease,ZNValueType *type,NSString **error){
 auto fail=[&](NSString *reason)->uintptr_t{if(error)*error=reason;return 0;};
 if(!record||!record.entry||record.imageIncarnation!=lease.incarnation()||!lease.valid())return fail(@"Static value-cell incarnation unavailable");
 if(!(record.entry->flags&ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1))return fail(@"当前生成物没有 RW Value Cell；请用 M5.6 重新生成 UnityFramework");
 znmacho::File headerFile;const char *reason=nullptr;
 if(!znmacho::parse(lease.image->bytes(),lease.image->headerSize(),headerFile,&reason,true,false))return fail(@"value-cell header invalid");
 znmacho::SectionLocation location;if(!znmacho::findSection(headerFile,"__ZNDATA","__zndata",location,&reason))return fail(@"value-cell runtime 缺少 __ZNDATA");
 auto section=(const section_64 *)(headerFile.bytes+location.sectionOffset);auto segment=(const segment_command_64 *)(headerFile.bytes+location.segmentOffset);
 uint64_t address=0;if(!lease.image->translate(section->addr,&address)||address!=record.headerAddress||section->size<sizeof(ZN44StaticHeader))return fail(@"value-cell header identity mismatch");
 ZN44StaticHeader header={};if(!lease.image->read(address,&header,sizeof(header))||header.magic0!=ZN44_STATIC_MAGIC0||header.magic1!=ZN44_STATIC_MAGIC1||header.entrySize!=sizeof(ZN44StaticEntry)||!header.count||header.count>ZN44_STATIC_MAX_ENTRIES||!(header.flags&ZN44_STATIC_HEADER_FLAG_VALUE_CELLS_V1))return fail(@"value-cell runtime Static Header 无效");
 uint64_t expectedEntry=0;if(record.entryIndex>=header.count||!ZNCheckedAdd64(address,sizeof(header)+(uint64_t)record.entryIndex*sizeof(ZN44StaticEntry),&expectedEntry)||expectedEntry!=record.entryAddress)return fail(@"value-cell entry index 无效");
 uint64_t bytes=(uint64_t)header.count*8,cellVM=0,cell=0;if(bytes>segment->filesize||!ZNCheckedAdd64(segment->vmaddr,segment->filesize-bytes+(uint64_t)record.entryIndex*8,&cellVM)||!lease.image->translate(cellVM,&cell)||(cell&7)||!lease.image->contains(cell,8,VM_PROT_READ|VM_PROT_WRITE))return fail(@"value-cell range/protection invalid");
 uint32_t raw=ZN44StaticValueCellTypeFromFlags(record.entry->flags);if(raw>ZNValueTypeF64||raw==ZNValueTypeAuto)return fail(@"value-cell resolved type 无效");if(type)*type=(ZNValueType)raw;return cell;
}
