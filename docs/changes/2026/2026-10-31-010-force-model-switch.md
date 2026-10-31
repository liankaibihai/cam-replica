# CHG-2026-10-31-010 手动强制切换与独立路线重建

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期／时区 | 2026-10-31／Asia/Shanghai |
| 状态 | 已验收（功能／状态） |
| 执行／审核 | Sol xhigh独立执行器负责映射、UI及新合同；总指挥负责交叉审核、既有回归、文档与Git |
| 基线分支／Git | feature/reference-comparison／f06915235a977eca7939d79e370f91afb03b94eb |
| 标签 | 强制切换、改形、路线模型、重建、备份恢复、固定35 |

## 动机与边界

用户截图显示cubic转独立Bezier到250控制点，最大位置差0.0561598 mm、RMS 0.0140383 mm、全程切向差0.641045°，超过保形门限。原严格拒绝按设计执行，但未应用训练输入又阻止“重建路线”，缺少明确的改形出口。用户要求增加强制切换。

保留普通严格映射，并另设显式手动强制入口。强制仍从实际曲线拟合目标模型，不直接将异模型XY换名；如保形超限则真实标记，端点约束、有限几何和参数合法性不可绕过。强制前备份完整项目、原结果和待应用表格输入，提供恢复入口。重建直接从目标按当前所选模型和设置生成，不依赖旧路线保形验收。硬件、传动比和物理验收阈值不得自动更改，全自动仍锁定已应用模型。

## 改动文件

| 文件 | 实际改动与原因 |
|---|---|
| `+camdesign/mapRouteModel.m` | 默认严格；显式AllowApproximate允许有限且端点约束合格的超限拟合；记录forced、approximate和真实withinTolerance |
| `+camdesign/applyTrainingSettings.m` | 传递强制诊断，禁止auto-tune启用强制；通用接口不增删锁定的顶层展示元数据 |
| `+camdesign/rebuildRoute.m` | 从目标创建当前所选模型；保留起点／硬件，cubic保留新种子且增点时精确细化，独立于旧曲线保形门禁 |
| `CamReplicaApp.m` | 固定可见的强制／恢复按钮、完整会话备份、预校验恢复、待应用重建、合法新路线发布、旧结果失效、无凸轮绘图及坐标轴模式恢复 |
| `check_force_model_switch.m`、`check_force_model_switch_ui.m` | 核心和真实UI各6组新合同、保存导入和截图 |
| `check_model_mapping_ui.m`、`check_review_ui_fixes.m`、`check_bspline_ui.m`、`check_auto_model_lock.m` | 仅新增可选输出目录，既有断言不变，不覆盖历史证据 |
| `scripts/archive_force_model_switch_evidence.py`、`data/force_model_switch_20261031.json` | 汇总48项／组与38份来源SHA256，保留失败和最终通过日志入口 |
| `AGENTS.md`、`README.md`、`docs/MODEL_MAPPING.md`、`TRAINING_PARAMETERS.md`、`USAGE.md` | 长期手动例外、按钮语义、备份恢复与重建行为 |
| `docs/INDEX.md`、`VALIDATION.md`、`LESSONS_LEARNED.md`、本单和变更索引 | 维护入口、实际证据与EXP-033 |

## 验证命令与结果

新核心／UI合同与既有映射、状态、B样条、自动模型锁回归使用独立MATLAB R2025b实例及新输出目录，不覆盖历史证据，不关闭用户窗口。本轮是切换状态修复，不评价优化收敛或实车精度，无需重跑长轮次优化。

统一使用`./run_matlab_checks.ps1 -Task "<MATLAB命令>"`，输出目录`outputs/force_model_switch_20261031`。

| MATLAB命令／检查 | 实际结果 | 日志 |
|---|---|---|
| `check_force_model_switch;` | 6组通过，退出0；保存候选Bezier15在250点普通拒绝、手动强制通过，32003点独立网格和首末约束核对 | `local/matlab_609e872433814206b961a0c57fc76492.log` |
| `check_force_model_switch_ui;` | 最终6组通过，退出0；真实按钮、完整状态／残缺备份、物理失败后可编辑及四张截图 | `local/matlab_db871bfdb54c405ab427ecf3adfcc4fc.log` |
| `run_tests; check_model_mapping(fullfile(pwd,'outputs','force_model_switch_20261031','regression_mapping')); check_auto_model_lock('contracts',fullfile(pwd,'outputs','force_model_switch_20261031','regression_auto'));` | 基础12、严格映射4通过，后续auto锁失败；完整运行不计通过，见下方修正 | `local/matlab_f74a91e218db454a96c8a1b256f23217.log` |
| `try, check_review_ui_fixes(fullfile(pwd,'outputs','force_model_switch_20261031','regression_ui','state')); check_model_mapping_ui(fullfile(pwd,'outputs','force_model_switch_20261031','regression_ui','mapping')); check_bspline_ui(fullfile(pwd,'outputs','force_model_switch_20261031','regression_ui','bspline')); catch ex, disp(getReport(ex,'extended')); exit(1); end; exit(0);` | 状态UI4、严格映射UI3、B样条UI10通过，退出0；既有B5短功能夹具出现矩阵秩不足／近奇异警告，未修改求解门限 | `local/matlab_140d4f75e1bc4cb8b47a0eee17779a59.log` |
| `try, check_auto_model_lock('contracts',fullfile(pwd,'outputs','force_model_switch_20261031','regression_auto_confirmed')); catch ex, disp(getReport(ex,'extended')); exit(1); end; exit(0);` | 3组通过，退出0；cubic及Bezier四组配置保持模型、阶数、硬件，B样条不支持后端仍拒绝 | `local/matlab_2b8343ca01974beea109bae39d3d6858.log` |

