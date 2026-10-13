# Device acceptance — NOT VERIFIED

执行者需填：App bundle ID/shortVersion/build、Unity/metadata hash、iOS/设备型号、签名/加载方式、dylib SHA256。

- 冷启动不打开菜单：Hook 生命周期独立准备、无启动卡顿/崩溃。
- 首次浮窗/重复显示隐藏、compact/full、前后台、主题/窗口切换。
- Static、Runtime Method、Direct Native、各 Native Hook template；同方法不同功能保持独立。
- Slider 松手一次、Number执行、Fixed/Switch/Button、值保存与重启。
- Hook off/retire在途调用、重装/identity conflict/slot满；确认停用保留语义。
- GCHandle receiver、场景切换、对象销毁；缺 API 时默认错误；不要默认打开 raw兼容标志。
- static-only/runtime-only/hook-only/mixed、partial draft、项目JSON导入导出、缺省target、失败后再生成。
- 生成后重新解析 metadata/签名/结构，替换回 IPA 后整包重签安装。
- 日志/崩溃/性能证据：明确功能结果、首个错误、复现条件，不仅截图“菜单可打开”。

这些项目全部尚未执行。CI/native macOS fixture不能勾选这里的通过项。

## 本轮新增验收（均未验证）

- H05：默认值首次迁移/重复启动用户选择保留；所有旧Selector仍可调用；compact/full/页面/搜索/链执行完整交互无回归。
- M10：真实App的thin ARM64二进制及workspace跑static/runtime-only/hook/mixed；合法输出字节/section/CodeDirectory结构复核；正常IPA整包重签与安装。
- M10 loaded-image：映像动态加载/卸载时finder、resolver、运行表、Hook协调的指针生命周期与缓存回归。
- M11：按 docs/PERFORMANCE_ACCEPTANCE.md采集五类span、首帧/queue等待/取消、CPU/峰值内存；留设备身份与raw结果。启用/关闭采样对照，不以host JSON推断真实性能。

## owned-image / independent UI / async continuation（DEVICE PENDING）

- 映像加载、卸载、同址重载与finder/probe并发；native在途函数/slot写入不得把header快照当租约。
- 7个独立UI单元的compact/full、footer/tick、modal转场、Feature Group/Runtime控制/Slider交互回归。
- 启动前启用UI trace，导出每stage前后IMP、旧Selector实际调用；超4096事件需重采集，不能称complete。
- 性能9指标、取消请求至completion、队列等待；display-link代理与真实首帧分别测量，采样开关对照。
- Native-only/Mixed真实prepatch样本、所有template、ProtectionV2随机变体、IPA重签安装；native macOS fixture仍不能勾选此项。

## 深度整改独立验收（全部未执行）

- 填写最终Commit、dylib SHA256、App/Unity/metadata版本、iOS/设备、加载与签名方式。
- M56各scalar类型/边界/超范围拒绝；并发Static switch、Cell slider、诊断与映像卸载。人为test revocation不可作为实机撤销证明。
- 14独立UI TU：SearchHistory填充不自动搜、SearchRestore explicit Assembly/地址查询、ABI详情和Runtime-only build gate；首次/反复显示、键盘和转场。
- Runtime-only suffixless输出的Full Signature实读及真实调用；Static/Runtime/Native/Mixed真实样本，签名后整包重签安装。
- Native回调/BR/trampoline在途与退出/同址重载；当前统一execution owner源码尚未完成，不以CI管理路径稳定宣称动态卸载安全。
- 生产内建provider真实discovery/prepare/emit，当前多Runtime目标路由未支持部分必须独立记录，不当作已关闭功能验收。
- 逐族UI IMP完整trace及旧alias外部调用；overflow重采，保留兼容层直至消费者证明。
