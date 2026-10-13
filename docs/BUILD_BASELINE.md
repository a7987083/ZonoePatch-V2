# Reproducible build identity

初始 source baseline: ae631f4ff17658e747016d596a71b11deab5450f，Actions 38330343864 success。
基线日志证实 Xcode 16.4 / Build 16F6，Apple clang 17.0.0 (clang-1700.0.13.5)。后续显式选择同一 Xcode，不升级 SDK；iphoneos SDK 校验为 18.5。

Theos: 304e0799973e8145f32e4ca2de6c747a84b758ce；submodules 固定到该 gitlink。
Dobby: 5dfc8546954ce3b3198132ab13fddb89ee92cdd7；现有 Python pipes 和 extern-C include 调整保留，diff SHA256 写入 Artifact。
checkout/upload-artifact 已锁定 v4 对应 commit，不使用浮动 ref。

macos-15 hosted image、brew ldid/cmake 的底层安装环境仍可能变化；每次输出 toolchain.txt。当前目标是依赖/SDK 身份可核对，不宣称 dylib 位级确定性。

本地 macOS 设置同一 DEVELOPER_DIR/THEOS，按工作流准备 Dobby 后运行 bash scripts/build-ios.sh。Linux 只能执行 portable/source 检查，不代表 iOS 编译。
