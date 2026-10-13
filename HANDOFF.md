# 当前源码治理状态（2026-10-13，e5361b7之后）

本轮具体变更、验证边界与未完成项以 [FINAL_SOURCE_GOVERNANCE_20261013.md](docs/FINAL_SOURCE_GOVERNANCE_20261013.md) 和 [EXECUTION_OWNERSHIP_20261013.md](docs/EXECUTION_OWNERSHIP_20261013.md) 为准。以下保留此前历史，旧14/40和未迁移Managed API描述不再代表当前实现。

- M10.1：已迁移的执行消费者、Managed incarnation缓存、短期owner及Bool/Callback Slot拒绝旧generation已实现，d54cf6a完整push/PR CI通过；汇编整次调用/返回地址、匿名trampoline、Codec期望generation及GC/Domain仍UNRESOLVED。
- M10.2：真实Store的Prepare Descriptor批次原子验证/发布及第二项失败回归通过；多个Runtime目标身份和完整内建Provider端到端仍UNRESOLVED，不能称仅DEVICE PENDING。
- H05.2：19个独立UI TU，35段inc。新增5个真实编译模块、窄Selector接口和coordinator显式依赖；最后2个模块及最终HEAD以交付Actions为准。全量剩余词法依赖见docs/UI_COMPILATION_DEPENDENCIES.json，未当作语义闭包证明。
- H05.1：新增真实RuntimeControls/Polish/RuntimeMethod安装族的历史前驱、覆盖顺序、重复安装和异常初始化回归。未删除缺外部消费者证据的Selector/alias/IMP。
- 所有iPhone/目标App项仍DEVICE PENDING；最终commit、完整CI/artifact、新增提交与独立下载后pagehash证明见交付包DELIVERY_STATUS.json / COMMITS_THIS_TASK.txt。

---

# ZonoePatch-V2 独立交接：2026-10-13 深度整改

Repository `a7987083/ZonoePatch-V2`，继续使用 `dev/technical-debt-p0-p2-20261013`，draft PR https://github.com/a7987083/ZonoePatch-V2/pull/1 。禁止改写历史/强推。

本次起点 `0afc080e8e264255424264b4480222275f0eca5b`（push CI 38353817406成功），用户参考 `afa81485978fa280ca025e4ccfdbb6aa55e70f94`，源码anchor `47950495e1f5293fc6851805b068bbdaa96a204a`，完整push CI `38356984676`成功。最终文档Commit也跑完整CI；精确交付Commit/Run/Artifact/digests见包内 DELIVERY_STATUS.json，不能使用PR merge SHA冒充branch HEAD。

当前状态：M10.1已统一M56真实写租约/完整Cell几何/atomic records与诊断锁，但native execution/API消费者仍SOURCE PENDING。M10.2已增加Runtime table/signature私有文件事务、报告失败传播、拒绝已有输出覆盖以及11点Executor故障/输出树字节回滚；所有内建Provider和多个Runtime映像尚未闭环。H05.2为14个独立UI TU、40个.inc；H05.1新增真实SearchHistory前驱/alias/重复安装fixture，未知兼容层全部保留。目标App/iPhone未验证。

关键调用链：Binder -> ZNStaticValueCellAddressForRecord -> ZNM56WriteTextToCell -> 同一ZNImageOperationLease::store；Static管理调用使用global Static gate -> runtime monitor -> ephemeral loader/per-image lease。诊断遵循同顺序；dyld callback只撤销不等待。Builder -> captured ZNBuildSession -> provider prepare -> base target stage -> provider emit -> file edits/postprocess/sign -> ZNBuildOutputTransaction一次目录发布，失败回滚owned stage；authoring stores使用scoped深拷贝。

详细改动、源码位置、失败证据、测试double边界、阻塞与后续条件见 docs/DEEP_REMEDIATION_20261013.md、KNOWN_ISSUES.md、docs/DEEP_REMEDIATION_CI.json。新增Commit以分支真实Git为准；交付含完整历史、参考Commit之后与本任务之后记录。

