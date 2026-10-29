# CHG-2026-10-29-010 接入原生非线性约束优化

## 基本信息

| 字段 | 内容 |
|---|---|
| ID | `CHG-2026-10-29-010` |
| 日期 / 时区 | 2026-10-29 / Asia/Shanghai |
| 标题 | 接入原生非线性约束优化并进行同输入对照 |
| 状态 | 已验收（实验后端功能与诊断；默认工程案例均未通过加密验收） |
| 执行人 / 角色 | 独立Sol xhigh执行器：代码、运行；总指挥：选型、文档、交叉核验、Git |
| 审核人 / 角色 | 总指挥：已复核代码、主要结果/图、加密拒绝检查和最终文档 |
| 标签 / 搜索关键词 | fmincon、内点法、SQP、充分迭代、差分、加密验收 |
| 基线分支 | `feature/reference-comparison` |
| 基线 Git | `9dba55413d2dea85230842d9a3928630fd1a995f` |
| 关联提交 | 本单所属提交用 `git log -- docs/changes/2026/2026-10-29-010-constrained-optimizer.md` 查询 |

## 动机与边界

用户询问公开成熟算法能否适配，并明确“开始”。旧优化即使改善综合分，默认案例仍明显超过压力角限制。本轮接入原生约束求解器，把物理限值和目标评分分开验收。保留当前路线参数化、机构计算和已有优化选项；不宣称恢复原版完整算法，不擅自改变用户尺寸和阈值。

用户随后强调不能凭一两轮结果评价算法，要给充分迭代预算。本轮将此加入长期规则，补充分离保存的300轮预算诊断、实际终止和收敛过程检查；默认函数评价预算按自由变量及迭代数派生，显式预算仍保留。SQP短跑仅用于接口及效率分析，内点法早停须分析数值原因，不将“请求300”写成“完成300”。

实验后端及检查已实施；所有本单记录的默认齿条/平推工程算例均未通过独立加密验收。简单可行解析夹具和合成阈值回归属于功能检查，不能计为工程设计通过。本单不包含CHG-011的原版UI/同输入对照。

## 改动文件

- 计算入口与辅助：`+camdesign/optimize.m`、`optimizeFmincon.m`、`fminconModel.m`、`verifyConstrained.m`。新增独立内点法/SQP入口、固定维度约束、严格可行优先、独立加密与完整自交验收；现有路线/物理模型和旧默认保留。
- UI：`CamReplicaApp.m`，增加实验选项、预算/终止和加密实际指标，区分历史评分与求解目标。
- 检查与诊断：`check_constrained_optimizer.m`、`check_constrained_app.m`、`check_constrained_convergence.m`、`check_constrained_sensitivity.m`；总指挥补 `check_constrained_refinement.m`。
- 说明与状态：`README.md`、`docs/CONSTRAINED_OPTIMIZATION.md`、`docs/USAGE.md`、`docs/VALIDATION.md`、`docs/FEATURE_STATUS.md`、本单及变更索引。长期规则/经验/总索引由总指挥维护。
- 证据：`local/collect_constrained_summary.py` 生成 `data/constrained_optimizer_20261029.json`，保留来源SHA256；完整历史在忽略的 `outputs/constrained_optimizer/`。原始 `all.json` 的6组检查未改写，最新 `contracts.json` 的7组另列。

## 验证命令与结果

