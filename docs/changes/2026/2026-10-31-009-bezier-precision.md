# CHG-2026-10-31-009 贝塞尔计算精度与同输入优化复核

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期／时区 | 2026-10-31／Asia/Shanghai |
| 状态 | 已验收（数值精度；优化候选物理未达标） |
| 执行／审核 | Sol xhigh独立会话负责数值诊断与约定核心实现；总指挥负责独立审核、优化对照、文档和Git |
| 基线分支／Git | feature/reference-comparison／100c44df3b2e2a15bc9fc438bb0eebc5d7949a4f |
| 标签 | Bezier、解析导数、积分、回程、数值精度、固定35 |

## 动机与边界

用户要求继续优化贝塞尔算法，让路线到凸轮计算更准。先区分固定曲线的数值误差与移动控制点后的物理可行性，不凭评分下降宣称精度提升。保持用户选定路线模型和阶数、固定起点、硬件及验收阈值；比赛输入太阳能平推、传动比35。原有Bezier曲线位置语义不得静默改变。

基线包由 `git archive 100c44d +camdesign` 固定到 `local/bezier_precision_baseline`。对照采用完全相同保存项目与参数，两组各给600轮、80000次求解器调用及3600秒上限；训练601/721，最终2401/2881及4801/5761加密，并做实际轮廓闭环。预算结束仍改善时另存追加诊断。两个局部样例不代表通用算法优劣；原版3.1.2数值对照和实车验证仍缺。

## 改动文件

| 文件 | 改动与原因 |
|---|---|
| `+camdesign/independentBezierBasis.m`、`bezierRoute.m`、`routeGeometry.m` | 增加解析D3，原位置/D1/D2语义不变 |
| `+camdesign/route.m`、`analyticCamMotion.m` | Bezier行程与航向同步RK4；解析转角及凸轮相位D1/D2；其他路线数值分支保留 |
| `+camdesign/quinticHermitePP.m`、`camProfile.m` | 匹配半径、解析一二阶导数的五次Hermite工作段及回程；保存workPP及方法标识；拒绝不可分辨相位 |
| `+camdesign/simulate.m` | 理论反推读取已生成的workPP；无workPP保持旧PCHIP兼容；实际接触反推未改 |
| `check_bezier_precision.m`、`check_bezier_precision_core.m`、`check_bezier_precision_actual.m` | 冻结旧包诊断、独立de Casteljau/D3/自适应积分、两级积分容差、核心合同及实际轮廓点数收敛 |
| `check_bezier_quality.m` | 两组相同保存初值、相同预算的旧新对照，独立加密验收与实际接触，继续改善时另存加密续算 |
| `check_actual_cam.m`、`check_actual_cam_ui.m`、`check_model_mapping.m` | 可选输出目录，保留原证据；断言不放松 |
| `check_path_method_comparison.m`、`check_conversion_chain.m` | 审计读取workPP；新增显式五次工作段且旧样本被毒化的压力极值合同 |
| `scripts/archive_bezier_precision_evidence.py`、`data/bezier_precision_20261031.json` | 只读汇总、成对协议核查与源SHA256 |
| `AGENTS.md`、`README.md`、`docs/BEZIER_PRECISION.md`、`TRAINING_PARAMETERS.md`、`USAGE.md` | 长期来源约定、使用及计算范围 |
| `docs/INDEX.md`、`VALIDATION.md`、`LESSONS_LEARNED.md`、本记录与变更索引 | 证据、EXP-032及回退入口 |

## 定位与核心验收

R2025b独立批处理，统一启动脚本 `./run_matlab_checks.ps1 -Task "<MATLAB命令>"`。

