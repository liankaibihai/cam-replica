# CHG-2026-10-31-019 后台计算与界面响应

## 基本信息

| 字段 | 内容 |
|---|---|
| ID | `CHG-2026-10-31-019` |
| 日期 / 时区 | `2026-10-31` / Asia/Shanghai |
| 标题 | 将重计算移出界面线程，保留搜索与验收语义 |
| 状态 | 已验收（合成功能与现场安装；无比赛测速） |
| 执行人 / 角色 | Sol独立执行器：源码与合成功能检查；总指挥：范围、审查、文档及本地Git |
| 审核人 / 角色 | 总指挥，源码/独立证据/现场状态复核 |
| 标签 / 搜索关键词 | backgroundPool、parfeval、线程、进程、SQP、停止、旧结果、进度绘图 |
| 基线分支 | `feature/reference-comparison` |
| 基线 Git | `02489ec4d0b7f2951da6686bc340d22c16c2ae59` |
| 关联提交 | CHG-017具名回调、CHG-018训练反馈；本单所属提交以git log查询 |

## 动机与边界

用户报告功能增多后卡顿，要求增加多线程能力。基线优化在UI调用链中运行，`optimizationUpdate`在缺少缓存结果时重新`evaluate`，每次回调完整绘图。将计算与UI解耦，不降低采样、不跳验收、不更改模型/机械参数/评分/预算，也不以后台运行冒充所有搜索候选并行。

沿用用户本轮约束，只运行手写合成的功能、并发、状态和一致性检查；不跑比赛路线或长优化效果测试，不推GitHub。现场观察到用户自己正在运行接力精修，未停止、关闭或清空其会话；现场升级必须等其空闲并保全状态。

## 改动文件

| 文件 | 实际改动及原因 |
|---|---|
| `cam_app_async.m` | 类外任务状态、提交/预览/停止/发布/回退及执行方式菜单；完成outcome先保存再发布 |
| `cam_app_async_pool.m` | 按真实算法预选线程/进程；不重复运行、不删除用户已有池 |
| `cam_app_async_worker.m` | 后台纯数据数值入口、停止消息与进度节流，保持搜索串行决策 |
| `cam_app_async_receive.m`、`cam_app_async_complete.m`、`cam_app_async_registry.m` | 具名客户端消息/完成处理与任务归属 |
| `cam_app_ui_dispatch.m`、`cam_app_ui_spec.m`、`cam_app_ui_binding_plan.m` | 既有按钮转入异步服务，新增菜单列入具名回调与身份盘点 |
| `CamReplicaApp.m` | 提取原优化结束显示与闭环显示方法，供同步/后台共用；没有新增class属性 |
| `launch_cam_app.m` | 新窗/空闲复用安装菜单，保留活动中的旧任务 |
| `check_background_ui.m` | 独立手写合成输入，验证后台按钮、预览、停止/回退和短后端兼容性 |
| `check_actual_cam_ui.m`、`check_auto_tune_app.m`、`check_bspline_ui.m` | 旧同步按钮检查显式选择前台兼容；本轮仅静态适配，未运行其数据测试 |
| `AGENTS.md`、`docs/BACKGROUND_COMPUTATION.md`、`docs/LESSONS_LEARNED.md` | 长期并发边界、使用与实现说明、EXP-041经验 |
| 本记录、`docs/INDEX.md`、`docs/changes/README.md`、`docs/USAGE.md`、`docs/VALIDATION.md` | 本次改动、用法、验证与检索入口 |
| `data/background_computation_20261031.json` | 最终报告、源码指纹、失败与现场记录、本地证据SHA-256 |

`+camdesign`中的原数值核心不改。后台处理计算凸轮、迭代优化、实际轮廓闭环三个按钮；一个任务持有全部搜索状态，候选仍串行，不是多候选同时搜索。节流预览最多每1.5秒一包，须收到上一包显示确认；最终完整历史另行返回。自动最终加密交叉展示也在worker预备数据，避免UI再求值。

## 验证命令与结果

初始能力探针：`outputs/parallel_ui_20261031/probe_parallel_capabilities_019.m`，独立MATLAB batch运行；本机R2025b、Parallel Computing Toolbox 25.2可用，backgroundPool报告8 workers。两个0.4秒等待/算术任务时间区间重叠0.418秒，取消future成功。单独2-worker Threads池探针此次未观察到重叠，不能宣称其已证实并发或将等待任务当计算加速基准。