复现：按未修改pins的 .github/workflows/ios-build.yml 执行源码门禁、7 portable tests、strict ownership/UI、Foundation、Mach-O完整字节等价/独立签名页校验、Xcode16.4/SDK18.5/arm64 iOS14完整构建。Linux本机Apple编译未执行；本地portable用g++，ASan/UBSan，本地LSan关闭不改变CI。dylib下载后运行 scripts/verify-artifact.py，并逐文件核对Artifact源码ZIP与交付Commit tree。

Next Task：优先统一Managed/native execution owner与method/API incarnation（含回调锁序/retire-drain fixture），再完成生产内建Provider的多Runtime目标路由和端到端故障矩阵；继续40段独立UI owner/实际installer fixture；设备按独立清单执行。不能用永久dlopen、header快照、格式变更或强行删除alias关闭技术债。

下面保存前轮原始交接作为历史证据；其中旧7/47、旧anchor与旧CI不是本轮当前状态。

---

# ZonoePatch-V2：独立接手指南

仓库 https://github.com/a7987083/ZonoePatch-V2 ，分支 `dev/technical-debt-p0-p2-20261013`，draft PR https://github.com/a7987083/ZonoePatch-V2/pull/1 。继续追加提交，没有amend/rebase/force-push，没有重做已关闭P0。

本轮基线：`94491dae3541d00af172db7bb7e4b16c634530cb`，Run `38338809727`，Artifact `11786396518`成功。业务源码anchor：`42d57508e6fc1d50904d2409519ca67b2ec3092f`，Run https://github.com/a7987083/ZonoePatch-V2/actions/runs/38344834920 ，Artifact `11787828938`；下载archive SHA256 `b3f201e28b19f1fc490e3f315328a8635fe5d2b0614f43882126d61d9288f4cb`，dylib SHA256 `1826810ca4c956d25fa03c8e515a4ea6add0b03f7a14c69b5c8a71b694a6ad9f`，本地独立复验ARM64/iOS14/SDK18.5和SHA1/SHA256两个CodeDirectory共各520页通过。

**最终文档提交也执行完整CI。精确最终HEAD、Run、Artifact、ZIP/dylib hash以交付包 `DELIVERY_STATUS.json` 为准；上述业务anchor不是最终checkout身份。**本地Git镜像和GitHub API提交的Commit ID不同，内容tree/CI源码包逐文件核对；远端分支与CI `dist/COMMITS.txt`是历史身份来源。

## 四种状态分别记录

| 整改项 | 源码与自动化完成范围 | CI | 目标App | iPhone |
|---|---|---|---|---|
| M10.1 | owned header、safe VM read/cache/window、主要reader迁移和真实macOS加载卸载；活跃entry/cell及native调用租约未统一 | anchor通过 | 未验证 | DEVICE PENDING |
| H05.2 | 7个独立UI TU、shared owners、11个真实静态依赖解决；47段仍include，SOURCE PENDING | strict编译/anchor通过 | 未验证 | DEVICE PENDING |
| H05.1 | 完整源码安装点清单与真实ObjC alias/IMP测试、默认关闭的runtime trace；历史Swizzle仍保留，SOURCE PENDING | anchor通过 | 动态图未采集 | DEVICE PENDING |
| M10.2 | 完整单目标V3/runtime、实际native prepatch、serialize/embed组合/容量/拒写/回滚/签名页hash | anchor通过 | discovery/全provider端到端未验证 | DEVICE PENDING |
| M11.2 | 9类指标、async ticket/结果、首display tick、registry、sampling overhead harness | anchor通过 | 真实耗时未测量 | DEVICE PENDING |
| L02 | 本轮4个、累计8个有明确无引用证据的static helpers删除 | anchor通过 | 兼容调用未验证 | DEVICE PENDING |

