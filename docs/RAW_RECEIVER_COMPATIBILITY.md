# Raw receiver compatibility

GCHandle API 完整的路径保持不变。API 不完整时，默认拒绝缓存无 GC 所有权的 raw receiver，返回明确错误；历史分支没有删除。

只有明确了解目标生命周期的诊断环境才能通过 NSUserDefaults 的 zonoe.compat.raw-receiver.enabled=YES 选择兼容分支。兼容分支每次执行重新验证类型/内存，并限于选择后的 30 秒。

这不能防止验证后释放、同类对象地址重用；兼容模式仍未验证，不能宣称与 GCHandle 等价。默认行为变化会使缺少 GC API 的目标要求重新选择支持的调用/实例路径。实机目标需逐个验收，不应批量开启该标志。