证据：`outputs/parallel_ui_20261031/capability_1/capabilities.json`、`local/matlab_360a24a862e84eeb842db7bf67dc064b.log`。

第二轮能力检查：`probe_parallel_numeric_019.m`，三点手写项目（101路线采样、181凸轮采样）后台/同步完整结果`isequaln=true`；小二次题fmincon的interior-point在后台成功，工作线程创建停止队列、主线程发送停止后正确返回。嵌套backgroundPool探针报错，进程协调者的后台池仅1 worker且未重叠，均保留证据而不作为候选并行实现。结果在`numeric_1/numeric.json`、日志`local/matlab_12cc44be62eb4e5b91bc4aa98238215a.log`；初始源码指纹及范围在`diagnosis.json`。这些是初步能力证据，实际生产入口检查见下方最终结果。

首轮集成检查`check_background_ui`未通过：已越过菜单/异步计算一致性、主线程零evaluate、完成延后和旧任务消息拒绝的断言，在后台优化的`status=='finished'`断言失败（第47行）。本次只保存了断言日志，没有完整故障状态，不能据此推断优化算法错误；后续补充诊断修复。运行前源码副本/哈希在`source_run_1/manifest.json`，输出独占`check_1`，日志`local/matlab_8c112419c62a4a599de24e52ef77b776.log`。保留原件，不用后续通过结果覆盖它。

第二轮仍在同一断言失败，日志补出`cam:BackgroundInputsChanged`；当时有1个预览包、1次显示求值和1次后处理求值。冻结源在`source_run_2`，结果目录`check_2`，日志`local/matlab_fe41ed410e3e4f8db333cfa60b29db99.log`。静态追踪发现权重表第3列由`updateDiagnostics`更新，属于显示输出却仍在工程输入整体比较中；修订应只比较可编辑权重值，不能放开真实输入变更保护。

`check_3`用真实快照差异确认只读权重列与ScoreBasis导致误判，修正后发布成功；随后停止断言失败：30轮合成优化在0.81秒结束，慢截图期间任务已结束，之后才调用停止。改为活动任务内先Stop再截图；日志`local/matlab_eddb6c29a28d4045b777d1c2a9121f53.log`。`source_run_4/5`是未运行的中间冻结副本，不能计为两轮测试。

`check_6`记录`STOP_REQUEST active=1 futureState=running`，正常停止在38/300轮、860次评价；预览、停止、强制取消/原图恢复、旧消息/关闭清理、输入改变时保存已完成结果、闭环与前台兼容均通过其前置断言。后端循环在接力遇到`parallel:threadpool:DisallowedBuiltin`：`nlpSQP`不受线程支持。保留失败日志`local/matlab_c41ce87c8adf4aa782d3ad7b85da889e.log`、`check_6/last_session.*`；不将前面小二次题interior-point的成功泛化到SQP。修订为提交前选择进程池，首次创建1个worker；已有进程池复用，已有用户Threads池明确拒绝且不删除，用户可显式选前台兼容。当前全自动精修是interior-point，仍用线程。

### 最终功能验收

运行命令（仓库根目录，独立MATLAB配置目录）：

```powershell
./run_matlab_checks.ps1 -Task "check_background_ui(fullfile(pwd,'outputs','parallel_ui_20261031','check_7'));"
```

R2025b退出0，日志`local/matlab_da9cc761cdd2440b8e925e29d5b4e24a.log`输出`BACKGROUND_UI_PASS checks=13 mainEvaluate=0 backends=7`。输出独占`check_7`；16个运行前冻结源文件与最终源SHA-256一致。13组覆盖具名回调盘点/空闲安装、逐位计算一致、小型搜索节点/分数/评价次数一致、预计算加密交叉展示、异常保留原状态、真实输入改变拒绝覆盖但保存outcome、预览/停止、强制取消回退且不取消无关future、实际闭环/前台兼容、关闭清理、后端与已有池保护、进程停止保存。

