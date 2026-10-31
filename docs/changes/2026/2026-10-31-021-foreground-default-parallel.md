# CHG-2026-10-31-021 删除后台模式，前台同步与默认候选线程

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期/时区 | 2026-10-31 / Asia/Shanghai |
| 状态 | 已审核，验证通过 |
| 执行/审核 | Sol执行器负责代码、检查、文档；父侧完成独立审核与清理检查 |
| 基线 | 53b6018e2a5d6c6116a6c8a6f997fe7a38e18f85 |
| 标签 | 前台、默认4线程、停止、异常清理、迁移 |

## 动机与边界

用户明确不允许产品后台运行，要求删除此功能、候选多线程默认开启。数值入口同步，只有候选评估在线程执行并由主线程等待。保留原硬件、排序、预算和完整加密门禁。不跑比赛数据，不做比赛测速；父侧统一本地提交，不push。

父侧先确认原用户窗口已关闭、Busy=false、后台Running/Queued=0、无process pool，并保存Project/Result/History等到parent_live/before.mat/.json，随后才授权删除旧服务。执行器未操作或重开该窗口。

## 改动文件

- 删除6个cam_app_async服务、旧check_background_ui和旧进程协调check_candidate_parallel；历史Git/输出保留。
- dispatch/spec/binding_plan/launch：恢复同步具名入口、移除执行方式菜单清单，空闲迁移先备份后清理旧菜单/appdata。
- cam_candidate_pool/ui：主线程候选池，默认4线程，可选2/串行诊断；不创建或替换进程池。
- CamReplicaApp、optimizeFeasibilityFour、optimizeRelay：GUI预检在清历史前；默认4，支持阶段传递StopCheck；未支持后端按原方法同步并明确日志。
- PhysicalEvaluationBudget、CandidateFutureScope：每批drawnow、结算后停止；绑定handle方法做独立future退出清理，未知预留不虚报为Used。
- 旧三个UI检查去除已删除的foreground模式调用；本次不运行其数据测试。
- migrate_foreground_execution、check_foreground_parallel、check_foreground_cleanup：保全迁移、同步/默认/预算/停止和异常清理检查。
- 本单、FOREGROUND_COMPUTATION、CANDIDATE_PARALLEL、历史BACKGROUND页、USAGE、INDEX、AGENTS、经验、数据摘要与变更索引同步。

## 验证与实际结果

独立R2025b，全部手写3点输入，源码均在运行前复制并SHA256归档。

| 输出 | 日志 | 结果 |
|---|---|---|
| prototype_1 | local/matlab_a96de6bf5f2c478bba573ff620911b5d.log | 退出0；同步回调等待完成；真实重叠0.012秒；串并行/预算/停止通过 |
| check_1 / source_1 | local/matlab_8eb67411a5c940f89411722dac83646c.log | 8组通过、退出0：直接API默认4，预算4/11/100及接力60一致，批次StopCheck准确5次，真实同步按钮完成、旧菜单删除/完整迁移、Busy保护、预检保全、非支持后端正常工作、UI停止 |
| cleanup_2 / source_2 | local/matlab_4359ed4b851945508f54c462b108facc.log | 业务断言通过且退出0，但nested onCleanup引用变量被先销毁，出现真实清理警告；不能算清理验收通过 |
| cleanup_3 / source_3 | local/matlab_eb787f1bee1241b490bde03c680446ff.log | handle容器纠正后通过，无警告；4次结算，Reserved0，无关future正常，同步完成截图 |
| owned_future_4 / source_4 | local/matlab_1d7a35d0fe9d481284b6301dbb45bbd8.log | 退出0：受控异常触发绑定cleanup，实际running的自有future变为ExecutionCancelled，无关future返回42，无警告 |

父侧独立补充：`parent_scope/verification.json` 与本地helper `local/check_owned_future_021.m`，日志 `local/matlab_7818dd47fffb4badb9dfd49203cd2af6.log` 已输出 `OWNED_FUTURE_UNWIND_PASS`。自有future由running变为finished/ExecutionCancelled，无警告，无关任务返回42；无模型求值，不是字面Ctrl+C。父侧会话PASS后退出等待较久，WMI曾确认测试进程仍存在；随后进程自行结束，session34004最终返回exit_code=0，未执行任何人工终止命令。不将退出等待解释为实际模型正常停止失败。执行器自己的owned_future_4已由工具确认退出0。

父侧现场保全证据位于 `outputs/foreground_parallel_20261031/parent_live/before.json` / `before.mat`：figureOpen=false、appBusy=false、backgroundRunning=0、backgroundQueued=0、processPoolPresent=false。工程Project/Result/History等已保全；窗口是用户先关闭，执行器与父侧都未为此重开。

完整命令使用run_matlab_checks.ps1；入口分别为输出目录prototype_021、根目录check_foreground_parallel/check_foreground_cleanup、输出目录check_owned_future_021。未注入真实Ctrl+C、worker硬崩溃。cleanup_3截图已查看：顶栏仅候选线程菜单，无执行方式菜单；同步结果、评分、路线/凸轮完整。

## 证据、局限与回退

详情见[前台说明](../../FOREGROUND_COMPUTATION.md)。后台服务删除是用户要求，不把候选内部backgroundPool技术名称当产品后台模式。同步前台单次数值调用可能等待；每批drawnow处理停止。只测小合成，未声称比赛加速或质量改善。原019/020输出不改写。

代码冻结与已运行source_4一致，较完整八组之后只补退出清理与菜单中文；最终针对性检查覆盖这些改动。回退保留现有数据及迁移MAT，通过本单Git历史恢复源码，不能清空用户状态。

## 关联经验与交付

EXP-043；默认4、同步生命周期及单账本规则记入AGENTS。父侧已核对源码冻结哈希、差异、截图和独立异常清理证据；完成本地交付，不push。
