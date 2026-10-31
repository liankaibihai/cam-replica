# CHG-2026-10-31-006 全自动锁定模型与真实曲线保形映射

## 基本信息

| 字段 | 内容 |
|---|---|
| ID／日期 | CHG-2026-10-31-006／2026-10-31 Asia/Shanghai |
| 状态 | 已验收（功能；质量实验候选仍未达标） |
| 执行 | 独立Sol xhigh会话：映射核心、自动锁定、核心合同及长测；总指挥：UI集成、专项测试、复核、文档与Git |
| 审核 | 总指挥，2026-10-31 |
| 标签 | R1、R3、控制点语义、固定模型、保形、切向、固定35 |
| 基线分支／Git | feature/reference-comparison／9389d919d784687fad80e8062d7a58ea40ece3bc |
| 关联 | 005修复其余审查问题；本单提交由 `git log -- docs/changes/2026/2026-10-31-006-model-mapping-lock.md` 查询 |

## 动机与边界

用户指出全自动切模型直接复用坐标会改变路线，要求先固定选择的模型，并支持手动转换时保持路线。现在模型及独立Bezier阶数锁定；权重与适用训练参数可调。所有硬件、固定起点、目标顺序、验收阈值保持。B3/B5目前仍只支持内点法，全自动明确拒绝，不静默换模型。

手动模型／阶数／数量切换采样真实前轮曲线，优先精确空间转换，否则受约束拟合。控制点可增至250；独立偏移网格检查最大/RMS位置、全程切向、首末位置及全导数，失败不发布候选。显示实际数量与精确／容差内区别，详情见[映射说明](../../MODEL_MAPPING.md)。不存在任意有限维模型均可精确互换的承诺；显式拖点／删点仍是改形操作。

## 改动文件

| 文件 | 内容 |
|---|---|
| `+camdesign/mapRouteModel.m` | 同参数真实几何映射、约束最小二乘、精确空间嵌入、独立误差门禁、自适应数量 |
| `+camdesign/applyTrainingSettings.m`、`setControlPointCount.m` | 统一使用映射；返回实际点数及fitInfo，删除错误保形承诺 |
| `+camdesign/optimizeAuto.m` | 锁模型和阶数；配置映射失败记录并跳过；回调检查硬件和模型不变 |
| `CamReplicaApp.m` | 模型锁定说明、映射误差日志、实际控制点数、保形减点无法成立时保留数量 |
| `check_model_mapping.m`、`check_auto_model_lock.m`、`check_model_mapping_ui.m` | 新几何、锁定、错误回滚、UI及长测入口 |
| `check_training_controls.m`、`check_auto_tune.m`、`check_bspline.m`、`check_bspline_ui.m` | 更新旧坐标复用假设，覆盖实际点数、保存导入及原功能 |
| `scripts/archive_model_mapping_evidence.py`、`data/model_mapping_20261031.json` | 完成产物的只读汇总及源SHA256；不覆盖原实验 |
| `AGENTS.md` | 仅长期模型语义、锁定和验证规则 |
| `docs/MODEL_MAPPING.md`、`AUTO_TUNING.md`、`TRAINING_PARAMETERS.md`、`USAGE.md` | 使用方式、支持范围、误差边界 |
| `docs/INDEX.md`、`VALIDATION.md`、`SOFTWARE_REVIEW_20261031.md`、`LESSONS_LEARNED.md`、变更索引及本记录 | 证据入口、修复状态、经验、回退 |

## 验证命令与结果

均在独立MATLAB R2025b进程运行，入口 `./run_matlab_checks.ps1 -Task "<下列MATLAB命令>;"`。不关闭用户窗口。JSON证据及SHA256归档于[数值摘要](../../../data/model_mapping_20261031.json)。

| MATLAB命令 | 实际结果 | 本地证据（outputs/下） |
|---|---|---|
| `check_model_mapping` | 4组通过；独立32003点复核；比赛转换接受／拒绝均覆盖 | model_mapping_20261031/contracts/model_mapping.json |
| `check_auto_model_lock` | 3组通过，覆盖旧第4组切模型位置；短测试仅验证锁定 | model_mapping_20261031/contracts/auto_model_lock.json |
| `check_training_controls` | 11组通过 | model_mapping_20261031/training_core/training_verification.json |
| `check_auto_tune` | 9组通过 | model_mapping_20261031/legacy_auto_contracts/verification.json |
| `check_bspline` | 6组通过 | model_mapping_20261031/bspline_core/verification.json |
| `check_model_mapping_ui; check_bspline_ui` | 3+10组通过；UI实际回调、保存导入、错误保留 | review_fixes_20261031/mapping_ui、bspline_ui/verification.json |
| `check_review_ui_fixes; check_model_mapping_ui` | 最终UI改动后4+3组通过，退出0 | local/matlab_f71653db29614809b6cdeb0a0e85bead.log |

