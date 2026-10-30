# CHG-2026-10-30-001 固定用户传动比与可见的训练、评分、自交结果

## 基本信息

| 字段 | 内容 |
|---|---|
| ID | CHG-2026-10-30-001 |
| 日期 / 时区 | 2026-10-30 / Asia/Shanghai |
| 状态 | 已验收（固定比与结果界面；固定35候选工程未达标） |
| 执行人 / 角色 | 总指挥：核心、验证与整合；独立Sol执行器：界面与界面检查 |
| 审核人 / 角色 | 总指挥，代码、独立检查产物与原生窗口复查 |
| 标签 / 搜索关键词 | 固定35、训练入口、评分、日志、自交定位、回程 |
| 基线分支 | feature/reference-comparison |
| 基线 Git | e6451e3342a92ed91324a5fe6efd2a496b95bdf1 |
| 关联提交 | 本单提交由git log查询 |

## 动机与边界

用户确认传动比35，用户可以修改，程序不能修改；同时反馈训练页被挤掉、日志过小、算法名称难理解，希望看评分与自交位置。本次使这些设置与结果可见，并移除计算层自动增比。旧模型的自动增比实验保持历史记录，不作为固定35方案。

## 改动文件

| 文件 | 改动 |
|---|---|
| `+camdesign/camProfile.m`、`defaultProject.m`、`solarTestProject.m`、`importProject.m` | 计算无条件固定输入比值；太阳能35，历史回归20；旧autoRatio提示停用 |
| `+camdesign/evaluate.m`、`fminconModel.m`、`verifyConstrained.m`、`exportResult.m` | 回程实际角/是否满足、固定维度回程约束、严格门禁与导出比值来源 |
| `+camdesign/optimizeFmincon.m`、`optimizeSearch.m` | 固定比报告；真实本轮名义差分/计划平滑记录，不改变训练调度公式 |
| `CamReplicaApp.m`、`+camdesign/resultDisplayData.m`、`camInspectionData.m` | 训练常驻入口、初始/运行值分开、评分及目标两图、完整日志、自交坐标与同网格放大、历史结果提示 |
| `check_fixed_ratio.m`、`check_fixed_ratio_convergence.m`、`check_constrained_optimizer.m`、`check_trajectory_bounds.m`、`check_training_controls.m` | 固定比合同、回程、长预算、约束维度与实际训练记录检查 |
| `check_results_panel_ui.m`、`check_training_controls_ui.m`、`check_training_actual_crossings.m`、`check_plot_layout.m`、`check_app.m` | 新结果面板、既有训练回归、归档8倍固定比自交夹具、布局及应用回归；独立本轮输出目录 |
| `data/fixed_ratio_results_20261030.json` | 固定35本轮数值摘要与来源哈希 |
| `AGENTS.md`、`README.md`、`docs/{USAGE,TRAINING_PARAMETERS,CONSTRAINED_OPTIMIZATION,REVERSE_ENGINEERING,FEATURE_STATUS,VALIDATION,INDEX,LESSONS_LEARNED}.md`、本记录及变更索引 | 长期规则、功能说明、历史边界、验证与经验 |

## 验证命令与结果

所有计算检查在独立MATLAB R2025b实例中执行，用户窗口保留。

