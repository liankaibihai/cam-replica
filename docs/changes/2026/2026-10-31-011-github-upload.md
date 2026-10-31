# CHG-2026-10-31-011 GitHub 私有仓库整理与上传

## 基本信息

- ID：CHG-2026-10-31-011
- 日期 / 时区：2026-10-31 / Asia/Shanghai
- 状态：已验收（上传与文档）
- 执行 / 审核：总指挥负责整理、Git 上传与核验；无独立代码改动。
- 基线分支：feature/reference-comparison
- 基线 Git：ed29d033413a895db7e4b08648ef6c7b14f714e9
- 关键词：GitHub、私有仓库、版本历史、发布范围
- 本单提交：git log -- docs/changes/2026/2026-10-31-011-github-upload.md

## 动机与边界

用户要求整理提交 GitHub。账号为 liankaibihai，原仓库无远端，创建私有 cam-replica 仓库并保留现有开发分支及提交历史，不改写历史。上传不代表算法通过实车验收或与原版逐点相同。

## 改动文件

- README.md：仓库入口、分支、分发内容与外部资料依赖。
- docs/changes/README.md：登记本记录。
- 本记录：上传范围与核验方法。

## 验证命令与结果

- git status --short：上传前工作区干净。
- git remote -v：上传前无远端。
- gh api user --jq .login：账号 liankaibihai。
- git rev-list --objects --all 配合 git cat-file：未发现超过 1 MB 的历史 blob。
- git log --all --oneline -- '*.exe' '*.mp4' '*.zip' '*.mat'：无结果。
- git ls-files outputs local：仅 outputs/.gitkeep。
- 当前文件特征扫描：未发现 GitHub token、私钥头或已知主板号；此项不是完整的秘密审计。
- gh repo create --private --source . --remote origin --push：成功；基线已上传到 origin/feature/reference-comparison。
- 本次仅整理上传及文档，不重复 MATLAB 数值测试；计算证据沿用对应变更记录。

## 证据及局限

仓库：https://github.com/liankaibihai/cam-replica 。保留既有资料引用和本机路径，使用私有可见性。原始视频、软件、缓存、项目备份及运行输出不分发；某些取证脚本仍需本机资料。未新增开源许可授权。

## 关联经验

无新增经验，不为上传操作虚构算法经验。

## 回退办法

文档可对本提交使用 git revert；远端上传不需要通过删除仓库回退。若需停止同步，可移除本地 origin，但不会删除 GitHub 数据。保留全部历史与本地资料。

## 审核与交付

原代码未改变；仓库已创建，基线推送成功。本记录提交后再次推送并核对本地 HEAD 与远端分支，实际最终提交号由 Git 查询。
