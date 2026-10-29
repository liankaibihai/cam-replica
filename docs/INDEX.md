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

| 文档 | 负责记录什么 | 常用搜索词 |
|---|---|---|
| [使用说明](USAGE.md) | 启动、参数、导入导出、固定凸轮试调、本地视频工具 | R2025b、运行、参数、反推、ASR |
| [拆解说明](REVERSE_ENGINEERING.md) | 独立模型、字段映射、公式、复现边界 | 平推、齿条、坐标、传动比、包络 |
| [视频算法实现映射](ALGORITHM_IMPLEMENTATION_MAP.md) | 视频步骤、实际代码、独立补充及尚未恢复部分逐项对应 | 候选整套加权、邻点平滑、Bezier、十二项评分 |
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
