# CHG-2026-10-31-015 接力精修与多起点搜索

## 基本信息

- 状态：已验收（功能与本版数值；不等于实车验证）。
- 日期/时区：2026-10-31 / Asia/Shanghai。
- 基线：`feature/reference-comparison`，`58f73fd15a1173b1552706e00f7695900df8edd1`。
- 执行：既有 Sol 独立执行器负责生产代码、界面、针对性测试和主实验；总指挥负责协议、审查、独立验收、文档及本地 Git。
- 标签：接力、SQP、多起点、物理评价预算、太阳能、平推、固定35。
- 交付：仅作本地 Git 记录；用户明确要求本次不推送 GitHub。

## 动机与边界

用户希望在现有四方向基础上，用接力精修和多起点搜索继续缩短路线、减小打卡偏差，并保持合理整圈压力角。三者使用本队太阳能平推项目，保持路线模型、阶数、硬件、目标顺序、起点与验收阈值。接力改变搜索方法，不转换控制点语义。

本次从已通过检查的 CHG-014 最终候选继续优化。原版 3.1.2 的导出授权仍不可用，本次三臂对照均是本版实现，不能称为原版同输入输出比较。未知的整车外廓和 UID 覆盖不因机构数值通过而自动通过。

## 预先固定的比较协议

详见[接力与多起点说明](../../RELAY_MULTISTART.md)。主实验目录独占归执行器 `outputs/relay_multistart_20261031`，父侧审核另写 `independent_review`；不重复启动同一路径、不覆盖已完成结果。

1. 共同起点为 `outputs/feasibility_four_20261031/feasibility/continuation_v3_1/candidate_project.mat` 中的最终 `project`，不是实验 MAT 中的旧初值。
2. 34 控制点、独立融合贝塞尔5阶、601路线点/721凸轮点、固定比35；三臂统一机构和评分口径。
3. 三臂为当前可行性四方向继续、四方向接力 SQP、多起点接力。每臂请求200000次实际模型评价预算，含搜索中的完整接受检查；缓存命中不算新评价，独立加密验收另列。
4. 允许合理提前收敛，不以空耗计算凑齐；记录每阶段和起点实际调用、轮数、终止原因、耗时及尾段趋势。长实验保存中间项目与来源快照。
5. 统一在原网格、4倍、8倍验收。保留原始已验证方案；最终候选失败不得冒充合格结果。分别比较前轮/主动轮长度、最大/RMS偏差、整圈/工作/回程压力、回程余量、欠切、顺序、自交及中心场界。
6. 对终值做冻结实际 XY 轮廓的独立接触反推；更低训练评分、更多迭代或更长计算时间均不能代替数值与物理指标。

## 改动文件

| 文件 | 内容 |
|---|---|
| `+camdesign/PhysicalEvaluationBudget.m`、`optimizeFeasibilityFour.m` | 严格共享实际模型预算，失败/完整检查计数，中途停止保留候选，默认四方向行为兼容 |
| `+camdesign/optimizeRelay.m`、`optimizeQualitySqp.m`、`relayPerturbation.m` | 四方向/SQP接力、平滑固定种子多起点、完整门禁接受和加密失败退回初值 |
| `+camdesign/fminconModel.m`、`optimize.m` | 显式共用质量目标及新增分派；原约束后端默认目标保持 |
| `+camdesign/projectJSON.m`、`data/relay_multistart_initial_20261031.json` | 完整输入数值形状元数据、逐值回读及可追踪共同初值 |
| `CamReplicaApp.m` | 两个入口、阶段/起点/调用量与终止原因显示、缓存结果复用和安全方向绘制 |
| `check_relay_multistart.m`、`check_relay_multistart_ui.m`、`check_relay_multistart_quality.m`、`check_relay_sqp_supplemental.m` | 正确性、真实界面、冻结来源/独占锁、每阶段保存、三臂长对照与独立细差分诊断 |
| `check_relay_actual_review.m` | 父侧独立锁定输入、8倍复算、实际轮廓闭环及标准项目保存 |
| `scripts/archive_relay_search_evidence.py`、`data/relay_multistart_20261031.json` | 轻量证据、完整日志及本地大文件哈希 |
| `AGENTS.md`、`docs/RELAY_MULTISTART.md`、`USAGE.md`、`TRAINING_PARAMETERS.md`、`DYNAMIC_WEIGHTS.md`、`FEASIBILITY_SEARCH.md`、`VALIDATION.md` | 长期比较规范、使用及证据边界 |
| `docs/INDEX.md`、`LESSONS_LEARNED.md`、本单和变更索引 | 可搜索索引、真实错误与修正 |

## 验证命令与结果

