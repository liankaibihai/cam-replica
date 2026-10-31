# CHG-2026-10-31-013 整车外廓与UID标签覆盖检查

## 基本信息

- ID：CHG-2026-10-31-013
- 日期/时区：2026-10-31 / Asia/Shanghai
- 状态：已验收（功能及采样几何；非实车验证）
- 执行：Sol独立执行器负责代码与针对性测试；总指挥负责规则映射、交叉审核、文档和Git。
- 审核：总指挥独立核对坐标变换、矩形与圆覆盖计算、采样门禁、状态恢复、导出和实际界面截图。
- 标签：外廓、压线、UID覆盖、假设尺寸、状态失效。
- 基线：feature/reference-comparison，2c0fe8ed043976187230f145ce4e6800613566c9。
- 本单所属提交通过git log查询，不预写自身哈希。

## 动机与边界

用户同意按规则核对结果改进凸轮软件。新增整车占地包络、独立覆盖区域和标签覆盖检查，图上定位，明确未知尺寸与采样局限；保留既有路线到凸轮计算及六项评分，不以几何检查冒充真实读卡或官方成绩。该诊断目前不进入优化器约束，也不会自动修改路线。

用户随后提供计算表并确认轮径135、轴距110、轮偏距60/-105、传感器(20,0)、c20、d150为本队平推设计；新建本队入口，旧回归夹具不改。传动比仍为35且仅用户手动修改。用户澄清12238 mm来自原版计算结果，用于凸轮工作段利用率；按表中135/35换算82.4439%、工作角296.7982°，保留参考来源，不用它替换本版主动轮积分或宣称已经同输入对照。

## 改动文件

| 文件 | 实际范围 |
|---|---|
| `+camdesign/contestGeometrySettings.m`、`contestBodyPolygon.m`、`contestGeometry.m`、`verifyContestGeometry.m` | 可选配置、车体航向刚体变换、四角边界余量、完整圆标签覆盖、重复/乱序事件、双网格与分辨率限制 |
| `+camdesign/validateProject.m`、`exportResult.m` | 校验可选参数；导出从当前项目重新计算并记录诊断，保留候选状态 |
| `CamReplicaApp.m` | 独立设置/结果页和常驻入口，失效提示、地图定位、备份恢复、反推模式隔离、窄窗列宽 |
| `+camdesign/teamSolarProject.m`、`launch_cam_app.m`、`data/team_solar_design_20261031.json` | 来源可追溯的本队设计入口；历史默认与用户已有项目不被覆盖 |
| `check_contest_geometry.m`、`check_contest_geometry_ui.m`、`check_contest_geometry_review.m`、`check_team_solar_project.m` | 解析反例、UI合同、独立旋转/边距离复核及来源配置测试 |
| `check_force_model_switch_ui.m` | 允许传入独立输出目录，避免覆盖历史证据；原断言保留 |
| `scripts/archive_contest_geometry_evidence.py`、`data/contest_geometry_20261031.json` | 保存紧凑测试摘要、已阅日志及本地原报告/截图SHA256，长数组仍留本地 |
| `AGENTS.md`、`README.md`、`docs/INDEX.md`、`docs/USAGE.md`、`docs/VALIDATION.md`、`docs/CONTEST_CONTEXT_2027.md`、`docs/CONTEST_GEOMETRY.md`、`docs/LESSONS_LEARNED.md`、本记录及变更索引 | 长期规则、使用入口、规则对应、实际结果、来源纠正与经验 |

## 验证命令与结果

均使用Windows MATLAB R2025b独立batch，命令模板为`powershell -ExecutionPolicy Bypass -File .\run_matlab_checks.ps1 -Task "下表Task"`；唯一临时配置及日志在`local/`，仅关闭各自测试窗口。

