# Known issues / residual debt

| ID | 当前状态 | 剩余验证与下一步 |
|---|---|---|
| H01 | 已修复重试撤销；生产 Scheduler 测试 | 目标 App 的高频前后台/移除重加实机回归 |
| H02 | 已隔离会话与 Store/row；生产隔离/异常测试 | 全能力组合生成、插件消费者和真实二进制复验 |
| H03 | UUID 专属输出、checked report I/O、无旧输出覆盖 | 多目标/签名/磁盘故障的目标 App 故障注入 |
| H04 | retire 保留 trampoline，不再公开销毁 | ARM64 in-flight/长期 slot 使用；不回收槽是有意取舍 |
| H05 | 部分整改：activation owner/顺序测试 | 18K UI 与历史 IMP 链尚未彻底拆分 |
| H06 | 默认 fail closed；原 raw 兼容分支保留 | 兼容模式不能保证 GC 生命周期；逐目标实机验收 |
| H07 | 已修正行数误报，旧 baseline 保留，UI digest 强门禁 | 新 UI 行为变更必须另做审阅/实机 |
| M01/M04 | requested latch + add/remove generation +独立 scheduler reconcile | 动态加载/卸载/前台事件集成测试，native 目标映像卸载仍需专门生命周期协议 |
| M02 | identity-scoped preference，retired ID 继续校验 | 新身份需要新 ID/重启；不猜测迁移旧 actionID-only value |
| M03 | 生产 parser 边界测试通过 | 真实 method 参数转换/调用 ABI 回归 |
| M05 | Xcode/SDK/Theos/Dobby/Actions 身份固定并留证 | hosted image/brew 工具非位级锁定，不宣称二进制确定性 |
| M07 | 扩展生产模块/格式/原生 ABI fixture 检查 | macOS fixture 不等于 iOS/Unity 实机；UI政策 stub 不等于 UI集成 |
| M09 | 兼容代码保留并记录引用/hash | 动态 API/历史消费者未证明无引用，不删除 |
| M10 | 部分整改：generated layout shared reader + sanitizer fuzz | 剩余 Mach-O parser/writer 尚未全量统一 |
| M11 | 部分整改：inactive/hidden tick 优化 | Instruments 与各 App 悬浮窗/主题回归尚未做 |
| L01 | 独立 logger ring 与顺序/清空测试 | 性能收益未量化 |
| L02 | 部分整改：row/snapshot/activation/logger owner 抽取 | 历史 UI 命名/单行 category 仍需按调用族迁移 |
| L03 | 新 owner 严格 warning gate | 旧动态 category suppression 仍按兼容保留 |
| L04 | 明确三态 owner 和 typed BuildSession | 第三方能力扩展需要同步会话契约与独立验证 |

本轮不是全项关闭：H05、M10、M11、L02 仍有明确结构/性能债务，所有目标 App/实机验证仍未完成。详见 HANDOFF 与 DEVICE_ACCEPTANCE。
