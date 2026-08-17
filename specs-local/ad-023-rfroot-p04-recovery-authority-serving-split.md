# AD-023 — RF-ROOT P04 恢复权威与服务权威分离

| 项 | 值 |
|---|---|
| 状态 | `APPROVED / FROZEN` |
| 用户锚 | 2026-08-15：`方案 A（推荐）` |
| Reader 锚 | `READ-DECISION RFROOT-P6-S05-5-P04-RECOVERY-AUTHORITY-SERVING-SPLIT-20260815` |
| 适用范围 | `ST8-M01-P4-S0414`，RF-ROOT P6 / S05-5 P04，current-owner OPEN E2 |
| 不包含 | failed-origin `RECOVERY_REQUIRED`、E2 之外的新恢复协议、持久格式或 wire 变更 |

## 1. 触发原因与两轮证据

同一 E2 pre-recovery authority 因果链已经完成两轮局部修复：

1. 第一轮把 CSSD、QVOTEC、READY/quorum 从 phase4 移到 phase3。focused startup unit 从
   `4/13 RED` 到 `15/15 GREEN`，但 TAP 424 仍以 formation reason16 阻塞。
2. 第二轮在 phase3 增加 existing live-formation bounded wait。focused startup unit
   `16/16 GREEN`，TAP 424 从 reason16 前进到 reason4，同时候选文件 SHA/size 仍零 mutation。

reason4 的直接链是：E2 `cluster_wal_retention_action_begin` → BOOTSTRAP_VALIDATE → STRONG
root read → `cluster_cf_lock(ShareLock)` → seven-step S1 → exact LMS READY。LMS 原在
StartupXLOG 之后的 phase4。若第三轮只把完整 LMS 提前，现有 GCS 又把 CSSD ALIVE + quorum +
MEMBER 当作恢复完成代理，会让 cold serve/conflicting grant 在 StartupXLOG 完成前可达。

缺失的不变量是：**成员/恢复协调权威不等于普通数据服务权威**。这触发 AGENTS.md 的同一因果链
第三轮设计重评；用户选择方案 A，Reader 随后冻结本 AD 的精确合同。

## 2. Oracle 证据与未知边界

### 2.1 Oracle 官方事实

- `O23-01`：ORA-29701 的官方动作要求 CSS 未启动时先启动 CSS，再重试数据库启动：
  <https://docs.oracle.com/en/error-help/db/ora-29701/>。
- `O23-02`：Oracle Clusterware 官方文档说明 CSS 控制集群成员关系，`cssdagent` 提供 I/O
  fencing：<https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/introduction-to-oracle-clusterware.html>。
- `O23-03`：Oracle RAC 官方文档要求节点先启动 Grid Infrastructure stack，RAC instance 才能
  启动；数据库 `MOUNT` 可执行恢复但不允许普通访问，`OPEN` 才提供正常数据访问：
  <https://docs.oracle.com/en/database/oracle/oracle-database/21/racad/administering-database-instances-and-cluster-databases.html>
  与 <https://docs.oracle.com/database/121/ADMIN/start.htm>。

### 2.2 推断与 PGRAC adaptation

- `I23-01`（公开证据推断）：cluster membership/fencing 可先于数据库普通服务；恢复阶段可以拥有
  比普通 OPEN/serving 更窄的内部权威。
- `U23-01`（`UNVERIFIED`）：Oracle 没有公开 PGRAC 的 phase 编号、LMS worker generation、
  recovery-only GES allowlist、内部 wire、CF/WALR resource 编号或 publish/clear 算法。
- 本 AD 的双 readiness、generation binding、CF/WALR allowlist 和 gate 落点均为
  `PGRAC ADAPTATION / NO-MATERIAL-DEVIATION`，不得表述为 Oracle RAC 内部协议。

## 3. 冻结状态机

```text
OFF/STARTING
    -> RECOVERY_AUTHORITY_READY
    -> SERVING_READY
```