整体H05/M10仅部分完成，不标全项关闭。M11是设施扩展完成，不是性能改善。L02保留未知外部消费者接口。逐项源码位置、阻塞、尝试方案、验收条件见 `KNOWN_ISSUES.md` 和 `docs/CONTINUATION_EVIDENCE.md`；47段清单见 `docs/UI_REMAINING_MODULES.json`。

## 复现

固定Xcode16.4(16F6)、iphoneos SDK18.5、arm64/iOS14；Theos `304e0799973e8145f32e4ca2de6c747a84b758ce`、Dobby `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`、Action pins见workflow。SDK及外部依赖不打包，不宣称完整离线工具链或hosted runner位级可复现。

Linux源码检查：

```bash
python3 scripts/ui_source.py
python3 scripts/check-cleanup.py
python3 scripts/ui-dependencies.py
python3 scripts/ui-install-graph.py
python3 scripts/audit-compatibility.py
python3 iosruntimepatchmenu/tests/retained_hook_contract.py
bash iosruntimepatchmenu/tests/single_ui_owner_contract.sh
python3 iosruntimepatchmenu/tests/znunifiedui_topology_audit.py --report topology.json
```

Portable tests按 `.github/workflows/ios-build.yml` 执行，loaded-image、layout/file用ASan/UBSan；Linux本轮LSan无法可靠扫描宿主proc，因此本地使用 `ASAN_OPTIONS=detect_leaks=0`，这不修改CI检查。macOS执行 `bash scripts/check-module-warnings.sh`、`bash scripts/check-ui-modules.sh`、`bash scripts/test-foundation.sh`、`bash scripts/test-macho-equivalence.sh`；fixture从当前production私有函数精确抽取，span hash归档，路径/预验证字节/Store sink替身边界在测试输出声明。

构建：按workflow安装pins，设置THEOS后 `bash scripts/build-ios.sh`；脚本产生dylib/source ZIP/toolchain/commit/file/dependency/signature记录。下载对应**push** Artifact，核对archive digest、toolchain HEAD；重新运行 `python3 scripts/verify-artifact.py <dylib>`，检查CI source ZIP与checkout tree所有tracked文件一致。PR merge SHA产物不能混用作branch HEAD产物。

## 诊断启用与接手顺序

启动前可设置 `zonoe.diagnostics.performance.enabled=YES`、`zonoe.diagnostics.ui-install.enabled=YES`。诊断默认关闭，不自动上传。导出 `ZNPerformanceSnapshot()`、`ZNPerfAsyncState()`、`ZNUITraceSnapshot()`，trace超过4096事件必须标为incomplete。first display-link tick不等于GPU首帧，host P95是批均值P95。

优先完成源码剩余：M2 engine私有类型/接口owner迁移和逐TU编译；真实Swizzle族安装/转发fixture与compat alias策略；StaticDispatch/M56活跃表读取和写入租约；BuildExecutor所有provider、多目标/第二hook/签名失败注入回滚。不要给header Cache无条件dlopen pin，不要把元数据snapshot当native代码调用租约，不要恢复Dobby公开销毁。

然后按 `DEVICE_ACCEPTANCE.md`执行App功能、Hook在途/卸载与ABI、IPA安装；按 `docs/PERFORMANCE_ACCEPTANCE.md`采集同设备匹配基线至少3批。所有设备项当前未执行。

## 失败记录

每个独立点单独远端提交并触发push CI，保留失败历史。第一处真实错误依次包含不支持的mach_vm头、漏private Selector声明、M56旧digest需要精确adapter重建、误加duplicate owner、生产Makefile漏计时模块、FeatureGroup漏直接capability导入/部分初始化、两个无用metadata wrapper。修复后最终源码anchor全部门禁通过；没有关闭检查、屏蔽新警告、简单换旧digest或声称失败Commit本身成功。每个Commit/Run状态见 `docs/CONTINUATION_VERIFICATION.json`。
