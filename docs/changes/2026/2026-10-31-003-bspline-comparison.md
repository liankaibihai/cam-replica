# CHG-2026-10-31-003 标准B样条接入与太阳能四方法对比

## 基本信息

| 字段 | 内容 |
|---|---|
| ID | CHG-2026-10-31-003 |
| 日期／时区 | 2026-10-31 / Asia/Shanghai |
| 状态 | 已验收：功能／比较完成；20主实验及4追加均未获全面合格候选 |
| 执行人 | Sol xhigh独立会话负责核心／UI；总指挥负责协议、长测、文档、整合与Git |
| 审核人 | 总指挥整合与证据核对；Sol额外只读审查与UI修复 |
| 标签 | B样条、太阳能、固定35、66DOF、同条件比较、压力角极值 |
| 基线分支 | feature/reference-comparison |
| 基线Git | 7c6d4e0e58ceac958210a849ead87107f8cdad67 |
| 关联提交 | cea4968文献报告、7c6d4e0专用文献会话 |

## 动机与边界

用户要求读取文献会话结果，选择适用算法加入，并与原有两种在本队比赛路线充分迭代比较。选择标准B3/B5，通过同一前轮路线到车辆／传感器／凸轮链，固定硬件与阈值。新增支持内点法，其他后端显式拒绝；不称原版函数恢复。

## 改动文件

| 范围 | 目的 |
|---|---|
| +camdesign/bsplineBasis.m、bsplineRoute.m、routeGeometry.m、toBSpline.m | 标准基函数、解析导数、共同前轮求值及受约束拟合 |
| +camdesign/optimizationVariables.m、controlBounds.m | 精确消去端点等式、区分系数和物理轨迹场界 |
| +camdesign/route.m、validateProject.m、setControlPointCount.m、applyTrainingSettings.m | 模型分派、端点验证、数量与画法转换 |
| +camdesign/fminconModel.m、optimizeFmincon.m、verifyConstrained.m | 零正则比较接口、端点映射与统一物理门禁 |
| +camdesign/optimize.m、optimizeAuto.m、optimizeLegacy.m、optimizeSearch.m | 不支持的B样条后端明确拒绝 |
| CamReplicaApp.m、check_bspline*.m | 新方法可选择、编辑、优化和存档，合同／UI验证 |
| check_path_method_comparison.m、report_path_method_comparison.m、scripts/build_path_evidence.py | 5成对初值×4表示与4追加；加密、压力极值、恢复锁、图与证据生成 |
| data/path_method_comparison_20261031.json | 24组压缩数值、输入、源码SHA256、合同与额外网格诊断 |
| docs/PATH_METHOD_COMPARISON.md、PATH_LITERATURE_REVIEW.md | 实际检索交付与公平比较协议／结果 |
| AGENTS.md、docs/INDEX.md、changes/README.md、本记录、LESSONS_LEARNED.md | 长期表示约定、索引、经验和回退 |
| docs/USAGE.md、TRAINING_PARAMETERS.md、CONSTRAINED_OPTIMIZATION.md、PATH_METHODS_RESEARCH.md、VALIDATION.md | 新入口、参数含义、历史与当前边界、实际结果 |

总共17个核心文件（6新增、11修改），未改车辆积分方程或凸轮接触／回程公式，保留旧cubic默认。标准B样条系数可见场外编辑允许，真实五中心场界仍严格执行。

## 验证命令与结果

