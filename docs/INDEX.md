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
| [拆解说明](REVERSE_ENGINEERING.md) | 独立模型、字段映射、公式、复现边界 | 平推、齿条、坐标、传动比、包络 |
| [视频算法实现映射](ALGORITHM_IMPLEMENTATION_MAP.md) | 视频步骤、实际代码、独立补充及尚未恢复部分逐项对应 | 候选整套加权、邻点平滑、Bezier、十二项评分 |
| [长教程源码审计](BEZIER_SOURCE_AUDIT.md) | 可读函数片段、接口、原始特征及未知聚合依赖 | Simulation_cal、Squares_standard_sum、570–588秒 |
| [第一代源码与兼容模块](FIRST_GENERATION_SOURCE.md) | 原r2数值链、9路线零差、版本差异及复跑方式 | firstGenerationCam、c+f、两遍推进、后轴弦长 |
| [五份新增算法包](ADDITIONAL_SOURCE_PACKAGES.md) | 单Bezier源码恢复、阿克曼/共轭/通用凸轮资料分类 | BV1obN9enEtd、杨辉三角、de Casteljau |
| [原版实操与对照](REFERENCE_COMPARISON.md) | 原版窗口功能、资料/视频证据、同输入比较进展 | 3.1.2、2.5.1、Bezier、评分、截图、时间戳 |
| [验证记录](VALIDATION.md) | 实际执行的检查与结果、尚未验证事项 | run_tests、check_app、误差、收敛 |
| [功能证据与复现进展](FEATURE_STATUS.md) | 原版实操、视频、更新日志对应的功能状态与实施次序 | F01～F13、地图编辑、太阳能、Bezier、局部最优 |

## 数据与代码入口

| 入口 | 用途 |
|---|---|
| [太阳能点库](../data/2027_solar_course.json) / [太阳能检查](../check_2027_solar_course.m) | 队伍正式赛项点位、顺序访问及重复起终点 |
| [生物质能点库](../data/2027_biomass_course.json) / [点库检查](../check_2027_course.m) | 另一赛项资料及历史算法测试 |
| [四段原理视频证据](../data/video_principles_20261029.json) / [公式检查](../check_video_principles.m) | 来源、抽帧及独立解析验证 |
| [两段反推视频证据](../data/video_inverse_lectures_20261029.json) / [反推检查](../check_video_inverse.m) | 相位/行程/积分线索、转写质量与覆盖范围 |
| [AI 入门视频完整音轨证据](../data/video_ai_20261029.json) | 整套候选点集改善量加权、邻点平滑、画面复核位置及版本边界 |
| [优化质量数值摘要](../data/optimizer_quality_20261029.json) | 旧算法、新算法 30/300 轮同输入指标、终止原因及未达标证据 |
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
