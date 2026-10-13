# ZonoePatch-V2 独立交接：H05/M10/L02/M11 continuation

## 接手入口与身份

Repository: https://github.com/a7987083/ZonoePatch-V2  
Branch: `dev/technical-debt-p0-p2-20261013`；draft PR #1。未改写历史、未 force push。此次沿用该独立分支，不重做已关闭 P0。

本轮稳定基线：`5e7d1d4c8b487c6c3fd5a3eb5685954ede24870a`，Actions `38333900370` 成功，Artifact `11783827840`，dylib SHA256 `fc638e5a53a43ed0e793ac9cdcdfa72e1b03f27e5fade5ba61009bd51c7378ad`。这是源码/编译基线，**不是实机稳定性基线**。输入 ZIP 与初始治理记录见原始《代码库诊断与重构指南.md》和 docs/COMMIT_RECORDS.json。

源码anchor Actions `38338059240` 已成功，Artifact `11785439746`；下载archive digest已核对，dylib SHA256 `267f46b1f14377e554ce4cd690e7b01436bc253fbaaebc1f00b7d9fb48789f9e`，本地复验ARM64/iOS14/SDK18.5和双CodeDirectory pagehash通过。

本轮业务代码及最后测试扩展 anchor：`0c2e02d5d22a875b15b363afa1016d227b891100`。后续文档提交也必须执行 CI。最终精确 HEAD、Run、Artifact ID、archive/dylib hash 以交付包 `DELIVERY_STATUS.json` 为准，不将业务 anchor 混称为最终 checkout。远端通过 GitHub API追加 Commit；本地分析镜像的 Commit ID 不作为远端身份，核对 tree/源码字节。完整历史以 GitHub 分支为准。

## 四项状态

| ID | 已完成、可复验部分 | 整体状态 |
|---|---|---|
| H05 | 54 个有序 UI 源码模块；默认值迁移独立编译；真实策略 Foundation 测试；原始 UI 重建/Selector/安装顺序门禁；13 个跨段静态/宏引用清单 | 部分完成；历史 Category/Swizzle 链仍保留，不能全项关闭 |
| M10 | 全部当前 mmap 文件输入路径和兼容 V1 builder 接入共同校验；两套 LINKEDIT 写入合并为预检后写；共享 owner section 定位；范围/溢出与畸形/fuzz/字节对照测试 | 文件输入治理完成本轮范围；运行中映像解析尚未全量统一，不能全项关闭 |
| L02 | 四个已证明无引用的 static 对齐函数删除；两个重复 LINKEDIT writer/shift helper合并；职责目录/独立策略 owner；删除证据和保留合约 | 确认无引用清理已完成；历史 API命名/外部兼容路径继续保留 |
| M11 | 五个生产入口的 opt-in、有界、同线程去重计时；JSON snapshot/reset；并发测试；固定 protocol host microbench + CI证据上传 | 基础设施完成；目标 App实际性能/改善均「未验证」 |

## 数据流与模块边界

- UI composition root：`iosruntimepatchmenu/src/ZNUnifiedUI.mm` → `src/ui/{core,shell,finder,execution,features,compat}`。渲染与动态层仍是一个编译单元；include 不等于独立 object。`ZNMenuPresentationDefaults.mm` 是真正独立编译的 Foundation UI策略 owner；实类仍由 UI持有，私有接口不重复实现类。
- `scripts/ui_source.py` 按 include顺序拼接源码、重建迁移出去的原函数位置、核对模块及 external owner hash。移除 M11 的指定计时 token 后必须还原前一稳定 UI。原 imported digest 另存 `ui_pre_performance_digest.json`，不只放宽行数。`docs/UI_DEPENDENCIES.json` 是保守词法引用证据，**不是完整动态调用图**。
- 文件：`ZNMachOFile.h` → 安全 command遍历/segment-section范围/已知 LINKEDIT表范围 → 业务 layout解释 → 容量预检 → 生成/后处理。它仅接受 thin little-endian Mach-O64文件，默认 ARM64；不能传入 dyld mapping然后把header长度当文件长度。
- LINKEDIT shift：收集所有待写字段 → 校验64/32位溢出 → 一次应用；失败时不修改该编辑函数的输入字节。整个 builder仍在独占副本上生成；这不是全文件系统事务或断电耐久性承诺。
- 所有已有 BuildSession/store隔离、manifest/retire/generation机制保持前轮修复。不得恢复公开 DobbyDestroy，未确认外部依赖的旧实现继续保留。
- 性能：`ZNPerformance.h` 是统一有界采样 owner；默认关闭，开启方法与五个入口的准确测量范围见 docs/PERFORMANCE_ACCEPTANCE.md。`ZNPerformanceReport.mm` 输出 Foundation/JSON数据；不会自动上传或修改用户流程。

