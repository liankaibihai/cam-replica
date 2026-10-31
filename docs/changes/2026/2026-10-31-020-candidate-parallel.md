# CHG-2026-10-31-020 真正候选并行搜索

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期/时区 | 2026-10-31 / Asia/Shanghai |
| 状态 | 已验收（合成功能；用户运行中窗口尚未安装） |
| 执行/审核 | Sol独立执行器实现、文档与检查；总指挥完成代码、报告和冻结源码核验 |
| 基线 | 688541c3fdecdf24ab077151e29b851959a909fa |
| 标签 | 候选并行、CPU核、预算、确定性、停止 |

## 动机与边界

用户明确需要多CPU核同时搜索候选；019仅解决界面与计算并发。本项只并行同轮冻结best的独立坐标探针，默认关闭且未接入用户窗口。无比赛计算、无算法质量/比赛加速比例结论；验收后本地提交，不推送。

## 改动文件

- `+camdesign/PhysicalEvaluationBudget.m`、`candidateEvaluation.m`：单账本预留/结算，普通数据候选worker，实际间隔证据。
- `+camdesign/optimizeFeasibilityFour.m`、`optimizeRelay.m`：默认串行；显式CandidateWorkers并行探针，保留索引、排名及接受顺序，接力复用单账本。
- `cam_candidate_pool.m`、`cam_candidate_ui.m`：协调进程线程配额、独立默认关闭开关、2/4worker和显式空闲池准备。
- `cam_app_async*.m`相关适配：运行前选有配额的进程、普通数据参数传递、取消先结算、保存完整outcome和异常账本。
- `cam_app_ui_dispatch.m`、`cam_app_ui_spec.m`、`cam_app_ui_binding_plan.m`、`launch_cam_app.m`：具名菜单、可审计可选控件、新窗口安装。
- `check_candidate_parallel.m`：手写小输入串并行、预算、真实重叠、失败计数、正常停止、UI取消、前台模式冲突。
- 本单、使用说明、后台说明、总索引、变更索引、经验和AGENTS：语义及证据维护。

## 验证命令与结果

通过独立R2025b批处理，未用默认/比赛工厂或旧比赛MAT。运行前源码副本及SHA256均保留在输出根目录的source_1/2/3，未覆盖。

| MATLAB入口 | 日志 | 结果 |
|---|---|---|
| `prototype_020`（输出目录中的小原型） | local/matlab_13baeab19f98478893887bae1bd4ed42.log | 退出0，4worker，重叠0.509秒 |
| `check_candidate_parallel` | local/matlab_9498fa98feeb40539f79dda62f177dd5.log | 退出0，串并行/预算一致，模型重叠0.001006秒，UI完成 |
| `check_candidate_parallel(...check_2)` | local/matlab_b8d1ad225a1a47889080fc568377f2fe.log | 退出0，加入取消结算及结果保留，重叠0.002002秒 |
| `check_candidate_parallel(...check_3)` | local/matlab_cc33904087e6412498bd98fdbcb708b0.log | 退出0，加入接力60次预算一致及前台冲突拒绝，重叠0.002002秒 |

最终输出 `outputs/candidate_parallel_20261031/check_3/verification.json`；源码冻结 `source_freeze.json` 与实际执行的source_3一致。这是小合成功能检查，不是充分预算优化或工程性能实验。所有本项检查正常退出，无伪造失败/性能结论。

## 证据、局限及回退

见[候选并行说明](../../CANDIDATE_PARALLEL.md)，以及轻量数据摘要。进程首次初始化可等待；停止粒度为整轮探针，基础设施未知尝试保留预留额度。未在用户窗口运行。回退时保留本地备份及输出，撤销本单代码；已有窗口先保全后处理，不清工作区/类。

## 关联经验与交付

EXP-042。总指挥已核对预算预留/实际结算、候选生成与归并顺序、停止/取消结果保全、菜单与旧窗口兼容，核对最终日志与运行前冻结源码。现场只读观察到用户100控制点方案正处于40/300轮训练，停止按钮可用、优化按钮禁用；没有打断、安装菜单、建池或改输入。用户当前窗口仍未启用候选并行。训练结束后可执行`cam_candidate_ui(camReplicaApp,'install')`安装菜单，选择后台计算，并在候选菜单选2/4worker、开启开关；首次需准备合适的进程池。完整界面合成功能已检查，这次未做用户窗口实操验收。源码、证据摘要、文档及索引同次本地Git提交，未push；所属提交通过git log查询。
