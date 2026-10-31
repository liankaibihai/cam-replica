# CHG-2026-10-31-016 旧窗口按钮回调恢复

## 基本信息

- 状态：已完成（按钮连接与状态保全；未进行比赛数据计算）。
- 日期/时区：2026-10-31 / Asia/Shanghai。
- 基线：`feature/reference-comparison`，`40fca017f5a9253530741a83d561ad28ac87b306`。
- 执行分工：既有Sol独立执行器负责代码与必要按钮检查；总指挥负责真实窗口状态保全、审核、文档和本地Git。
- 标签：MATLAB、匿名回调、热更新、旧窗口、未应用输入、状态保全。
- 用户限制：本次只修功能，不用比赛数据实测，不运行路线优化和质量对照；不推送GitHub。

## 动机与边界

用户日志反复出现 `CamReplicaApp.m 中找不到函数 @(~,~)app.applyTraining()` 和 `@(~,~)app.syncTrainingInputs()`，由按钮事件分发器报告。不能据此认定路线或凸轮算法失败。独立最小例子复现了源码变化后存活匿名句柄抛出同类 `MATLAB:dispatcher:UnableToResolveHiddenFunction` 错误，具名分派可调用。这与现场现象一致，但没有恢复旧窗口创建时的全部源码，不声称还原了完整历史触发过程。

本次保持项目、原结果、训练设置和未应用的表格输入，优先就地恢复回调，不通过清空工作区或强行关闭用户窗口修复。

## 改动文件

| 文件 | 内容 |
|---|---|
| `cam_app_ui_dispatch.m` | 外置具名分派，仅允许应用训练设置和还原两种动作；不执行旧匿名句柄 |
| `repair_cam_app_callbacks.m` | 先保存并回读核对快照，再就地重绑两个按钮；核对状态不变，失败恢复原绑定 |
| `CamReplicaApp.m` | 新窗两个按钮直接使用具名分派；增加显式项目/跳过初始化计算参数，原单参数默认行为保留 |
| `launch_cam_app.m` | 无参数启动遇到基础工作区已有存活实例时返回并提示，不覆盖或重新初始化其项目 |
| `check_ui_callback_recovery.m` | 合成输入的基本界面检查和临时回调源码变化探针；不加载比赛点库，不执行真实应用训练或优化 |
| `data/ui_callback_recovery_20261031.json` | 报错、备份和实际检查的轻量证据 |
| `AGENTS.md`、`docs/USAGE.md`、`docs/VALIDATION.md`、`docs/INDEX.md`、`docs/LESSONS_LEARNED.md`、本单及变更索引 | 规则、入口、经验与证据；使用说明同时纠正旧段落将本队设计入口误写成历史回归配置的描述 |

实现初稿尝试迁移更多白名单回调，最终按最小修复范围收缩为两个明确报错的按钮，不包括整套热更新或重开迁移。异步委派时应尽早固定范围，避免追加消息使执行器反复调整。

## 已观察事实与状态保全

- 用户原始报错：`C:/Users/22416/.codex/attachments/fbfc4e7f-f99a-4d90-8543-6d5f888e7e7e/已粘贴的文本.txt`，SHA256 `0e8a62dee584924704e5502a25d9319d4826496188bc6b26874fafda363adc67`。
- 电脑操作观察到MATLAB主窗口及“工创赛凸轮设计 · MATLAB 复现 v0.2”旧窗口；命令行保留相同错误，基础工作区有 `camReplicaApp` 对象。未点击计算、优化或应用设置按钮。
- 在确认非Busy、非仿真和非地图编辑模式后，直接执行 `camReplicaApp.snapshotModelSwitchState()` 成功，保存项目、既有结果、历史及未应用输入；这一步只是保存，没有执行路线计算。
- 原始备份：`local/tp8ebf1087_a052_4233_b43f_949497bf6f0e.mat`，变量 `camRecovery016Backup`，559050字节，SHA256 `2eb380515573418de02a2e57aad5b378c4ea1a9a2159349b59bb5a226e099fe7`。独立备份及恢复工具可另补字段，不能覆盖此原始备份。

## 验证命令与结果

独立R2025b批处理使用手写三点合成输入和 `CamReplicaApp('off',project,false)`，不读取比赛点库，也不执行初始计算。检查入口：

```matlab
check_ui_callback_recovery(fullfile(pwd,'outputs','ui_callback_recovery_20261031','basic_3'))
```

该目录已有证据，再次检查应换新目录。四组检查通过：新窗具名绑定、旧式绑定替换与完整快照回读/重复调用、重复启动保留原窗口、真实“还原”控件回调恢复训练显示且不改项目和其他待应用表格。profiler记录 `evaluate=0`、默认点库工厂调用 `0`、真实 `applyTraining=0`；没有执行应用训练业务、计算或优化。

源码生命周期探针仅用计数器对象：改写临时回调工厂源码后旧句柄出现相同错误，外置具名分派通过；另测保存句柄重新加载未出现错误，分别保留结果。

过程失败如实保留：

- 第一轮 `basic` 在重复修复的 `alreadyBound` 断言失败；不再比较整组函数句柄是否相等，改为核对分派名、对象身份和方法名。日志 `local/matlab_6b096038731c4a44a2521c61c8e88c3e.log`。
- `basic_2` 四组通过，但 `matlab.uitest.press` 因父标签未选中失败，使用真实控件的回调属性直接调用；日志 `local/matlab_2d2082f033db4041b5e41d01f91184b1.log`。
- `basic_3` 先选训练标签后，手势仍受隐藏窗口的 `VisibleHierarchy` 限制，继续以真实控件回调直接调用通过；日志 `local/matlab_f46b4a084f3349aa8372a37ac1b24af5.log`。不把这两次称为鼠标点击验收，没有继续加测。

父侧在用户仍打开的真实 `camReplicaApp` 上执行 `repair_cam_app_callbacks(camReplicaApp)`，工具另存备份并回读核对，报告 `stateUnchanged=true`、`calculationsPerformed=0`、`oldWindowRetained=true`、`alreadyBound=false`。报告在 `outputs/ui_callback_recovery_20261031/independent_live/verification.json`；实际备份路径与SHA256登记于[证据归档](../../../data/ui_callback_recovery_20261031.json)。修复后把原窗口显示到前台，没有点击“应用”或“还原”，没有重算屏幕上的旧结果。

## 证据及局限

按钮恢复属于交互可靠性修复，不新增算法精度、数值闭环、原版一致性或实车可用结论。只修这两个明确报错的按钮；其他匿名回调未全面迁移，不保证任意后续源码编辑都能热更新。实际“应用训练设置”的计算业务本次未运行，符合用户不做数据实测的要求。

## 关联经验与回退

关联EXP-015、EXP-030、EXP-037、[EXP-038](../../LESSONS_LEARNED.md#exp-038-磁盘源码更新不等于旧窗口回调更新)。按本文件Git历史查所属逻辑提交，必要时使用 `git revert`，保留用户备份和本地恢复证据。

## 审核与交付

已审核生产差异、合成检查报告及当前窗口修复报告；核心路线/凸轮/优化公式未改。文档索引、JSON及差异检查随本次提交归档；仅本地Git提交，不推送。
