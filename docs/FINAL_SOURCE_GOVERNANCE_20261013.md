# 剩余源码治理：当前结果与明确边界

起点：e5361b701b081283a2c48bd61a5ff4b739077907；起点 push Actions 38357648704。继续同一 dev/technical-debt-p0-p2-20261013 分支，所有新增提交保留，不改历史、不强推。最终准确 commit、Actions、artifact、SHA256及新增提交清单在交付包 DELIVERY_STATUS.json / COMMITS_THIS_TASK.txt；该文件避免在提交内伪造自己的最终hash。

## 逐项状态

| 项目 | 本轮生产源码变化 | 源码/自动化范围 | 仍未关闭 |
|---|---|---|---|
| M10.1 | 新 execution gate、短期 code owner、可重入调用Scope、incarnation缓存；统一 Common/Invoke/Direct/MultiArg/Marshaller/ABI/Codec等已列消费者；Hybrid handle泄漏修复、Owning Method API扫描；Native安装Scope、Bool/Callback Slot generation | 上述具体消费者 SOURCE COMPLETE；d54cf6a push/PR完整CI PASS；真实dyld卸载/重装/缓存/独立线程/在途Managed调用排空、实际生产helpers与扫描路径已运行 | UNRESOLVED：汇编entry-to-return与caller返回地址、匿名trampoline退休/释放、全部slot消费者、Codec期望generation、Domain/MethodInfo/GC所有权、全部历史Finder消费者；真实App/iPhone DEVICE PENDING |
| M10.2 | Native Prepare Descriptor完整批次在私有真实Store验证，再一次发布；预期authoring快照变化拒绝；第二descriptor故障不会留下第一项修改 | 该批次接口 SOURCE COMPLETE / CI PASS（b8e745c、后续d54cf6a）；实际Store测试有效/畸形第二项/fault/成功批次/并发编写状态变化 | UNRESOLVED：多Runtime target身份与作用域Store、Runtime-only目标循环、Native target路由、完整内建Provider端到端；并未把host provider doubles升级成完整生产Provider证明；NSUserDefaults真实durability异常亦未验证 |
| H05.2 | 14→19个独立UI TU；迁移M43Polish、M551SliderStability、M57UnifiedRuntimeControls、RuntimeMethodCallFinderUI、RuntimeMethodCallFeatureUI；新增两Selector窄接口、直接导入实际coordinator owner | 原54段顺序/历史源码展开摘要不变；无重复category Selector；严格独立arm64编译；精确生产安装器的IMP、重复安装、缺类/缺方法回归；最后两模块以最终CI为准 | 35个inc仍UNRESOLVED。全量类型/Block/私有Selector/IMP/初始化词法清单可重生成；它不是语义依赖闭包或35个模块已整改证明 |
| H05.1 | 精确提取控制族、Polish、RuntimeMethod Finder/Feature真实installer；断言真实交换/覆盖顺序、历史前驱、重复安装、异常缺类/方法 | 已测试的安装族 SOURCE COMPLETE；handler/UIKit和未知外部调用 DEVICE PENDING / UNRESOLVED | 没有删除未知alias、selector、pref key或swizzle。M551 alias保留历史前驱，M57覆盖当前事件owner后并未使旧alias等价；不能据计数判死代码 |

最终完整 Actions 必须全部成功后交付，不能依据单个step或旧commit冒称最终CI PASS。故障修复与失败记录完整保留于 DEEP_REMEDIATION_CI.json 和交付原始日志。

## M10.2 根因与后续实现条件

`ZNBuildManifest.mm` 的Runtime/Hook collector只给index/title，未给目标Mach-O身份；`ZNRuntimeActionModel` / `ZNNativeHookAction`缺统一每Action运行映像契约。`ZNRuntimeOnlyBinaryBuilderBuildWorkspace`只生成defaultTargetBinary；`ZNNativeHookBuildPrepare`解析UnityFramework；`ZNNativeHookStaticPrepatch:ZNM610FindUnityOutput`选择一个Unity产物。`ZNRuntimeActionBuilder`及FullSignature发射全Store，运行时仍按默认Unity解析。把全Store表复制到每个输出不能正确路由调用。

本轮追踪上述调用链，并实际修复Prepare descriptor批次的部分修改；没有提交一个只改target字符串、只循环output或替代Provider的虚假多目标实现。下一源码工作需要一个兼容旧项目的显式目标身份（路径/UUID/arch/基准），贯穿authoring保存/导入、BuildItem、BuildSession captured Store、provider grouping、每target descriptor/prepatch/table/signature/report及运行时解析；目标间同basename需要明确发布命名契约。该工作仍可在源码和CI继续做，未归因缺少iPhone。

现有Executor组合fixture精确执行生产控制流、真实V3多目标、双Hook预埋、序列化/签名和文件事务，但session/manifest/provider后端为明确host doubles。现有11故障点及完整树字节比较继续运行；不是完整内建Provider路由已完成。后续须以生产内建Registry/Store/Prepare/Emit/Postprocess运行双Runtime目标、双Hook目标与Mixed成功及第二目标/第二Hook/descriptor/provider/msync/pwrite/signature/output.publish失败，保留input/output/authoring完整快照；再验真实App/IPA。

`ZNNativeHookStore:applyPreparedDescriptors:expectedActions:error:` 在私有Store执行原生产验证器，全部通过后才切换当前mutableActions并persist一次。expectedActions全持久化字段比较拒绝过期编写状态，异常恢复内存数组。fault点prepared-descriptor.write位于原验证器写入前；不能把该注入称为真实NSUserDefaults磁盘故障或任意后端事务回滚证明。

## 测试与失败记录

- 新portable execution gate，以及原scalar/layout/Mach-O/loaded-image/lifetime/performance测试全部保留。
- Foundation生产回归含真实短期loader owner、symbol cache generation、实际Native helper/Slot和Owning resolver；后端对象/IL2CPP导出明确synthetic。
- 阻塞真实Managed helper的底层invoke，另一线程dlclose，drain超时；release后调用完成、ticket归零、实际映像卸载。未在dyld callback等待。
- 原完整Mach-O基线/当前byte cmp、Runtime Table/Signature msync/pwrite/file.publish、Executor 11点故障、CodeDirectory pagehash验证不变。
- UI源码重建digest没有刷新。严格编译暴露unused kZNM57FieldTag，删除无消费者的私有常量，以精确before/after反向重建保存原digest；未屏蔽warning。
- 本轮修复：空NSString filesystemRepresentation异常；生产旧C++方言inline thread_local声明不兼容；assert宏中的ObjC数组逗号；UI未用私有常量；实际Managed Slot抽取漏capacity常量。失败commit/run保留，没有删assert、跳测或改SDK。
- f950dd0 PR失败在依赖安装阶段；同commit push成功，随后commit完整push/PR成功。此类外部步骤失败与源码首错分开记录。

## 待验收

独立 iPhone/目标App清单见 DEVICE_ACCEPTANCE.md。所有实机项未执行，不能声称性能改善、全部Native template/GC生命周期/IPA安装通过。
