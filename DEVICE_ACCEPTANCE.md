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