- 只允许单调前进；禁止 `OFF/STARTING -> SERVING_READY`。
- 状态是易失 shared-memory authority，不新增 on-disk、WAL 或 wire 格式。
- readiness 绑定 current boot、当前 QVOTEC admitted incarnation、同一 live formation 和当前 LMS
  worker generation。任一为零、未知、漂移、上一 boot 或上一 worker generation 都不承权。
- `RECOVERY_AUTHORITY_READY` 只有在 CSSD READY、QVOTEC READY、quorum、exact live formation
  全部 current，且 CF/WALR 的全局 holder truth 已恢复/重主或请求可路由至已证明的 current
  serving master 后才可发布。空/新 GRD、缺失 holder state、`OK_NATIVE` 或 native/local fallback
  一律不满足。
- phase4 只有在 StartupXLOG 成功后才能复用同一 LMS child，初始化普通 GES/GCS/CR/PCM data
  plane，并原子发布 `SERVING_READY`；不得重复 spawn。DIAG/STATS 仍归 phase4。
- LMS loss、quorum/formation loss、rollback、crash、shutdown 或 generation drift 必须先使两个
  readiness 都失效，再允许重启或后续服务；旧 READY 不得跨 generation 存活。

## 4. 恢复态精确 allowlist

本地 recovery access 必须同时满足：

- caller 是 `StartupProcess`；
- current phase 是 phase3；
- boot/recovery/readiness generation 全部 exact current；
- resource/mode 恰为以下之一：

| Resource | 编号 | 唯一允许 mode | 用途 |
|---|---:|---|---|
| CF singleton | `0xF1` | `ShareLock` | E2 STRONG canonical root read |
| WALR canonical per-thread | `0xFA` | `ExclusiveLock` | StartupXLOG E2 destructive-retirement guard |

Ingress、master 和 grant 三处必须独立复核 preserve/release 这两个 recovery request 所需的
操作，且不能丢失它们的全局冲突真值。其他 resource、mode、caller、ordinary GES/GCS grant、
GCS block/data serving、PCM-X、CR、ordinary reconfiguration 和 serving action 均 fail closed。
CSSD ALIVE、quorum、MEMBER 只表示 control-plane 事实，不再推导 serving。

ordinary egress/peer selection 与 local ingress/grant/serve 都必须校验 current-generation
`SERVING_READY`。恢复 allowlist 不是 ordinary service 的替代入口。

## 5. 验收门

- 状态机：合法两步、禁止跳转、旧 boot/incarnation/formation/LMS generation 拒绝。
- allowlist 正向：仅 phase3 StartupProcess 的 CF(0xF1/S) 与 WALR(0xFA/X)。
- allowlist 负向：错误 caller、phase、mode、resource、generation、空 GRD、缺 holder truth、
  `OK_NATIVE`/local fallback 全拒绝。
- recovery-ready 期间 ordinary GES/GCS/CR/PCM-X/reconfig/data serve 均不可达；master-side 与
  requester-side 都有 fail-closed witness。
- phase4 同一 LMS child 复用、无 double spawn；StartupXLOG 成功前无 `SERVING_READY`。
- LMS/quorum/formation loss、rollback/crash/shutdown 清理 readiness，旧 generation 不复活。
- TAP 424 先证明 E2 intersecting candidate 精确 reason5/53RBA 且 SHA/size 零 mutation，再证明
  frozen disjoint positive retirement。

## 6. 迁移与回滚边界

这是单一 current binary、易失 shared-memory cutover；不增加 mixed-version wire 或持久迁移。
实现若未通过任一 gate，回滚方式是清空 readiness、停止/回收 phase3 LMS，并在 E2 mutation 前
维持 53RBA fail-closed；不得退回 CSSD ALIVE/MEMBER 即 serving、不得放宽 STRONG root、不得启用
native/local fallback。产品 rollback 不修改已存在的 root/WALR durable bytes。

## 7. 方案处置