| 命令／阶段 | 实际结果 | 日志 |
|---|---|---|
| `check_bezier_precision` 旧链诊断 | 两条保存曲线、601～19201路线点；位置/D1/D2与独立求值吻合，定位回程端点导数估计偏差和独立行程积分误差 | `local/matlab_b6b61cecf1e84c649a7c959870346d89.log` |
| `check_bezier_precision_core` | 9组通过，退出0：D0-D2逐位保留，D3独立核对；3～49阶/标量/端点；精确五次恢复；平推/齿条恒转角与变转角相位差分；旧cubic/B3/B5样例逐位；4/8/16倍；理论和实际字段隔离 | `local/matlab_de52722145a34f5eaee3c2d41801c5cc.log` |
| `check_bezier_precision_actual` | 同一9601点路线/2401-4801积分，凸轮5761/11521/20001点收敛，数值通过、物理仍失败 | `local/matlab_8bf4c011b317423fbd1ff61cf9f4a7c1.log` |
| `run_tests; check_model_mapping(fullfile(pwd,'outputs','bezier_precision_20261031','mapping')); check_path_method_comparison('audit-contract'); check_actual_cam(fullfile(pwd,'outputs','bezier_precision_20261031','actual_core')); check_actual_cam_ui(fullfile(pwd,'outputs','bezier_precision_20261031','actual_ui'));` | 原核心12、映射4、压力极值4夹具、实际核心8/UI7通过，退出0；总指挥查看新截图 | `local/matlab_1ba1ff000ef14f1ea759e824a342c363.log` |

诊断首次失败为测试辅助器调用MATLAB不支持的`diff(controls,0,1)`，日志 `local/matlab_f9261c6824124e6aae1aaf4c543bd1f3.log`，显式零阶原样返回后通过。核心合同首次在MATLAB目录优先级断言失败 `local/matlab_c4eb50f137c842d6ab9072cf5239629f.log`；随后冻结包缺相对点库 `local/matlab_3aecc6d7123549009076fdc1d46e97fb.log`，改用完整保存候选后通过。以上均为测试环境/辅助器修正，不改物理门限。

root在长测前审查发现新Hermite相位拒绝编号不属于搜索器已有可拒绝类别，已统一用`cam:ConstraintNonfinite`并保留具体原因；极短区间及超过20001样本的合同覆盖。此项仅调整错误处理，不改变有效输入方程；其他数值核心在长测期间冻结。

固定paired35曲线在601/4801/9601路线点时，旧整圈轮廓误差为7.98381/0.453794/0.127588 mm，新为0.00106663/0.00000557/0.000000185 mm，参照独立de Casteljau+ode113高精度数值参考。参考还用更紧容差及最大步长复算，不将浮点底噪解释为物理精度。两条固定曲线的9601点理论反推误差为1.47e-6/6.13e-7 mm。

实际折线点数另作隔离：quality34固定9601点设计参考及2401/4801积分，5761→11521→20001凸轮点的最大传感器偏差0.074504→0.018666→0.006178 mm；每个折线在积分加密期间冻结。压力角及回程仍失败。固定5761点时新闭环误差未优于008旧值，不能宣称每一项误差必然更小；旧拟合误差与折线误差可抵消。

## 长预算优化对照

旧新各两组主运行，每组请求600轮；随后两组均再给最多600轮、1201/1441训练网格。每次优化只移动控制点，固定模型/阶数、起点、物理参数和门限，参数不变断言通过。主初值为quality34与paired35的同一原MAT；追加阶段各自从本版主结果开始，属于续算诊断，不能说是新的相同初始曲线比较。

命令：旧版使用 `root=pwd; addpath(root); cd(fullfile(root,'local','bezier_precision_baseline')); check_bezier_quality('baseline');`；新版 `check_bezier_quality('improved');`；续算分别在对应包下调用 `check_bezier_quality('<variant>',<1或2>,'continuation');`。八组共请求4800轮，实际 **4627轮、329060次模型尝试**；七组达到600轮上限，旧paired35续算427轮由求解器判局部不可行停止，无时间超限。并发执行耗时有CPU负载混杂，不做速度排名。

下表为最终4801/5761网格；压力角≤35°、打卡≤30 mm、回程≥60°且欠切裕量>0、自交0，阈值未改。全部八个返回候选有自交和负欠切余量，均未通过物理验收，实际接触闭环明确拒绝自交。

