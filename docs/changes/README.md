# 变更索引

从 2026-10-29 起，每个逻辑改动维护一个独立 Markdown 记录。一个改动可以涉及多个文件；相互独立的行为或目的应分别记录。长期规则见 [AGENTS.md](../../AGENTS.md)，经验见 [经验与教训](../LESSONS_LEARNED.md)，全部文档入口见 [文档索引](../INDEX.md)。

## 命名与登记

- 路径为 `docs/changes/YYYY/YYYY-MM-DD-NNN-slug.md`，日期按 Asia/Shanghai；`NNN` 为当日三位递增编号，从 `001` 开始，不复用。`slug` 使用简短的小写英文和连字符。
- 记录 ID 为 `CHG-YYYY-MM-DD-NNN`，与文件日期和序号对应；文件创建后不因标题微调而改号。
- 使用 [变更模板](TEMPLATE.md)。实施前或实施中建立记录，完成后补充实际验证、证据、限制与回退方法，并在本表登记。
- 状态使用“草拟 / 实施中 / 待验收 / 已验收 / 已回退”。执行人与审核人分别记录；未运行、失败或未完成的验证如实保留，不填“通过”。
- 每条记录关联相关 `EXP-NNN`；没有可关联经验时填写“无”，不为凑编号虚构教训。Git 提交前检查记录与最终改动范围相符。
- 一条记录跟踪一个逻辑改动；Git 提交应保持可独立审查与回退。若一个逻辑改动确需多次提交，在记录中解释并列出关联提交。

## 变更记录

| ID | 日期 | 标题 | 状态 | 标签 | 基线 Git |
|---|---|---|---|---|---|
| [CHG-2026-10-29-001](2026/2026-10-29-001-project-governance.md) | 2026-10-29 | 建立项目长期规则、经验与逐次变更记录 | 已验收 | governance、docs、Git、经验、索引 | `4cd829d` |
| [CHG-2026-10-29-002](2026/2026-10-29-002-route-map-editor.md) | 2026-10-29 | 场地图节点编辑与部件轨迹显示 | 待验收（原生鼠标） | 地图编辑、节点、轨迹、原版实操、更新日志 | `f625a50` |
| [CHG-2026-10-29-003](2026/2026-10-29-003-optimizer-quality.md) | 2026-10-29 | 优化质量诊断与视频算法实现核对 | 已验收（本轮诊断/实验；工程仍未达标） | 压力角、峰值、候选加权、平滑、停滞 | `a91d5e2` |
| [CHG-2026-10-29-004](2026/2026-10-29-004-main-map-layout.md) | 2026-10-29 | 路线主视图、搜索方向与参考圆 | 已验收（布局/回调） | 主图、图例、基圆、固定凸轮 | `a91d5e2` |
| [CHG-2026-10-29-005](2026/2026-10-29-005-source-audit.md) | 2026-10-29 | 深读视频源码与已知特征前端 | 已验收（可见特征） | Simulation_cal、源码、特征、评分依赖 | `541cae8` |
| [CHG-2026-10-29-006](2026/2026-10-29-006-resolution-study.md) | 2026-10-29 | 固定节点采样加密诊断 | 已验收（模型诊断） | 采样、收敛、压力角、未达标 | `541cae8` |
| [CHG-2026-10-29-007](2026/2026-10-29-007-first-generation-source.md) | 2026-10-29 | 第一代原脚本基准与忠实移植 | 已验收（第一代兼容） | 第一代、r2、逐点对照、厚度 | `541cae8` |
| [CHG-2026-10-29-008](2026/2026-10-29-008-additional-sources.md) | 2026-10-29 | 五份新资料与单曲线源码移植 | 已验收（单曲线） | Bezier、五包、逐点对照 | `34c4e5b` |
| [CHG-2026-10-29-009](2026/2026-10-29-009-full-collection-audit.md) | 2026-10-29 | 全部资料去重与核心缺口核对 | 已验收（资料审计） | 18包、来源、嵌套ZIP、农机凸轮 | `51234e7` |
| [CHG-2026-10-29-010](2026/2026-10-29-010-constrained-optimizer.md) | 2026-10-29 | 接入原生非线性约束优化与同输入比较 | 已验收（功能/诊断；工程案例未过加密验收） | fmincon、内点法、充分预算、差分、加密 | `9dba554` |

## 按主题查找

现有全部材料：[CHG-009 18包去重与源码核对](2026/2026-10-29-009-full-collection-audit.md)。

最新核心工作：[CHG-005 视频特征](2026/2026-10-29-005-source-audit.md)、[CHG-006 采样诊断](2026/2026-10-29-006-resolution-study.md)、[CHG-007 第一代源码](2026/2026-10-29-007-first-generation-source.md)、[CHG-008 新资料与单曲线](2026/2026-10-29-008-additional-sources.md)。界面见[CHG-004](2026/2026-10-29-004-main-map-layout.md)。验收仅限各单写明范围；3.1.2完整算法、工程阈值与原生鼠标未完成项保持开放。