- `A`：`APPROVED / FROZEN`，即本文双 readiness 与 recovery-only CF/WALR 权威。
- `B`：未选择；不建立无 CF 的 bootstrap root 旁路。
- `C`：`REJECTED`；不在单一 readiness 下直接前移完整 LMS/data plane。

## 8. A1 no-PGPROC 执行合同补充（2026-08-16）

### 8.1 权威锚与实证

- 用户锚：Reader 给出 `A1/B1/C1` 精确映射后，用户选择 `A1`。
- Reader 锚：`RFROOT-P04-A1-NOPGPROC-CONTRACT-20260816` 与
  `RFROOT-P04-A1-PHASE3-CALLGRAPH-CLOSURE-20260816`。
- 第一个不可变崩溃锚：`postgres-2026-08-16-004834.ips`，证明 Postmaster/no-PGPROC 在
  formation snapshot 的 blocking LWLock 上 PANIC。
- 第二个不可变崩溃锚：`postgres-2026-08-16-083717.ips`，证明 formation edge 改为
  conditional 后，同一 phase3 链前进到 `GRD DONE enqueue -> cluster_lmon_wakeup ->
  cluster_lmon_pid -> LWLockAcquire` 并再次 PANIC。
- 完整调用图审计还发现同一 Postmaster barrier 链含 outbound-ring 排他锁与 post-barrier
  GRD shard cleanup 锁；因此只修 `cluster_lmon_pid` 仍会留下同因果链阻塞边。

### 8.2 Oracle 映射与未知边界

- 继承 `O23-01..03`：Oracle 公开资料支持 membership/fencing 先于数据库普通服务，以及
  MOUNT/recovery 与 OPEN serving 分层。
- 继承 AD-021 的 Oracle LMON 公开角色证据：LMON 协调 GCS/GES recovery。
- Oracle 没有公开 Postmaster/PGPROC/LWLock、PGRAC request generation、terminal slot 或内部
  retry 算法；这些精确机制保持 `UNVERIFIED / PGRAC ADAPTATION`，不得宣称 Oracle wire parity。
- 本补充不改变 recovery/serving authority 语义，只把既有阻塞 recovery 工作放回已冻结的
  LMON actor，并让无 PGPROC 的 coordinator 只做非阻塞发布与有界观察；公开角色层面为
  `NO-MATERIAL-DEVIATION`。

### 8.3 冻结执行合同

1. phase3 Postmaster 只发布一个易失、request-generation 绑定的 recovery-authority request；
   其读边只能使用原子读取或 conditional LWLock，锁竞争表示 unavailable。
2. formation、CSSD、phase-state 与 LMON identity 的 Postmaster 读取不得排队等待；只在现有
   phase3 deadline 内重试，deadline 到期 fail closed。
3. 既有 LMON 是唯一 blocking executor：outbound enqueue/wakeup、holder redeclare、peer-DONE
   收集、stale-epoch cleanup 与 final seal 均不得在 Postmaster 执行。
4. terminal 必须同时绑定 request generation、boot incarnation、当前 QVOTEC/live formation
   epoch/hash 与同一 LMS generation；任一 loss/mismatch/rollback/crash/shutdown/deadline 都使
   request/result 失效。
5. 不新增 actor、wire、持久格式、authority 语义、workload/judge，也不实施 C1 whole
   StartupProcess relocation。

### 8.4 验收与回滚

- unit RED/GREEN 必须证明 no-PGPROC read contention 从不调用 blocking acquire，且只在既有
  deadline 内重试；普通有 PGPROC caller 保留原 blocking 语义。
- unit 必须证明 Postmaster 不能直接完成 redeclare/cleanup/seal；只有 LMON tick 能发布匹配
  generation terminal，stale/cancelled terminal 不承权。
- 未修改的真实两节点 `t/243_wal_thread_2node_shared_root.pl` 必须越过两份 crash anchor，且
  生产 REDECLARE_DONE 收敛后才能称 GREEN。