## 构建与测试复现

从 GitHub clone并 checkout上述分支/精确交付HEAD。固定 Xcode16.4(16F6)、iphoneos SDK18.5、arm64/iOS14.0。Theos `304e0799973e8145f32e4ca2de6c747a84b758ce`，Dobby `5dfc8546954ce3b3198132ab13fddb89ee92cdd7`，其必要兼容修补和Actions pins见 `.github/workflows/ios-build.yml`。源码包包含项目完整源码；外部依赖按pins取得，Xcode/SDK不包含在源码ZIP，不能宣称离线全工具链可复现或hosted runner位级确定性。

Linux/source检查：

```bash
python3 scripts/ui_source.py
python3 scripts/ui-dependencies.py
python3 scripts/check-cleanup.py
python3 scripts/audit-compatibility.py
python3 iosruntimepatchmenu/tests/retained_hook_contract.py
bash iosruntimepatchmenu/tests/single_ui_owner_contract.sh
python3 iosruntimepatchmenu/tests/znunifiedui_topology_audit.py --report topology.json
```

portable测试编译选项与源码见 workflow：scalar、checked_layout、macho_file及performance tests；Mach-O使用 ASan/UBSan 和seed `0x5a4e` 的20,000组突变。本地 Linux LeakSanitizer 的 /proc检查不可用，因此 `ASAN_OPTIONS=detect_leaks=0`，不据此声称已查明无泄漏；CI保留正常sanitizer配置。

macOS：`bash scripts/check-module-warnings.sh`；`bash scripts/test-foundation.sh`；`bash scripts/test-macho-equivalence.sh`；`python3 scripts/benchmark.py --output performance-host.json`。准备固定依赖后 `bash scripts/build-ios.sh`。CI必须全部steps成功，读取日志第一处真实错误后修复，不能只看Artifact上传成功。

生产字节对照包含：完整 signer源码与稳定基线、V3 parse/owned-segment install的原样提取函数、runtime-only单目标生成的原样提取函数（仅ModuleManager路径提供者为stub）。同一固定合法fixture输出必须 `cmp`一致。另有实际RVA writer畸形输入拒绝/文件不变测试。**这些不代表真实所有workspace/Hook/IPA已验证**；提取fixture不是完整App集成。原始函数SHA由提取脚本生成以便审计，不以重写算法模拟生产代码。

源码拆分首轮CI `38335959673` 失败于 .inc触发nullability完整性诊断；`802256df`限定diagnostic scope修复后 `38336234932`成功。原失败Commit保留，未重写。其他独立点的Run关联见 docs/CONTINUATION_VERIFICATION.json；最终HEAD的完整日志/产物在交付包。

## 剩余工作与具体阻塞

详见 KNOWN_ISSUES.md（位置、阻塞、下一步、验收条件逐项列出）。重要边界：

1. H05 的宏/私有helper跨段引用和动态Selector链使直接独立编译/合并Category不是机械搬文件。先按依赖清单做typed内部接口与旧/new IMP链测试，再在单调用族上迁移。保持原Selector可调用、installer顺序、重复安装语义；禁止先删历史入口再补适配。
2. M10的dyld读取使用load-command内的fileoff/VM/slide，File校验不能代替LoadedImage接口；代际失效不能阻止读取中的unload。先建立owned header snapshot和读取生命周期协议，做卸载竞争/地址溢出/section生命周期测试，再迁移缓存中的指针为值或有owner引用；不能假设有iPhone便自然解决此设计问题。
3. L02未知外部消费者和动态消息引用未被证明不存在；保留不是笼统“风险高”。对每个待删API要列消费者、导出/Selector注册、source-distribution使用边界及替代迁移测试。
4. M11仅有host microfixture数据，无法得出iOS菜单/真实搜索/Hook/生成耗时结论。先按性能协议采集匹配设备基线与当前数据；hook队列等待、首帧、异步取消、CPU/峰值内存另用Instruments。

## 实机验收与风险

所有目标App/UI行为、Hook安全、加载/卸载、GC生命周期、生成IPA安装、真实性能均「未验证」。DEVICE_ACCEPTANCE.md不可用CI结果勾选。至少交付App/Unity/iOS/device与dylib身份、操作输入、失败数、日志/崩溃、产物重新解析及正常整包重签证据。无新增性能改善宣称；ad-hoc pagehash检查不证明Apple信任链/IPA可安装。

交付ZIP的 `source/`、`dist/`、CI logs、commit ledger、测试/状态文档、校验hash可由独立工程师使用；先核对SHA与精确HEAD，再运行上述检查。不要从旧根文档里复制过时anchor作为新的验证结果。
