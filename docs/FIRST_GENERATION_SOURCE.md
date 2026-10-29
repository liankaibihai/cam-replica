# 第一代 MATLAB 原脚本基准与兼容模块

日期：2026-10-29，Asia/Shanghai。用户提供的“第一代 MATLAB 凸轮仿真代码”现已作为**该份 r2.m 的独立数值基准**：9 条附带路线逐点对照全部通过，9 类输出的最大绝对差均为 0。这不构成 3.1.2 或实车等价结论。第一代工作开始于 `541cae8`，最终本项验证时仓库基线为 `34c4e5b`；变更整合见 [CHG-007](changes/2026/2026-10-29-007-first-generation-source.md)。

## 原资料与隔离副本

原目录：`F:/许昊阳/竞赛/2027工创/第一代MATLAB凸轮仿真代码`。先对 5 份原件计算 SHA256，再复制到 `local/first_generation_source/run_fixture/`；原目录只读。运行后复核，所有原件和副本哈希均未变。

| 文件 | 大小 / B | SHA256 |
|---|---:|---|
| `r1.m` | 53 | `5eb448d71f0d92f9e1f41c4515fb52f4a9d0a7072e0d607f2e814cb5696242b8` |
| `r2.m` | 4233 | `538cc0310e89432879c77ee2eb420dde8d62cec3008c4cec8746efdc8c42e17e` |
| `routes.mat` | 127256 | `a99b9e626d716eed786bbe19750163857b366b3a8019dbe32196acf1d32cc1e2` |
| `代码运行示范.docx` | 996549 | `7bbd674abadd48d2d2ad45240fd6c4467d2d420e6391fff8bc2e47d46a4d0f96` |
| `说明.txt` | 2971 | `1dc5234aafc5d89a71b29fe8e7bcdb7a4b023a66a37175dbbbc8bbe4506ffbfe` |

`r1.m` 只清理工作区、`load routes`，再将 `x00/y00` 置空。实际计算由 `r2.m` 完成；它不生成前轮路线，也没有优化器或评分。`routes.mat` 由 MATLAB 读取，包含 `Untitled1` 至 `Untitled9` 九个 table，以及空的 `x00/y00`。各表三列，本次与示范一致，按顺序取前两列作为 `x00/y00`，第三列 Z 不参与计算。MAT 文件头记载 PCWIN64、2020-12-01 创建时间；这只是文件头信息，不是源码发行版本证明。

本次独立 MATLAB R2025b batch 执行的是**未改动 r2.m 副本**，其工作区输出保存于 `outputs/first_generation/original/Untitled1.mat` 至 `Untitled9.mat`。没有修改 EXE、授权信息或用户窗口，也没有运行 `r1.m` 清理用户会话。原脚本自带的 `figure(1:3)` 仅存在于独立 batch 进程内，默认设为不可见。

## 忠实保留的数值链

原默认值为 `a=150,b=81.5,c=23.5,d=200,f=3`，长度单位 mm。这些是作者示例参数，不是队伍实测尺寸。

1. 后轴中点初始化为 `[-1900,a]`，左右点按源码分别为 `[-1900+b/2,a]`、`[-1900-b/2,a]`。第 i 次推进以**下一前轮点**与当前后轴中点决定方向，并将新后轴中点放在离下一前轮点 a 的位置。保留原来的 X 精确相等分支、`atan(dy/dx)` 和 X 大小判断，没有改为 `atan2`、RK4 或现版车体积分。
2. 完整推进两遍。第一遍末尾的后轴及左右轮位置直接作为第二遍首点，再按原顺序处理前轮点 2…N；不是迭代到闭合收敛。最终轨迹为第二遍，兼容模块另外保留第一遍轨迹供诊断。
3. 对每一段，`v1=front(i)-rear(i)`、`v2=front(i+1)-front(i)`。原角度为 `acos(dot(v1,v2)/(norm(v1)*norm(v2)))`，**不裁剪 acos 自变量**。若 `cross(v1,v2)` 的 Z 分量大于 0，取负角、`m=c+f`；否则取正角、`m=c`。位移为 `u=m*tan(t)`。因此普通左转为负，不能直接沿用现版左转为正的解释。
4. 每段行程是**后轴中点弦长** `l(i)=norm(rear(i+1)-rear(i))`，逐次累积为 `x03`。相位为 `alpha=x03/sum(l)*2*pi`，没有主动轮行程、轮径或传动比参数。
5. 强制 `u(N)=u(1)`，再令 `p=u+d/2`。工作区 `all=[编号,X,Y,Z]`，其中 `X=p*cos(alpha)`、`Y=p*sin(alpha)`、`Z=0`，仅导出数值数组的前 N−1 点。原脚本不自动写出文件，本次由隔离包装函数保存 MAT；它也不求滚子法线包络或厚度实体。

