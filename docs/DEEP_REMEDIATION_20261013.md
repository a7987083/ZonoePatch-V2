# e5361b7之后的执行所有权 / UI继续治理

当前证据见 [FINAL_SOURCE_GOVERNANCE_20261013.md](FINAL_SOURCE_GOVERNANCE_20261013.md)、[EXECUTION_OWNERSHIP_20261013.md](EXECUTION_OWNERSHIP_20261013.md) 与 DEEP_REMEDIATION_CI.json 新增 execution_governance 字段。当前19个独立UI单元、35段inc；历史正文数字及Managed裸atomic缓存问题已由新的具体实现覆盖，其他未关闭风险继续有效。未宣称M10.1/M10.2/H05全部关闭。

以下为上轮保留证据。

---

# 2026-10-13 深度整改：当前源码状态与验收边界

本次开始真实远端 HEAD 为 `0afc080e8e264255424264b4480222275f0eca5b`，分支 `dev/technical-debt-p0-p2-20261013`，push Run `38353817406` 成功。用户参考 `afa81485978fa280ca025e4ccfdbb6aa55e70f94`之后已有整改，不从参考Commit重新开发。所有远端更新均追加parent、expected HEAD校验、force=false；没有历史改写。最终身份/Run/Artifact/digest以交付包 `DELIVERY_STATUS.json` 为准。

## 已实际修改

### M10.1

- `ZNStaticValueCellWriter.h:ZNM56StoreCell/ZNM56WriteTextToCell`成为唯一生产M56 scalar writer。通过调用方同一个 `ZNImageOperationLease::store`检查incarnation、撤销、对齐和RW范围，不再在Binder直接atomic写入。不另开第二个loader retain获取cell地址。
- `ZNStaticValueCellAccess.h:ZNStaticValueCellAddressForRecord`校验Static版本、完整Entry表在section内、checked segment end、Cell尾区与Static表不重叠。旧Record的Entry/Dispatch已经是owned值，本次没有退回live指针。
- F32在double转float前拒绝超出FLT_MAX的有限输入，避免写入Inf；原NSScanner文本语义保留。
- `ZNStaticDispatchRuntime`以atomic property发布records/读取enabled。diagnosticLines采用与写入相同的global Static gate -> runtime monitor顺序，避免枚举正在修改的owner数组。添加第三个observer线程与Static/Cell两个writer并发。
- 保留LoadedImage Snapshot、短期且平衡的RTLD_NOLOAD retain、dyld非阻塞撤销、ABA incarnation、ARM64 stub和现有Hook retirement语义；没有新增永久dlopen。

### M10.2

- `ZNRuntimeActionBuilder.mm:ZNRABEmbedTableAtPath`和`ZNRuntimeActionSignaturePostprocess.mm:ZNM46AugmentPath`不再原地mmap提交：私有副本编辑，成功后由`ZNEditBuildFileAtPath`完成pwrite/fsync和原子rename。msync/pwrite/publication失败保留原始文件。
- Signature selector同时识别旧`.znpatched`与Runtime-only suffixless UnityFramework。`ZNBuildManifest.mm:ZNM684RuntimeSignatureBridge`移除hard-link alias。原因：事务rename替换inode时，alias与真实output不再共享更新，删alias会丢失扩展。没有改表布局、RVA/branch或签名算法。
- V3/Runtime-only target builder不再unlink同名输出后复制。已有产物/不同target同basename由copy拒绝，Executor回滚自己拥有的stage；拒绝覆盖是失败，不称已支持同名目标的独立成功生成。
- `ZNRABUpdateBuildReport`返回BOOL并经生产`ZNWriteBuildReport`写入；缺失/畸形指定report及持久化失败向provider/Executor传播。没有report路径的历史独立调用保持兼容。
- Executor故障fixture增加第二个Hook实际无效RVA、第二个Descriptor sink、pwrite、file.publish。已有输出由目录名比较升级到整个输出树逐文件NSData比较。保留原始输入及authoring validator/row数据断言。

### H05.2 / H05.1

本次从实际10个独立UI单元推进到14个；相对用户列举的7个基线为累计+7。剩余40段`.inc`，不是全量完成。新增独立单元：SearchHistory、SearchRestore、ABIDetail、RuntimeOnlyBuilderGate。

建立/直接导入真实finder getter/submit接口与BuildCapability owner。UI展开源码仍逐字节重建历史baseline，54段顺序、63exchange/8set、安装stage和Selector保持；没有刷新expanded digest掩盖改动。每个独立单元使用iPhone SDK arm64/iOS14 `-Wall -Wextra -Werror`编译，完整dylib构建检验剩余consumer依赖。

新增实际SearchHistory installer/start-wrapper/Foundation历史存储fixture：安装前原IMP，安装后wrapper与旧alias各自行为、100次重复安装、历史上限50、去重。Renderer为明确的facade，不是UIKit行为证明。实际旧alias安装后调用前驱且绕过history逻辑，不能无证据删除。没有删除任何未知外部Selector/IMP兼容层。

## 自动化证据

