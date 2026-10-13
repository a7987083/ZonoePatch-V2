# 当前优先级更新（2026-10-13）

本轮具体源码位置、已实现措施、失败证据和后续验收条件：docs/DEEP_REMEDIATION_20261013.md。以下剩余项均未全关闭。

| 项目 | 当前剩余及后续验收 |
|---|---|
| M10.1 SOURCE PENDING | Native Managed API缓存未绑定incarnation；Common/Invoke/Direct/MultiArg/Codec的裸函数消费者未统一execution owner。生成BR stub/返回地址在途安全不能由Cell写租约推导。需无dyld等待的retire/drain、回调锁序、实际bridge/unload/ABA fixture后再实机。Cell写入和诊断并发本轮已修复。 |
| M10.2 SOURCE PENDING | 生产内建provider/discovery不是完整Executor fixture后端；Runtime-only和Native prepatch仍单Unity目标，缺每action映像目标身份路由。已有V3多目标/碰撞拒绝与11点故障回滚不替代多个Runtime映像成功。需typed target grouping/作用域Store/完整内建prepare-emit fixture，保留旧格式兼容。 |
| H05.2 SOURCE PENDING | 14独立UI单元，40段.inc。core/version、UnifiedFinder/chain/builder私有类/Block/Selector owner继续迁移。UI strict、真实全build与历史源码重建必须每组执行。 |
| H05.1 SOURCE + DEVICE PENDING | M47/SearchHistory实际兼容alias仍有不同的前驱行为；全71安装源点的外部消费者及初始化途中未穷举，不删除。需逐族完整runtime trace与前中后/重复安装fixture。 |
| DEVICE PENDING | 所有真实App Hook执行、GC receiver/scene、卸载与安装、iPhone UI/ABI、IPA重签安装、性能改善均未验证。 |

以下保存历史清单；旧Entry/Cell状态及7/47数字已由上述当前状态覆盖，其余未关闭风险继续有效。

---

# 剩余技术债与验收边界

源码完成、CI通过、目标App通过和iPhone实机通过是四种状态。业务源码anchor `42d5750`完整CI通过；最终交付身份见 DELIVERY_STATUS.json。尚未执行目标App/iPhone验证，性能改善未验证。已关闭P0没有重做。