| Task或操作 | 实际结果 | 最终日志（均正常退出0） |
|---|---|---|
| `check_contest_geometry();` | 8组：直行/90°解析、触边与余量、半露UID、重复/额外/同时进入、缺省与非法值、路线独立于凸轮、导出重算、本队10次访问 | `local/matlab_f7bd6a93e09940149ac28d7c462c7a69.log` |
| `check_contest_geometry_ui();` | 6组：旧项目、假设/确认状态、失效与定位、路线独立检查/反推拒绝、含待应用输入的完整备份及旧备份、太阳能/窄窗/非法输入原子拒绝 | `local/matlab_efa89042042b4d75adae5d41a9cc37e0.log` |
| `check_contest_geometry_ui('locations');` | 3组显示复查；刷新外廓、标签及本队1320×860/1100×800截图 | `local/matlab_e011443d11584f8d975b64b4a41bb867.log` |
| `check_team_solar_project` | 5组；来源参数、旧夹具不变、10次访问、传感器起点坐标、保存重读及未实测标志 | `local/matlab_a919c270b3bb4302a8bb567a739495b9.log` |
| `check_contest_geometry_review; run_tests;` | 独立复核3组/100随机姿态，最大误差1.13687e-13 mm；原核心12/12项通过 | `local/matlab_e704cce9f0134b4ca47d190ac9a9d241.log` |
| `check_force_model_switch_ui(fullfile('outputs','contest_geometry_20261031','force_ui'));` | 原强制切换UI6组通过 | `local/matlab_4f7d5090946b4010a4fafac145e6fd59.log` |
| `check_auto_model_lock('contracts',fullfile('outputs','contest_geometry_20261031','auto_contracts'));` | 模型/阶数固定及不支持组合明确拒绝，共3组；仅短功能合同 | `local/matlab_e3333e6f766c4e81b957a13393501e11.log` |

普通启动单独运行以下操作，`TEAM_LAUNCH_MISSING_GEOMETRY_PASS`，日志`local/matlab_124a7739441d47388024890123e922aa.log`：

```matlab
a=launch_cam_app(); drawnow; a.openContestGeometry();
a.checkContestGeometry();
assert(~a.ContestGeometryReport.configured);
assert(a.Project.params.wheelDiameter==135 && a.Project.params.gearRatio==35);
exportapp(a.Figure,'outputs/contest_geometry_20261031/team/launch_missing_geometry.png');
delete(a.Figure); disp('TEAM_LAUNCH_MISSING_GEOMETRY_PASS');
```

额外以`camdesign.evaluate(camdesign.teamSolarProject(),true)`检查新参数种子可运行：前轮12811.56 mm、主动轮12448.18 mm、压力角80.2575°、回程58.1045°；仅初始状态，未满足物理门禁，未运行优化质量实验。日志`local/matlab_88adfe8f2f0d45adab8c747d5b498fb9.log`和本地`team/initial_evaluation.mat`保留；不能据此判断搜索算法优劣。

报告根目录`outputs/contest_geometry_20261031`；总指挥目视检查普通启动、外廓越界、标签覆盖不足、本队诊断及窄窗口截图。通过脚本归档报告、日志和SHA256；MAT/PNG原件继续忽略，不入Git。

## 证据及局限

采用2027评分规则车身投影压线和UID全覆盖条款；规则来源与阅读范围见[赛项理解](../../CONTEST_CONTEXT_2027.md)。外包络与内接覆盖区域分开；完整圆覆盖与恰好相切采用保守数值保护。粗细两档都通过且事件稳定、最大前轮步长≤5 mm、车体角步长≤0.5°、确有增加点数，才可称本输入下采样几何通过；最多20001点，非连续保证。

原表没有完整车身包络/不透光内接区域，故实际配置留空。测试中填写的矩形与UID直径仅验证程序；本队例明确未实测。起终点离开后重进检查不等于RFID、LED或语音触发。没有新增原版3.1.2同输入输出、实车滑移/读卡、发车引入段、停车段、能耗或完整官方评分证据。原始表未改动；设计值不等于制造实测。

## 关联经验与回退

EXP-034：机构门禁与比赛几何分别报告；审核修正同网格伪加密及界面显示。EXP-035：12238 mm的来源错误推断已按用户澄清纠正，不能以相同数值替代来源与轨迹口径核验。详见[经验文档](../../LESSONS_LEARNED.md)。

回退时先保存用户完整项目，通过`git log -- docs/changes/2026/2026-10-31-013-contest-geometry.md`找到本逻辑提交，再`git revert <实际提交哈希>`；不删用户MAT、原表或本地证据。回退后普通启动恢复历史测试参数；核对保存项目参数与12项核心检查。旧项目无新增配置时当前版本仍能打开并明确未配置。

## 审核与交付

2026-10-31代码、独立数值检查及实际截图审核通过，交付范围为独立采样诊断与本队设计配置。总指挥已核对新增实现没有改写路线/凸轮公式、优化器或既定门限；文档索引与经验同步。提交前运行`git diff --check`并核对仅暂存本逻辑文件；提交与远端状态由最终Git输出确认，不在记录内预写自身哈希。
