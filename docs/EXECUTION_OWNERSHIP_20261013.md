# 执行所有权整改与剩余边界

基线：e5361b701b081283a2c48bd61a5ff4b739077907，开发分支不变。本文描述生产实现与测试范围，不将自动化通过等同目标 App 执行通过。

## 已实现的生产协议

`ZNRuntimeExecutionScope.h:ZNCodeExecutionOwner::acquire` 使用函数实际所属的 dladdr base 查询 lifetime，校验期望 incarnation，通过短期、平衡的 RTLD_NOLOAD 保持映像，再进入 ExecutionGate；重新检查同一 lifetime 和地址归属后才能返回。主可执行文件无需 loader retain。析构退出 ticket 并释放 loader reference。没有永久 loader cache。

`ZNExecutionGate.h` 使用短 mutex 维护 accepting / active，撤销关闭入口而不等待；drain 有期限。`ZNImageLifetime.h` 在 dyld remove / 同址 add 时撤销旧 gate。未知映像、撤销映像和旧 incarnation 均拒绝。执行 ticket 不获取读写租约的 operations mutex，因此不会跨用户函数持有该互斥锁。

嵌套 Scope 把 owner 归入最外层调用，帮助函数返回的 API 不会因帮助函数退出而立刻释放。同一线程的重入复用 owner，另一线程获得独立 ticket。最多 32 个映像，超过限制 fail closed。Common symbol helper 在没有调用 Scope 时返回空，不泄漏 handle。

`ZNRuntimeSymbolCache.h` 仅缓存 path/name/address/incarnation 值；命中必须在当前 Scope 下重新 retain(expected incarnation)。cache mutex 在 loader retain 或执行用户代码前已经释放。Native Managed 三个 API 已使用该缓存。Invoke、Direct、MultiArg、Marshaller、Instance/Signature、M48/M50、ABI 和具体 Codec 调用已接入执行 Scope；Hybrid Finder 移除泄漏的长期 handle，以同步 owner 保护共享 API ivars。Owning Method 扫描保留原 handle-first 解析顺序，但为实际 API 所属映像获取执行 owner，候选附带 incarnation。

Native 安装入口跨解析与安装保持 Scope；ReturnBool 和 ManagedCallback Slot 保存安装 incarnation，进入 handler 必须 retain(target, incarnation)，旧 Slot 不允许同址新 incarnation 重新绑定。Original 若属于已登记映像同时 retain；匿名 Dobby trampoline 继续既有退休资源策略，未恢复危险销毁入口。Hybrid/Owning 候选携带 incarnation，Direct 消费该值拒绝陈旧目标。

## 锁序与重入

- cache mutex 只复制/提交值，不跨 loader 调用或用户执行。
- lifetime registry / ExecutionGate mutex 只做短状态操作；dyld 撤销不等待在途调用。
- Native public installer 创建 Scope，然后进入 runtime monitor；析构释放 loader reference 在 monitor 退出之后。
- code owner 不获取 Lifetime::operations；读写 lease 的原有顺序不改变。
- drain 仅供外部协调者在没有本线程 execution ticket、loader/state/operations 锁时使用。当前接口以注释契约和 bounded timeout约束，并没有自动检测所有错误调用环境。
- receiver / MethodInfo / IL2CPP Domain 的 GC 所有权不是代码映像 owner，不能据此宣称已经解决。

## 自动化的实际范围

`execution_gate_test.cpp`：并发进入/退出、非阻塞撤销、有期限 drain、旧 gate 与同址新 incarnation。

`runtime_execution_scope_test.mm`：实际 dylib、嵌套重入、另一线程执行、外部 dlclose、最后 owner 退出后卸载、重装拒绝旧 incarnation、缓存重新解析。

`extract-managed-bridge-fixture.py`：从生产 NativeRuntime 精确提取 Prepare、Managed invoke、Bool/Callback slot 结构与 handlers，记录 SHA256。实际 dyld 加载/卸载/重装，后端 IL2CPP 导出和对象为明确的 synthetic fixture。覆盖 bool参数、短期 owner 释放、旧 slot generation拒绝，以及底层调用阻塞期间 external dlclose 与 drain timeout、排空后实际卸载。没有用复制的 helper 算法代替生产函数。

`owning_method_execution_test.mm`：直接编译生产 OwningMethodResolver，真实 dylib扫描 synthetic IL2CPP metadata，校验候选 incarnation、ticket归零、卸载/重装及旧 identity拒绝。

## 未完成的源码项：不是仅缺 iPhone

1. `ZNArgScaleBridgeArm64.mm` / `ZNStructFieldBridgeArm64.mm` 的汇编路径仍恢复寄存器后 BR 到 Original。C++ helper 返回时 Scope 已结束，缺 entry-to-return gateway 与调用者 return-address 生命周期协议。给 helper 加锁、Header复制或 Cell lease 均不证明整次执行安全。需要可覆盖原始路径、启用/停用、撤销、在途执行、同址重装的 gateway ABI实现和实际 arm64测试；再验目标 App。
2. 匿名 Dobby trampoline 的释放、资源退休及旧CPU分支/return地址无法用 dladdr owner证明。旧 Slot 拒绝generation只约束已迁移的 C++ Bool/Callback消费者，不能解决所有 Native/Struct Slot。需要 Dobby/backend 与入口排空协议，不能直接销毁正在执行的代码。
3. Codec函数组仍是原 ABI结构的裸值，未携带每函数期望generation；本轮获得调用期短 owner，但旧地址 ABA的生产来源契约尚未贯通。不能无兼容证据改变旧 codec注册 ABI。需要独立identity sidecar、producer验证和实际codec回归。
4. IL2CPP Domain/MethodInfo/receiver/GC handle在代码存活期间仍可能变更；Native callback对象和全部API可能来自不同provider。多runtime实际对象归属路由尚缺。部分历史 Finder API消费者还保留短期手动 loader handle，尚未全部统一到同一执行协议。
5. 暂停/撤销映像的主动释放需要由外部owner协调drain，当前dyld事件没有强行排空，且不得在dyld callback阻塞。

以上保留 UNRESOLVED。已完成消费者标记 SOURCE COMPLETE，在对应完整Actions通过后标记 CI PASS；真实IL2CPP、ARM64桥、App卸载、receiver GC与UI标记 DEVICE PENDING。
