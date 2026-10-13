# Known issues：具体剩余债务与验收边界

以下状态区分源码治理、编译/自动化证据、真实App验收。已关闭P0未重开；保留其原实机待办。

| 项目 | 当前状态 | 源码位置 / 真实阻塞 | 剩余工作与验收条件 |
|---|---|---|---|
| H05.1 历史IMP链 | 部分完成；54段拆分、策略独立owner已完成 | `src/ui/core/ZonoeRuntimeMenu.inc` 的V040/V0401/V0402等；`src/ui/finder/ZNMethodFinderUnifiedUI.inc`；`src/ui/features/ZNM630HardCutUI.inc`；仍有63处exchange、8处setImplementation。前层通过改名Selector调用先前IMP，直接删层会断链；UIKit私有属性接口未集中 | 为每个调用族建立selector→安装前/后IMP→调用前驱图，测试重复安装/不同category加载顺序及shared初始化；先导出typed内部接口再逐族消层。旧Selector、C installer和安装顺序保持可观测兼容；最终目标App交互回归另验 |
| H05.2 跨段静态作用域 | 明确保留 | `docs/UI_DEPENDENCIES.json`列13个词法跨段符号，例如core的`ZN48TopViewController`→FeatureBuilder、execution的`ZNM52XTop`→M630、`kZN51CandidateKey`→ChainExecute。根core私有controller声明和宏仍被后段使用；include必须维持lexical环境 | 逐个helper提取或构造私有接口，定义/消费者清单与编译均通过；消除该符号的跨段file-private依赖后再变独立TU。词法清单可能保守包含注释且不能证明动态引用不存在 |
| M10.1 运行中映像解析 | 未全量统一；不能全项关闭 | `ZNIL2CPPOwningMethodResolver.mm:ZNM45LoadRuntime`、`ZNSharedSiteProbeV2.mm`、`ZNOffsetResolverV2.mm`、`ZNRuntimeActionRuntime.mm`、`ZNStaticDispatchRuntime.mm`、`ZNNativeHookRuntime.mm` 等仍读取dyld header/segments/functionStarts；generation缓存失效不是读取期间的映像租约。fileoff通常超过header字节数，不能用File parser处理mapping | 新建LoadedImage/header-owned-snapshot接口，checked unsigned/signed slide和VM range、section/table长度；模拟header截断/卸载竞争/缓存引用寿命；将长寿命raw command指针改为值或共享owner；共享policy逐个适配。真实动态load/unload另需目标App日志。阻塞包含源码生命周期协议和自动化fixture缺口，绝非只有缺手机 |
| M10.2 完整业务生成覆盖 | 固定fixture字节验证已完成；业务组合未验证 | V3 fixture覆盖parse/install，runtime-only fixture执行单目标builder（路径provider stub），完整signer执行并重复签名；不运行真实IL2CPP resolver、复杂payload随机布局和所有provider组合 | 增加可公开复现的真实合法Mach-O/对应workspace样本，覆盖static/runtime/hook/mixed、section容量边界、签名后重新解析；最终替换IPA整包重签安装。未知新LC保持旧preservation policy，新增LINKEDIT命令必须有schema/样本再扩展 |
| L02.1 外部兼容入口 | 必须保留 | `ZNStaticBinaryBuilder.mm`、`ZNAnyImageAddressResolver.mm`、`legacy/ZNLegacyStaticBinaryPipeline.mm`与旧UI Selector；当前Makefile未使用不代表source消费者不存在；ObjC/dlsym调用不能仅靠grep否定 | 列外部消费者/导出/selector注册与source发布边界，建立兼容migration fixture后才能弃用。四个file-private无调用align helper已删除；证据见L02_REMOVAL_EVIDENCE.json |
| L02.2 历史命名与清理候选 | 部分完成；保留行为相关名字/文案 | `src/ui/compat`、版本号前缀Selector、偏好key以及`ZNIL2CPPInvokeEngine.mm:ZNInvokeCStringFinished`。后者仅无直接文本调用还不足以证明其生命周期设计已不需要；pref/Selector重命名会影响外部兼容/持久化 | 对命名区分纯内部名与协议/API名；只改纯内部并测试。未调用生命周期函数先查创建/清理责任，确认替代路径与失败清理测试后再删除 |
| M11.1 真实性能 | 采样/报告/host harness完成；实际性能「未验证」 | `ZNPerformance.h` / `ZNPerformanceReport.mm`、生产五类span及docs/PERFORMANCE_ACCEPTANCE.md；host parser/editor fixture不代表UIKit/IL2CPP/Hook/完整生成。没有匹配设备基线、热状态、App输入集合 | 同设备/App/iOS/输入按5预热+30以上操作、3批基线/当前采样，记录raw环境/次数/错误、median/P95；cold startup独立30次。Instruments验证CPU/内存、异步首帧、队列等待。没有这些证据不宣称改善 |
| M11.2 测量边界 | 显式保留的基础设施扩展待办 | `zn_beginActivation`只测可用window后的同步激活；`search.sync`只测V3同步核心；Hook只测reconcile执行，不测queue latency/目标函数或trampoline；1024样本有界ring丢弃更早样本 | 添加与业务请求关联的异步ticket/结果标签及raw导出，分别测cancel/debounce/首帧/queue等待；不能把现有span换名字冒充端到端测量；采样本身需开/关对照 |

## 前轮已治理项目的实机待办（未重做）

- H01/H02/H03：调度撤销、BuildSession隔离和输出I/O已有生产回归；真实App事件burst、全能力组合与磁盘/签名故障仍待验收。
- H04：retire停用且保留trampoline/registry；in-flight调用、槽长期占用和映像卸载的生命周期待验。不改回公开销毁。
- H06：默认fail closed；raw receiver兼容开关保留但不能保证GC安全。需API缺失、对象销毁和scene切换证据。
- M01/M04：image generation和lifecycle latch有自动化验证；读期间unload协议仍是独立设计问题。
- M05/M07：固定SDK/依赖并执行macOS/ARM64 fixture；hosted image和brew未位级锁定，macOS ABI不是目标iOS App ABI实机证明。

CI、format/pagehash验证不能替代 DEVICE_ACCEPTANCE.md。项目未宣称H05/M10/L02全部技术债清零，也未宣称性能改善。
