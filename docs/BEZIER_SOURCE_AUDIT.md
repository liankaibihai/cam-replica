# 长编程教程源码画面审计

日期：2026-10-29。基线 `541cae8`。研究两段长教程 `861804050`、`865568585`，并按后续授权新增独立原始特征诊断模块及其单项 MATLAB 检查。既有生产评估、路线构造、UI 和默认优化器未改动，未操作用户窗口。本记录与配套 JSON 由总指挥审核整合。

## 新发现：Simulation_cal 的实际函数体

上篇 `861804050-1-208.mp4` 的 **09:30–09:48（570–588 s）** 实际打开 `Simulation_cal.m`。不再只是函数列表中的名字：函数体第 3–36 行可读，首行输出表被横向裁切，底部第 39 行之后未完整出现。

主审复核入口：

- [09:40 原分辨率帧](../local/bezier_source_audit_20261029/861_simulation_continuous/frame_000580000ms.png)。
- [09:34 代码区域放大图](../local/bezier_source_audit_20261029/crops/861_574_editor.png)：由原帧裁取 `(380,125,1280,740)`，仅放大，不补画字符。
- 连续帧及请求/实际时间见 `local/bezier_source_audit_20261029/861_simulation_continuous/frames.json`：560–602 s，间隔 2 s，含进入和退出该函数的上下文。

以下按画面转录，空白规范化，省略注释与空行。**这是部分函数体，不是可独立运行的完整恢复文件。**

```matlab
% Simulation_cal.m, visible line 3
ps=Bezier_superposition(control_points,route_index,num);

% lines 6-8: sampled front-path polyline length
Vs=ps(2:end,:)-ps(1:end-1,:);
Vs_norm=(Vs(:,1).^2+Vs(:,2).^2).^0.5;
length=sum(Vs_norm);

% lines 11-25: control-polygon features
Vs=control_points(2:end,:)-control_points(1:end-1,:);
Vs_norm=(Vs(:,1).^2+Vs(:,2).^2).^0.5;
length_cp=Squares_standard_sum(Vs_norm);
Vs=Vs./[Vs_norm,Vs_norm];
dot=Vs(2:end,1).*Vs(1:end-1,1)+Vs(2:end,2).*Vs(1:end-1,2);
symbol=dot>1;
dot(symbol)=1;
symbol=dot<-1;
dot(symbol)=-1;
t_cp=acos(dot);
t_cp_sum=Squares_standard_sum(t_cp);
dt_cp=t_cp(2:end)-t_cp(1:end-1);
dt_cp_sum=Squares_standard_sum(dt_cp);
ddt_cp=dt_cp(2:end)-dt_cp(1:end-1);
ddt_cp_sum=Squares_standard_sum(ddt_cp);

% lines 28-33: wheel/body tracks and steering features
[ps_body,ps_driving,ps_driven,ps_sensor,t_front_wheel]=all_routes_cal(ps,V_0,driving_wheel,driven_wheel,Z_sensor,index);
t_sum=Squares_standard_sum(t_front_wheel);
dt=t_front_wheel(2:end)-t_front_wheel(1:end-1);
dt_sum=Squares_standard_sum(dt);
ddt=dt(2:end)-dt(1:end-1);
ddt_sum=Squares_standard_sum(ddt);

% line 36
[P_distance_sum,~]=distance_calculate(P,ps_sensor);
```

这段可直接支持：

1. 贝塞尔融合接口为 `Bezier_superposition(control_points,route_index,num)`，不能把三个参数随意替换成现版样条节点的语义。`route_index` 的具体算法含义仍需函数体确认。
2. `length` 明确是生成的 `ps` 相邻点欧氏距离之和；`length_cp` 却调用另一聚合函数，不能仅按变量名解释成同一种长度。
3. 控制折线转角由相邻单位边点积求 `acos`，范围裁到 [-1,1]；它是无符号夹角。可见部分没有零长度边保护，不应据此假定作者完整程序一定处理或一定不处理重合点。
4. 控制角特征是一阶、二阶**原始相邻差分**；前轮角也同样处理。这些行未除以弧长、相位或时间间隔，不能写成已确认的物理角速度/角加速度。
5. `t_front_wheel` 是第六个输出，其他部件坐标由 `all_routes_cal` 返回。完整函数输出表与输入表尚未全部读到。
6. `Squares_standard_sum` 与 `distance_calculate` 只是此处的调用，尚不能用名称补出聚合、最短距离或有序匹配的具体实现，更不能据此拼成完整十二项评分。

## 搜索与覆盖状态

两份现有 ASR JSON 共 3916+1395=5311 个分段，已全文搜索英文函数名、贝塞尔/叠加等词及“函数”常见误识别（寒树、含书等）。英文函数名均无直接命中；上篇相关“函数/参数”词 26 个分段、下篇 2 个。机器文本用于定位，不能以没有检索命中证明视频没有源码。下篇 0–100 s 机器文本沿用既有质量排除，画面可独立检查。

