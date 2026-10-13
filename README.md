# ZonoePatch-V2

Runtime Patch Menu 独立治理工程。输入为 1.zip（SHA256 bc905c4243dc0be99c3a6dd7df037c05c2c8684273ce681db9b0d583d1851805）。

源码在 iosruntimepatchmenu/，构建入口为 scripts/build-ios.sh；GitHub Actions 定义见 .github/workflows/ios-build.yml。

Apple SDK / Theos / Dobby 为构建依赖；部署基线 iOS 14.0、arm64。CI 构建、ABI/结构检查与 iPhone 实机验证分别记录，后者尚未验证。

历史兼容实现保留，治理工作只追加提交。诊断报告见项目根目录《代码库诊断与重构指南.md》。
