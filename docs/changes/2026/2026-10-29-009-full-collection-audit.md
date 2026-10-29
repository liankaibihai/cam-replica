# CHG-2026-10-29-009 全部资料去重与核心缺口核对

## 基本信息

| 字段 | 内容 |
|---|---|
| 日期 / 时区 | 2026-10-29 / Asia/Shanghai |
| 状态 | 已验收（资料审计范围） |
| 执行 / 审核 | 总指挥负责库存、索引和整合；Sol极高独立对话负责相关源码复核；最终由总指挥审核 |
| 基线分支 / Git | feature/reference-comparison / 51234e7f4c4633feb89232d101c6fbb9b20b5600 |
| 标签 | 资料总库、SHA256、去重、融合、评分、调度、农机凸轮、嵌套ZIP |

## 动机与边界

用户提供“41 MATLAB代码及软件”，说明这是其目前能找到的全部。目标是穷尽目录清点、识别重复与新增相关材料、明确哪些可解码源码已查和哪些内容未读；避免继续反复索取已给材料或把无关示例算法误称为原版实现。

本轮只读原资料，新增审计工具/证据/文档，不改默认计算或UI，不执行包内EXE、动画或交互模型，不追索无关加密包密码。

## 改动文件

| 文件 | 内容 |
|---|---|
| tools/audit_matlab_collection.py | 可复跑ZIP/嵌套ZIP目录、哈希、文本解码和关键字覆盖扫描 |
| data/full_collection_inventory_20261029.json | 18包清单、逐成员覆盖与命中、重复和额外第一代哈希对照 |
| docs/FULL_COLLECTION_SOURCE_REVIEW.md、data/full_collection_review_20261029.json | Sol对相关源码、农机点集、未读边界的独立复核 |
| docs/MATERIALS_CATALOG.md | 18包用途及核心缺口结论 |
| AGENTS.md、docs/INDEX.md、docs/REFERENCE_COMPARISON.md、docs/LESSONS_LEARNED.md、docs/changes/README.md、本文件 | 资料入口、用户已提供全部材料的事实及逐次记录 |

## 验证命令与结果

`C:/Users/22416/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/audit_matlab_collection.py "F:/许昊阳/竞赛/2027工创/41 MATLAB代码及软件" data/full_collection_inventory_20261029.json --known data/additional_sources_20261029.json`

退出码0：18个外层包、5个整包重复，56份文本成功扫描（47.m、1.asv、8.txt）；30目录、1嵌套ZIP、293二进制仅登记、7加密成员未读，共387记录。确切函数/调度标识零命中。额外逐项计算第一代压缩包的r1/r2/routes/DOCX/说明SHA256，5项与此前原目录一致。初次手工读取嵌套包时收到password-required，此后显式登记其7项加密边界，未尝试解密。

源码专项复核已读：通用反射面评分、天体标准差和向量叠加不能证明就是缺失函数；农机是指定周期位移/连杆投影/中弦法线偏置。总指挥独立解析点集确认1001×3、全有限、Z=0、1000不同XY及首尾闭合，有向面积12888.550797984；只作静态核对，未运行原模型。全18包运行后SHA256未变；380外层成员+7内层成员与库存总数一致。不需要重跑未变动的MATLAB生产测试。

## 证据及局限

扫描命中与未命中不是算法等价证明。结论限已读源码；EXE、MAT、图像等只登记的内容，以及内层加密文件，不能声称不存在所需算法。既有相同哈希的资料沿用此前已完成的检查，不伪造本轮重跑。

## 关联经验

EXP-006/008/009/016/017：版本/证据范围、源码与算法名、文本扫描不能代替实际语义；本次新增EXP-017，记录哈希去重、备份源码与嵌套加密覆盖的区别。

## 回退办法

回退本次新增审计工具、JSON和文档及对应索引；原材料与生产计算不受影响。提交后优先git revert本逻辑提交，保留已有来源和历史记录。

## 审核与交付

总指挥已审核相关原源码、专项复核、双方一致的56文本/7548行覆盖及农机静态统计；两份JSON可解析，新增文档链接无缺失，git diff --check通过。本单所属提交由 `git log -- <本记录路径>` 查询。
