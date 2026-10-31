# 历史后台模式（已删除）

用户在CHG-021明确要求删除产品后台执行模式，当前请读[前台执行与默认候选线程](FOREGROUND_COMPUTATION.md)。原异步服务和菜单已移除；底层候选线程池仅在前台同步求解期间使用，不是后台产品模式。

019的原始实施、失败与验收保留在[CHG-019](changes/2026/2026-10-31-019-background-computation.md)，020候选并行原结构见[CHG-020](changes/2026/2026-10-31-020-candidate-parallel.md)。不将历史设计当作当前功能。