- 完整workflow未改SDK、依赖pins、测试开关或历史基线。所有失败保留，后续Commit修复。
- 本地7个portable C++测试g++通过；layout/file/loaded image含ASan/UBSan，LSan仅本地detect_leaks=0；Apple生产编译与ObjC运行由Actions验证。
- `static_owned_metadata_test.mm`执行实际dyld映像、owned Entry、共享Owner、leased Cell/selectedTarget、int边界/F32溢出/NaN/未对齐拒绝、畸形版本和表、人工撤销、并发reader/writer、真实unload及旧incarnation拒绝。人工撤销之后还原state只存在test，不是生产恢复协议。
- Runtime Table与Full Signature真实生产函数msync/pwrite/file.publish拒写后完整bytes比较；成功后独立签名pagehash复核。签名不是以返回YES代替。
- 完整Executor控制流/真实V3多target/native双Hook/serializer/signer/file transaction + host provider/session/manifest backend doubles。11个故障点：prepare、emit、第二target、第二hook、第二descriptor、msync、pwrite、signature、file.write、file.publish、output.publish。这是所列路径的真实注入，不是所有内建Provider/discovery端到端通过。
- 原signer、V3 install、Runtime-only target基线/当前完整byte cmp保持。组合成功产物5个独立CodeDirectory校验；最终dylib在下载后再独立验页。
- Runtime报告fixture抽取真实函数并调用真实report writer，检验写入失败保留、畸形拒绝、成功结构、无report兼容。
- 失败摘要：M56删除段empty provenance锚点；UI Unified consumer缺submit声明及缺private header直接导入；Report抽取器误把inline template调用当定义、下一提交错误搜索实现文件。后续修复保留失败Commit，未跳过检查。

## 仍未关闭：具体源码工作

### M10.1：执行租约仍未统一（SOURCE PENDING）

`ZNNativeHookRuntime.mm:456-503/545-562`的三个Managed invoke API atomic指针，没有绑定映像incarnation，prepare的非零缓存shortcut没有证明重载安全；`ZNManagedInvokeBoolCallback`实际调用期间没有execution owner。`ZNIL2CPPRuntimeCommon.h:ZNIL2CPPResolveSymbol`fallback loader handle没有平衡释放；InvokeEngine/DirectNative/MultiArg/Codec消费方返回裸function/MethodInfo，不能只在symbol lookup结束时dlclose修复。

当前metadata/write lease短期retain只覆盖管理调用。生成stub经BR跳到replacement或trampoline；撤销不能撤回CPU已读取的branch/return地址。给C++ helper加lock不能证明汇编返回前的映像保活，给Header复制不能证明代码地址可执行。已有loader lease使用operation mutex，直接扩展到任意managed invoke还必须验证callback/reentrancy/跨线程主队列等待的锁顺序，不能用永久pin规避。

本次已实现并验证Cell统一store与并发诊断；未提交未经上述验证的全native execution改造。后续条件：区分短读写与可重入execution owner，将method/codec/API/slot绑定同一incarnation，建立不在dyld callback等待的retire和在途drain；对实际bridge原始/启用/停用/撤销/同址重载及主队列回调分别建立host fixture，再做目标App/iPhone ABI实机。此项不是“只差iPhone”。

### M10.2：全Provider/跨Runtime目标模型仍未贯通（SOURCE PENDING）

`ZNNativeHookStaticPrepatch.mm:ZNM610FindUnityOutput`仍选择一个Unity output；一个Hook Store/Runtime Table没有每action运行映像身份路由。`ZNRuntimeOnlyBinaryBuilderBuildWorkspace`仍生成一个default target。V3 Static支持多个不同basename目标；新增同basename碰撞拒绝保护产物，但不把拒绝称完整多目标成功。

完整Executor测试的session/manifest/provider后端仍为显式host doubles；另有真实BuildSession隔离与实际prepatch/序列化/签名测试，不能把组合解释成所有真实内建discovery/prepare/emit端到端。随机ProtectionV2、全部native template执行/最终IPA安装亦未验证。

本次实现Runtime两文件阶段事务、报告失败传播、已有产物保护与更强故障证据。下一步需要为Runtime/Hook manifest建立明确目标身份与per-target provider分组/作用域Store，保留旧单Unity格式兼容，使用生产内建providers加受控IL2CPP discovery fixture，完成两runtime目标/两hook目标、第二target/descriptor/signature failure以及authoring完整快照。不能仅将一个table复制到各target制造多目标通过。

### H05.2：40段仍有可继续做的源码迁移

清单 `UI_REMAINING_MODULES.json`。核心V040/version族，UnifiedFinder/ImmediateChain/Builder的private classes/blocks/Selectors尚未完整建立owner。保持source baseline reconstruction；下一组从MenuBinding installer声明owner及Unified finder接口开始，每组strict独立编译 + full build + runtime family fixture。此项并非设备阻塞，也没有宣称已审阅并完成全部259个生产源码文件的整改。

### H05.1：兼容性证据不足时保留

M47与SearchHistory真实alias fixture只覆盖指定family。487方法/71安装点源码图不穷举外部objc_msgSend/dlsym及启动中途调用。保留旧Selector/历史前驱，不扩大category或加swizzle。下一步逐族采集完整trace（overflow标incomplete），建立before/mid/after和重复installer fixture；只有明确消费者/转发契约后才能删除。

目标App与iPhone验收全部未执行；独立清单见 `DEVICE_ACCEPTANCE.md`。CI成功不能替代Hook执行、receiver GC lifetime、IPA安装或跨场景验证。