已复看既有 38+22 张时间索引概览，随后对上篇 09:20–10:02 函数切换与 27:50–30:10 参数/执行上下文、下篇 01:40–03:40 开头反推代码作定向连续抽帧。下篇这一段是 `reverse_validation.m` 调试过程与临时 `Untitled`，不能改称为 `Bezier_curve` 或 `score_cal` 函数体。

进一步对 `Squares_standard_sum/score_cal` 及 `square/standard/sum/平方/标准/標準/求和/加和/均值/平均/指数/指數/幂/次方` 搜索。上篇 2733–2767 s 的平方/开根号是在恢复凸轮极径，不是 `Squares_standard_sum`；4158 s 及 6727 s 之后的均值是在讨论相邻转角和瞬心步进。下篇 2957.67–2963.86 s 的“得分套”位于矩阵输入说明，不能当评分证据。未找到可据此定位的聚合函数讲解，不再盲目全片抽帧。

## 四个目标函数的最终证据等级

| 目标 | 此次实际看见 | 可定位的主证据 | 尚未看见 |
|---|---|---|---|
| `Simulation_cal` | 实际函数体 3–36 行；函数首行输出表前段；调用前段；内部几个辅助函数调用 | 上篇 570–588 s；574/580/586 s 原帧互校，575–578.5 s 横向滚动互校 | 第 39 行之后的完整函数、完整头部及全部输入尾项 |
| `Bezier_superposition` | **真实调用** `ps=Bezier_superposition(control_points,route_index,num);`，另有文件名 | 上篇 574–588 s 第 3 行；下篇 150.021 s 文件列表 | 融合函数体、权重函数、首尾策略；不能由调用恢复三者 |
| `Bezier_curve` | 文件列表 `Bezier_curve.m`，类型显示“函数” | 下篇 150.021 s 原帧左上列表 | 函数体及可读调用式，尚不能确认其参数或杨辉系数实现 |
| `score_cal` | 文件列表 `score_cal.m`；主程序另有 12 维得分指数线索 | 上篇 540 s 当前文件夹；1740 s `Scored_index` 定义 | `score_cal` 函数体、调用式及完整十二项合成表达式 |
| 新依赖 `Squares_standard_sum` | 在 `Simulation_cal` 中 7 处调用 | 上篇 574/580/586 s，行 13、21、23、25、29、31、33 | 聚合函数体；不能默认是平方和、均方、RMS 或积分 |

以上“尚未看见”只针对本次检索、概览复查及定向连续帧的覆盖，不是对每一视频帧或作者所有资料的不存在证明。两段画面中的路径均属于“第八届工训赛 2.5.1”，不能无条件升级成 3.1.2 的实现结论。

## 可读接口与数量定义

首行从重叠的横向滚动画面可互校出以下输出前缀（方括号尾部仍被裁切，故不补闭合的完整函数签名）：

```text
ps, ps_body, ps_driving, ps_driven, ps_sensor, t_front_wheel,
length, length_cp, P_distance_sum, t_cp_sum, dt_cp_sum, ddt_cp_sum,
t_sum, dt_sum, ddt_sum, cam_theoretic, cam_virtual, displacement,
fluctation, Problem_location, rho_max, ...
```

575–578.267 s 的右边界还能看到 `pressure_ang...` 截断前缀；即使工作区有相近名字，也不据此补全函数头。`cam_calculat.m` 第 15 行调用的可读输入前缀在 589.767–590.5 s 为：

```text
Simulation_cal(P0,route_index,num_route,V_0,driving_wheel,driven_wheel,
               Z_sensor,index,P,car_type,c,thickness [右侧仍截断])
```

这里 `P0` 与函数内部 `control_points` 对应、`num_route` 与内部 `num` 对应，是根据同一被打开函数的调用顺序推定的接口对应关系；函数头输入表未完整读到，不能扩写后续位置。确定的三个下游接口为：

```matlab
ps=Bezier_superposition(control_points,route_index,num);
[ps_body,ps_driving,ps_driven,ps_sensor,t_front_wheel]=all_routes_cal(ps,V_0,driving_wheel,driven_wheel,Z_sensor,index);
[P_distance_sum,~]=distance_calculate(P,ps_sensor);
```

令控制点行数为 N、生成路线行数为 M、`t_front_wheel` 元素数为 K，则可见评分前端送入各聚合调用的数据数量为：

