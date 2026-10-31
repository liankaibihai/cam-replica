# CHG-2026-10-31-014 四方向搜索：可行性与短路线

## 基本信息

- 状态：已验收（功能与本版数值；非实车验证）。
- 基线：feature/reference-comparison，dada6c638590ec7013e1d36050e1c25cd9c48f63。
- 日期/时区：2026-10-31 / Asia/Shanghai。
- 执行：Sol独立执行器负责实现、界面与实验；总指挥负责独立审查、文档及本地Git。
- 交付策略：仅本地Git提交，本轮不推送GitHub；以后积累完整开发阶段再统一上传。
- 标签：贝塞尔、四方向、偏差、压力角、路程、可行性、固定35。

## 动机与范围

用户希望以较短路程获得合理凸轮压力角和较小打卡偏差。现有四方向以六项加权分接受候选，长度收益可以抵消部分物理指标恶化，且训练评分没有固定比回程与中心轨迹场界项。新增独立的可行性优先搜索选项，保留旧实现作同初值对照；不冒称恢复原版完整评分和调度。

不修改路线到凸轮公式、已选路线模型/阶数、硬件、传动比35、目标顺序或验收门限。训练代理与完整离散几何及加密验收分别记录；比赛外廓/UID资料缺失不能默认通过。

## 改动文件与实现

| 文件 | 用途 |
|---|---|
| `+camdesign/optimize.m`、`optimizeFeasibilityFour.m` | 独立后端分派、双提案四方向、完整检查后接受、可行坐标提升、回溯/救援与调度、最终加密 |
| `+camdesign/feasibilityFourState.m`、`feasibilityFourBetter.m`、`pressurePreferenceProbe.m` | 严格物理状态、可行性排序、小偏差/压力余量偏好；不修改既有正反算公式 |
| `CamReplicaApp.m` | 明确可选入口、动态权重冲突提示、独立排序、最终8倍结果及历史标识 |
| `check_feasibility_four.m`、`check_feasibility_four_ui.m`、`check_feasibility_four_quality.m` | 核心/UI合同、同初值长预算、实验独占锁及标准候选保存 |
| `check_training_controls_ui.m` | 维护基线已过期的固定点数断言，验证实际映射数量、独立几何误差及有效仿真前置条件 |
| `data/feasibility_four_fixtures_20261031.json` | 可追踪的小型独立项目夹具；核心合同不依赖忽略目录中的历史MAT |
| `check_feasibility_gate_review.m`、`check_feasibility_actual_review.m` | 总指挥侧独立精确门限与实际轮廓闭环复核 |
| `scripts/archive_feasibility_search_evidence.py`、`data/feasibility_search_20261031.json` | 紧凑结果、日志、实验和源码哈希归档；大MAT与截图仅本地保存 |
| `AGENTS.md` | 固定用户目标与阶段性推送规则；无逐次进度 |
| `docs/FEASIBILITY_SEARCH.md`、`TRAINING_PARAMETERS.md`、`USAGE.md`、`DYNAMIC_WEIGHTS.md`、`ALGORITHM_IMPLEMENTATION_MAP.md`、`VALIDATION.md` | 新模式语义、适用性、入口与验证范围 |
| `docs/INDEX.md`、`LESSONS_LEARNED.md`、本记录及`changes/README.md` | 文档入口、真实过程教训与版本索引 |

初稿只沿违规方向移动，600轮后压力/顺序仍不合格。第二版复用同批探针生成原六项固定分的辅助方向，候选仍按可行性/质量排序接受。第三版保留正式门限，将偏差质量系数从0.02增加至0.2，引入同工作段额外相位压力采样和0.5°柔性余量偏好；近可行时优先完整复核可能可行的坐标候选。全部版本及失败结果单独保存，没有重写历史实验。

## 验证协议、命令与结果

MATLAB R2025b，独立batch。共同初值为本队设计值、传动比35、34控制点5阶独立贝塞尔、601路线点/721凸轮点；从目标重建，是显式改形初始化，不声称与旧路线保形。两方法使用相同初值、固定硬件、阈值、顺序及起点，基础六项权重为`[12 1 2 3 10 10]`，探针0.5、学习率1、平滑0.1、间隔50、调节指数0。每阶段600轮；轮数相同不代表评价次数与运算量完全相同。

所有命令从仓库目录运行`./run_matlab_checks.ps1 -Task "<下列MATLAB表达式>"`。新独立后端不依赖 Optimization Toolbox；独立复核脚本使用本地实验MAT，先运行对应质量实验。