MATLAB R2025b，独立 batch。下列表达式通过 `./run_matlab_checks.ps1 -Task "<表达式>"` 运行；质量入口冻结后核对82个源码文件哈希，冻结时间2026-10-31 17:26:29 +08:00。

| 检查 | 表达式/协议 | 结果及日志 |
|---|---|---|
| 核心预算/目标/停止 | `check_relay_multistart()` | 9组通过；`local/matlab_dddba8a5fd814ff1b91fef8a5a0af376.log` |
| 真实UI | `check_relay_multistart_ui()` | 3组通过，321搜索＋8验收＝329 profiler调用；`local/matlab_1d4305e0af2d44b5be4fe2325adfa29e.log` |
| 既有约束及核心回归 | 独立输出目录运行原约束合同、`run_tests()`及`check_feasibility_four()` | 原约束7组、基础12/12、四方向8组通过；`local/matlab_1d091351c2be405dbc53d375ab649dd1.log`。合同调用没有重新运行旧质量对比 |
| 完整流程冒烟 | `check_relay_multistart_quality('smoke-prepare')`及`smoke-run`三臂 | 700次/2轮上限，仅流程检查；三臂完成、加密均过。`local/matlab_e3c3417b0f2d4c5a9d673dbdc15808c3.log`；不用于算法质量结论 |
| 正式共同初值 | `check_relay_multistart_quality('prepare')` | 原候选完整参数保留，JSON逐值回读通过；夹具SHA256 `467dc593b4ac9e31eb18e7e722f527e095f019bc0bbec3a249956cac69064286` |
| 首次正式三臂 | `check_relay_multistart_quality('run','four')` / `'relay'` / `'multistart'` | 完成，真实调用200000/50225/97985；三个8倍及收敛均通过，无回退。分别日志`matlab_3e012b6968fc4da9a542c0f14ce6c3ef.log`、`matlab_982bd01a15eb4670ba9064f14fe06738.log`、`matlab_188ad863c1594275b3f369b1f6dae8a6.log` |
| 父侧复核语法 | `assert(isempty(checkcode('check_relay_actual_review.m','-id')))` | 通过，`local/matlab_d4ede0bf59d0486b99c97537814027ed.log` |
| 物理/质量核心源码 | 与基线比较7个正反算/质量文件 | 无修改，`outputs/relay_multistart_20261031/source_review.json` |

失败也保留：分派命名参数顺序语法错误（`matlab_b4c3dce753004bcf9b93730b4ef61ff2.log`）、接力UI缺方向字段（`matlab_e1e7654ba5d442be90a7821701f2ff02.log`）均已修正；初次冒烟准备的空结构体清单赋值失败（`matlab_eac02eafd2c642df8732b54409136cd8.log`），改为声明字段后完成流程。父侧语法检查首次因多余的`NASGU`抑制注释触发MSNU提示而失败（`matlab_fa434910511b4651861153b83c4621dd.log`），删除多余注释后通过，不是数值问题。

父侧用 `check_relay_actual_review(label,candidateFile,referenceFile)` 对三臂标准候选独立复算4801/5761网格、冻结实际轮廓并做1201/2401积分。完整非nodes字段、固定起点/数量、固定35及相位-行程恒等式均通过；加密项目保存后标准导入逐值一致。

| 初版臂 | 实际轮廓最大传感器闭合差/mm | 积分加密差/mm | 实际接触压力/° | 反推打卡偏差/mm | 日志 |
|---|---:|---:|---:|---:|---|
| four | 0.030041927 | 0.000040290 | 34.186096 | 0.891335 | `matlab_3d28e24a571e43569d133ffa08e7ce49.log` |
| relay | 0.083738473 | 0.000045517 | 34.290130 | 0.927839 | `matlab_69467d46bcb54c57a6a6132bbe0a04b9.log` |
| multistart | 0.014818336 | 0.000014656 | 27.628441 | 0.971696 | `matlab_be43afb2a93947b09ab3b191127954cf.log` |

初版0.05 mm差分的单起点SQP仅2轮便步长停止，一阶最优性约0.476。按用户要求未据此否定算法，另从同一50000调用前缀启动两个各150000新调用/10000轮诊断：`check_relay_sqp_supplemental('run',0.005)`和`0.0005`，分别68轮/5067调用、131轮/9679调用，8倍均过。日志`matlab_5b224b0c429e4f40a0143d1e28d1259d.log`和`matlab_cbf135f7a712468bbdbaa56d04a250be.log`；两组独立诊断不累加冒充原始接力。结果详表见[专题说明](../../RELAY_MULTISTART.md)。

