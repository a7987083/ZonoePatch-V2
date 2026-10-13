# 本轮验证记录与边界

稳定编译基线5e7d1d4；本轮最后生产/测试anchor0c2e02d。逐提交Actions对应关系见CONTINUATION_VERIFICATION.json；该表是最终文档提交前的快照，完整最终checkout日志及精确HEAD在交付包DELIVERY_STATUS.json。

| 验证 | 实际覆盖 | 不证明的内容 |
|---|---|---|
| ui_source + topology/单owner | 54段的顺序/独占owner、迁移函数原字节重建、计时token以外的UI源码不变、Selector文本频数与63 exchange/8 setIMP/63 once、stage顺序 | 编译器优化后的IMP身份及真实UIKit行为 |
| 新owner strict warnings | 独立默认值策略、性能报告及前轮owner -Wall/-Wextra/-Werror | 所有历史dynamic代码已消除warning suppression |
| Foundation生产回归 | 真实菜单偏好迁移函数（有/无实类的test double）；性能JSON；原Scheduler/BuildSession/output/logger/activation/ABI/codec等 | 真实UIApplication/Unity/IL2CPP/Hook后端集成；macOS ARM64 fixture不等于iOS实机 |
| Mach-O ASan/UBSan | 截断header/commands/section、32/64位字段溢出、owner missing/duplicate/outside segment、全部shift字段族完整golden、失败编辑不改变输入、seed0x5a4e/20,000突变 | 真实所有合法App/Mach-O变种；加载中的映像寿命 |
| Production Mach-O binary equivalence | 同fixture基线/新版完整signer字节及重复重签幂等；原样提取的V3 parse/install和runtime-only单目标builder，产物完整cmp；实际RVA writer畸形输入拒绝/文件未改；legacy V1语法编译 | 完整workspace/provider组合、真实Hook、复杂随机payload布局、IPA信任/安装 |
| 性能模块自动化 | 默认不记录、nested去重、epoch reset、4线程4000次、有界1024保留、分位数和JSON序列化 | 性能采样开销为零、五类目标App实际性能改善 |
| host benchmark | 固定64KiB fixture、5预热/31测量/每批1000，生产portable parser/editor，-O2、环境/commit记录 | 跨hosted runner可比较的性能百分比；完整binary generation性能 |
| arm64 dylib artifact | 精确CI HEAD、archive digest、源码archive逐文件与HEAD对照、ARM64/MH_DYLIB/iOS14/SDK18.5、无外部Dobby/Substrate依赖、SHA1/SHA256 CodeDirectory pagehash | Apple信任链、成功加载/安装、实机无崩溃 |

本地17条检查/编译/运行命令全部成功，逐条stdout/stderr/exitCode见CONTINUATION_LOCAL_TESTS.json。Linux本地缺Foundation/Xcode，因此Apple编译与生产ObjC运行证据只取真实Actions，而不伪造本地执行。一次exec transport断开发生在命令创建前；恢复后完整本地检查执行成功，未将未启动命令计入测试。

H05首轮失败的第一处真实错误是inc带来的 -Wnullability-completeness。修复只在UI include区间恢复旧implementation诊断边界，未扩大到新owner；失败Commit保留，后续修复Commit完整CI成功。未用更新newline_count绕过UI内容门禁，未以CI成功勾选DEVICE_ACCEPTANCE。
