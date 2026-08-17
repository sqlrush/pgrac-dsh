# 09 — 扫描方法与覆盖范围记录

> 记录 2026-08-16 这次扫描的诚实边界：哪些读了、哪些只是清点。

## 扫描方法

三轮递进：
1. 目录清单 + README + git 状态（两仓）
2. 控制文档深读：README、AGENTS.md、CLAUDE.md 头部、最新 talk 头部、
   progress.md 头部、roadmap 阶段表、talk-state 状态文件
3. 全盘清点：每个子目录的文件数/体量、specs/features/docs/reports 清单、
   linkdb cluster 源码/头文件清单与行数、测试数量、提交统计、worktree 状态

## 实际读过正文的

- 两仓 README.md 全文
- `~/pgrac/AGENTS.md` 前 60 行（CURRENT OVERRIDE 0.2.10 规则）
- `~/pgrac/CLAUDE.md` 前 50 行（改名通知 + 核心原则 0 + 可见性边界）
- `~/pgrac/talk_20260816-0052.md` 前 ~80 行（当前 talk 的 authority/WIP/告警区）
- `~/pgrac/progress.md` 前 100 行（08-12~08-14 记录）
- `~/pgrac/docs/development-roadmap.md` 阶段表与发布决策节（grep 提取）
- `.pgrac-talk-state/{writer,reader}/state.json` 全文
- git 状态/日志/分支（两仓 + 公共 worktree）

## 只清点未读正文的

- 259 篇 talk 日志（只统计时间分布；未读历史内容）
- 287 份 specs、113 份 features、162 个 docs、182 个 reports（只看文件名）
- `scratchpad/` 27,557 文件（只抽样目录与体量）
- linkdb 117K 行 C 代码（只看文件清单与行数，未读实现）
- `_graph/` 439 文件、ppt/build-harness/codex_migration/codex_review（只清点）
- 214 个 TAP、139 个单元测试（只看文件名）

## 数据要点存档（扫描时点的数字）

- talk 文件 259 篇；按天分布峰值 07-30（45 篇）、08-09（40 篇）
- specs 287（其中 spec-0.x 31 份）；features 113 文件；reports 182 文件
- linkdb：58,933 提交；cluster .c 117,182 行；.h 34,347 行；
  TAP 214 个；cluster_unit 139 个
- pgrac scratchpad 2.1GB；ppt 45MB；docs 19MB；specs 19MB
- linkdb .worktrees 98 个；pgrac .worktrees ~40 个
- 公共 worktree：branch agent/stage8-r3-r4d10-integration

## 环境事实

- 本会话工作目录：`/Users/sqlrush/pgrac-dsh`（独立于项目两仓）
- 当前日期：2026-08-16（据文件时间戳与最新 talk）
- 项目 talk 协作还在活跃期（writer epoch 32 于当日更新）
