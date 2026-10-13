# 本轮源码治理证据与验证边界（2026-10-13）

本轮基线为远端 `94491dae3541d00af172db7bb7e4b16c634530cb`，push Run `38338809727` 成功，Artifact `11786396518`。其 dylib SHA256 为 `c470424abd4830daef58af8cdfed20ae499a2d353e76dd1be957f1a7d12222dd`。这是源码/构建基线，不是目标 App 或 iPhone 的稳定性证明。继续使用独立 dev 分支、固定 Xcode16.4/SDK18.5、Theos/Dobby/Actions pins；没有改写历史或强推。

## M10.1：已实现的读协议

`ZNLoadedImage.h` 的 Snapshot 将 header/load commands 拷贝到自身 storage，保留原 runtimeBase/preferredBase、可读段值和 generation。header 限 16MiB、4096 commands，读取限64MiB，所有地址/长度/slide转换经过 checked arithmetic。header-only parser 不把映像映射当完整文件。VM adapter 使用 iOS SDK 支持的 `vm_read_overwrite`，只在完整读取且前后 epoch 相同后发布数据。Cache最多256项，任一映像 generation变化失效；ReadWindow最多64KiB，超过窗口的请求直接交给有界 VM reader。Snapshot持有元数据，**不 pin executable image、不充当原生调用租约、不提供活跃数据事务一致性**。

迁移位置：IL2CPPResolver、IL2CPPOwningMethodResolver、MethodFinderSearchV2/V3/ZeroVMAddrFix、M2 Engine、OffsetResolver、AnyImageAddressResolver兼容源码、PatchRuntimeValidator、NativeHookBuildPrepare/Runtime、IL2CPPHybridFinder、StaticDispatchRuntime、SharedSiteProbeV2/ExecutionProbeV3、RuntimeActionRuntime、M56 header。probe command pointers由共享owner保活；function-starts与代码扫描使用安全拷贝；Runtime Action/Native Hook生成表先拷贝再解析。

测试：portable `loaded_image_test.cpp`覆盖拥有存储、file-vs-mapping、negative slide、畸形header/section、overflow、读期间epoch变化、同址卸载重载ABA、缓存失效、窗口边界和65537字节请求，ASan/UBSan；`loaded_image_apple_test.mm`在macOS实际dlopen/dlclose动态C映像、dyld generation和生产VM reader。macOS通过不等于iPhone通过。

剩余：`ZNStaticDispatchRuntime.mm:ZN44HeaderValid/parse/selectedTarget`与`ZNM56StaticValueCellBinding.mm:ZNM56RecordMatches/ZNM56ValueCellAddress/ZNM56WriteTextToCell`仍持有/读写生成映像的活跃entry/cell；native调用和trampoline也不能由header快照保活。不能给 Cache无条件加dlopen引用：这会改变卸载语义，且Objective-C/IL2CPP运行状态不因此安全。需单独设计映像租约/撤销/在途调用协议，先用可控卸载竞争、重复地址映像、原子写入失败fixture验证，再目标App实机验收。源代码残余工作存在，M10.1不全项关闭。

## H05.2：真实独立编译与剩余接口

54个逻辑段保留原顺序，7个成为独立 `.mm`：ModalShell、PublicCompactUI、FeatureBuilderControlsV2、M47VersionUI、M562SliderIsolation、FeatureGroupUI、FeatureRuntimeControlsV2。真实私有controller声明、共享association keys/tags、top-controller helpers、search policy各有唯一owner。13个旧词法边中11个真实静态依赖已移到接口；余下Start/Show宏在消费者前已undef，是词法假边。这个数字不能解释为所有类/类型/Selector依赖已经解决。

`UI_DEPENDENCIES_BASELINE.json`保留旧清单，当前JSON记录owners。`ui_source.py`重建旧源码并核对旧digest；只对已列出精确before/after的安全读、计时、完整零初始化、证明无用的内部函数删除作逆向重建。没有简单刷新旧基线。独立TU用iphoneos arm64/iOS14 `-Wall -Wextra -Werror`编译；新增编译错误通过补直接导入/真实声明解决，未屏蔽警告。剩余47段不是独立编译单元，见 `UI_REMAINING_MODULES.json`。

具体下一接口边界：`core/ZonoeRuntimeMenu.inc`保留主要实现/旧版本categories；`finder/ZNIL2CPPMethodFinderM2.inc:ZN61ProgressBlock/ZN61CompletionBlock/ZNMethodFinderM2Engine`包含engine与UI双职责；M21/M22取消族和unified finder/chain族仍共享private Selector与词法导入。原方案只加controller主声明不足以完整声明所有调用族；本轮真实编译已暴露capability import、内容高度声明、旧unused wrappers并修复。下一步应将M2 engine类型/接口作为owner迁移，然后按剩余清单逐个strict编译，不把整份巨型UI复制为依赖头。上述剩余为SOURCE PENDING，不声称只需iPhone。