实际功能证据：固定保存的太阳能cubic候选转Bezier15，最大位置差0.0437050842 mm、RMS 0.00509620135 mm、切向差0.0641930525°。最后一项超0.05°，普通入口拒绝；强制返回`withinTolerance=false`及`forced=true`，起点按位保持且首末导数约束通过。UI夹具故意加入未提交轮径131、权重13、目标及节点修改，确认它们仅按用户输入应用，传动比仍为35；完整恢复连同原项目、结果、历史和未提交表格一起还原。轮径1的合法输入使凸轮工作相位超整圈，强制仍保留新模型可保存和节点表编辑，旧凸轮、评分、自交和闭环记录清空；该例不称为可行设计。

失败和修正如实保留：

- 新核心第一次把原太阳能种子误当成必然拒绝的Bezier15样例，实际能严格通过，故测试失败；改用已有训练候选。日志`local/matlab_527a6d4258224c55a4179f9a768119e1.log`。
- 第二次减为10个新种子后沿用原插值密度，触发原101点下限；夹具显式设插值12后通过，未放宽门限。日志`local/matlab_2b5a28483ad34747b05de85a053ede87.log`。
- 首轮总指挥回归发现通用训练函数新增顶层映射记录触发`cam:AutoTunePhysicalMutation`。将手动展示记录保存移到UI，保留原物理签名比较；修后自动锁3组通过。
- UI首次6组通过日志`local/matlab_e4166ae87eb5481b8ff7fa3a7f97bd19.log`；截图又发现恢复坐标范围会遗失自动缩放模式，已保存／恢复模式、发布新路线时重置自动范围，并补充断言后最终6组复测通过。总指挥复看最终窄窗口转角X轴为0～500 mm。
- 受限运行中的失败批处理及之后自动合同在输出PASS后未退出，分别核对唯一日志／父PID后只停止专用进程40548／53160，包装退出1；后者日志`local/matlab_af6e463106974121abf964fa128ff3d4.log`记录3组已完成断言，但不冒充正常退出。受限UI启动无结果后同样只清理专用49800，空日志`local/matlab_bfb0be461b1c48b4893525880b98db0a.log`不计验证。使用正常主机访问、仍隔离偏好目录，最终UI和自动合同均正常退出0。未证明停滞的更底层原因。

## 证据及局限

用户截图是触发证据；尚没有其当前完整MAT项目，测试使用`outputs/model_mapping_20261031/quality_cubic/result.mat`里的完整q复现同类严格拒绝，来源哈希入库。强制意味着允许路线改变，成功切换不表示凸轮可加工或比赛规则已通过。

训练页固定底部按钮和备份路径、普通严格拒绝、全自动锁定、无结果绘图已检查。四张截图位于`outputs/force_model_switch_20261031/ui`。项目与待应用输入备份位于`local/model_switch_backups`，按钮恢复最近一次，`app.restoreModelSwitch(filename)`可显式恢复既有文件；该会话备份不是普通项目MAT。测试只关闭自己创建的隐藏窗口。旧窗口不热更新，用户应先保存再打开新版。

入库[数值和状态摘要](../../../data/force_model_switch_20261031.json)含48项／组合同及38份代码、日志、截图和来源哈希；`python scripts/archive_force_model_switch_evidence.py`可复建汇总。大型MAT、个人自动备份和运行输出不进入Git。函数测试依赖已有保存候选，缺少该MAT时不可宣称复跑成功。

## 关联经验

EXP-029的模型几何语义、EXP-030的完整状态恢复；新增[EXP-033](../../LESSONS_LEARNED.md#exp-033-保形门禁不能封死显式改形出口)，记录保形门禁与显式改形出口、完整恢复及派生元数据误触发自动锁的教训。

## 回退办法

对本逻辑提交执行`git revert`，同时恢复使用说明及索引。保留用户项目、自动备份及本轮实验输出。

## 审核与交付

总指挥已审核核心拟合门禁、重建语义、UI状态来源及恢复顺序；检查新核心/UI结果、旧路径回归、最终截图及失败修正。数值和行为无进一步变化后检查来源哈希、文档链接、补丁并本地Git提交，不推送。所属提交通过`git log -- <本记录路径>`查询。
