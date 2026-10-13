# H05 activation ownership review

唯一 UI 编译 owner、既有 selector、63 次 IMP exchange 与 activation call site 顺序未改变。只将原先丢弃 stage 名称的 no-op wrapper 移至 ZNActivationStageRunner。

新 runner 验证 main thread、菜单类已加载和直接 stage 前置条件；完成状态仅在 block 返回后记录，重复阶段不重装，异常不会记录成功。Fault/顺序/重复测试执行生产 runner。

UI digest 的更新只对应此单一变更，旧冻结 topology JSON 未更改。没有删兼容 category，也没有猜测 class/selector 无引用。

这解决启动 owner/前置依赖缺失的可检测性，但 18K UI 和多代 category/selector 动态链仍需进一步按页迁移。没有实机行为基线前，本轮不宣称已完全清除 UI 历史叠层债务。剩余 H05 在 KNOWN_ISSUES 继续跟踪。
