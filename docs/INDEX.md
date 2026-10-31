# 文档总索引

先读 [项目概览](../README.md) 和 [长期协作规则](../AGENTS.md)，再按问题查下表。每次逻辑改动的详情保存在独立变更记录，错误与经验使用稳定编号检索。

## 协作与历史

| 入口 | 内容 | 常用搜索词 |
|---|---|---|
| [AGENTS.md](../AGENTS.md) | 长期规则、总指挥与执行器分工、重要约定 | Sol、xhigh、Git、证据 |
| [逐次变更索引](changes/README.md) | 每次改动的独立 MD、迁移前历史入口 | 日期、变更 ID、标题、标签 |
| [变更记录模板](changes/TEMPLATE.md) | 新改动的统一记录格式 | 基线、范围、验证、回退 |
| [经验与教训](LESSONS_LEARNED.md) | 已发生错误、纠正办法及可复用经验 | EXP、机构编号、默认参数、转写、验证 |

## 功能、算法与验收

全部可用材料先查[资料总目录](MATERIALS_CATALOG.md)，包括18包去重、读取覆盖和与本项目的关系；相关源码详读见[专项复核](FULL_COLLECTION_SOURCE_REVIEW.md)。

| 文档 | 负责记录什么 | 常用搜索词 |
|---|---|---|
| [使用说明](USAGE.md) | 启动、参数、导入导出、固定凸轮试调、本地视频工具 | R2025b、运行、参数、反推、ASR |
| [旧窗口回调恢复](changes/2026/2026-10-31-016-ui-callback-recovery.md) | 源码更新后按钮失效、完整状态保全和就地恢复 | 找不到函数、匿名回调、applyTraining、未应用输入 |
| [全界面回调检查](changes/2026/2026-10-31-017-all-ui-callbacks.md) | 全部持久UI连接、事件参数、旧窗口覆盖清单与无计算验证 | 按钮、SizeChangedFcn、具名分派、MATLAB工具栏 |
| [训练设置反馈与点数调整](changes/2026/2026-10-31-018-training-controls-feedback.md) | 优化灰色原因、保形请求与实际点数、显式强制调整 | 动态权重、50→170、待应用、保形 |
| [实际轮廓完整反推](ACTUAL_CAM_CLOSURE.md) | 冻结实际XY、线段接触、车辆积分、闭环及加密检查 | actual、圆盘、RK4、积分稳定、理论对照 |
| [贝塞尔数值精度](BEZIER_PRECISION.md) | 固定曲线误差定位、解析凸轮导数、同步积分与工作/回程构造 | Bezier、D3、RK4、Hermite、workPP、采样收敛 |
| [总路程显示](changes/2026/2026-10-30-002-route-length.md) | 前轮总路程与主动轮行程、单位及结果来源 | 总路程、mm、m、历史、加密 |
| [动态评分权重](DYNAMIC_WEIGHTS.md) | 违规调权、固定参考/动态分、支持后端和公式 | 基础权重、实际权重、间隔、倍率、响应 |
| [全自动调优](AUTO_TUNING.md) | 六项权重与训练配置搜索、固定物理门禁、统一网格与收敛 | 全自动、配置、验收、稳定性 |
| [模型映射与自动锁定](MODEL_MAPPING.md) | 真实曲线转换、严格保形／手动强制、完整备份恢复、独立重建 | 固定模型、强制切换、0.05mm、切向、改形、重建 |
| [2026-10-31软件审查](SOFTWARE_REVIEW_20261031.md) | 基线5项程序问题和1项规则覆盖缺口；005/006修复与回归入口 | 模型切换、控制点语义、重建失败、保形误报、导出漏项 |
| [路线画法文献与比较](PATH_METHODS_RESEARCH.md) | 三次/五次B样条、低阶贝塞尔、回旋线/G³的文献与适配边界 | 学术搜索、曲率变化率、局部支撑、固定35、长度预算 |
| [文献会话复核](PATH_LITERATURE_REVIEW.md) | 专用工具会话4次多源检索与7篇身份核验、直接配点与凸轮参数化补充 | academic-search、读取程度、直接最优控制 |
| [四方法太阳能比较](PATH_METHOD_COMPARISON.md) | 标准B3/B5与旧插值/独立Bezier接入、66DOF、5成对初值长测和极值审计 | 同条件、节点、压力角、稳定性、实际结果 |
| [训练参数与独立贝塞尔](TRAINING_PARAMETERS.md) | 九项参数实际语义、后端适用性、独立融合及自交红圈 | 控制点、插值、阶数、学习率、调度、自交 |
| [四方向可行性与短路线](FEASIBILITY_SEARCH.md) | 先处理违规、再比较长度/偏差/压力角；同初值对照与验收 | 四方向、固定35、回程预算、可行性 |
| [接力精修与多起点](RELAY_MULTISTART.md) | 固定模型的四方向/SQP接力、平滑多起点及统一计算预算对照 | 接力、SQP、20万、真实调用、候选保留 |
| [拆解说明](REVERSE_ENGINEERING.md) | 独立模型、字段映射、公式、复现边界 | 平推、齿条、坐标、传动比、包络 |
| [视频算法实现映射](ALGORITHM_IMPLEMENTATION_MAP.md) | 视频步骤、实际代码、独立补充及尚未恢复部分逐项对应 | 候选整套加权、邻点平滑、Bezier、十二项评分 |
| [成熟约束优化适配](CONSTRAINED_OPTIMIZATION.md) | 公开方法选型、原生fmincon实现与同输入验证边界 | SQP、B样条、约束、压力角、可行性 |
| [长教程源码审计](BEZIER_SOURCE_AUDIT.md) | 可读函数片段、接口、原始特征及未知聚合依赖 | Simulation_cal、Squares_standard_sum、570–588秒 |
| [第一代源码与兼容模块](FIRST_GENERATION_SOURCE.md) | 原r2数值链、9路线零差、版本差异及复跑方式 | firstGenerationCam、c+f、两遍推进、后轴弦长 |
| [五份新增算法包](ADDITIONAL_SOURCE_PACKAGES.md) | 单Bezier源码恢复、阿克曼/共轭/通用凸轮资料分类 | BV1obN9enEtd、杨辉三角、de Casteljau |
| [原版实操与对照](REFERENCE_COMPARISON.md) | 原版窗口功能、资料/视频证据、同输入比较进展 | 3.1.2、2.5.1、Bezier、评分、截图、时间戳 |
| [验证记录](VALIDATION.md) | 实际执行的检查与结果、尚未验证事项 | run_tests、check_app、误差、收敛 |
| [路线到实际凸轮专项核查](changes/2026/2026-10-31-007-conversion-chain-audit.md) | 运动学推导、实际轮廓独立接触恢复、理论反推缺口 | 平推、相位、法向补偿、0.000238mm、模型前提 |
| [功能证据与复现进展](FEATURE_STATUS.md) | 原版实操、视频、更新日志对应的功能状态与实施次序 | F01～F15、地图编辑、太阳能、Bezier、局部最优 |

