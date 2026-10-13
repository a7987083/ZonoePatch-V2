# ZonoePatch-V2 独立交接

## 定位与稳定基线

Repository: https://github.com/a7987083/ZonoePatch-V2  
Branch: dev/technical-debt-p0-p2-20261013  
输入 1.zip SHA256: bc905c4243dc0be99c3a6dd7df037c05c2c8684273ce681db9b0d583d1851805。

新仓库从空仓初始化；旧仓库和历史 Commit 未改写。输入 ZIP 不含 Git 历史，目录名 cb049821…不是本次已验证的 Git HEAD。

原始源码编译基线 ae631f4ff17658e747016d596a71b11deab5450f，Actions 38330343864，Artifact 11782621102；源码未改，测试/构建 harness 新增。基线 dylib SHA256 bfc407a1dcf913a0a5f34629025b7d21a83338d02aff3caf4ac4141900290373。不是已实机验证基线。

本轮业务源码 HEAD：3a53fbb992dad885476a14eb0c18e97b6a0c722b。后续仅文档提交的精确 checkout HEAD 以 `git rev-parse HEAD` 为准；不可把业务源码 anchor 与文档 HEAD 混称。Commit 明细见 docs/COMMIT_RECORDS.*；完整历史以 GitHub 分支为准。

## 调用链与已改动 owner

- 启动：constructor -> main-thread menu prewarm -> ZNActivationStageRunner -> 原有 installer。新 runner 负责顺序/幂等/类可用性，历史 category 与 63 次 IMP 交换仍保留。
- 构建：UI -> ZNBuildExecutor -> main-turn ZNBuildSession 捕获 -> row 深副本/独立 Runtime/Hook Store -> frozen Manifest provider -> prepare/base/emit -> checked output/report/signing。固定顺序锁定两个 Store，threadDictionary 只对同步会话重定向 sharedStore；异常 finally 清理。
- Native Hook：dyld/前台 -> 生命周期 requested latch -> capability snapshot -> Scheduler。generation 撤销 timer，identity 防同 ID 错目标，v2 preference 按绑定身份命名。值命令与 reconcile/teardown 串行。显式 retire 停用槽但保留 trampoline/registry，正常 OFF 不销毁。
- 图像缓存：ZNImageGeneration 注册 add/remove 原子代际，Registry/Coordinator/Static/Runtime/Hook 使用代际而非仅 count。
- 格式：ZNCheckedByteView 与 GeneratedDataLayout 使用 checked arithmetic / memcpy；其余独立 Mach-O parser/writer 尚未全量迁移。
- 参数：Direct Native 与 managed invoke 使用同一 scalar parser，拒绝负 unsigned、非有限 float；RVA 仍保留历史十六进制 fallback。
- 日志：ZNRuntimeLogger 独立 owner，200 条 ring，保留最近记录顺序，移除每条 NSDateFormatter 分配。

## 构建与验证

构建工具链固定 Xcode 16.4 (16F6)、iphoneos SDK 18.5、arm64/iOS 14.0，Theos/Dobby commit 见 docs/BUILD_BASELINE.md。macOS prepared dependencies 后执行 `bash scripts/build-ios.sh`；完整 CI 是 .github/workflows/ios-build.yml。不要无依据升级 SDK/依赖。

测试：scripts/test-foundation.sh；脚本包含真实 Scheduler、BuildSession、output IO、activation、logger、production ABI metadata 与 codec 测试。某些后端/呈现策略有明确 stub，不能当作目标 App 集成测试。native ARM64 fixture 若 runner 为 arm64 则自动运行，它仍是 macOS ABI fixture。

Linux 可执行：single_ui_owner_contract.sh、znunifiedui_topology_audit.py、retained_hook_contract.py、scripts/audit-compatibility.py、scalar_parser_test.cpp、checked_layout_test.cpp。当前沙盒 LeakSanitizer 的 /proc 检查不可用；本地 ASan/UBSan 使用 ASAN_OPTIONS=detect_leaks=0，未把该限制当作源代码内存泄漏。

源码 anchor 3a53fbb 已由 Actions 38333258510 编译/回归成功，Artifact 11783771960，dylib SHA256 7ecc16458f9555dfc0034cb904d5f7a0496262d774fdccecb4901f5a489319e3。源码 anchor 之后的最终 Actions/Artifact 与 SHA256 在交付包 DELIVERY_STATUS.json 中核对。较早一次完整成功 Run 38333056338 对应 7cd6c1f3eecbdd5bfabc0abc42d7c2dfe99e778a；不把它当作之后新 HEAD 的成功记录。

状态必须分开：已修改、已提交；各 CI 的编译/测试结果见事实清单；目标 App 未运行，iPhone 未验证，完整实机回归未完成。ad-hoc 局部签名不代表最终 IPA 安装成功，必须正常整包重签。

## 已知风险与阻塞

- H05：checked activation 已实现，18K UI 的历史 renderer/search/IMP 链未完整迁移。不能按“所有技术债已清零”交接。
- H06：默认缺少 GC API 时拒绝缓存 raw receiver；显式兼容模式只有 30 秒 lease/逐次校验，仍无 GC 所有权保证。
- H04/M02：停用保留方案不回收 process-lifetime slots（每模板上限 8），不同绑定不能复用同 ID。需要更多新目标时重启；旧 destructive 代码保留为私有 legacy，未添加调用。
- M10：shared generated layout 读路径已统一，其他 Mach-O 签名/relocation/legacy scanner 边界仍需迁移与 fuzz。
- M11/L02：tick 无效工作减少，timer 保留；完整性能测量和 UI family 拆分待真实设备。
- 自定义 provider 必须同步使用会话输入，不得缓存全局编写 Store 绕过 BuildSession。Workspace 编辑按 UIKit 主线程契约，外部线程直接属性写入不受支持。
- 原子 slot 停用不保证已经开始的回调立即终止；允许在途调用完成，不宣称零延迟停止。

阻塞：没有目标 App / Unity 版本匹配测试环境、iPhone 和 Instruments。没有伪造运行/实机结果。

## 下一任务

先用本轮产物完成 DEVICE_ACCEPTANCE.md。记录目标 bundle/build/Unity metadata identity、iOS/设备、dylib hash、加载方式、整包签名、各功能和崩溃日志。通过实机稳定基线后按页拆 UI，再统一剩余 Mach-O readers/writers。不要删除未证明无消费者/动态 selector 引用的兼容代码。
