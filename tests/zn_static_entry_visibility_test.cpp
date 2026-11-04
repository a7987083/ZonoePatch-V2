#include "../ZNStaticEntryVisibility.hpp"
#include <cstdio>
static int failed=0;
static void check(bool yes,const char*name){if(!yes){++failed;std::fprintf(stderr,"FAIL %s\n",name);}}
int main(){
 ZN44StaticEntry toggle{};toggle.flags=ZN44_STATIC_ENTRY_FLAG_CANONICAL;
 check(ZNCustomerP9EntryVisibleAsToggle(toggle),"normal P9 switch stays visible");
 toggle.flags|=ZN44_STATIC_ENTRY_FLAG_SHARED;
 check(ZNCustomerP9EntryVisibleAsToggle(toggle),"normal shared P9 visibility unchanged");
 toggle.flags|=ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1;
 check(!ZNCustomerP9EntryVisibleAsToggle(toggle),"code numeric dispatch hidden");
 toggle.flags=ZN44_STATIC_ENTRY_FLAG_CANONICAL|ZN44_STATIC_ENTRY_FLAG_OFFSET_HOOK_V1;
 check(!ZNCustomerP9EntryVisibleAsToggle(toggle),"numeric offset-hook hidden");
 toggle.flags=ZN44_STATIC_ENTRY_FLAG_CANONICAL|ZN44_STATIC_ENTRY_FLAG_VALUE_CELL_V1|
  ZN44_STATIC_ENTRY_FLAG_OFFSET_HOOK_V1;
 check(!ZNCustomerP9EntryVisibleAsToggle(toggle),"mixed numeric markers hidden");
 std::printf("P10.7.5 Customer P9 numeric slot isolation: %s (%d failures)\n",
   failed?"FAIL":"PASS",failed);
 return failed?1:0;
}