新增实验求解路线：[CHG-010 约束后端与充分预算诊断](2026/2026-10-29-010-constrained-optimizer.md)，已实施，默认工程案例均未通过加密验收；功能检查通过与工程可行性分开记录。

| 关键词 | 入口 |
|---|---|
| 协作规则、执行审核、Git、回退、变更模板 | [CHG-2026-10-29-001](2026/2026-10-29-001-project-governance.md)、[模板](TEMPLATE.md)、[AGENTS.md](../../AGENTS.md) |
| 错误、教训、ASR、版本、实车、验证边界 | [EXP 关键词索引](../LESSONS_LEARNED.md#关键词索引) |
| 当前功能、运行方式、原版对照、历史验证 | [项目说明](../../README.md)、[使用说明](../USAGE.md)、[对照记录](../REFERENCE_COMPARISON.md)、[验证记录](../VALIDATION.md) |

## 迁移前历史入口

本制度的迁移基线为分支 `feature/reference-comparison` 上的 `4cd829d49016784f79fe87569805d873fbd817b8`。从首个提交 `9e295c5` 到该基线的已有提交未按本制度建立独立变更单；以下仅列真实 Git 历史及现有文档入口，不补造事件当时的逐次记录、审核或测试结果。

本地查看完整历史与某次实际补丁：

```powershell
git log --reverse --format="%h %ad %s" --date=short 4cd829d
git show <提交哈希>
```

| 日期 | Git 提交 | Git 原始标题 | 现有文档入口 |
|---|---|---|---|
| 2026-10-28 | `9e295c5` | docs: document cam app evidence and MATLAB reproduction scope | [项目说明](../../README.md)、[拆解说明](../REVERSE_ENGINEERING.md) |
| 2026-10-28 | `f0891e4` | feat: implement tested route kinematics and roller cam geometry | [验证记录](../VALIDATION.md) |
| 2026-10-28 | `8499fad` | feat: add Chinese MATLAB app and verified end-to-end demo | [使用说明](../USAGE.md)、[验证记录](../VALIDATION.md) |
| 2026-10-28 | `a45e4a7` | fix: verify original app type mapping and add reference comparison workflow | [对照记录](../REFERENCE_COMPARISON.md)、[EXP-001](../LESSONS_LEARNED.md#exp-001-机构编号必须绑定版本) |
| 2026-10-28 | `0addc6f` | feat: add fixed-cam parameter tuning based on original app workflow | [使用说明：固定凸轮试调](../USAGE.md#固定凸轮试调)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `96cf43c` | test: validate vehicle coordinate offsets and document original app audit | [对照记录](../REFERENCE_COMPARISON.md)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `1756c5e` | docs: verify original control point pick-and-place interaction | [对照记录](../REFERENCE_COMPARISON.md)、[EXP-005](../LESSONS_LEARNED.md#exp-005-交互验收先核对实际操作规则) |
| 2026-10-29 | `090c1e8` | docs: clarify original mechanical parameters and align UI labels | [使用说明](../USAGE.md)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `05281d7` | docs: confirm team flat mechanism and distinguish author defaults | [EXP-002](../LESSONS_LEARNED.md#exp-002-作者默认值不是实车尺寸)、[对照记录](../REFERENCE_COMPARISON.md) |
| 2026-10-29 | `fdd7165` | feat: add calibrated screenshot digitization and straight reference fixture | [对照记录](../REFERENCE_COMPARISON.md)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `11604f1` | feat: add verified 2027 solar course and biomass test data | [EXP-003](../LESSONS_LEARNED.md#exp-003-资料赛项不能替代队伍确认)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `7841e81` | docs: record AI tutorial evidence and local video workflow | [使用说明：本地视频研究](../USAGE.md#本地视频研究)、[对照记录](../REFERENCE_COMPARISON.md) |
| 2026-10-29 | `c776a2b` | feat: validate four local cam tutorials and envelope formulas | [对照记录](../REFERENCE_COMPARISON.md)、[验证记录](../VALIDATION.md) |
| 2026-10-29 | `4cd829d` | feat: validate inverse tutorial formulas and flag ASR failures | [EXP-004](../LESSONS_LEARNED.md#exp-004-asr-完成不代表字幕可靠)、[对照记录](../REFERENCE_COMPARISON.md)、[验证记录](../VALIDATION.md) |

历史表中的文档链接指向当前文档，具体提交时内容以 `git show <哈希>:<仓库相对路径>` 为准。当前状态与后续澄清应以最新记录为准，不能只依据旧提交标题判断验证范围。