这些定义与当前默认模型有实质差异。特别是源码注释中的 c 为“凸轮靠内侧相对于前轮的偏转距离”，f 在此进入分侧位移。不能据 `c+f` 这一行立即修改现版 `lift` 或将第一代同名参数静默当作新版接触几何。

## 独立兼容接口

实现：[`camdesign.firstGenerationCam`](../+camdesign/firstGenerationCam.m)。该入口不被默认 `evaluate/route/lift` 或 UI 调用。

```matlab
data=load('local/first_generation_source/run_fixture/routes.mat');
frontXY=table2array(data.Untitled1(:,1:2));
r=camdesign.firstGenerationCam(frontXY);
% 可单独修改第一代参数，不改变现代默认项目：
rOther=camdesign.firstGenerationCam(frontXY,a=150,b=81.5,c=23.5,d=200,f=7);
```

输入为 N×2 有限实数 double，N≥2。名称值参数 a、b、c、d 必须为有限正标量，f 为有限非负标量；`initialRear` 可指定有限实数 1×2，默认 `[-1900,a]`。**这些参数域和最低点数守卫是兼容 API 新增的约束，原脚本没有相同的显式验证**；域外参数不属于本次兼容承诺。

| 输出 | 形状 / 含义 |
|---|---|
| `rear,leftTrack,rightTrack` | N×2，第二遍后轴中点及原 `xz/yz`、`xy/yy` 轨迹 |
| `firstPassRear,firstPassLeftTrack,firstPassRightTrack` | N×2，第一遍诊断轨迹 |
| `steeringRad,leverArmMM,crossZ` | N−1×1，源码有符号角、分支臂长和叉积 Z |
| `rearStepLengthsMM,rearDistanceMM,totalRearDistanceMM` | N−1×1、N×1、标量；后轴中点弦长与累计量 |
| `u,alpha,p` | N×1；原位移、整圈相位及理论极径，u 末值重复首值 |
| `all` | (N−1)×4，原工作区同名数值数组 |

与原脚本行数组比较时只统一向量行列方向，不改变点序、符号、零位、相位或单位。`leftTrack/rightTrack` 对应原变量命名，未套入当前车体局部坐标。

## 实际对照结果

检查：[`check_first_generation.m`](../check_first_generation.m)。固定 SHA256 在**执行原脚本前后**各核验一次；文件缺失或哈希不符即拒绝。检查还要求 `-batch` 启动，且该实例初始不能已有图形，避免直接在用户当前 MATLAB 会话运行而覆盖 `figure(1:3)`。

命令：

```powershell
# 新环境先准备隔离副本；在仓库根目录执行，原资料只读。
$sourcePath='F:\许昊阳\竞赛\2027工创\第一代MATLAB凸轮仿真代码'
$fixturePath=Join-Path $PWD 'local/first_generation_source/run_fixture'
New-Item -ItemType Directory -Force -Path $fixturePath | Out-Null
Get-ChildItem -LiteralPath $sourcePath -File | Get-FileHash -Algorithm SHA256
Get-ChildItem -LiteralPath $sourcePath -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $fixturePath
}
# 检查自身会拒绝与上述固定 r2/routes SHA256 不符的副本。
./run_matlab_checks.ps1 -Task 'check_first_generation;'
```

MATLAB **R2025b**，绝对差阈值 `1e-12`。逐点比较后轴、左右轮轨迹、u、alpha、p、all、后轴各段弦长及累积弦长，共九类数组；九条路线全部实数有限，所有数组 `isequaln` 为真，**实测最大绝对差为 0**。

