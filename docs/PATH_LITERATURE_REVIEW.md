来源：用户指定文献查询会话 `01a18d7a-5a3e-74f1-bdad-01bf8bd58e02`，2026-10-31 实际检索后的交付。以下保留其读取范围与失败说明；总指挥选择 B 样条表示先做同条件实验，性能结论另见 [赛道比较](PATH_METHOD_COMPARISON.md)。

复核结论：现有报告把三次／五次 B 样条列为**路线表示的优先试验**是合理的，但遗漏了一个应并列评估的成熟方向：**直接最优控制（多段直接配点或多重射击）**。它可以把车辆运动学、顺序打卡、主动轮行程和凸轮约束纳入同一个优化问题。直接配点是一种求解框架，可以与 B 样条或曲率参数化结合；目前没有证据证明它在本赛道优于报告中的候选。

另一个值得提前研究的方向是**直接参数化凸轮位移／转向规律，再积分车辆轨迹**。它更贴近压力角和回程约束，但接入有序传感器打卡的难度更高，适合作为独立后端，而非未经验证地替换现有路线。

### 检索与核验

已使用 `academic-search` 的 `search_papers`，同时请求 CrossRef 和 arXiv，查询词包括：

- `vehicle path planning curvature continuous waypoint optimal control`
- `vehicle path planning G2 continuous curvature waypoint optimization`
- `cam mechanism trajectory optimization pressure angle spline`
- `trajectory optimization waypoint car steering rate direct collocation`

四次检索均返回结果且工具未报告来源错误；返回的前列结果主要来自 CrossRef，不能据此认为 arXiv 检索覆盖充分。随后用 `get_paper_by_id` 对下列 7 篇逐条核验，CrossRef／arXiv 查询均成功。另查看出版社摘要、预印本摘要及部分作者仓库。个别网页访问失败：Clothoids 论文 DOI 页面不可达、Xue 的 `devel` 分支页面返回 429；相应结论改用成功返回的元数据、仓库主页或现有报告，未将失败写成已验证。

