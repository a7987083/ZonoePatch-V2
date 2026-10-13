static BOOL fixtureSecondHookFails;
@implementation ZNBuildManifest
- (BOOL)hasStaticItems{return fixtureMode==0||fixtureMode==3;}
- (NSUInteger)itemCount{return self.items.count;}
- (NSUInteger)staticItemCount{return self.hasStaticItems?self.items.count:0;}
- (NSUInteger)runtimeItemCount{return self.hasStaticItems?0:self.items.count;}
+ (instancetype)manifestForWorkspace:(FixtureWorkspace *)w{
 ZNBuildManifest *m=[self new];NSMutableArray *items=[NSMutableArray array];if(fixtureMode==0||fixtureMode==3)for(NSUInteger i=0;i<w.rows.count;i++)[items addObject:[ZNBuildItem itemWithProvider:@"fixture" kind:@"static" identifier:@"row" domain:ZNBuildItemDomainStatic metadata:@{@"rowIndex":@(i)}]];else [items addObject:[ZNBuildItem itemWithProvider:@"fixture" kind:@"runtime" identifier:@"action" domain:ZNBuildItemDomainRuntime metadata:@{}]];
 ZNBuildProviderRecord *p=[ZNBuildProviderRecord new];p.emitGroup=@"fixture";
 p.prepare=^BOOL(ZNBuildManifest *manifest,FixtureWorkspace *workspace,NSString **error){(void)manifest;if(ZNBuildFail("provider.prepare")){if(error)*error=@"Prepare injected";return NO;}uint32_t nop=0xD503201F,on=0x52800020;for(ZNBinaryPatchRow *row in workspace.rows){FixtureValidatedBytes *v=[FixtureValidatedBytes new];v.rva=0x1000;v.patchBytes=[NSData dataWithBytes:&on length:4];v.capturedOriginalBytes=[NSData dataWithBytes:&nop length:4];row.validator=(ZNPatchRuntimeValidator *)v;row.validated=YES;}return YES;};
 p.emit=^BOOL(ZNBuildManifest *manifest,NSArray *paths,BOOL runtime,NSString **report,NSString **error){(void)manifest;(void)runtime;if(ZNBuildFail("provider.emit")){if(error)*error=@"Emit injected";return NO;}NSArray *actions=(fixtureMode==1||fixtureMode==3)?@[runtimeAction()]:@[];NSArray *hooks=@[];if(fixtureMode==2||fixtureMode==3){ZNNativeHookAction *a=preparedHook(),*b=preparedHook();b.actionID=9;b.preparedRVA=fixtureSecondHookFails?UINT64_C(0xFFFFFF):0x1104;a.staticPrepatch=b.staticPrepatch=NO;a.staticHookSlotRVA=b.staticHookSlotRVA=0;fixtureHooks=@[a,b];if(!ZNBuildInstallStaticPreparedNativeHooksV1(paths,nil,error))return NO;hooks=fixtureHooks;}
 for(NSString *path in paths)if(![path.pathExtension isEqual:@"json"]){NSData *table=ZNRABSerialize(actions,hooks,error);if(!ZNRABEmbedTableAtPath(path,table,error))return NO;}if(report)*report=@"fixture provider";return YES;};
 m.items=items;m.activeProviderIdentifiers=@[@"fixture"];m.providerSnapshot=@{@"fixture":p};return m;
}
@end
// The postprocessor backend here exercises the production signer and report I/O;
// privacy/value-cell/signature-extension built-ins retain their separate tests.
BOOL ZNPostProcessGeneratedBinaryOutputs(NSArray *paths,NSString *r,NSArray **outputs,NSString **report,NSString **error){for(NSString *path in paths)if(![path.pathExtension isEqual:@"json"]&&!ZNAdhocResignMachOAtPath(path,nil,error))return NO;if(outputs)*outputs=paths;if(report)*report=r;return YES;}
BOOL ZNRuntimeOnlyPostProcessGeneratedOutputsM461(NSArray *paths,NSString *r,NSArray **outputs,NSString **report,NSString **error){return ZNPostProcessGeneratedBinaryOutputs(paths,r,outputs,report,error);}