7种UI优化方法均走真实worker：峰值、旧四方向、可行性四方向、内点法、全自动走线程；接力、多起点走进程。这里每种只用手写3/6点短输入验证兼容与返回路径，不判断算法质量；进程停止这次在预览前收到，成功返回`user_stop`的完整检查候选并保存结果，不冒称已验证进程中的可见长时预览。纯SQP及legacy低层入口未单独跑，进程选择已覆盖SQP所需执行路径。自动夹具没有开启polish，interior-point通过独立后端覆盖，不能称全自动各种配置穷尽检查。

实际计算和优化显示路径的主线程`evaluate`调用均为0；同步/后台完整计算`isequaln=true`，一轮搜索节点、分数、终止原因与评价账本一致。提交用时0.264秒仅是本轮小任务观测，不作生产速度承诺。父侧查看预览与取消恢复截图，确认停止提示和预览标签可见；普通主线程图形渲染、首次进程池准备、未改后台的其他业务仍可能等待。

## 存活窗口接入与实际失误

开发中的首版分派立即影响旧窗下一次回调，用户自行启动后台优化后实际遇到同一输入误判（`cam-tpc8011d64_bc91_431b_900f_32e04421462a`）；不是仅在隔离检查中发现。父侧未触发这次比赛计算，也不将它当作性能测试。发现后完整备份，再临时切换前台兼容；这次切换前后项目/结果/历史/待应用输入完全相等，日志只增加模式提示。证据在`parent_live/before_compat.*`、`after_compat.*`、`temporary_compatibility.json`。

旧失败任务只留下第0轮预览，已单独保存为`parent_live/retained_preview.*`；不能称其为恢复了本次优化最终成果。新版增加“完成outcome先落盘再检查UI输入”，并要求安装标识才能启用旧窗后台入口。最终源验收后再备份空闲旧窗、显式安装/切后台，不重算、不清工作区、不关用户窗口。

最终父侧执行`local/install_background_live_019.m`，`parent_live/verification.json`记录完整工程状态/未应用输入/原日志/轴限保留，日志只增1条模式提示，50个现有控制点不变，70个具名回调识别无未知项。`before_install.*`、`after_install.*`保全原数据；界面菜单实操确认“后台计算（界面可操作）”选中并收起。状态查询保留旧失败任务记录且`active=false`，不是再次发生失败，也未清掉其历史证据。

## 证据及局限

- MathWorks [线程支持范围](https://www.mathworks.com/help/matlab/matlab_prog/run-functions-on-threads.html)、[backgroundPool](https://www.mathworks.com/help/matlab/ref/parallel.backgroundpool.html)、[响应式App示例](https://www.mathworks.com/help/matlab/matlab_prog/use-the-background-to-make-your-apps-more-responsive.html)、[PollableDataQueue](https://www.mathworks.com/help/parallel-computing/parallel.pool.pollabledataqueue.html)。在线页面当前展示R2026b，R2025b支持情况以本机实测补证，不直接照搬最新版本结论。
- 后台线程内再次调用backgroundPool不能据此获得嵌套候选并行；有依赖的迭代步骤保持原序，预算对象不复制给多个worker各自计数。
- 能力探针只证明基础调度，最终合成检查证明本次所测入口兼容；没有新增比赛性能对照、凸轮精度比较、原版或实车一致性结论。没有候选并行的加速保证，也未跑比赛夹具的旧全套检查。

## 关联经验

采用EXP-038（源码/旧窗生命周期）、EXP-039（状态保全）、EXP-040（实际用户流程）；新增[EXP-041](../../LESSONS_LEARNED.md#exp-041-后台计算与候选并行需要分别证明)，记录能力探针和首版静态审查发现，明确区分实际失败与潜在陷阱。

## 回退办法

若出现状态错写、停止失效或结果不一致，先保留项目与任务证据；针对本次实际提交执行`git revert <提交哈希>`，不清空用户工作区。回退后核对原同步计算及具名回调可用。

## 审核与交付

已完成源码审查、13组合成功能验收、截图复核与空闲旧窗保全安装；[归档摘要](../../../data/background_computation_20261031.json)保存原报告、失败记录和55份本地证据指纹。相关源码、文档、经验与索引同次本地Git提交，不推GitHub。提交号通过`git log -- docs/changes/2026/2026-10-31-019-background-computation.md`查询。
