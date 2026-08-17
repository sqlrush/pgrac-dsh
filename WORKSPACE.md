# WORKSPACE — pgrac-dsh 工作区说明（仅本地，不推送）

> 本文件被 `.git/info/exclude` 排除，**永远不会进入公开仓库**。

## 这是什么

`~/pgrac-dsh` 是我（AI agent）服务 pgrac 项目的**独立工作区 + 自己的代码仓库**。

- 本目录本身是一个 git 仓库：本地 `main` 分支 = 上游代码的完整副本（含全部提交历史）
- GitHub 仓库：**https://github.com/sqlrush/pgrac-dsh**（公开，2026-08-16 建立）
- 上游来源：https://github.com/sqlrush/pgrac（项目的公开代码仓，remote 名 `upstream`）

## 目录布局

```
~/pgrac-dsh/                  ← 工作区根 = git 仓库（main 分支）
├── src/  docs/  diagrams/ …  ← pgrac 公开代码（与上游 main 一致）
├── AGENTS.md / README.md …   ← 上游公开仓库自带的文件
├── WORKSPACE.md              ← 本文件（仅本地）
├── MEMORY.md                 ← 核心记忆（仅本地）
├── MEMORY-CHANGELOG.md       ← 记忆更新日志（仅本地）
└── memory/                   ← 分主题记忆（仅本地）
```

## 记忆文件索引

| 文件 | 用途 |
|---|---|
| `MEMORY.md` | **核心记忆（快速热身）**——会话开始先读这个 |
| `memory/01-project-overview.md` | 项目背景与目标：pgrac = PG 上的 Oracle RAC |
| `memory/02-repo-map.md` | 两仓分工、路径地图、术语对照 |
| `memory/03-hard-rules.md` | 硬约束：公开/私有边界、命名约定、Oracle-first 门 |
| `memory/04-roadmap.md` | Stage 0-8 路线图、工程量、发布决策 |
| `memory/05-current-state.md` | 当前进行中状态（2026-08-16 快照） |
| `memory/06-talk-protocol.md` | pgrac-talk 0.2.10 Writer/Reader 协作协议 |
| `memory/07-file-map.md` | 两个仓库的关键文件/目录地图 |
| `memory/08-open-issues.md` | 悬而未决的问题与待办清单 |
| `memory/09-scan-notes.md` | 本次扫描的方法、覆盖范围与未读部分 |

## 远程仓库

| remote | URL | 用途 |
|---|---|---|
| `origin` | git@github.com:sqlrush/pgrac-dsh.git | **我的工作区仓库**（push/pull 到这里） |
| `upstream` | https://github.com/sqlrush/pgrac.git | 项目公开主仓（只读同步，fetch 用） |

## 工作纪律（重要）

1. **我的代码修改提交到 `origin`（sqlrush/pgrac-dsh）**，不碰项目的
   `~/linkdb`、`~/pgrac/.codex-candidates/*` 等权威仓库。
2. **本地记忆文件（本文件 + MEMORY.md + memory/）绝不 push**——它们包含
   设计推理摘要，按项目核心原则 0 必须私有。`.git/info/exclude` 已兜底，
   但每次 `git add` 前仍需自查 `git status`。
3. 需要上游最新代码时：`git fetch upstream && git merge upstream/main`。
4. 需要把成果回馈上游时：只提交代码/公开文档类的变更，经用户确认后
   以 PR 或补丁方式发往 `sqlrush/pgrac`，绝不直接 push。
5. 接手 pgrac 项目任务前，先读 `MEMORY.md` + `memory/05-current-state.md`，
   并对照 `~/pgrac/talk-current` 与 `~/pgrac/.pgrac-talk-state/` 的最新状态。

## 建立过程存档（2026-08-16）

1. 全盘扫描 `~/pgrac`（私有设计仓）与 `~/linkdb`（公开主仓本地副本），
   生成 12 个记忆文件。
2. `git init` + `remote add upstream https://github.com/sqlrush/pgrac.git`，
   fetch 全部 100 个远端分支 + 221 个 tag，checkout `main`（d50c76b99c）。
3. 经用户指示，在 GitHub 新建公开仓库 `sqlrush/pgrac-dsh`。
4. `remote add origin git@github.com:sqlrush/pgrac-dsh.git`，
   push `main` + 全部 tags（其余 WIP 分支未推送，保持仓库整洁）。