| 检查 | 完整命令（仓库根目录PowerShell） | 实际结果 / 证据 |
|---|---|---|
| 固定比与相关回归 | `./run_matlab_checks.ps1 -Task "check_fixed_ratio; run_tests; check_constrained_optimizer('contracts'); check_training_controls"` | 7+12+7+11项通过，退出0；`local/matlab_5ecbd931d2824c219e9603853edf95ea.log` |
| 场界合同 | `./run_matlab_checks.ps1 -Task "check_trajectory_bounds;"` | 8项通过，退出0；`local/matlab_5b01564eb2e6490bb33a81c955c06a49.log`。首次历史夹具因固定比后细网格回程59.991°而失败，正确保留此额外拒绝后复测；未放宽阈值 |
| 动态训练记录 | `./run_matlab_checks.ps1 -Task "check_training_controls;"` | 增加history.plannedSmoothingRates后相关11项复测通过；`local/matlab_a0bf2930ed1d492c82dd6e06b58372b0.log`。计划系数和实际采纳系数分开，搜索行为未改 |
| 内点法实时记录 | `./run_matlab_checks.ps1 -Task "check_constrained_optimizer('contracts');"` | 增加history.nominalDifferenceStepMM后7项复测通过；`local/matlab_025ac55927df4d55948ce59cf0095528.log` |
| 充分预算诊断 | `./run_matlab_checks.ps1 -Task "check_fixed_ratio_convergence;"` | 34节点固定35；请求300、实际173轮，12462次模型尝试，70.03秒；求解器不可行停止，非超时。8倍压力角37.729812°、打卡37.710807mm、回程54.698366°，工程门禁未过。日志`local/matlab_62d29651cb434764a54ce2a804b7bf25.log` |
| 结果界面及布局 | `./run_matlab_checks.ps1 -Task "check_plot_layout; check_results_panel_ui; check_app;"` | 布局6场景、结果面板8项通过；同批check_app因旧图例位置断言失败，随后更新为当前位置并复测。日志`local/matlab_ef9319ac991e49eea608c8afb7aa75ec.log` |
| 训练与应用回归 | `./run_matlab_checks.ps1 -Task "check_training_controls_ui; check_training_actual_crossings; check_app;"` | 训练8项、真实历史8处自交显示、太阳能启动与应用检查通过，退出0。日志`local/matlab_79555f985d014c0295c45069576a0540.log` |
| 原生窗口 | Computer Use实际鼠标导航；独立新版窗口加载真实173轮记录 | 从车体页点击常驻训练按钮，九项设置、末轮实际参数可见；点击日志大窗，完整日志可见。保留旧用户窗口；未改任何用户输入 |

完整长预算输出为`outputs/fixed_ratio_results_20261030/convergence_300/`，入库摘要`data/fixed_ratio_results_20261030.json`保存来源哈希。短合同测试只验证代码行为，不代替长预算质量结论。

## 证据及局限

用户口头确认35是当前实车值，其余尺寸未确认为实测。回程角不足作为约束与最终门禁，不通过自动增比消除。评分为本版独立指标，不是原版完整评分。离散模型通过不等于原版一致或实车可用。

原版动态调参有既有实操16→8及停止后设置恢复的证据，但本版调度仍为独立实现，不声称恢复其精确衰减、插值增加或完整评分。自交8对的显示夹具来自历史归档，显式使用其8倍网格当时的实际比38.30021972006618；不是自动替用户增比，也不是固定35的队伍方案。加密复查是只读显示，导出按项目设置重新计算。

验证过程如实记录：短训练夹具因回程半径无效而更换为真实太阳能路线做1轮回调检查，不用该短运行判断算法能力；历史自交夹具初稿误用粗网格比38.304119420784225，改为归档8倍比后重现8对。复用旧布局/训练UI检查时覆盖部分可再生旧产物及通用outputs/fixed_cam_preview.png，后续输出迁到本次results_panel_20261030目录；旧布局目录两张solar_flat PNG不再作为CHG-012原始图像，原始候选MAT及传动比归档JSON未改，入库历史数值摘要保留。

最终界面证据在`outputs/results_panel_20261030/`：ui_verification.json、layout/verification.json、training_1120x760.png、training_1320x860.png、training_1920x1080.png、actual_search_runtime.png、large_complete_log.png和genuine_crossing_zoom.png。8处红圈图是历史失败夹具，不能与固定35候选混淆。布局测量最初改变axes单位导致截图裁切，现改为只读测量，最终6场景没有被图例遮住的路线/凸轮采样点；凸轮保持等比例。截图与检查摘要及哈希归入数值摘要的uiValidation字段。

## 关联经验

EXP-020（布局与实际可发现性）；EXP-024（参数结构未改不代表实际传动比未改）。

## 回退办法

交付后使用git revert本逻辑提交，保留运行证据。不得为了回退静默恢复用户已禁止的自动增比行为；若回退界面须保留核心固定比修正。

## 审核与交付

本轮请求的固定比、训练入口与运行值、评分趋势、日志和交点定位完成。总指挥复核代码、测试日志及截图，并实际打开“新版凸轮设计 · 训练与评分 · 固定35测试”；旧用户窗口未关闭。提交前检查差异与文档索引，仅提交本轮源代码/文档/摘要，原始输出不入库。原版完整调度仍未恢复，固定35长预算候选未通过工程门禁，不作为加工结果交付。