| 验证项 | 命令或检查 | 环境 / 输入 | 实际证据 | 状态 |
|---|---|---|---|---|
| 工具箱可用性 | 独立 `run_matlab_checks.ps1`，命令见选型文档 | MATLAB R2025b | license=1，找到fmincon；`local/matlab_6643ea11deca4f90a8f01ff7d775f020.log`，exit0 | 通过 |
| 同输入早期比较与原12项回归 | `check_constrained_optimizer('all'); check_constrained_app; run_tests;` | 默认历史齿条/平推，30轮请求 | `local/matlab_3d440cdabc62408faea5f12e5794d485.log`；4条对照、当时6组契约、UI及12/12原数值检查通过；工程案例均未过加密验收 | 功能检查通过；工程未通过 |
| 原数值设置的300轮请求 | `check_constrained_convergence(300);` | 名义0.5 mm前向差分；30000函数预算、180秒软限 | `local/matlab_58456bfcf86d41f49f6ce7b62e27276c.log`；实际23/22轮，小步长且不可行退出，未耗尽预算 | 已记录提前终止；工程未通过 |
| 差分、密网格及延伸 | `check_constrained_sensitivity;` | 0.05/0.005 mm前向及0.005 mm中心；平推2倍求解网格 | `local/matlab_94976d93080a40e388b719aa2783cee3.log`；7案及1延伸案；齿条中心差分300/300，密网格平推300/300后另存552/1000 | 充分预算诊断完成；全部未过加密验收 |
| 最终针对检查 | `check_constrained_optimizer('contracts'); check_constrained_app;` | 最终预算/差分选项和逐轮记录版本 | `local/matlab_bfd24944760543b49d48346766fc9886.log`；7组及UI通过 | 通过（功能检查） |
| 最终UI截图 | `check_constrained_app;` | 独立实例，方法/回调 | `local/matlab_b378c29dc14d4aa68c41d487c073a726.log`；截图 `outputs/constrained_optimizer/constrained_app_preview.png` | 通过；非原生鼠标验收 |
| 加密拒绝回归 | `check_constrained_refinement;` | 合成阈值夹具，生产压力角仍35° | `local/matlab_90f21c5df31b40499ce2ed4b9ab016dd.log` 首行PASS：粗65.938694093°、专用阈值66.052975780°、细66.167257467°，粗通过而加密拒绝 | 通过（验收门禁） |

## 证据及局限

公开来源、目标/约束公式、数值表及完整目录见[约束优化说明](../../CONSTRAINED_OPTIMIZATION.md)，精简数据见[汇总JSON](../../../data/constrained_optimizer_20261029.json)。初始SQP各4轮约113秒，仅作效率依据；改用内点法后继续做充分预算及数值敏感性诊断，没有据短测判断算法能力。

齿条中心0.005 mm确实完成300轮（24.947秒），粗网格可行但加密压力角35.598343°。平推2倍求解网格在300轮末仍改善，独立延伸为1000轮请求，实际552轮（45.017秒）小步长退出；粗网格最大违规为0，但加密压力角35.284867°、打卡30.003515 mm、欠切余量−0.244941、自交1处，故未通过。其余默认工程案亦未通过。结果不能外推为全局无解或方法不可用，不能视为加工批准。

最终7组检查与UI在预算/差分选项更新后复跑；原12项数值回归执行较早，未在最后元数据补充后再跑整套。历史all报告仍为当时6组，汇总另纳入最新7组。加密拒绝日志中后续原版直线准备输出不属于本单证据。

首轮简单夹具固定传动比20导致完整回程侵入滚子半径；保留失败/定位日志 `matlab_c8667f7ea35a46e68374f59069eb654e.log`、`matlab_3e116b65019a4b3989ce6fe5d1cbb293.log`，只将独立解析夹具改为固定2，未改工程默认项目。该可行夹具仅用于功能验收。

## 关联经验

EXP-008（验证层次）、EXP-012（综合分下降不替代峰值验收）、EXP-015（独立批处理，保留用户窗口）、EXP-018（简单路线也须检查完整回程）、EXP-019（优化后重新验证分辨率）。经验由总指挥维护。

## 回退办法

保留已有优化后端与默认项，可在界面切回原选项。代码级回退使用本逻辑提交的 `git revert`；保留试验日志和结果，文档索引随提交回退。

## 审核与交付

2026-10-29 总指挥核验实现、结果、文档与索引，`git diff --check` 通过；按本单范围统一提交。记录结论为“实验后端与功能检查已完成、默认工程案例均未通过加密验收”；原版3.1.2对照另由CHG-011推进，不回填为本单数值等价证据。独立执行器未提交Git。提交前工作区另有未提交的CHG-011脚本和记录，未混入本单。
