# Performance acceptance

M11 tick 保留 0.5s fallback timer 和正常 active 场景的 window/attach/layout/theme 路径。仅跳过后台或 panel/floatButton 都已隐藏的无效工作，置顶前检查当前 sibling 位置，避免无条件改动视图顺序。

已做源码 topology/digest 检查和 iOS 编译；冷启动、前台恢复、其他游戏悬浮窗竞争、系统主题切换仍需 iPhone 验证。没有 Instruments 数据，不声称耗时/CPU 改善百分比。

仍需测量：首次菜单、重复搜索/取消、隐藏/显示/后台 CPU、image burst、生成峰值内存/耗时。搜索当前有 6 秒预算和候选上限，不是无界；V2/V3 查询路径不在无运行基线时强行合并。

## 可重复采样入口（M11 continuation）

默认关闭：启动前在目标 App 的 NSUserDefaults 设置 `zonoe.diagnostics.performance.enabled=YES`；也可在开发集成中调用 `ZNPerformanceEnable(YES)`。`ZNPerformanceReset()` 开始新的采样窗口，`ZNPerformanceSnapshot()` 返回可 JSON 序列化的五类指标。关闭后不读取时钟、不记录样本，但各入口仍有一次 atomic enabled 检查。每指标仅保留最近 1024 样本，总数单独累计；分位数按 retained samples 的 floor((N-1)*p/100) 取值。reset 使用 epoch，忽略 reset 前尚未结束的 span；同线程同指标嵌套只计最外层。

| 指标 | 实际源码入口 | 测量范围与限制 |
|---|---|---|
| menu.activation | ui/shell/ZNDeferredBootstrap.inc `zn_beginActivation` | 可用 host window 后同步 begin/finish 激活；不含进程启动、等待 window、首帧 GPU 完成 |
| page.refresh | 六个 `*renderPage` 实现 | 当前调用族最外层同步渲染；不含异步布局/合成完成 |
| search.sync | ZNIL2CPPMethodFinderSearchV3.mm `zn60_searchCandidates` | 同步 V3 查询，包括失败返回；UI debounce/取消等待不在此 span |
| hook.reconcile.execution | ZNNativeHookScheduler.mm 队列内部 reconcile block | 执行耗时；不含队列等待、被 Hook 的目标函数耗时、trampoline 安全性 |
| binary.generation | ZNBuildExecutor.mm `ZNBuildExecutorBuildWorkspace` | 会话 capture/prepare/build/emit/postprocess，同步全流程，包含失败尝试 |

复现 host microbenchmark：`python3 scripts/benchmark.py --output performance-host.json`。固定 64KiB fixture，5 批预热、31 批测量、每批 1000 次，-O2；记录 Commit、平台、CPU 架构、编译器、clock。它只执行生产的 portable Mach-O parser/editor，不将结果命名为菜单、搜索、Hook 或完整生成性能。CI 上传该 JSON；不建立跨 hosted runner 的性能百分比门禁。

实机协议：同 App/版本、iOS、设备、签名包、输入集合、温控/前后台状态；冷启动激活独立运行至少 30 次；其余场景先预热 5 次，reset 后执行至少 30 次相同操作，导出 snapshot 和操作数/失败数。搜索固定查询和加载映像；Hook 固定 action 集合并另测 queue 等待；生成固定 workspace 并核验产物。基线/当前分别运行至少 3 批，保存 raw device evidence、median/P95、成功率和 Instruments CPU/内存。诊断采样自身有开销，需启用/关闭对照。UIKit、IL2CPP、目标 Hook、完整二进制生成的实际性能均「未验证」；目前没有性能改善结论。