| 文献及核验结果 | 本次读取程度与相关性 | 作者代码 |
|---|---|---|
| Xue、Yue、Dolan，2023，[Spline-Based Minimum-Curvature Trajectory Optimization for Autonomous Racing](https://arxiv.org/abs/2309.09186) | **arXiv 摘要及仓库主页**。论文以 B 样条控制点为优化变量；支持研究局部控制点参数化，但赛车最小曲率目标不能直接替代打卡和凸轮约束。 | [作者仓库](https://github.com/HaoruXue/spline-trajectory-optimization)：Python／Julia，主页标示 Apache-2.0，并指向 `devel` 为论文代码；本轮该分支访问 429，未运行或独立复核分支许可证。 |
| Botros、Smith，2022，[Tunable Trajectory Planner Using G³ Curves](https://doi.org/10.1109/TIV.2022.3141881)，[2021 预印本](https://arxiv.org/abs/2106.03836) | **CrossRef 元数据、预印本摘要**。论文研究固定起终状态间的连续曲率变化率路径及速度规划；不直接覆盖本车多点读卡和凸轮回程。 | 本轮未核实到作者代码与许可证，不能视为不可用或不存在。 |
| Bertolazzi、Frego，2018，[Interpolating clothoid splines with curvature continuity](https://doi.org/10.1002/mma.4700) | **CrossRef 元数据与摘要**。论文将连续性约束下的回旋线插值与长度、曲率等目标结合；适合作为曲率连续的几何初值，但连接处曲率对弧长的导数仍可能跳变。 | [Clothoids](https://github.com/ebertolazzi/Clothoids)：C++ 与 MATLAB 接口；[许可证文本](https://github.com/ebertolazzi/Clothoids/blob/master/license.txt)允许按条件再分发。MATLAB R2025b 兼容性未测试。 |
| Soudbakhsh、Eskandarian、Chichka，2010，[Vehicle steering maneuvers with direct trajectory optimization](https://doi.org/10.1109/IVS.2010.5547966) | **CrossRef 元数据；另查到二次来源摘要**。摘要称其用配点求解车辆转向轨迹的非线性优化。它为直接配点提供车辆应用先例；本轮未读原文，因此不声称其已处理本项目的打卡、凸轮或回程。 | 本轮未核实到作者代码与许可证。 |
| Nguyen、Kim，2007，[Flexible cam profile synthesis method using smoothing spline curves](https://doi.org/10.1016/j.mechmachtheory.2006.07.005) | **CrossRef 元数据、[出版社摘要及正文片段](https://www.sciencedirect.com/science/article/pii/S0094114X06001558)**。论文研究三次与五次平滑样条，并同时考虑凸轮运动的位移、速度、加速度及离散约束；示例为发动机气门机构。 | 本轮未核实到作者代码与许可证。其机构与本车不同，公式不能直接移植。 |
| Qiu、Lin、Li、Ozaki、Wang、Yue，2005，[A universal optimal approach to cam curve design and its applications](https://doi.org/10.1016/j.mechmachtheory.2004.12.005) | **CrossRef 元数据、[出版社摘要及正文片段](https://www.sciencedirect.com/science/article/pii/S0094114X05000108)**。论文用均匀 B 样条表示凸轮运动曲线，并优化控制点以综合多个运动学或动力学目标；其示例不是本车机构。 | 本轮未核实到作者代码与许可证。论文使用自动调权；不能据此绕过项目对固定验收阈值和同权重比较的要求。 |
| Cheng、Chen、Zhang、Gan、Liu，2022，[Real-Time Trajectory Planning for Autonomous Driving with Gaussian Process and Incremental Refinement](https://arxiv.org/abs/2205.11853) | **arXiv 元数据与摘要、仓库 README**。论文使用 Frenet 坐标下的高斯过程路径表示并考虑曲率约束，再迭代优化路径与速度；适合作为补充比较，参考线和道路驾驶假设需要重建。这里作者名单按预印本列出；仓库会议引用另多列一名作者，**两个版本不能直接合并为同一作者表**。 | [作者项目 GPIR](https://github.com/jchengai/gpir)：仓库说明为 MIT，依赖 ROS／CARLA，包含 C++／Python；许可证依据仓库 README，LICENSE 单页本轮打开失败。未安装或运行。 |

### 对现有报告的具体修订建议

1. **调整推荐结构，而非取消 B 样条优先试验。** 将“标准三次／五次 B 样条”明确限定为*路线表示层的第一组消融*；在研究路线中增加“状态与控制量直接配点／多重射击”作为并列的联合约束方向。G³ 和回旋线分别解决不同连续性或初始化问题，不能替代约束建模。

2. **补充凸轮运动规律参数化。** 将 Nguyen 和 Qiu 的论文加入“从凸轮运动规律反推路线”的证据；但把“可直接处理本车压力角”标为**待推导的工程设想**。需要先按本项目确认的平推接触模型，建立位移到转角、车辆轨迹及传感器轨迹的映射，不能因其他论文中的从动件名称相似就套用机构公式。

3. **把有序打卡写成显式约束，而非路线穿点。** 工程上可为每个目标引入按次序排列的进度变量，在对应车辆状态下计算偏置传感器位置并限制误差；重复目标坐标仍保留为独立事件，是否要求严格时间间隔应由赛题与模型确定。这是本次**工程推断**，并非上述论文已完成的赛题方案。

4. **将压力角、工作段和回程放入同一个可行性检查。** 在报告现有模型、\(q>0\) 且允许压力角小于 \(90^\circ\) 的条件下，可把工作段压力角限制等价写成 \(\lvert dq/d\phi\rvert\le q\tan\alpha_{\max}\)。这只约束所采用模型的工作段；仍需单独构造并检查回程、接缝、极值与欠切。传动比 35 按用户输入固定参与计算，只能由用户修改。

5. **保留连续性限定。** 五次 B 样条简单内节点的 \(C^4\)、曲率变化率连续和最终凸轮曲线的平顺性处于不同层次。参考曲线须正则、参数化及整个车辆／凸轮计算链接缝也须满足相应条件；上游平滑不能自动传递至当前三次重拟合和五次回程。

本轮未修改共享文档或代码，未打开 MATLAB，也未运行新规划器或实车测试；以上优先级是文献与约束结构上的判断，不是赛道性能排名。