| 检查 | 命令／证据 | 实际状态 |
|---|---|---|
| 新核心合同 | run_matlab_checks.ps1 -Task check_bspline；local/matlab_f2d5ee5d0e1e4beb9583ef62474107eb.log | 6组通过；总指挥核对解析、端点、自由度、场界与真实短回调断言；不用于质量结论 |
| 共同初值 | run_matlab_checks.ps1 -Task "check_path_method_comparison('prepare')"；local/matlab_e7545e7d39dd4a4189d48a18d4b2d086.log | 20初值全部可计算，拟合误差记录；不是质量验收 |
| 压力极值审计接线 | prepare seed1；local/matlab_cb12271331c24305aa8159a9c4bbcc06.log | 四组运行完成 |
| 压力极值解析合同 | check_path_method_comparison('audit-contract')；local/matlab_9f585a97e11d4d5ba0f25e2fc6205e84.log | 常圆、已知二次峰值、五次回程密网格oracle通过 |
| 正式质量 | run_matlab_checks.ps1 -Task "check_path_method_comparison;"；local/matlab_0a89994b26b54bbf871546a908fd03fc.log | 20组完成，10134轮／714235模型尝试；0/20全面合格 |
| 并行独立组 | seed5：local/matlab_bdfaa0015d3949208391aaa5a6f25b8b.log；seed4-B5：local/matlab_ebf9ed7fe48e4a129fa206453c158f5f.log | 主实例复用完成文件；无同组重叠，墙钟不做隔离速度排名 |
| 统一密网格追加 | check_path_method_comparison('continue',1)；local/matlab_fe20b49116ea4711802b7272f907fa30.log | 4组完成，2292轮／159033尝试；0/4全面合格 |
| 4/8/16倍补充诊断 | local/inspect_comparison_seed1.m；local/matlab_4ba9ded010e24658b179fe20e1ae9909.log | 初值1四表示重新加密；数值归档，未把单个压力峰收敛当轮廓收敛 |
| UI | run_matlab_checks.ps1 -Task check_bspline_ui；local/matlab_d56446b9ad5d4c93aae1484d01d6dbf5.log | 最终10/10；outputs/bspline_20261031/ui_map_bounds，场外系数可选可拖但物理越界仍拒绝 |
| 旧核心回归 | run_matlab_checks.ps1 -Task run_tests；local/matlab_1fb1ae80a8c74dd8b65c7d8d8eb79991.log | 12/12；可再生旧固定测试文件恢复原内容 |
| 恢复／无效值合同 | check_path_method_comparison('storage-contract')；local/matlab_4200a63f71b44e2db894fd4d289b184a.log | 缺JSON恢复、非有限统计、协议／轮径／目标／阈值变更拒绝、互斥目录锁通过 |
| 24组保存证据核验 | local/audit_path_evidence.m；local/matlab_2a5264c99cfa43fcb51b7d64b5bd6ccf.log | 12426轮／873268尝试；全部固定35、66DOF、参数不被优化器改写；摘要与MAT相符 |
| 全部恢复及绘图 | local/matlab_928a9f1b9139494da816f535e846b1e3.log；最终绘图local/matlab_da196eb66d9b4d48a65119ccb1fc3233.log | 核验20+4保存项目物理输入；正式图成功，人工查看布局、标签、共同坐标和自交标记 |
| 入库摘要 | python scripts/build_path_evidence.py | 完整141KB左右JSON及表格生成；包含实测输入状态和明确适用范围 |

首个prepare因空结构体字段初始化报错（local/matlab_4b07474ebc54415d9762bbdcbecf3ecf.log），修正脚本后重跑，不算算法失败或正式样本。

只读审查发现JSON的Inf→null→空数组会使汇总报错、MAT存在不等于完整完成、协议遗漏物理字段，以及地图把系数误限于场地；均已修复并作针对验证。锁取得后的完成状态再次检查，恢复补JSON也在锁内。直线短合同出现近奇异警告但断言通过；原生鼠标与文件选择器未测，UI验证走真实回调／动作路径。排版预览曾因未完成全部初值产生图例多余项警告，改按实际曲线DisplayName，正式图无该警告。Python环境无SciPy，原始MAT一致性检查改用已有MATLAB执行，没有安装依赖。

## 证据及局限

参见[比较说明](../../PATH_METHOD_COMPARISON.md)。固定35与实际平推已确认，其余尺寸、初始航向、30mm测试容差尚非实车标定。无原版同输入数值和实车加工证据。局部优化不证明全局最优；初值拟合近似，控制变量及基函数分布不同。

## 关联经验

EXP-019增加粗细网格及回程差证据；EXP-026轻量checkpoint及恢复经验；EXP-028文献身份复核；新增EXP-029说明控制变量、等式秩、场界和移动正则的比较口径。

## 回退办法

提交后用git log定位本单关联提交并git revert，保留outputs原始质量证据；不动用户原资料或窗口。回退后执行旧run_tests、check_app并检查项目导入，B样条新工程不应静默解释成cubic。

## 审核与交付

总指挥已核对核心差异、合同、24组MAT一致性、图件及入库统计；功能与本次比较范围验收通过，工程候选全部未通过。保留三次默认，新增B3/B5可选，不给出加工批准或原版等价结论。`git diff --check`通过，最终所属提交用`git log -- <本记录路径>`查询；提交后检查工作区无遗留本次修改。