## H05.1：安装图与保留链

`UI_SELECTOR_IMP_GRAPH.json`记录487个method definitions、71个安装源点（63exchange/8set）、123个含literal selectors的helper调用，包含方法body hash与语法self调用边。七个独立category无同类同Selector body冲突。动态安装包装在默认关闭时透传真实runtime函数；开启后记录stage/file/line/Selector/Method及前后IMP，最多4096事件并标记overflow。`ui_install_trace_test.mm`实际Objective-C执行两层alias调用111、set返回旧IMP、停用追踪与还原行为。

未删除任何历史Swizzle。原因不是抽象“风险高”：alias Selector在交换后保存前层IMP，同一个安装器可能在后层接管前被调用；旧Selectors/API可能存在外部消息消费者。源码graph不覆盖所有objc_msgSend/dlsym或所有目标App早期调用。先在启动前设置 `zonoe.diagnostics.ui-install.enabled=YES`，导出 `ZNUITraceSnapshot()` 和 stage事件，确认complete；用真实族的installer/转发方法建立重复安装/前中后调用fixture，明确外部兼容alias迁移，再逐族消层。当前动态目标App关系图 DEVICE PENDING；消层本身 SOURCE PENDING。

## M10.2：生产组合与签名

原基线 signer/V3 parse-install/Runtime-only生成fixture的完整字节cmp保留。新增 `extract-builder-combinations.py`抽取完整生产V3与Runtime-only单目标builder、Action序列化/owned embed、Native static prepatch全部helper与完整函数，并记录每段SHA256；没有重写测试版算法。测试替身只提供模块路径、已验证原字节/patch、Store snapshot/descriptor sink和prepared IL2CPP descriptor。Fixture含合法ARM64 NOP区、__TEXT/__DATA/__LINKEDIT、UUID和iOS14/SDK18.5 load command。

覆盖Static、Runtime-only、Native-only与Mixed，实际native branch/cave/slot生成和重签；检查branch编码与displaced NOP、表完整字节、输入未修改、拒绝重复覆盖、最大entry/超一项、缺少Direct RVA/Native descriptor、owned容量exact-fit/超一字节、V3原字节不匹配时删除输出。每类签名后重签幂等、重新parse，再用最终artifact同一严格独立校验器计算CodeDirectory page hashes，必须5个文件均验证。

未覆盖：完整真实IL2CPP discovery/validator、所有能力provider的生产orchestrator端到端、multi-target/provider注入故障时完整回滚、Native prepatch中途/签名失败后全事务恢复、随机payload每个变体实际执行、IPA重签安装。单目标原字节失败删除输出不是对所有这些场景的替代证明。需接入 `ZNBuildExecutor.mm` 的会话/能力provider fixture，注入第二目标、第二hook、签名/I/O失败；保存输出目录与store前后快照。Native文件writer循环写入后才msync，不能仅因已有fixture通过就声称所有失败事务安全。真实Hook ABI/生命周期和iPhone执行 DEVICE PENDING。

## M11.2：测量定义

增加Hook队列等待、M2搜索队列等待、取消请求至completion确认、首个CADisplayLink tick/1s超时；Ticket跨线程exactly-once、reset epoch隔离、completed/cancelled/failed outcome，搜索registry最多256并导出pending/dropped。原5类同步span保留。首个display tick是代理指标，不代表真实GPU首帧，也不包含进程启动/窗口等待。

`async_performance_test.cpp`确定性时钟/并发/重复结束/reset/超时；`async_search_metrics_test.mm`生产registry取消/清理/容量；host benchmark使用相同volatile工作负载的empty/disabled scope/enabled scope/enabled ticket，并保留Mach-O parser/editor场景。5预热、31测量批、每批1000次，double batch means避免丢失sub-ns值。P95是31批均值的分位数，**不是逐操作P95**。CI JSON保存环境/编译器/协议。没有真实设备匹配基线，实际9类场景与性能改善均未验证。

## L02：删除边界

原4个alignment helpers之外，确认删除Invoke尾部字符串谓词、ZN65旧metadata包装、ZN50旧metadata包装及其唯一trim helper。全部file-local static，没有调用/address-of/注册/导出属性，删除体hash与依赖证据在 `L02_REMOVAL_EVIDENCE.json`。Invoke谓词不是内存释放函数，旧“lifetime”描述已纠正。保留所有旧Selector、API、prefs key、Legacy builder与AnyImage resolver等未知外部消费者路径。