| 项目 | 位置与实际阻塞 | 已尝试/完成 | 剩余工作与验收条件 |
|---|---|---|---|
| H05.2 SOURCE PENDING | 47个 `.inc`；完整清单 `docs/UI_REMAINING_MODULES.json`。M2文件同时定义engine/type/block与UI，取消/统一finder/chain族仍借词法private Selector/类声明；13静态边不是完整依赖闭包 | 原只搬.inc不等于独立编译；本轮建立真实私有controller/key/helper/policy owners，7段独立TU；strict编译暴露缺capability import/内容高度声明/旧unused wrapper并已修复 | 提取M2 engine type/interface owner，逐族定义真实private契约，不以巨型复制头覆盖依赖；每段旧body/order reconstruction、同Selector无冲突、strict iPhone SDK编译、相关fixture+fullCI。仍有可做源码工作，不能标为仅DEVICE PENDING |
| H05.1 SOURCE + DEVICE PENDING | core V040/V0401/V0402、unified finder/chain、compat族；`UI_SELECTOR_IMP_GRAPH.json`列所有63exchange/8set源点。alias Selector交换后保留前层IMP，源码不能穷举外部objc_msgSend或初始化途中调用 | 487方法/123 literal helper调用图、stage/Selector/前后IMP真实runtime trace，实际ObjC双层alias/旧IMP返回/禁用/还原测试；没有删除Swizzle | 对真实族执行安装前/中/后与重复安装fixture，采集目标App complete trace；明确外部兼容aliases再替换为显式实现/转发。不能直接跳过早期安装：后层接管前是否调用无证据 |
| M10.1 SOURCE PENDING：活跃表与写租约 | `ZNStaticDispatchRuntime.mm:ZN44HeaderValid/parseHeader/selectedTarget`、`ZNM56StaticValueCellBinding.mm:ZNM56RecordMatches/ZNM56ValueCellAddress/ZNM56WriteTextToCell`仍使用mapping entry/header/cell，M56 flags读取在snapshot前。native slots/trampolines也有live地址 | metadata header-owned snapshot、safe VM adapter、cache epoch和读取复制完成，真实macOS卸载/ABA/畸形/窗口ASan通过；不能把这当execution lease | 所有active metadata读改copy并保留owner/generation；写路径需要撤销/在途同步设计与故障fixture。无条件dlopen pin会改变卸载语义，不能作为通用修复。可控卸载/同址重载/并发写/在途调用fixture后再实机；全项尚未关闭 |
| M10.1 DEVICE PENDING：动态调用 | IL2CPP resolver/invoke、NativeHookRuntime、StaticDispatch dispatch | image/epoch校验与元数据寿命改善；VM复制不崩溃测试通过 | 真实IL2CPP API调用期间卸载、scene/receiver销毁、Hook在途撤销，需要目标App/设备日志与生命周期证据。当前不能承诺native函数指针安全 |
| M10.2 SOURCE PENDING：完整业务事务 | `ZNBuildExecutor.mm`能力prepare/emit/postprocess；`ZNNativeHookStaticPrepatch.mm:ZNBuildInstallStaticPreparedNativeHooksV1`循环直接修改mmap、成功后更新descriptor与签名 | 完整生产单目标V3/runtime、实际Native prepatch与Mixed、输入未改/拒覆盖/容量/max entry/V3原字节失败输出删除、5产物独立pagehash通过 | BuildExecutor真实provider和多目标端到端fixture；第二target/第二hook/descriptor sink/签名/msync/pwrite失败注入，断言所有输出/Store恢复。现有单目标拒绝不是完整事务回滚，仍有源码测试与可能修复工作；不要只说“复杂/风险高” |
| M10.2 DEVICE PENDING | 随机ProtectionV2 payload、所有Native template、目标IPA | 原格式fixture完整字节cmp、生成结构与签名验证 | 真App原样本/对应workspace，ARM64实际分支/trampoline执行、变体恢复、IPA整包重签安装。macOS构造Mach-O不证明iOS可安装/执行 |
| M11.2 DEVICE PENDING：性能结果 | `ZNPerformance.h`、ZNAsyncPerformance、ZNFirstDisplayTick、scheduler和M2调用点 | 9指标、结果计数、async/reset/concurrency/cap测试、6 host微基准和sampling开关对照 | 首tick只是display-link代理，不是GPU首帧；host分位数是31批均值。按性能协议记录同设备/App/温度/输入/操作数/错误数，5预热/至少30操作/3批baseline-current，Instruments CPU/内存、采样开关对照；没有数据不称改善 |
| M11.2 SOURCE PENDING：更细边界 | M2取消completion、ZNFirstDisplayTick、performance ticket/registry | queue等待与取消确认已采样，bounded registry含dropped；timeout计Failed | 真实首帧/GPU时间、全搜索族的debounce与取消端到端、Hook目标函数耗时尚非现有span。不要重新命名旧span冒充该指标；进一步业务入口需要对应事件/回调fixture |
| L02 外部兼容保留 | legacy pipeline、兼容V1 builder、AnyImage resolver、版本Selector、prefs keys | 累计8个无调用static helpers移除、旧LINKEDIT包装合并；删除体hash和引用证据保留 | 未在Makefile中不能否定源码消费者；ObjC/dlsym/API/prefs未知消费者未证伪。先建立consumer/migration fixture、弃用协议与导出核对，未满足不得删除/重命名 |
| 构建环境可复现性限制 | workflow brew/macOS hosted image | Xcode16.4/SDK18.5、Theos/Dobby/Actions pins、toolchain/artifact digest保存 | 外部SDK依赖不内嵌、hosted OS/brew未位级锁定。不能声称离线工具链或bit-identical跨runner；本次下载文件与对应CI源码逐字节核对 |

前轮P0实机待办继续保留：Hook scheduler事件burst、BuildSession真实全能力组合、retire保持trampoline的在途安全、GCHandle/缺API/scene切换、I/O/签名故障。没有把CI成功替代这些验收。详细证据和下一步见 `docs/CONTINUATION_EVIDENCE.md`、`DEVICE_ACCEPTANCE.md`。