| 版本／阶段／初值 | 实际轮数 | 压力角° | 打卡mm | 回程° | 自交段对 | 最小欠切裕量 |
|---|---:|---:|---:|---:|---:|---:|
| 旧／主／quality34 | 600 | 35.6563 | 30.7117 | 57.8574 | 2 | -0.0842 |
| 新／主／quality34 | 600 | 35.5696 | 30.7438 | 58.1761 | 8 | -0.0958 |
| 旧／主／paired35 | 600 | 49.4030 | 31.6630 | 58.4599 | 6 | -0.9835 |
| 新／主／paired35 | 600 | 36.3003 | 39.3552 | 57.3401 | 2 | -21.5956 |
| 旧／续／quality34 | 600 | 35.6563 | 30.7117 | 57.8574 | 2 | -0.0842 |
| 新／续／quality34 | 600 | 35.1534 | 31.1653 | 58.1250 | 1 | -0.0584 |
| 旧／续／paired35 | 427 | 34.7479 | 31.1425 | 57.3405 | 2 | -0.9204 |
| 新／续／paired35 | 600 | 36.4614 | 56.3249 | 59.0813 | 6 | -13.2530 |

旧paired35主运行数值稳定性失败，其余七项按现有加密稳定规则通过；稳定不等于可加工。新quality34压力角更接近35°但打卡略差；新paired35仍有明显搜索/采样缺口，本轮不能称新版控制点搜索整体更好。数值链修复更准确地评价同一曲线，并不会自动产生可行路线。未将这些失败候选替换进用户正在编辑的项目或推荐加工。

末50轮趋势：旧quality34主保留违规0.08128→0.04801；新quality34主0.05416→0.05020；旧paired35主保留解停滞但内部违规0.8910→0.6485；新paired35主0.78287→0.72093，故全部给额外预算。续算后旧两组保留解均停滞，内部违规仍略降；新quality34续0.09580→0.07920、新paired35续2.56313→2.52499仍改善。追加预算后仍未证明最终收敛，更不能断言固定35无可行解；局部求解未达标如实保留。

| 阶段 | 本地日志（均退出0） |
|---|---|
| 旧两主组 | `local/matlab_508c4a030a784418a726bc80ee9d44a9.log` |
| 旧quality34续 | `local/matlab_a44834b3a1934d43acd7d70a3ee15e63.log` |
| 旧paired35续 | `local/matlab_d7c2e562662c41b5940a5f6c402b8cd0.log` |
| 新两主组 | `local/matlab_bd91cb5b7d244a88b5b30238bfe0be56.log` |
| 新quality34续 | `local/matlab_e4215c9303d64c7c9698268beec3b17f.log` |
| 新paired35续 | `local/matlab_9e85ecf7188c47989d1f1d2d8bc0aa7c.log` |

入库[数值摘要](../../../data/bezier_precision_20261031.json)包含原诊断、9组核心、轮廓密度、相关回归和八组优化记录，以及46份来源/代码/日志SHA256；`python scripts/archive_bezier_precision_evidence.py`可只读复建。完整项目、历史及checkpoint在`outputs/bezier_precision_20261031`，大MAT不入库。

## 复跑与限制

原诊断在核心改动前产生，当前 `check_bezier_precision` 会显式选择冻结100c44d包并拒绝覆盖，默认新目录`baseline_diagnosis`；要从空目录重建本次后续核心所需数据，指定`OutputFolder=fullfile(root,'outputs','bezier_precision_20261031')`。核心/轮廓密度测试同样拒绝覆盖已有证据。需要恢复本机历史完整MAT候选（quality_bezier、quality_cubic、seed1_bezier5、seed1_bspline3/5），不把缺失夹具标为通过。

实际轮廓、数值参考和有限相位采样仍非连续全局认证；机构间隙、滑移、加工误差及3.1.2同输入输出不在本轮验证范围。实际闭环为手动独立入口，本次未自动并入训练/导出门禁。

## 关联经验与回退

遵守EXP-019的加密验收、EXP-022的参数/端点语义、EXP-029的同输入比较、EXP-031的独立接触验证；新增EXP-032记录端点导数偏差及对照环境教训。总指挥已逐项审核公式/调用、核心日志、参数隔离、UI截图及八组实际结果。文档链接、来源哈希和补丁检查通过后本地提交，不推送。若回退，针对本单提交执行`git revert`，同步恢复入口与文档；保留原项目和所有实验输出。
