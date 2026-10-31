# CHG-2026-10-31-017 全界面持久回调检查与修复

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期 / 时区 | 2026-10-31 / Asia/Shanghai |
| 状态 | 已验收（回调与状态保全；无比赛数据计算） |
| 执行人 / 角色 | 既有Sol独立执行器：代码与合成回调检查；总指挥：独立审核、当前窗口保全、文档与Git |
| 审核人 / 角色 | 总指挥：源码差异、冻结哈希、旧窗口修复前后独立验收 |
| 基线分支 | `feature/reference-comparison` |
| 基线 Git | `b422cf79d656bd7704443defc5a751ee28917659` |
| 标签 | 按钮、匿名回调、持久UI、事件参数、窗口恢复 |

## 动机与边界

用户在两训练按钮修复后，要求检查其他按钮并一并处理同类回调错误。初步静态扫描发现主操作按钮、地图/键盘、表格编辑、训练字段、交点视图等仍使用绑定在类源码位置的匿名函数。它们具有相同生命周期风险，不把“存在风险”冒充每个按钮均已现场报错。

本次仅调整持久UI回调的连接、分派和空闲旧窗口恢复；保持方法参数、事件和来源对象语义。不改路线/凸轮/优化公式，不跑比赛数据、优化实测或计算业务。完整保存用户窗口输入、结果与历史；不关闭旧窗口。只本地Git，不推送。

## 改动文件

| 文件 | 实际改动及原因 |
|---|---|
| `CamReplicaApp.m` | 主窗口及动态交点视图等持久UI绑定改用具名分派，固定参数显式保存 |
| `cam_app_ui_spec.m`、`cam_app_ui_callback.m`、`cam_app_ui_dispatch.m` | 本App限定动作表、标准cell回调创建、来源/事件/固定参数转交 |
| `cam_app_ui_binding_plan.m`、`cam_app_ui_callback_matches.m`、`cam_app_ui_legacy_compatible.m` | 本App所属窗口的绑定清单；识别旧签名及闭包所属对象；遗漏/未知连接拒绝 |
| `cam_app_apply_ui_bindings.m`、`cam_app_ui_value_snapshot.m`、`repair_cam_app_callbacks.m` | 批量替换与回滚、公开UI值及完整模型快照保全，支持DryRun |
| `cam_invoke_ui_callback.m` 与20个旧检查/脚本 | 41处调用改为兼容函数句柄与cell格式；逐文件逆转换后与基线完全一致；清单见证据JSON的compatibilityFiles |
| `check_ui_all_callbacks.m` | 手写三点界面夹具、分派spy、真实工具栏、状态保全及拒绝/回滚检查；不加载比赛数据 |
| `data/ui_all_callbacks_20261031.json`、文档、索引、AGENTS及经验 | 轻量证据、使用范围、长期回调约定、实际教训与本单 |

## 验证命令与结果

独立MATLAB R2025b batch入口分别执行 `check_ui_all_callbacks(fullfile(pwd,'outputs','ui_all_callbacks_20261031','check_1'))` 与修正后的 `check_ui_all_callbacks(fullfile(pwd,'outputs','ui_all_callbacks_20261031','check_2'))`。目录独立且拒绝覆盖。仅使用手写合成输入、不计算的界面、分派计数器与状态快照；计算/导入/导出等按钮只检查事件分派，不执行业务。

父侧修复前已完成：

- 当前旧窗口只读盘点共106个非空回调：本软件65个匿名回调、016已改的2个具名分派、MATLAB图形工具的39个回调。盘点仅在本软件拥有的Figure及DiagnosticsFigure内查找，没有扫描其他App。
- 当前窗口快照保存在 `outputs/ui_all_callbacks_20261031/parent_independent/before.mat`，SHA256 `211d4ee51d7ec67324cfa75e88a2560f5a3890bc22230d1e6c06e741d6f20ecf`；只读盘点前后快照一致。
- 仅调用不计算的 `Figure.SizeChangedFcn`，现场复现 `MATLAB:dispatcher:UnableToResolveHiddenFunction`，消息为找不到 `@(~,~)app.resizeLayout()`，快照仍一致。证据 `parent_independent/before_layout.json`。其他业务按钮没有依次执行，不能把这一次复现写成每个按钮都报过错。
- 发现旧检查脚本多处按单函数句柄调用回调；迁移为cell回调时须同时兼容这些调用入口，本轮只做调用形式修订与无计算验证，不运行它们原有的数据测试。

首轮合成检查通过8组，67个主窗/72个含详情窗连接、124次分派，所有被监测的计算调用均为0（`local/matlab_7e4767e7c2b74208a1e4979759a1c474.log`）。随后真实旧窗首次DryRun在补充快照处失败：`ToolbarPushButton` 的Position属性存在但非公开。失败发生在任何回调修改前，不能把该首轮通过直接当作旧窗验收。已改用公开属性清单，并在最终检查中加入真实工具栏/图例对象。另一次尚未提交的长命令包含被JS展开的换行，父侧用Esc清除后改用短命令，未执行该错误命令。

