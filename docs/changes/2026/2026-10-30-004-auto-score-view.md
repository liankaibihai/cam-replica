# CHG-2026-10-30-004 评分表默认跟随实际权重

## 基本信息

日期：2026-10-30 / Asia/Shanghai；状态：已验收（显示）。执行：Sol 独立对话；审核：总指挥。
基线：feature/reference-comparison / `6fd6db6bbb3185304409cffd857b726207bd4ae6`。
关键词：评分表、实际权重、来源、默认视图。

## 动机与边界

用户发现底部一直显示基础权重。原视图默认固定参照，并在暂无动态记录时强行重置选择；新增默认“自动显示实际”，有效匹配记录到达后跟随实际权重。手动选择固定或动态保留；没有记录时明确待记录，不伪造权重。固定参照趋势仍保持同一尺度。

## 改动文件

- `CamReplicaApp.m`：自动视图、状态标签和短表头。
- `+camdesign/resultDisplayData.m`：固定与动态实际权重的贡献统一计算。
- `check_auto_score_view_ui.m`、`check_dynamic_weights_ui.m`：回调、来源、旧记录、大窗和小窗验证。
- 本记录、`docs/changes/README.md`、`docs/DYNAMIC_WEIGHTS.md`：登记行为。

## 验证命令与结果

独立 MATLAB R2025b 执行 `check_auto_score_view_ui`，5项通过；证据 `outputs/auto_score_view_20261030/verification.json` 和1320×860、1120×760截图。回放已有真实搜索记录，基础压力权重3、实际8.87722044显示一致。覆盖手动选择不重置、来源不匹配拒绝、历史/加密标签、主表和详情一致；未启动质量优化。总指挥复查补丁及证据JSON。

## 证据及局限

只修复显示，不改变搜索和物理结果，不构成原版或实车精度证明。

## 关联经验

EXP-025：记录来源和显示阶段分别处理。无新增独立经验。

## 回退办法

用 `git log -- docs/changes/2026/2026-10-30-004-auto-score-view.md` 找到提交后针对性 revert；保留测试证据。

## 审核与交付

总指挥代码审核通过；Git提交前检查差异与空白。后续全自动功能另立变更。
