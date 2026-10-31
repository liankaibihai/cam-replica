# CHG-2026-10-31-012 太阳能赛项规则与资料核对

## 基本信息

- 日期：2026-10-31，Asia/Shanghai；状态：已验收（资料核对，不是功能实现）。
- 执行/审核：总指挥阅读来源、代码并交叉核对；无执行器代码任务。
- 基线：feature/reference-comparison，75908ac1d128b4c84881739cd60dc5d53cdfbe47。
- 关键词：太阳能、规则、UID覆盖、车身投影、有效距离、功率。
- 本单提交由 git log -- docs/changes/2026/2026-10-31-012-contest-context.md 查询。

## 动机与边界

用户要求深入了解新能源赛项及工创文件夹。梳理当届正式赛项与完整比赛流程，区分旧届/其他赛道/供应商资料。只建立理解与缺口，不改算法。

## 改动文件

- docs/CONTEST_CONTEXT_2027.md：规则理解、来源、工程影响与待做事项。
- data/contest_context_20261031.json：关键源文件哈希及实际阅读覆盖。
- docs/INDEX.md、docs/changes/README.md：索引。
- docs/LESSONS_LEARNED.md：EXP-034。
- AGENTS.md：长期赛事判定区分及入口。
- 本记录。

## 验证命令与结果

本地pypdf提取、SHA256库存：111个PDF路径，96个唯一哈希；核心文件按覆盖表阅读。pypdfium2渲染评分页3/8/9并目视核对，读取trajectoryBounds/visitOrderAudit及太阳能点库，确认实现局限和初赛顺序。只读原件，缓存位于local/contest_review_20261031。网络检索找到高校2027通知及附件，官方站与远端PDF打开超时，不将搜索摘要当完整新规则。

首次提取其他赛道PDF遇代理字符编码失败，改用替换符保留其索引；该文件不用于本赛项公式。默认Python无PDF库；尝试安装PyMuPDF后改用已有运行时pypdf/pypdfium2完成，未把安装成功当阅读前提。

本轮不改计算，不重复MATLAB测试。提交前检查JSON可解析、来源哈希、文档链接及git diff --check。

## 局限、经验与回退

未读取所有CAD、视频和表格，未核实所有最新补充通知；厂商参数不是用户实测参数。规则文件外壳处罚表述冲突已列出待核，未自行裁定。关联EXP-034。回退使用本提交的git revert并同步恢复索引，不删除原资料或历史。