据该证据将两个新后端默认差分改为0.0005 mm，原fmincon入口不改；并补齐SQP末条用户停止标志。修订核心9组/UI3组通过（日志`matlab_0f6c8139772f4a759c03b3ecfedf3d64.log`、`matlab_036e247a4fa648dbb708435ecbffa2e2.log`）。源于2026-10-31 17:50:42 +08:00再次冻结，`revised/common_protocol.json`保留相同完整输入及四方向结果/候选/协议哈希，核对76个未变包依赖；不重复运行未受影响的200000调用四方向基线。`revised-run`两臂完成，加密和独立闭环均通过。

证据偏差：默认差分修订后的首轮合同复测写入原默认contracts/UI目录，旧JSON和截图被覆盖且无真实备份。新输出分离至`revised/pre_output_option`，原始通过日志和总指挥读取事实保留，主三臂和补充诊断均未受影响。没有重跑旧源冒充原件；随后合同入口增加可选输出目录和已存在验证文件拒绝覆盖，见EXP-036/037。新核心/UI证据另存`revised/contracts`、`revised/ui`。

### 最终修订结果

两臂分别运行 `check_relay_multistart_quality('revised-run','relay')` / `'multistart'`。接力实际437轮/59679调用（SQP131轮），5起点实际1446轮/145799调用（SQP258/170/122/183/264轮）；均完成全部起点，SQP各阶段为步长停止，不是时间截断。日志为`matlab_a81585e5d9494d2ab951bb6d4f64c18c.log`、`matlab_b25ea521175d481b829dafd2cc7479f6.log`。单接力复现0.0005诊断终值。

| 最终臂 | 前轮/mm | 最大偏差/mm | RMS偏差/mm | 压力/° | 欠切指标余量 | 8倍/稳定性 |
|---|---:|---:|---:|---:|---:|---|
| 当前四方向 | 12680.777278 | 0.885451 | 0.785822 | 34.156861 | 0.447122 | 通过 |
| 接力精修 | 12691.155278 | 0.973836 | 0.790134 | 25.536804 | 0.446765 | 通过 |
| 5起点接力 | 12682.193750 | 1.040466 | 0.866197 | 24.742646 | 0.060179 | 通过 |

无候选加密回退，三者无自交、完整顺序和当前中心场界通过。多起点比四方向压力低9.414214°，但长1.416472 mm、最大偏差大0.155015 mm、欠切余量更小，属于取舍，不能称更短且更准。首次三臂＋独立诊断＋修订两臂共568434次真实搜索评价，不重复计前缀和四方向基线。完整行程、回程、终止趋势和限制见[专题说明](../../RELAY_MULTISTART.md#最终交付版本的对照)。

父侧独立复核修订候选的完整参数锁、标准加密项目回读、相位-行程关系、8倍门禁及实际轮廓闭环均通过。固定5761顶点，1201/2401积分：

| 修订臂 | 最大闭合差/mm | 积分差/mm | 实际接触压力/° | 反推打卡偏差/mm | 日志 |
|---|---:|---:|---:|---:|---|
| relay_revised | 0.016935270 | 0.000048273 | 25.560796 | 0.977039 | `matlab_72a75cd5741046ac9ae3306fb824459d.log` |
| multistart_revised | 0.023032180 | 0.000045870 | 24.765168 | 1.050899 | `matlab_0e20b90a4ee24df99c852f6cecdce1b3.log` |

完整报告和本地大文件哈希收录于[轻量归档](../../../data/relay_multistart_20261031.json)，标准训练及细网格候选路径见专题说明。代码冻结后总指挥再次核对全部82个源文件一致，核心正反算和质量7文件仍与基线一致；没有修改算法核心来配合这组结果。

## 证据及局限

本次只验证当前模型和当前比赛路线；多起点有限预算不能证明全局最优。不同指标存在取舍时分别报告，不将综合分更低写成所有指标更好。实际轮廓闭环仍不包含加工误差、间隙、滑移和真实 RFID。

## 关联经验与回退

EXP-008、EXP-019、EXP-024、EXP-026、EXP-029、EXP-031、EXP-032、EXP-036、EXP-037。若新增方法不稳定，仍可选择现有可行性四方向并导入保留候选。提交后用 `git log -- docs/changes/2026/2026-10-31-015-relay-multistart.md` 查所属提交，针对该逻辑提交 `git revert`；保留实验输出及用户原始项目。

## 审核与交付

总指挥完成代码与结果交叉核验、最终候选独立实际轮廓反推及文档索引审核；修订UI完成态截图另经视觉检查。归档包含99份JSON报告、639份本地文件哈希和29份完整日志，包含执行器交付审计及父侧复核；文件哈希、文档链接和`git diff --check`检查通过。按本单作一次本地逻辑提交；本次不推送GitHub。具体提交由本文件Git历史定位，不在提交内预填自身哈希。
