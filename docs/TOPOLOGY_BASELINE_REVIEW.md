# UI baseline audit correction (H07)

旧冻结资料只报告 newline_count 18972 -> 19242；实现数量、关键 selector、IMP 交换次数和 activation stage order 均通过。原历史 commit 不是上传包中的 Git 对象，不能伪称已审阅历史 270 行 diff。

这次不改写旧 JSON，也不把行数直接更新为当前值。行数改为诊断统计，关键拓扑继续作为硬门禁，并新增从导入 1.zip 得到的四个 UI 文件 SHA256 硬门禁。当前 UI 字节与原始包一致，尚未重写 UI。以后 UI 行为修改必须在独立审阅记录中解释，并更新 digest；只更新 hash 不构成行为验证。

此举修复审计模型的误报，不宣称历史增量的运行语义已验证。