| 特征 | 送入的数据 | 数量 | 是否除以步长 |
|---|---|---:|---|
| `length` | 路线各段欧氏距离，直接 `sum` | M−1 | 不适用 |
| `length_cp` | 控制折线各段欧氏长度 | N−1 | 没有 |
| `t_cp_sum` | 相邻控制边的 `acos` 无符号夹角 | N−2 | 没有 |
| `dt_cp_sum` | 控制夹角的一阶相邻差分 | N−3 | 没有 |
| `ddt_cp_sum` | 控制夹角的二阶相邻差分 | N−4 | 没有 |
| `t_sum` | `all_routes_cal` 返回的前轮角原数组 | K | 没有 |
| `dt_sum` | 前轮角一阶相邻差分 | K−1 | 没有 |
| `ddt_sum` | 前轮角二阶相邻差分 | K−2 | 没有 |

该数量推导以输入具有足够点数为条件。`all_routes_cal` 的完整输出长度与边界规则尚未转录，因此不把 K 在所有条件下都认定为 M。控制夹角处可见 `acos`，前轮有符号转角的生成则委托给 `all_routes_cal`；本片没有给出可在此审计中独立恢复的完整主体。

## 已实现的独立原始特征诊断模块

已新增 [`camdesign.video251Features`](../+camdesign/video251Features.m)，接口为：

```matlab
features=camdesign.video251Features(controlPoints,frontPath,frontWheelAngles);
```

两个点阵为有限实数 double，至少两行、恰好两列（N×2、M×2），本项目诊断接口约定长度单位 mm；前轮角为有限、非空、有符号弧度向量，输出统一为列向量。它返回路线各段长度与总折线长、控制折线各段长度、无符号 `acos` 夹角及一/二阶原始差分、给定前轮角及一/二阶原始差分。没有弧长或时间归一化，也不要求前轮角元素数 K 等于路线点数 M。

模块明确返回 `aggregationImplemented=false`、`scoreImplemented=false`。没有实现或代用 `Squares_standard_sum`、`score_cal`、`distance_calculate` 和原版贝塞尔生成器；`length_cp` 等未知聚合结果未以同名字段伪装输出。控制边和路线边的零长段拒绝、最低点数检查是本诊断 API 增加的输入约束，**不是视频中已确认存在的保护逻辑**。两个点与单个前轮角是有效最小输入；不足以形成的夹角和差分返回空列向量。

[`check_video251_features.m`](../check_video251_features.m) 在 MATLAB **R2025b** 运行通过 **7 组检查**，绝对误差阈值 `1e-12`：

1. 手算 3–4–5 三角形各段长度与周长 12。
2. 直线控制折线的零夹角及一/二阶零差分。
3. 直角与反向边的无符号夹角 `[pi/2;pi/2;pi]` 及已知差分。
4. 已知有符号弧度序列的一/二阶差分、行向量转列向量、K≠M，以及无评分输出。
5. 平移与旋转保持长度、控制夹角及差分不变。
6. 统一缩放 2.5 倍仅缩放长度，原始角差分不按毫米变化。
7. 控制/路线零长段和单点输入被拒绝，最小有效输入产生空夹角/差分。

运行命令：`./run_matlab_checks.ps1 -Task 'check_video251_features;'`。检查记录位于 [verification.json](../outputs/video251_features/verification.json)，运行日志位于 [MATLAB 日志](../local/matlab_9f3146a35fd642f3bf4af8d6a0173b93.log)，末行 `VIDEO251_FEATURES_PASS 7 checks`。这些是独立诊断公式与手算/几何不变量的验证；本轮仅运行这一项检查。

## 剩余实现门槛

下列门槛针对上述两段教程的证据覆盖。用户随后提供 `F:/许昊阳/竞赛/2027工创/第一代MATLAB凸轮仿真代码` 文件夹，正由主指挥清点；本审计尚未读取该新目录，不能把视频中未见扩写成新材料中不存在。当前模块和检查已落盘，后续代码修改等待新材料分工。

1. **聚合算子仍是未实现依赖**：没有 `Squares_standard_sum` 的证据时，不默认使用 `sum(v.^2)`、`mean(v.^2)`、`norm(v)` 等。不同假设只能作为分别命名的实验，不能作为恢复结果。
2. **十二项评分仍需 `score_cal` 或可核对的表达式**：目前若干原始特征已有定义，但距离聚合、凸轮项、归一化尺度、得分符号、指数如何作用仍缺。不能直接接入既有独立六项目标并改称原评分。
3. **路线构造仍需融合函数体**：真实调用确认了参数顺序，但不提供精确融合权重。其他视频和资料的独立证据不混入本次源码转录。

本轮交付了新增的 `Simulation_cal` 评分前端源码与接口证据，以及已通过检查的独立原始特征模块；尚不足以交付完整可执行的原版评分模块，也不建立 3.1.2 或实车等价。逐条来源、转录、哈希、实际抽帧时间、模块与检查记录见 [审计 JSON](../data/bezier_source_audit_20261029.json)。
