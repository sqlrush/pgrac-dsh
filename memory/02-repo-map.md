# 02 — 两仓分工与路径地图

## 核心分工表

| 角色 | 本地目录 | GitHub 仓库 | 可见性 | CI |
|---|---|---|---|---|
| 公开代码 + 用户手册 | `~/linkdb` | `sqlrush/pgrac`（原 `pgrac-PostgreSQL-run-as-OracleRAC`，`linkdb` 为重定向别名） | PUBLIC | GitHub Actions（公开仓免费 unlimited） |
| 私有设计/推理 | `~/pgrac` | `sqlrush/pgrac-design`（原 `pgrac`） | PRIVATE | 不需要 |

- 2026-04-29 拆分为两仓（此前 ~/pgrac 同时持有代码 src/ 与设计文档）。
- 2026-06-15 GitHub 改名，本地 remote 已同步修正。

## 术语对照（易混，务必记牢）

- 内部旧称 **"linkdb"** = 公开代码库 = 本地 `~/linkdb` = GitHub `sqlrush/pgrac`。
- 内部旧称 **"pgrac"** = 私有设计库 = 本地 `~/pgrac` = GitHub `sqlrush/pgrac-design`。
- **陷阱**：GitHub 上 `sqlrush/pgrac` 是公开【代码】库，不是设计库。

## 可见性边界（三类内容）

| 类型 | 仓库 | 示例 |
|---|---|---|
| 代码 | linkdb（公开） | C/bash/perl + CI workflow + lint |
| 用户手册 | linkdb/docs/（公开） | 功能介绍、配置参考、CLI 用法、视图字段、等待事件参考、quickstart |
| 设计/IP | pgrac（私有） | spec、AD 决策、Oracle 对齐论证、知识置信度、路线图、CHANGELOG、CLAUDE.md |

边角判断：系统视图/等待事件的**字段说明**（怎么用）公开；其**设计理由/协议推理**私有。

## 跨仓引用约定

- 设计仓文档引用代码用 `linkdb:src/backend/cluster/...` 风格。
- 代码 tag 打在 linkdb 仓（如 `linkdb:v0.1.0-stage0.X`）；设计仓不打 tag，
  用 CHANGELOG.md 描述 spec 与 linkdb tag 的对应关系。

## 本地路径地图

- `~/pgrac/` — 设计仓工作树（main 分支，与 origin 分叉：领先 12、落后 261）
- `~/pgrac/.codex-candidates/stage8-d4b.LHbUJt` — **Stage 8 当前公共代码 worktree**
  （branch `agent/stage8-r3-r4d10-integration`，产品字节唯一合法修改点）
- `~/pgrac/.codex-candidates/stage8.git` — 备用 git 目录
- `~/pgrac/.worktrees/` — ~40 个历史 worktree
- `~/linkdb/` — 公开仓主工作树（当前 detached @ 238fe51d7c，有未提交修改）
- `~/linkdb/.worktrees/` — ~98 个历史 worktree（agent/*、s3-*、d11-*、r1-*、r4-*、backup/* 等）
- `~/pgrac/.claude/worktrees/` — 含 `linkdb-s3-source-authority` 等旧 worktree
- `~/pgrac/.p020-code`、`.p020-worktree`、`.public-worktree-p020` — 指向
  `/private/tmp/pgrac-p020.1hIcD7` 的软链，**目标已删除（悬空）**