| 检查 | MATLAB表达式 | 实际结果 |
|---|---|---|
| 固定初值 | `check_feasibility_four_quality('prepare')` | 生成并冻结共同初值；已有文件不重新生成 |
| 旧法600轮 | `check_feasibility_four_quality('run','video-four-direction-v1','primary')` | 完成；加密压力未通过 |
| 旧法续算 | `check_feasibility_four_quality('run','video-four-direction-v1','continuation_1')` | 再600轮；加密压力未通过，重复运行偏差详见EXP-036 |
| 新各版600轮 | `check_feasibility_four_quality('run','feasibility-four-direction-v1','primary')`、`primary_v2`、`primary_v3` | 各用当时保存源码运行；v1/v2未通过，v3通过。当前代码不能重新生成旧版本算法结果 |
| 新v3续算 | `check_feasibility_four_quality('run','feasibility-four-direction-v1','continuation_v3_1')` | 再600轮，累计1200轮，4/8倍通过 |
| 新核心与UI | `check_feasibility_four(); check_feasibility_four_ui()` | 核心8组、UI3组通过，分别日志`matlab_64b8b553692443edbc6b1a6e700be62f.log`、`matlab_d11a599957674c2b8d51ea075bcc1e20.log` |
| 无旧实验依赖复核 | `cd('outputs/feasibility_four_20261031/clean_contract/code'); check_feasibility_four` | 只复制源码、两个检查入口和三个JSON夹具，8组通过；日志`matlab_895f9bb6178447eba7a6ad62c41bb99b.log` |
| 精确门限对照 | `check_feasibility_gate_review()` | 8例通过，最终压力偏好加入后再次通过 |
| 旧法接触闭环 | `check_feasibility_actual_review('legacy','primary')` | 数值闭环通过，压力未通过 |
| 新v3接触闭环 | `check_feasibility_actual_review('feasibility','primary_v3')` | 数值闭环及离散模型门禁通过 |
| 最终新候选接触闭环 | `check_feasibility_actual_review('feasibility','continuation_v3_1')` | 数值闭环及离散模型门禁通过 |
| 同网格项目另存 | 从最终`actual_closure.mat`读`fine`，`saveProject`为`review_grid_project.mat`，用`importProject`逐值比较 | 通过，日志`matlab_fb3e7d9590254ab2b80ca5a93ad57664.log`；仅保存已检输入，未重复闭环计算 |
| 既有核心/动态UI | 隔离证据目录中的原入口`run_tests(); check_dynamic_weights_ui()` | 12/12及7组通过，日志`matlab_25d3a2beb0194e78930b6fdb93a75529.log`；同一批后续旧训练检查失败，不能说整批无错误 |
| 旧训练UI维护 | `check_training_controls_ui('outputs/feasibility_four_20261031/training_regression_fixed_2')` | 完整8组通过，日志`matlab_c20f3f0974d04567a1e7293068beda9a.log`；原失败及基线诊断均保留 |

已完成的阶段证据（后续修订不覆盖）：

- 旧四方向`legacy/primary`600/600轮、82530次搜索评价，8倍压力35.041653°、最大偏差0.059384 mm、主动轮12367.091453 mm、回程60.071050°，场界/自交/顺序通过但压力未通过；日志`local/matlab_4dadfc63d03c4303be2856fb78813a82.log`。
- 旧续算`legacy/continuation_1`再600轮，8倍压力35.017812°、偏差0.059072 mm、前轮12732.617212 mm、主动轮12367.707214 mm、回程60.056116°；数值收敛通过、物理未通过。该目录曾被异步交接中的两个实例重复运行，进度和物理结果一致，只计一份续算，详见EXP-036。两日志保留，禁止将其称为独立重复试验。
- 新初稿`feasibility/primary`600/600轮、82532次搜索评价，原网格压力45.989869°、偏差31.534168 mm、前轮12444.849364 mm、回程66.868894°，未可行，效果明显逊于旧分支。日志`local/matlab_09d36dce13184eba9550c264bc0c154d.log`。初稿源码保存在`source_snapshots/initial_feasibility`，不能仅因为门禁正确就称优化效果更好。
- 新第二版`feasibility/primary_v2`600/600轮、89560次搜索评价，8倍前轮12519.848460 mm、主动轮12159.783188 mm、最大偏差24.230947 mm、压力35.330719°；数值收敛通过，但物理未通过。原网格34.994198°不能替代加密验收，短约213 mm不能掩盖偏差增加。日志`local/matlab_7b0768d5eedb4423aadf918bc248ab6a.log`，源码`source_snapshots/proposal_v2`保留。
- 新第三版`feasibility/primary_v3`600/600轮、89713次搜索评价，8倍前轮12694.273462 mm、主动轮12328.317246 mm、最大/RMS偏差2.397832/1.938273 mm、整圈压力34.531874°、回程61.011409°；4/8倍及数值收敛通过。第476轮进入完整训练可行阶段。日志`local/matlab_4a9833b3363b4759b5555b2064d26f69.log`。此版小偏差/压力余量排序与v2不同，不跨版本比较排序值。
- 第三版续算`feasibility/continuation_v3_1`再600/600轮、97532次搜索评价，8倍前轮12690.206994 mm、主动轮12325.281803 mm、最大/RMS偏差0.906472/0.780295 mm、整圈压力34.270528°、回程61.085025°，4/8倍通过。累计187245次搜索评价，对照旧法165087次；均因预算结束，末段小幅改善不冒称已找到最优。日志`local/matlab_915c3405089348a69df6472f50a5742c.log`。标准`candidate_project.mat`保存最终项目，`solver_result.mat`含初值/终值，不作为用户导入入口。
- 父侧`check_feasibility_gate_review()`8个门限案例通过：新状态判定与已有验收器在压力、转角和回程边界两侧严格一致，快速评价不标可行；日志`local/matlab_7e4a2c24875f43dc8d8415f339b604d1.log`。新压力偏好函数加入后复跑8例通过，日志`local/matlab_449608337edd49b09cf2901541e988d6.log`。
- 父侧`check_feasibility_actual_review('legacy','primary')`以4801路线点/5761实际轮廓点、1201/2401反推积分检查；接触/闭环/积分收敛通过，最大传感器数值偏差0.018199 mm，实际接触压力35.065371°仍未达标。日志`local/matlab_a01527e37c5145d480c621413b245c80.log`。固定机构/起点/目标未改；这不是实车误差。
- 同口径`check_feasibility_actual_review('feasibility','primary_v3')`通过接触/闭环/积分与几何门禁：最大传感器闭合差0.053725339 mm、积分加密差0.000049800 mm、实际接触压力34.519850°、反推打卡偏差2.430681 mm。日志`local/matlab_1d3a7972d5f847b783027e3c163e21fe.log`。保持同一5761点实际轮廓，未回读理论半径替代接触，仍非实车验证。
- 最终续算的实际轮廓检查同样通过：最大/RMS传感器闭合差0.042651020/0.023597880 mm、积分加密差0.000047223 mm、接触压力34.287748°、反推打卡0.899113 mm，日志`local/matlab_dfbc4e65178947fca5ad0c021ef4d220.log`。
- 初稿功能合同5组通过，日志`local/matlab_cfec90f4e36b4a93a5d63e115ff3ce21.log`；首次测试曾用小于排序容差的违规差要求严格下降而失败，修正的是测试夹具，没有放松精确物理门限。失败日志`local/matlab_9a2d17ceda1841a78aac5c6d76bd8b6f.log`保留。

