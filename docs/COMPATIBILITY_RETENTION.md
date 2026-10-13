# Compatibility retention

M09：LegacyStaticBinaryPipeline 中仍定义旧 Builder 类，ZNUnifiedUI 中仍有该类 category/NSClassFromString 和 legacy prepare 入口。因此不能判定“无引用”，本轮保留其源码与编译配置。

StaticBinaryBuilder、StaticBinarySigningBridge、AnyImageAddressResolver 顶层文件不在当前 Makefile 列表；这仅说明当前 target 不直接编译它们，不能推断外部 API/历史消费者已无引用。所有文件保留。

public Hook retire 现在停用并保留 trampoline；旧 destructive 方法仅改为私有 legacy 名称保留，未新增调用。重启进程才释放资源，单模板 8 slots 的限制仍在。不同绑定复用同 ID 会明确失败，避免错目标写入。

删除兼容实现的前置证据：链接符号与 runtime selectors、真实下游消费者、旧生成二进制加载矩阵、有效 rollback 方案。未取得这些证据之前不排除旧路径，也不改写历史提交。
