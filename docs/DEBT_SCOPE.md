# 技术债治理范围

输入：1.zip SHA256 bc905c4243dc0be99c3a6dd7df037c05c2c8684273ce681db9b0d583d1851805。
远端 baseline ae631f4ff17658e747016d596a71b11deab5450f，Actions 38330343864 编译/结构验证通过；iPhone 未验证。

报告原来的高/中/低分别映射 P0/P1/P2；每项保留报告 ID。执行顺序先处理数据一致性和生命周期，不先重写 UI。不删除未确认无引用的兼容代码。

修复后的 CI 不能替代 iPhone、Unity 对象生命周期和真实 IL2CPP/Native Hook 行为验收。需要实机/性能测量的结论继续保留未验证；每项实际完成状态见 HANDOFF/KNOWN_ISSUES。