| 路线 | 输入点数 | all 行数 | 后轴累计弦长 / mm | u 范围 / mm | 最大绝对差 |
|---|---:|---:|---:|---:|---:|
| Untitled1 | 2000 | 1999 | 12606.192163 | −14.918478…13.215422 | 0 |
| Untitled2 | 2000 | 1999 | 10462.914178 | −12.939498…11.474645 | 0 |
| Untitled3 | 1000 | 999 | 10625.184433 | −16.299153…7.312490 | 0 |
| Untitled4 | 2000 | 1999 | 12308.572271 | −17.354078…15.373180 | 0 |
| Untitled5 | 2000 | 1999 | 21608.725257 | −21.479357…16.216805 | 0 |
| Untitled6 | 1000 | 999 | 10866.407961 | −16.571808…20.658332 | 0 |
| Untitled7 | 1000 | 999 | 10970.770297 | −22.129866…15.504651 | 0 |
| Untitled8 | 2000 | 1999 | 11994.098251 | −18.449318…16.360716 | 0 |
| Untitled9 | 2000 | 1999 | 16096.839653 | −22.941705…20.344531 | 0 |

另有 5 组独立检查：

1. a=5、b=2 的手算第一遍直行再竖直转向：后轴 `[0,0;3,0;3,-1]`，左右点也逐点手算核对。
2. 一维直线输入的完整两遍结果与后轴累计 `[0;10;10;20]`，相位 `[0;pi;pi;2*pi]`；位移为零至舍入误差。这同时显露第二遍不等于一般开路线正确初始状态。
3. 手算 ±45° 的位移分别使用 `−(c+f)` 与 `c`。该两点例的后轴总行程为零，检查明确要求 alpha 保留 NaN，不将其当有效闭合凸轮。
4. Untitled1 中 f 从 0 改为 7：轨迹和相位保持不变，仅正叉积分支的位移变化 `7*tan(t)`，其他分支不变。
5. 单点输入由新增 API 守卫拒绝；相邻前轮点重合仍保留原式产生的 NaN，不暗加去重或裁剪。

最终日志：[matlab_e0fe32812f5d42338a129afbdd9007f0.log](../local/matlab_e0fe32812f5d42338a129afbdd9007f0.log)，末行 `FIRST_GENERATION_PASS 9 routes 5 analytic checks`。完整数值和逐项误差见 [verification.json](../outputs/first_generation/verification.json)，来源与结果哈希见 [证据 JSON](../data/first_generation_20261029.json)。仅运行该项相关检查，没有重跑现代算法全套。

## 可视复核

[`Untitled1_comparison.png`](../outputs/first_generation/Untitled1_comparison.png) 包含前轮/后轴路线、位移、原脚本/移植理论凸轮叠加和逐点误差。图为 MATLAB 独立不可见 batch 导出，已目视检查；误差结论以原脚本保存的数值及逐点比较为依据。

![Untitled1 原脚本与忠实移植对照](../outputs/first_generation/Untitled1_comparison.png)

本地绘图脚本为 `local/first_generation_source/render_first_generation_comparison.m`，复跑命令：

```powershell
./run_matlab_checks.ps1 -Task "addpath('local/first_generation_source'); render_first_generation_comparison;"
```

## 失败记录与保留限制

首次检查在包装函数解析阶段失败：`alpha(:)` 被解析为同名内置函数调用，尚未运行原脚本。已在该局部工作区显式初始化脚本输出变量；日志 [matlab_6cb6742216ed4d9baa99b12d911d92b3.log](../local/matlab_6cb6742216ed4d9baa99b12d911d92b3.log)。第二次在 Untitled1 数值比较之后，向空结构数组写报告失败；改用 cell 收集同构报告后拼接，日志 [matlab_e4e81245d7e747238e3b8a527888858a.log](../local/matlab_e4e81245d7e747238e3b8a527888858a.log)。这两项只修正检查包装与记录，未修改基准源码或移植数值。随后九路线通过，加入哈希及 batch 防护后再次通过；所有日志保留。

仍保留：acos 未裁剪、零长度向量未保护、固定默认初值、仅两遍推进、全行程强制归一为 2π、位移末点直接闭合及 all 省略末点。零行程会除零；重复点可能产生 NaN；舍入导致 acos 自变量越界时可能为复数；开路线不自动获得适合的发车初值。模块没有通过重采样、平滑、夹角限幅或数值积分来修正这些行为。

本轮建立的是**用户提供的第一代 r2.m 在上述九表及有效默认参数上的可复跑逐点基准**。没有恢复 2.5.1 的未知聚合评分、重叠贝塞尔融合或 3.1.2 全实现，也不证明接触、间隙、打滑、比赛达标或可加工。