## 数据与代码入口

最新固定35规则、训练/评分界面变更见[CHG-2026-10-30-001](changes/2026/2026-10-30-001-fixed-ratio-results.md)；[固定35长预算摘要](../data/fixed_ratio_results_20261030.json)记录173/300轮后仍未通过，不沿用旧自动增比结果。

| 入口 | 用途 |
|---|---|
| [太阳能点库](../data/2027_solar_course.json) / [太阳能检查](../check_2027_solar_course.m) | 队伍正式赛项点位、顺序访问及重复起终点 |
| [太阳能平推测试入口](../+camdesign/solarTestProject.m) / [数值与规则结果](../data/solar_flat_validation_20261029.json) / [CHG-013](changes/2026/2026-10-29-013-solar-flat-test-case.md) | 同赛道充分预算、加密复核、部件出界与识别半径敏感性；非实车标定 |
| [三图布局变更](changes/2026/2026-10-29-012-chart-layout.md) | 左路线、右转角/凸轮、图内图例、真实场地边界与多窗口验证 |
| [路线细化与长预算](changes/2026/2026-10-29-014-route-refinement.md) / [数值摘要](../data/route_refinement_20261029.json) | 保形插值、固定站位、10/34节点自由度、压力角峰值及部件越界 |
| [部件场界与加密门禁](changes/2026/2026-10-29-015-trajectory-boundaries.md) / [结果摘要](../data/trajectory_bounds_20261029.json) | 五个参考中心点、固定长度约束、147/300轮、8倍模型检查；非整车/实车保证 |
| [训练功能与贝塞尔实验](changes/2026/2026-10-29-016-training-controls.md) / [数值摘要](../data/training_controls_20261030.json) | 九项真实接线、50控制点/7与15阶、8组300轮预算、自交定位；实验候选未通过加密验收 |
| [生物质能点库](../data/2027_biomass_course.json) / [点库检查](../check_2027_course.m) | 另一赛项资料及历史算法测试 |
| [四段原理视频证据](../data/video_principles_20261029.json) / [公式检查](../check_video_principles.m) | 来源、抽帧及独立解析验证 |
| [两段反推视频证据](../data/video_inverse_lectures_20261029.json) / [反推检查](../check_video_inverse.m) | 相位/行程/积分线索、转写质量与覆盖范围 |
| [AI 入门视频完整音轨证据](../data/video_ai_20261029.json) | 整套候选点集改善量加权、邻点平滑、画面复核位置及版本边界 |
| [优化质量数值摘要](../data/optimizer_quality_20261029.json) | 旧算法、新算法 30/300 轮同输入指标、终止原因及未达标证据 |
| [原版300次与图读数证据](../data/original_comparison_20261029.json) / [CHG-011](changes/2026/2026-10-29-011-original-comparison.md) | 相同目标/尺寸、固定传动比20，原版两机构各300次、五站位路线差异；非逐点凸轮精度 |
| [固定节点采样诊断](../data/route_resolution_20261029.json) / [检查入口](../check_route_resolution.m) | 四档网格的压力角、轮廓与传感器轨迹稳定性；不重新优化 |
| [视频源码证据](../data/bezier_source_audit_20261029.json) / [特征检查](../check_video251_features.m) | 2.5.1可见原始特征、7组验证；不含完整评分 |
| [补充资料审计](../data/algorithm_materials_audit_20261029.json) | 下架教程、重叠曲线板书、另一份凸轮代码压缩包的覆盖边界 |
| [第一代数值证据](../data/first_generation_20261029.json) / [对照检查](../check_first_generation.m) | 源文件指纹、九路线逐点结果及5组手算/边界检查 |
| [五包来源与Bezier验证](../data/additional_sources_20261029.json) / [对照检查](../check_bezier_source.m) | 包内文件清单、原曲线零差及独立递推验证 |
| [18包完整库存](../data/full_collection_inventory_20261029.json) / [源码复核](../data/full_collection_review_20261029.json) | 读取覆盖、重复来源、农机点集、加密边界及核心缺口 |
| [资料扫描工具](../tools/audit_matlab_collection.py) | 只读ZIP/嵌套ZIP清点、来源哈希与关键字行定位 |
| [计算模块](../+camdesign) / [界面](../CamReplicaApp.m) | 生产实现；具体行为以源码和相关验证为准 |
| [本地工具](../tools) | 视频解码、转写及质量检查等辅助处理 |

## 搜索方法

在仓库根目录运行，例如：

```powershell
rg -n '机构编号|默认参数|ASR|Bezier' AGENTS.md docs data
rg -n '2026-10-29-001|project-governance' docs/changes
rg -n 'EXP-' docs/LESSONS_LEARNED.md docs/changes
git log --oneline -- docs/changes
```

按文件查所属提交用 `git log --oneline -- <文件路径>`。Git 历史、原始证据和独立变更记录各自保留，不用本页代替详细记录。

## 2027太阳能赛项理解

当前赛项、评分与规则适配见[赛项理解与资料核对](CONTEST_CONTEXT_2027.md)，包含本地规则来源、阅读覆盖以及几何验收与比赛判定的差异。

整车外廓压线、UID覆盖和本队设计配置见[比赛几何](CONTEST_GEOMETRY.md)。