## 审查发现与边界

- 旧UI夹具严格映射产生约−1.9e−14 mm控制点越界，不能在精确门禁下标可行；改用明确重建的内部直线夹具，没有放松边界。初版promotion测试误把约200 mm坐标直接置为−1e−12 mm，实际上大幅改形；改用可追踪的真实映射微小残差，并单独处理第二个残差使其验证单坐标修复。相关失败日志保留。
- UI测试最初猜测“未配置/无法验收”文案，实际为“输入已修改，结果失效，须重新检查”；按真实失效状态核验。总指挥发现新结束分支漏掉“上次”标识，修复并新增修改输入后的历史结果合同。
- 核心合同原依赖本地历史MAT，经审查改为13 KB级JSON夹具，并在空实验目录中复核。实验入口锁取得后再次检查终值文件，拒绝并发及已完成证据覆盖。
- 旧训练UI固定50/540断言在当前代码和冻结基线均产生250/2740，日志分别`matlab_9089e64c6cc644509b8be7bab861392a.log`、`matlab_7967b1de9515425bbf8471b48f168247.log`；它与已实施的保形自动增点规则冲突。修订测试后独立4097点位置最大/RMS误差0.004591/0.000904 mm、切向0.027864°，未放宽保形门限。已达250点上限，插删测试先删一个内部点腾出容量，再核验插入/删除往返；显式重建按实际249点执行。
- 修订旧测试首轮`matlab_c37e40b2d47644ca983657e990dc556c.log`在重建后仿真因`cam:ReverseWheel`失败。显式改形不保证可立即计算；最终测试验证新路线参数和旧结果清除，再用已可计算的严格映射项目检查仿真禁用规则。没有修改生产算法或跳过倒转检查。
- 最终候选截图`feasibility/continuation_v3_1/candidate_ui.png`已视觉复核：路线/转角/凸轮、零位圆、固定比35、新优化入口、8倍指标、常驻训练入口均可见；未知比赛外廓继续显示不能认定赛事通过。
- 路线与实际轮廓正反算公式未改。结果仅支持当前理想模型、离散几何及固定输入，不能替代原版3.1.2同输入点集对照、实车加工/间隙/滑移/读卡验证或全局最优证明。

## 关联经验与回退

EXP-008、EXP-019、EXP-024、EXP-025、EXP-026、EXP-032、EXP-034、EXP-036。按`git log -- docs/changes/2026/2026-10-31-014-feasibility-first-search.md`查询本记录所属提交后`git revert <哈希>`；保留用户原始项目、候选与独立实验输出。旧峰值/加权四方向仍可用，默认未替换。

## 审核与交付

总指挥已审读新增排序、探针、候选接受、UI分支及旧测试修订，并独立完成精确门禁、实际轮廓闭环、无历史MAT的核心运行、截图和源码指纹复核。5个既有数学/旧搜索文件与基线SHA256一致；最终排序/压力辅助函数与正式试验快照一致，优化器仅修改一处余量说明文字。紧凑证据写入`data/feasibility_search_20261031.json`，大文件保留在本机忽略目录。按用户要求仅作本地逻辑提交，不推送GitHub；本单所属提交通过Git历史查询。