核心日志：训练11组及旧全自动9组 `local/matlab_1b5fecd8492049a2b32563390f5861b3.log`；映射4组及B样条6组 `local/matlab_80da82c73a71413c9a10dd3ed900be32.log`；最终映射4组、锁定3组及已有长测拒绝覆盖检查 `local/matlab_820f9756a0ed49bdb12b24f68487bec8.log`。全部退出0。

上一逻辑提交005的核心12/12、访问／导出4组、UI事务4组亦已通过，日志见005；本次共涉及66组不同检查（重复运行只计一次，额外拒绝覆盖断言不单独计组），不能把这些接口／解析检查算作66次工程调准。

UI新测试首次直接比较不同密度数组失败（`local/matlab_4a981c492e9443f49f525863ec4e301a.log`），修为相同参数网格；第二次读取私有字段失败（`local/matlab_c1d2fa6fcf0c4ae6a630d42446318ffb.log`），修为按公开表格标签定位。随后两UI入口全部通过，日志 `local/matlab_95f650066f384df8825e0964e012a2ab.log`。B5直线一轮内点法出现奇异KKT警告；该项只验接口和状态，不声称优化质量通过。

比赛34节点cubic→B3/B5分别36/102控制点，最大位置误差约4.6e-12 mm。转独立Bezier5达到250点时位置最大0.0114368 mm、RMS 0.00229581 mm，但切向0.11637°超0.05°，拒绝保留原方案。旧5→3阶太阳能Bezier同样拒绝；小平滑夹具允许有界转换，不误标为精确恒等。

## 充分预算与结果限制

输入：太阳能平推、固定35、34控制量，各主运行请求900轮（2组搜索和1组精修，每组300）。以下为8倍网格；几何门限未放宽。

| 运行命令 | 实际轮数／请求 | 停止原因 | 压力角° | 打卡最大mm | 回程° | 自交数 | 物理验收 |
|---|---:|---|---:|---:|---:|---:|---|
| `check_auto_model_lock('quality-cubic')` | 900/900 | 三组均iteration_limit | 37.1872 | 41.3074 | 58.0149 | 4 | 未通过，另有欠切和访问顺序问题 |
| `check_auto_model_lock('quality-bezier')` | 670/900 | 搜索300+300，精修70 constrained_infeasible | 37.8750 | 0.8424 | 47.2779 | 0 | 未通过压力角及回程 |
| `check_auto_model_lock('continue-cubic')` | 300/300 | iteration_limit | 37.1872 | 41.3074 | 58.0149 | 4 | 未通过，保留候选未改善 |

主运行评估次数109166/89164，续算20518。三者数值稳定性检查通过，但物理验收全部失败。两主初值的曲线不同，不能作为模型优劣成对排名。

主cubic精修末50轮仍改善：当前网格保留候选压力36.6952→36.6209°，打卡44.4971→41.3074 mm，因此追加300轮。新增预算末50轮保留候选不再改善。Bezier末50轮同样不再改善；停止由求解器给出，非手动中断。不据局部停顿断言无可行解。续算保留获选权重但移动正则参照改为续算输入节点，是新局部求解，非内部求解器状态精确恢复；原产物不追写此说明。`check_auto_model_lock('trends')`生成独立趋势摘要。

续算原始求解点的违规值末50轮2.66144→2.15572，仍差于保留候选0.895888；所以“保留候选未改善”不意味着求解器内部迭代完全停止，更不是收敛证明。续算日志 `local/matlab_fd1ae5d89fb24376aea015337a93cbdc.log`，最终趋势提取 `local/matlab_f10c11c4f4534206a5e9a389812c5c75.log`。

原始目录 `outputs/model_mapping_20261031/quality_cubic`、`quality_bezier`、`quality_cubic_continuation` 均有initial/checkpoint/result/summary；已有长测文件时入口拒绝覆盖。主日志分别 `local/matlab_f9ec3c904f524113ba7994fabc5a7758.log`、`local/matlab_327d59fc7a4e40e3820a3505f23e0354.log`。

本单不包含原版同输入凸轮逐点对照或实车验证；原版导出授权仍缺失。精确保形不等于改善压力角；密集网格误差门禁不是连续误差严格证明。B5精确升阶保留C²，不能继承此前均匀C⁴ B5实验结论。最终门禁未通过的结果仍不可宣称可加工。

## 关联经验、回退与交付

采用并补充EXP-029／EXP-030，保留旧失败证据。若需回退，用本单所属提交的 `git revert`，连同使用说明、索引及证据入口恢复；不删除原实验或用户项目。总指挥核对核心和UI差异、源摘要与长测趋势；文档链接及 `git diff --check` 检查后本地提交，不推送远端。当前问题修复验收完成，工程可行解搜索不冒充已经完成。
