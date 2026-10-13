# Performance acceptance

M11 tick 保留 0.5s fallback timer 和正常 active 场景的 window/attach/layout/theme 路径。仅跳过后台或 panel/floatButton 都已隐藏的无效工作，置顶前检查当前 sibling 位置，避免无条件改动视图顺序。

已做源码 topology/digest 检查和 iOS 编译；冷启动、前台恢复、其他游戏悬浮窗竞争、系统主题切换仍需 iPhone 验证。没有 Instruments 数据，不声称耗时/CPU 改善百分比。

仍需测量：首次菜单、重复搜索/取消、隐藏/显示/后台 CPU、image burst、生成峰值内存/耗时。搜索当前有 6 秒预算和候选上限，不是无界；V2/V3 查询路径不在无运行基线时强行合并。
