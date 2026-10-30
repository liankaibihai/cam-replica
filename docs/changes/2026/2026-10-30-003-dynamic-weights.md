# CHG-2026-10-30-003 动态权重与固定参考评分

## 基本信息

| 字段 | 内容 |
|---|---|
| ID | CHG-2026-10-30-003 |
| 日期 / 时区 | 2026-10-30 / Asia/Shanghai |
| 状态 | 已验收（功能及独立对照；工程候选未达标） |
| 执行人 / 角色 | 总指挥：核心、对照与文档；独立Sol执行器：界面 |
| 审核人 / 角色 | 总指挥，核心、对照、截图与原生运行显示复核 |
| 标签 | 动态权重、违规、固定参考、评分尺度、候选公平比较 |
| 基线分支 | feature/reference-comparison |
| 基线 Git | 2fa531f0a9bc4f99daf07f7308eaaf1d7c4697ec |
| 关联提交 | 使用git log查询本记录所属提交 |

## 动机与边界

用户要求动态控制评分权重。本轮先实现已说明的按违规调节，默认关闭、基础权重由用户控制；当前支持梯度与四方向搜索，内点法不静默采用或忽略。固定参考分和动态搜索分分开记录。公式与边界见[功能说明](../../DYNAMIC_WEIGHTS.md)。不修改几何算法、机械参数或工程阈值。

## 改动文件

| 文件 | 改动 |
|---|---|
| +camdesign/dynamicWeightSettings.m、updateDynamicWeights.m | 默认、验证、带上限与响应比例的违规权重 |
| +camdesign/validateProject.m、optimizeSearch.m、optimizeFmincon.m、optimizeLegacy.m | 冻结同轮评分、真实历史、拒绝不支持的后端 |
| CamReplicaApp.m、+camdesign/resultDisplayData.m | 设置、实际权重来源、固定/动态评分表及独立曲线 |
| check_dynamic_weights.m、check_dynamic_weights_convergence.m | 合同检查、同初值300/600轮静态/动态比较 |
| check_dynamic_weights_ui.m、check_app.m | 专项UI检查、既有应用回归支持指定输出目录 |
| data/dynamic_weights_20261030.json | 300/600轮数值摘要与来源哈希 |
| AGENTS.md、docs/DYNAMIC_WEIGHTS.md、docs/INDEX.md、docs/USAGE.md、docs/VALIDATION.md、docs/LESSONS_LEARNED.md、docs/changes/README.md、本记录 | 同轮评分长期规则、语义、验证与经验 |

## 验证命令与结果

独立R2025b批次：`./run_matlab_checks.ps1 -Task 'check_dynamic_weights; check_dynamic_weights_convergence;'`。日志`local/matlab_eb1df5f0b43b4ce3b390cc3053ae18b5.log`，合同7项、静态/动态各300轮完成、退出0。`./run_matlab_checks.ps1 -Task 'check_dynamic_weights_convergence(600);'`延长对照，两组均完成600轮，退出0，日志`local/matlab_cb1033ed2b534794b08a319ee1044e90.log`。静态85978次评价/94.98秒，动态85674次/94.05秒；不是超时或只运行几轮。输出独立放在`outputs/dynamic_weights_20261030/`。

600轮动态压力角68.84898°略低于静态69.15441°，但打卡偏差14.02005 mm大于9.11456 mm，固定参考分39.34466高于38.08645；两组均未通过压力角、回程等门禁。不能因动态评分改变而宣称优于静态，完整指标见功能说明与入库摘要。

调权标志修正后`./run_matlab_checks.ps1 -Task 'check_dynamic_weights;'`复测7项通过，日志`local/matlab_f96a05d3a31b4200b1eb6e78e35fafb5.log`。仅记录字段改变，不重跑600轮质量实验；已有权重向量与更新轮次均完整。

专项UI命令`./run_matlab_checks.ps1 -Task 'check_dynamic_weights_ui;'`：7项通过，覆盖缺记录、保存导入、真实两轮回调、切换评分来源、加密重评、历史标签及不支持后端；短回调不是优化能力验证。初次event断言失败日志0260426bf70d4f77919fc5712070638c，后续7项通过日志3ac42828abc648da810066a77dd33850、d7fc4708bc7e4238a6c30417c659a6ef（均在local/matlab_*.log）。最后仅缩短表头/字号并回放已有记录，最终回放日志local/matlab_860327492f3248e08b383f636b6fbe98.log为DYNAMIC_UI_REPLAY_PASS，无新训练；1120与1320截图位于本轮输出目录。

既有应用回归`./run_matlab_checks.ps1 -Task "check_app(fullfile('outputs','dynamic_weights_20261030','app_regression'));"`通过，日志`local/matlab_455df258650b447ea5d8e97dfed7cf80.log`；含真实固定凸轮反推、退出和静态优化路径。未覆盖旧截图目录。

原生桌面：独立打开“新版凸轮设计 · 动态权重 · 600轮对照候选”，启动脚本仅装载归档候选，没有调用优化。日志local/dynamic_ui_2a7b48c818f6401da85f4cae8128317f.log为DYNAMIC_WEIGHTS_UI_READY。随后观察时窗口已在新一轮训练，显示第11轮起的实际压力角权重7.3394（基础3），固定参照/动态分分别可见；未停止或修改该训练。此前已有窗口保留。

## 证据及局限

不声称恢复原版权重公式，不将动态分下降当固定尺度改善。初值和默认增益仅是实现测试配置，不是已经验证的最佳调参。原版动态同输入对照与实车验证未执行。

## 关联经验

EXP-024：算法可调的评分参数与用户固定机械参数分开；EXP-025：调权事件被运行阶段覆盖的实际错误与修正。候选必须同尺度比较属于本次设计约束。

## 回退办法

关闭开关即可回到静态评分；需要撤销界面和接口时git revert本逻辑提交，保留实验产物与历史。

## 审核与交付

核心、界面和独立预算对照已完成；用户确认按违规自动调节。总指挥检查真实日志、1120截图与原生运行显示。传动比和物理阈值不变，内点法不支持状态明确可见；原版精确调度、实车准确性以及工程可行解仍未获得。本轮源代码、数值摘要、经验与索引统一提交Git，原始产物不入库。