- 回滚时清零 request/terminal/readiness 与 volatile GRD seal，保留原 root/WALR durable bytes；
  不允许退回 Postmaster blocking barrier 或 native/local fallback。

## 9. A2 fast-rejoin episode 控制权补充（2026-08-16）

### 9.1 批准锚与证据边界

- 用户锚：在同一 fast-rejoin authority/lifecycle 因果链第三轮强制设计重评中，用户精确选择
  `B`；对应 talk 对象为
  `RFROOT-P04-A2-ONION-SCHEME-B-USER-BINDING-20260816`。
- Reader 回执：`RETURN_MAINLINE`，确认 B 与已批准 P04 fast-rejoin slice 的 episode-bound
  control-plane 主线相同，可继续实现；不新增第二次 user gate。
- 实证链：round 1 发布 synthetic `FAIL_STOP 0 -> 1`；round 2 阻止 prior-unclean 节点退回
  cold-bootstrap；round 3 的未修改 t243 通过 14 项断言后，survivor 发布 `JOIN_PENDING`
  epoch 2，随后 formation 变化使 `SERVING_READY` 失效，LMON 无法进入
  `JOIN_COMMITTED`，joiner 在固定 30 秒后报 `53R61`。
- 继承 `O23-01..03` 与 AD-021 LMON 公开角色证据：Oracle 公开材料支持 membership/fencing、
  GCS/GES recovery control 与普通 OPEN serving 分层。Oracle 未公开等价的内部 capability、
  tuple、状态编号或清理算法；下述精确机制为 `UNVERIFIED / PGRAC ADAPTATION /`
  `NO-MATERIAL-DEVIATION`，不得宣称 Oracle wire parity。

### 9.2 冻结 capability 合同

1. capability 是 LMON process-local、易失且单 episode；只在 shared-CF incarnation rollover
   对应的 synthetic FAIL_STOP 已成功发布后建立。
2. capability 精确绑定 `{target node, target incarnation, singleton join bitmap,
   failstop event_id/new_epoch, local boot incarnation, LMS generation}`。零值、变化、丢失、
   LMON/LMS 重启、crash、shutdown 或事件链不连续均立即失效，不得从旧 shmem 状态重建。
3. 该 capability 只允许同一 target 的既有
   `FAIL_STOP -> JOIN_PENDING -> JOIN_COMMITTED -> redeclare` 控制面事务跨越自身造成的
   formation 变化；不得授权第二个 joiner、新 FAIL_STOP、replacement、clean leave、node
   removal、external-fence operation 或其他普通 reconfiguration。
4. capability 不发布或恢复 `SERVING_READY`，不授权 ordinary GES/GCS/CR/PCM-X/data serve，
   不打开 joiner write gate；这些路径继续使用原 current-generation serving/admission 证明。
5. `JOIN_COMMITTED` 成功、target/incarnation/event mismatch、取消或任何终止失败都清除
   capability。清除后若 `SERVING_READY` 仍非 current，则所有普通动作保持 fail closed。
6. 不增加 wire、WAL、control-file、catalog 或其他持久格式；不改变 t243 workload、断言、
   顺序、restart mode、timeout 与 pass/fail judge。

### 9.3 RED/GREEN 与回滚边界

- 行为级 RED 必须复现：managed serving 因 `JOIN_PENDING` stale 后，没有 staged marker 的
  Phase 2 仍应只为绑定 target 进入 COMMITTED marker；未绑定 peer 不得被夹带。
- generation/incarnation/event mismatch 必须证明 capability fail closed；普通 managed-serving
  join 仍须等待 current `SERVING_READY`。
- focused unit 与完整 build/install GREEN 后，运行未修改真实 t243；只有
  `JOIN_COMMITTED`、redeclare、原 gate-open 顺序和固定 judge 全部收敛才算本补充 GREEN。
