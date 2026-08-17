# 05 — 当前进行中状态（2026-08-16 快照）

> **权威快照文档**：`~/pgrac/docs/2026-08-16-stage8-current-progress.md`
> （2026-08-16 16:21 生成，本文件是其摘要 + 我的分析；实时状态以 talk 为准）

## 一句话现状

- 顶层强制队列 **4/16**：RF-ROOT P6 / S05-5 P04 A2；队列 01-03 已完成
- RF-ROOT P0-P5 immutable GREEN；**P6 是 57 文件 +12,603/-267 的大型 RED checkpoint**
  （`aa213230f9e`，已公开合并为 `d50c76b99cd` 但非 GREEN 锚）
- P6 唯一 RED：未修改真实 `t243`——前 14 项通过，**node1 canonical ROOT ABSENT**，
  30 秒固定超时 `53R61`；根因是 t243 setup 没有调用 production ROOT producer
- Writer = STOP，需用户显式恢复；deviation 已被 Reader 判 RETURN_MAINLINE
- focused unit 91/91 GREEN、完整 build 通过——产品代码本身看起来是好的，卡在测试 provisioning
- 剩余约 105 个具名 D/gate；队列 05-16 未开始

## 快照来源

> 快照来源：`~/pgrac/talk_20260816-0052.md`（talk-current 指向）、
> `~/pgrac/.pgrac-talk-state/{writer,reader}/state.json`、
> `~/linkdb` 与公共 worktree 的 git 状态。

## 里程碑与阶段位置

- 里程碑：`ST8-M01-P4-S0414`
- stage8_position：`04 RF-ROOT P6 S05-5 P04 A2 PUBLIC-MERGED`
- **Stage 8 正式验收最新目标（user 2026-08-16 指令）**：相同配置的 4 节点存写场景
  TPS 性能超过 Oracle（替代"4×1×3 正确性+性能+三轮稳定性"口径；8-C 30 TPS 判据为历史合同文本）
- **执行策略调整（user 2026-08-16 指令）**：见工作区 `memory/10-stage8-plan-adjustment.md`——
  R11 后加 G-TPS-R11 中间采样（单轮零错 + TPS 三档判据），R16/R17 明确为接棒位，
  最终 verdict 在 R17 之后（~/pgrac 只读，调整只存本工作区）
- 当前线程：Scheme A（方案 A，用户已批准）——「recovery authority / serving split」
  - 语义：generation-bound OFF/STARTING → RECOVERY_AUTHORITY_READY → SERVING_READY
  - phase3 CF(S) / canonical WALR(X) recovery 访问 allowlist
  - 执行器归属：PostmasterMain 停止执行 live-formation/readiness/bind/barrier-arm，
    **改由真正的 StartupProcess 执行**（在 recovery WAL-retention 决策之前）；
    LMON 保留 ProcArray / holder redeclare / peer DONE / cleanup / final seal 所有权
  - 无本地 try-lock 变通、无重复 GRD/GES 执行器

## Writer 状态

- session：`01a00358-a64e-7040-8e9e-cae49b73d9ff`；lease epoch 32
- 最近活动：已把 `d50c76b99c` 发布到 GitHub 公共 main（parents
  `35548cd7d67` + `aa213230f9e`，merge tree 等于后者）
- **next_action = STOP**：t243 仍为已知 RED —— canonical node1 ROOT 缺失；
  若显式恢复，按 Reader 的 RETURN_MAINLINE（沿用已有 ROOT-producer 补救）继续

## Reader 状态

- session：`01a00855-6444-7802-a127-f771336773a1`
- 最近活动：签 Reader 决策 `RFROOT-P04-A1-T243-SHAREDCF-WITNESS-CONFLICT-20260816`
- next_action：按 pgrac-talk 0.2.10 保持轮次存活，跑 60 秒 monitor，
  只处理持久化的 Oracle/Spec 事件

## 未决告警（最重要）

- **P0 EMERGENCY-HOLD**：`RFROOT-P04-A-ROLLOVER-CLOSE-AUTHORITY-SMUGGLE-20260816`
  - milestone：ST8-M01-P4-S0414；predicate：`TALK_AUTHORITY_FORK`
  - 位于 talk 文件的 `[READ-ALERT P0]` 区段，详情需读 talk 该节
- 三个已 CLOSED 的告警（证据已归档）：
  - `RFROOT-P04-A-FIRST-FAILURE-BYPASS-FORMATION-REFRESH-20260816`
  - `RFROOT-P04-A-PHASE3-POSTMASTER-NO-PGPROC-20260816`
  - `RFROOT-P04-A-ONION-ROUND3-DESIGN-REEVAL-20260816`

## 测试基线（talk 记录的最近聚焦结果）

- startup 19/19；GES 25/25；lock 19/19；GRD 91/91
- IC router 18/18；GCS substrate 105/105；RDMA 9/9；reconfig 85/85；
  clean leave 11/11；node remove 13/13；LMS shard/lifecycle 10/10
- 真实 TAP `t/424_wal_retention_reuse.pl`：8/8 PASS
- 已知 RED：`t/243_wal_thread_2node_shared_root.pl`（canonical node1 ROOT 缺失）

## 代码仓库现场状态

### 公共 worktree（产品字节唯一合法修改点）
`~/pgrac/.codex-candidates/stage8-d4b.LHbUJt`，branch `agent/stage8-r3-r4d10-integration`
- 最近提交：`aa213230f9`（checkpoint Stage 8 RF-root work）等
- 未跟踪残留：pgrac-fenced 二进制、大量 `tmp_s0414_*` TAP 临时目录

### ~/linkdb 主工作树（⚠️ 有悬空改动）
- detached HEAD @ `238fe51d7c`（2026-07-02 backup PITR hardening 系列）
- **17 文件未提交**（+436/-49）：
  - `cluster_remote_xact.c`（+127 行，最大）
  - `cluster_tt_durable_stat.c`（+98）
  - `cluster_debug.c`、`cluster_guc.c`、`cluster_tt_status.c`、`cluster_visibility_resolve.c`
  - 头文件 `cluster_guc.h`、`cluster_remote_xact.h`
  - 测试：`030_acceptance.pl`、`214_cluster_3_8_undo_lifecycle.pl`、`test_cluster_debug.c`、cluster_unit Makefile
  - docs：perf-gates.md、system-views.md、configuration.md、run-cppcheck.sh
  - 归属不明——需要确认是哪个会话/分支的残留，不要直接丢弃或提交

### ~/pgrac 设计仓
- main 与 origin/main 分叉（本地领先 12、落后 261）
- 未提交：AGENTS.md、CLAUDE.md、_graph MOC、4x1x3-run-log、若干 report 文件

## 近期已冻结成果（最近两周 talk 线）

- RF-ROOT P4 happy path、P5 publishers、外部 fencing foundation
  （公共 worktree 提交 `e13af60e30` → `aa213230f9` 系列）
- member BARRIER local-close、coordinator PREPARED origin（公开提交
  `18d0b8c6af`、`3c1b675182`、`f980157af8d` 等）
- 四节点 SAMPLE/ACK receiver 语义激活（公开提交 `f980157af8d`）
- backup PITR e2e 加固（linkdb 主树 `238fe51d7c` 附近）