最终检查日志 `local/matlab_f71783c0467342a1a1dd3c7aa9a7d8b5.log`：8组全部通过，67个主窗/72个含详情窗连接、124次spy分派；合成窗口42处MATLAB框架回调原样保留。8组覆盖：

1. 所有主窗连接均为具名cell；真实工具栏及图例的公开属性快照成功。
2. 所有动作及实际控件槽位转交正确；检查8个循环主按钮、布尔/字符串固定参数、事件、Value和事件源CurrentPoint；句柄与cell调用均可用。
3. 动态详情视图及无Tag旧详情控件正确识别，默认关闭保持MATLAB原行为。
4. 合成控件上的安全视图切换、表格选中、Esc、布局、训练标记与输入还原调用正常。
5. 旧空槽重绑、完整项目/结果/历史/待应用值备份往返、重复修复和忙碌模式保护正常。
6. 已知槽位的异物回调、主窗异常closereq、未知移动/控件/图元回调均整批拒绝。
7. 第二项控件赋值失败时，第一项已替换回调回滚。
8. 详情控件歧义拒绝、不影响另一个App、已知动态移动回调可识别。

profiler记录 `evaluate`、三个项目工厂、`optimize`、`applyTraining`、`calculate`、`runOptimization`、`rebuildCurrentRoute`、`restoreModelSwitch` 调用均为0。旧20个检查/脚本只做41处调用格式兼容，没有运行它们的原有数据测试。`+camdesign`与基线无差异；32个执行器交付源码文件与冻结哈希逐一一致。

父侧在原有可见窗口独立验收：

```matlab
camAudit017Dry = repair_cam_app_callbacks(camReplicaApp, DryRun=true, ...
    OutputFolder=fullfile(pwd,'outputs','ui_all_callbacks_20261031','parent_independent','dryrun_2'));
camAudit017Repair = repair_cam_app_callbacks(camReplicaApp, ...
    OutputFolder=fullfile(pwd,'outputs','ui_all_callbacks_20261031','parent_independent','repaired'));
camAudit017Verified = verify_ui_callbacks_017(camReplicaApp);
```

最后一个是父侧 `local/` 中的独立审核脚本，不是产品入口；源码和哈希归档于证据JSON。DryRun识别67处、需替换65处、未知0；正式修复成功，仅重绑这65处。独立前后盘点仍为106处：本App匿名0、具名67、MATLAB框架39，39处原样不变。与修复前独立快照相比，原项目、已有结果、历史和未应用输入完全一致，原窗口保留；布局回调由同类错误变为正常，布局调用前后模型状态也一致。现场只执行这一无计算布局回调，没有逐个执行业务按钮或重算窗口里已有的比赛结果。

## 证据及局限

轻量报告、两份完整日志、源码冻结哈希、父侧审核脚本与本地工件哈希见[证据归档](../../../data/ui_all_callbacks_20261031.json)。完整输出在忽略目录 `outputs/ui_all_callbacks_20261031/`，真实状态MAT仅本地保存不入库；没有改写016历史证据。合成场景的42处框架回调与现场39处来自不同窗口，不能混作同一计数。

本轮不能支持算法质量或实车精度结论。计算/导入/导出按钮通过spy验证连接和参数，没有执行真实业务；不能称所有按钮鼠标操作和业务端到端均已验收。旧窗口修复与任意类结构热更新不同，后续变更仍需检查兼容性。

## 关联经验

采用并补充[EXP-038](../../LESSONS_LEARNED.md#exp-038-磁盘源码更新不等于旧窗口回调更新)；新增[EXP-039](../../LESSONS_LEARNED.md#exp-039-属性存在不等于公开可读)。异步执行与证据目录遵守EXP-036。

初稿审核发现：地图回调应继续读取事件源的CurrentPoint，不能无必要换成另一个轴对象；任意非空WindowButtonMotionFcn不一定属于地图编辑；未证实的历史图元回调不能只凭Tag假定行为；详情窗原MATLAB默认关闭无匿名源码问题，保持默认即可。上述均为提交前审核发现，未把初稿用于用户窗口。

## 回退办法

按本单Git历史找到对应提交后 `git revert`，保留本地备份、运行证据与历史记录；回退源码后须重新核对现存窗口绑定，不清空用户工作区。

## 审核与交付

已完成源码及独立现场审核。具名分派、旧连接拒绝规则、状态保全和文档一致性通过；原窗口已恢复。只本地提交，不推送GitHub。本单所属提交通过 `git log -- docs/changes/2026/2026-10-31-017-all-ui-callbacks.md` 查询。
