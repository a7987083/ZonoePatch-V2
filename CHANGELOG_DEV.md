# 2026-10-13 深度整改追加

本次起点0afc080，源码anchor4795049；全部真实Commit/CI见docs/DEEP_REMEDIATION_CI.json与交付Git记录。实际修复及验证边界见docs/DEEP_REMEDIATION_20261013.md。

- M10.1：统一M56 scalar lease.store、Cell表/重叠/版本校验、拒绝F32溢出；atomic records/enabled和diagnostic Owner锁；实际unload/reload/三线程回归。
- M10.2：Runtime Table/Full Signature私有副本+原子提交；去掉与rename不兼容的hard-link bridge；V3/Runtime-only拒覆盖；报告失败传播；11点Executor故障与既有树逐字节比较。
- H05.2：SearchHistory/Restore、ABI Detail、Runtime-only Gate独立TU，明确Selector/BuildCapability依赖，14独立/40剩余；old UI expansion与安装顺序保留。
- H05.1：增加实际SearchHistory前驱/alias/重复installer/50条历史fixture。没有删除未知外部兼容入口。
- CI失败都追加修复：provenance空锚点、Unified consumer缺私有Selector及导入、Report fixture误定位inline helper。没有跳过测试/刷新历史digest/升级SDK。

已修改/已提交、CI测试/编译与实机分开记录。当前SOURCE PENDING明细不是全项关闭。下面保留此前开发记录。

---

# Development change log

完整逐项 Commit 对照：docs/COMMIT_RECORDS.md / .json，GitHub 分支历史为权威。

本轮新增基线与修复：
- H01 重试代际/tombstone；M02 绑定身份、v2 preferences、串行值命令、退休身份保留。
- H02 row深复制、独立Store、frozen provider、typed BuildSession、slider preference冻结、固定Store锁序、异常cleanup。
- H03 UUID专属输出、ownership cleanup、报告原子写及错误传播、缺失/畸形report拒绝。
- H04 停用并保留trampoline/registry；历史destruction保留私有实现，不增加调用。
- H05 activation owner前置条件/幂等；H07旧行数资料保留、改用imported UI digest与关键拓扑硬门禁。
- H06默认拒绝raw receiver缓存，保留显式bounded兼容分支。
- M01/M04生命周期请求latch、dyld add/remove generation、cached discovery与Scheduler职责分离。
- M03 shared scalar parser，负 unsigned/NaN/Inf拒绝。
- M05 baseline Xcode/SDK/依赖/Actions revisions锁定与toolchain留证。
- M07 production Scheduler/BuildSession/I/O/activation/logger/ABI/codec、portable sanitizer与native fixture；失败测试修正都追加提交。
- M09兼容retention审计；M10 shared checked layout reader；M11减少后台/全隐藏tick与多余置顶。
- L01/L02/L03/L04独立row/snapshot/activation/logger owner、ring、严格warnings和三态边界。

真实失败：严格c++17不能编译生产typeof（测试改gnu++17）；ARC不允许捕获autoreleasing输出参数（改block owned locals）；报告writer迁移遗留unused变量（移除冗余）；Objective-C字典literal触发assert宏逗号解析（双括号）；snapshot category声明归属warning；metadata codec测试需要显式presentation policy依赖。未升级SDK/依赖，未掩盖这些错误。

一次工具发布产生与前一tree相同的 metadata-only Commit 6cb5785，保留历史并明确标记；实际M10源码由cdcc759提交。没有把该重复树算作已应用源码改动。

已修改/提交、CI测试与编译按具体Run记录；实机未验证。全项关闭状态未宣称，剩余项见KNOWN_ISSUES。