- 回滚只删除该 process-local capability，保留 boot/data-serving fence；不得用恢复普通
  serving、扩大 stage-pending 特例或修改测试时序替代本合同。

---

## 10. A3 crash-rejoin self-join 例外合同（工作区本地增量，2026-08-17）

> 来源：产品提交 `c4b2357723`（break the crash-rejoin phase-3 deadlock cycle）。
> 本文原文 §9.2 的 capability 合同针对 online fast-rejoin；本增量补充 crash-rejoin
> （kill -9 后重启、online_join=off、53R60）场景下的绑定。原文一字未改，本增量
> 仅在本工作区生效；是否并入私有库由 user 裁决后同步。

### 10.1 死锁圈（必须随合同出现的故障形状）

```
boot_decided=0 → LMON tick 把 self 降级 JOINING
→ phase-3 recovery-authority barrier request-current 失败
→ GRD authority seal 永不盖章 → transport 不 current
→ GES early-opcode gate 丢弃 survivor 的 REDECLARE_DONE
→ join view 永不重建 → boot_decided 保持 0（闭合）
```

### 10.2 解锁前提（AD-023 §9.2.3 的适用读法）

- crash-rejoiner 的 applied event 恒为空：`last_applied.event_id == 0`、
  `applied.new_epoch == 0`，而 local epoch 已由 durable JCMK 回调
  （qvotec self-admit → `cluster_reconfig_note_self_admitted`）采纳为 admitted epoch。
- 因此 §9.2 冻结的 `{target, incarnation, singleton, event_id/new_epoch}` 六元组中，
  event 两元对 self-join 本体不适用；**membership 证明唯一来自 durable JCMK 准入**
  （`ReconfigShmem->self_join_admitted`，note_self_admitted 在真实状态变化时置位、
  fence-authority cache 只在真实变化时失效）。

### 10.3 六个窄例外门（全部键 durable 准入，禁止伪造事件）

| # | 门 | 例外形状 |
|---|---|---|
| 1 | formation witness（`formation_witness_decide_live_v1`） | self-join 时 settled-epoch 门与 marker 元组门放行：`self_join_admitted` 成立即视为 formation settled，不要求 applied event 与 expected marker 相等 |
| 2 | `cluster_reconfig_note_self_admitted` | 发布 admitted-incarnation floor（`record_admitted(self, …)`）；fence cache 仅真实变化时 invalidate |
| 3 | recovery-authority barrier wait | self-join 的 epoch 例外：barrier 预条件按 admission-aware membership 判定 self |
| 4 | GES early-opcode（`ges_readiness_allows_early_opcode`） | REDECLARE_DONE 在组件货币性（admission-aware membership）上放行，无需 GRD seal |
| 5 | LMON tick self-state 门 | durably admitted 的 fast rejoiner 在 boot-decided latch 持有期间保持 MEMBER（block-level boot fence 仍 fail-closed，写门不放开） |
| 6 | `grd_recovery_authority_request_current` | self 用 admission-aware membership 判定 current |

### 10.4 边界（与 §9.2.4/9.2.5 一致，不放松）

- 不发布/恢复 `SERVING_READY`；不放开 joiner write gate；不授权第二 joiner、
  FAIL_STOP、replacement、clean leave、removal 或 external fence；
- 不新增 wire/WAL/control-file/catalog 持久格式；t243 workload/judge/顺序/timeout 不变；
- 每个例外都是"证明源从内存事件切到 durable JCMK 准入"的窄缝，不是 authority 放宽。

### 10.5 RED/GREEN 证据

- 行为 RED：06:55 诊断 `witness owner fail: local_epoch=3 applied_new_epoch=0
  applied_event_id=0 self_join_admitted=1`（死锁圈第 5 环的现场证据）；
- GREEN：t243 ok 18/19（L4 crash-rejoin 核心腿）于 08:54 轮起反复通过；
  剩余 L5 第二段 rejoin 为下一闭环项，非本合同的例外面。
