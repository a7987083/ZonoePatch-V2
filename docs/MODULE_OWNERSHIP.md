# Module ownership and migration contract

| 模型/入口 | Owner | 允许的输入/输出 |
|---|---|---|
| 编写态 | Workspace/RuntimeActionStore/NativeHookStore 的主线程编辑入口 | 用户配置；不持有 build 输出和运行 trampoline |
| 构建态 | ZNBuildSession -> Manifest -> Executor | 静态 row 深副本、独立 Store、副本 provider；prepare/emit 同步消费本会话 |
| 构建 I/O | ZNBuildOutputIO + builder/postprocess | UUID 专属目录；失败不能删除上一份成功输出 |
| 运行发现 | CapabilityRegistry + CapabilityCoordinator + image generation | 不可变快照，主 UI 只读取 |
| Hook 执行 | Scheduler -> Runtime -> atomic slot/bridge | identity 与 actionID 共同校验；retire 不释放 trampoline |
| 激活 | ZNActivationStageRunner | main thread、已加载菜单类、前置 stage 已完成 |
| 日志 | ZNRuntimeLogger | 有界 200 条 ring，按时间顺序读取 |

保留不同语义的能力注册、构建 provider、编写 action 和运行 snapshot，不将其合并为一个万能 manager。新 provider 必须同步运行，不能缓存 authoring Store 再在后台绕过 BuildSession；插件自定义行为仍需自身测试。

已抽取 row、build snapshot、activation runner、logger，原公开接口/格式保留。旧版本命名、category/swizzle 并非已删除；需要实机基线的 UI renderer/search family 改造继续分阶段推进。

新的所有权模块使用 -Wall -Wextra -Werror；旧动态 category 的全局 warning suppressions 暂保留。警告例外只能按模块审阅，不一次全树 Werror。
