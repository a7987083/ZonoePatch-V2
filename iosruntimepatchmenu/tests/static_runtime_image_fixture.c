#include "ZNStaticPatchFormat.h"
struct FixtureTable {ZN44StaticHeader header;ZN44StaticEntry entries[2];ZN44FeatureDescriptionHeader descriptions;ZN44FeatureDescriptionEntry details[2];};
static struct FixtureTable table;
int ZNFixtureOff(void){return 10;}int ZNFixtureA(void){return 20;}int ZNFixtureB(void){return 30;}
void *ZNFixtureTable(void){return &table;}
