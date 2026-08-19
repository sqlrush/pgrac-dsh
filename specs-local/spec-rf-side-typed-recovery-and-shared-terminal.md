# RF-SIDE — Typed recovery over shared transaction and space truth

> **Status: EXACT BODY ACCEPTED BY CC — USER APPROVED; PRODUCT AUTHORIZATION=1; SIDE JIT GATES MANDATORY / OPEN**
>
> User 于 2026-08-05 批准 Oracle-first baseline，CC 随后对本 exact normative body 返回
> `ACCEPT`。User 已将 `PRODUCT AUTHORIZATION` 翻为 `1` 并批准 Stage-8 执行计划。
> `JIT-SIDE-RESERVED` 与 `JIT-COLD-RETRY` 仍是 mandatory/open gate；本状态翻转不得
> 被解读为 orphan-RESERVED predicate/owner 或 cold-retry policy gap 已闭合。

| 可变元数据 | 值 |
|---|---|
| 决策日期 | 2026-08-05 |
| exact product evidence | `f076653df977dfa67c1f8fdaa1f985daf0a240b4` |
| normative body SHA-256 | `17b062d1c5eed83516912e7158ab73fc2f5751148c7cfddf90ae6ea8ad62cdac` |
| normative body lines / bytes | `734` / `64241` |
| SPEC EDIT AUTHORIZATION | `1` |
| PRODUCT AUTHORIZATION | `1` — **STAGE-8 EXECUTION ACTIVE** |
| Stage-8 JIT gates | **MANDATORY / OPEN (NOT CLOSED)** — `JIT-PAGE-AUTH`, `JIT-PAGE-ROUTE`, `JIT-SIDE-RESERVED`, `JIT-COLD-RETRY`; 本 spec 的受影响语义为后两项 |
| formal 目的地 | 高性能真实 `4×1×3 + rate10/20/30`；本文不声称已运行或已通过 |

<!-- NORMATIVE-BODY-BEGIN -->

## §0 决策摘要、证据与历史边界

### §0.1 Oracle-first 决策

RF-SIDE 采用 AD-019 的 2026-08-05 user-approved baseline，并只拥有 side-domain 语义：

1. normal transaction truth 是 **shared undo transaction table（TT）+ shared undo + terminal
   redo**。任何 local status store、cache、counter 或 replay cursor 都不能覆盖这份 truth。
2. `PREPARED` / in-doubt transaction 由 **database-scoped durable pending state**、matching TT/undo
   与 prepare/terminal redo 共同承担；resolution 采用 RECO-style responsibility，不把缺失状态猜成
   commit 或 abort。
3. PostgreSQL `CLOG`、`MULTIXACT`、`COMMIT_TS` 是 named PGRAC **derived projections**。每份
   projection 必须有 canonical producer、失效条件、可执行 rebuild 或 fail-closed 规则、以及
   verification；projection 永远不能反向修改 transaction truth。
4. HWM、extent allocation 与 allocation bitmap 的 authority 是 **WAL-logged shared canonical
   metadata page**。volatile master-local table 只能是 cache；per-master checkpoint image 不能成为
   steady-state authority。
5. canonical metadata page 消费 RF-PAGE 的 `PageVersion`、exact `expected-before`、source
   provenance、durable post-read 与 exhaustive page-class contract。RF-SIDE 不定义这些字段或 codec。
6. 一个 record decoder、一个 exhaustive route table、一个 primitive graph 服务 cold 与 online
   failed-thread recovery。每个 component 只得到 `APPLY`、`PROVED_NOOP` 或 `BLOCKED`；unknown
   rmgr/opcode/class 默认 `BLOCKED`。
7. readiness、release 与 access fence 按 exact transaction、undo segment、space-metadata resource、
   block 或 failed thread 生效。一个 resource ready 不证明另一个 resource 或整个 instance ready。
8. failed-origin WAL retirement 只消费 AD-019 `FND-10` 的单一公式。RF-SIDE 只产生 TT/undo、
   pending-2PC 与 space-metadata domain proof；不签发 root retirement，也不另建 terminal carrier。
9. normal transaction 新增同步 network RTT、fsync/fdatasync wait 与 shared-control-file I/O 都必须是
   `0/0/0`；恢复路径可以付出 durable verification 成本。

### §0.2 Oracle evidence ledger

| ID | 分类 | 公开事实或边界 | RF-SIDE 允许加载的结论 |
|---|---|---|---|
| OE-SIDE-01 | `ORACLE OFFICIAL FACT` 🟢 | Oracle RAC 每 instance 有自己的 redo thread，failed-thread redo 位于 shared storage，可由 survivor 做 instance recovery。[Oracle 26 Redo Threads](https://docs.oracle.com/en/database/oracle/oracle-database/26/adrac/rac_redo_threads.html) | duty 输入是 failed-origin redo，不是 recoverer-local side file |
| OE-SIDE-02 | `ORACLE OFFICIAL FACT` 🟢 | instance recovery roll forward committed changes，并 rollback incomplete transaction。[Oracle 19 Database Instance](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/oracle-database-instance.html) | terminal redo、TT 与 undo 是 normal transaction recovery truth |
| OE-SIDE-03 | `ORACLE OFFICIAL FACT` 🟢 | Oracle 把 transaction 分配到 undo tablespace 的 transaction tables；database recovery 使用 undo records 撤销从 redo log 应用到 datafiles 的 uncommitted changes。Source: AD-019 `OE19-06`（Oracle 26 Managing Undo） | TT/undo + redo 是 normal recovery truth；不能外推未公开的 segment-header bytes |
| OE-SIDE-04 | `ORACLE OFFICIAL FACT` 🟢 | prepared/in-doubt distributed transactions 由 database pending-transaction state 与 RECO 管理。Source: AD-019 `OE19-07`（Oracle Database Administrator's Guide, Managing Distributed Transactions） | PREPARED 单独进入 durable pending state；resolution 与普通 outcome lookup 分离 |
| OE-SIDE-05 | `ORACLE OFFICIAL FACT` 🟢 | Oracle tracks segment HWM；ASSM 使用 bitmap/bitmap blocks 记录 segment block-space state并寻找free blocks。Source: AD-019 `OE19-08`（Oracle 26 Logical Storage Structures） | 只支持 shared database metadata responsibility；不证明PGRAC page/redo codec |
| OE-SIDE-06 | `ORACLE OFFICIAL FACT` 🟢 | recovery resources 按 block/resource 恢复并 release；未受影响资源可更早开放。[Oracle9i RAC Concepts](https://docs.oracle.com/cd/A97630_01/rac.920/a96597.pdf), pp.72-73 | readiness 只能是 resource/thread scoped，不建立整实例 side-domain barrier |
| OE-SIDE-07 | `EVIDENCE-BASED PGRAC IMPLICATION` 🟡 | exact-f076 保留 PG status stores 且 PG visibility API 深度依赖它们 | CLOG/MULTIXACT/COMMIT_TS 保留为 derived projection；这不是 Oracle internal |
| OE-SIDE-08 | `PUBLICLY UNKNOWN` ⚫ | public Oracle material 未公开 PGRAC 对应的 TT/undo page bytes、pending-state bytes、HWM page layout、redo opcode 或 latch/actor API | 本文只能冻结 responsibility、ordering 与 fail-closed 边界，不能发明 ABI |
| OE-SIDE-09 | `EVIDENCE-BASED PGRAC IMPLICATION` 🟡 | AD-019 `FND-08`把Oracle shared-metadata responsibility与exact-f076 volatile-HWM缺口映射为WAL-logged shared canonical metadata page | 这是user-approved PGRAC mapping，不得冒充Oracle literal carrier |

Oracle 证据约束职责与外部语义；它不证明 PGRAC 的 C struct、文件名、rmgr opcode、page offset、
lock ID、message family 或 function name。任何新增 exact carrier/field/API 都重新触发 Rule 26。

### §0.3 exact-f076 只读事实

以下事实只绑定 object `f076653df977dfa67c1f8fdaa1f985daf0a240b4`：

| ID | exact evidence | 本 spec disposition |
|---|---|---|
| EX-SIDE-01 | `cluster_undo_alloc.h:91-138` 的 foreign recovery materialization 是 node-local；foreign shared path 只读 block 0 | 现有 local materialization 不能成为 shared transaction truth；迁移路径尚未成立，记 G3 gap |
| EX-SIDE-02 | `xact.c:6463-6477,6775-6794` 与 `cluster_undo_xlog.c:275-374,738-1092,1593-1650` 已有 shared undo TT 与 TT redo producer/consumer | 作为最接近 canonical substrate；业务 truth 与 exact ordering 可复用，恢复 mutation authority 仍须 future census |
| EX-SIDE-03 | `cluster_remote_xact.c:4-16,170-261,495-500,644-934` 的 independent status materialization 是 per-origin node-local `pg_xact_remote`，使用 `SYNC_HANDLER_NONE`；MULTIXACT/COMMIT_TS 被 blocked，PREPARE 不创建 database pending state | 该路径不能继续作 authority；local SLRU 只能降为 projection，缺失 pending state 是 P0 gap |
| EX-SIDE-04 | `twophase.c:28-68,621-633`、`xact.c:7048-7099` 与 `cluster_tt_2pc.h:6-20,64-75` 表明 PG 有 durable database-scoped 2PC state，但 current cluster binding 假设 origin-local ownership | 复用 database-scoped responsibility；exact cluster binding、migration 与 recovery writer 尚未成立，记 G3 gap |
| EX-SIDE-05 | `cluster_hw.h:15-26`、`cluster_undo_xlog.c:217-272`、`cluster_hw_shmem.c:323-371,518-655`、`cluster_hw_remaster.c:436-510` 的 HWM authority 是 volatile master-local shmem 加 per-master adoption image；`XLOG_HW_RESERVE` 只是 24-byte delta | 现状不满足 canonical metadata；不得把 24-byte delta 冒充已批准 page ABI |
| EX-SIDE-06 | page recovery 是 direct `smgrwrite`；TT/undo replay 是 direct `pwrite/fsync`；status materialization 是 local SLRU；HWM 是 shmem；这些路径未发现 recovery-generated successor `XLogInsert` | 继承 `FND-10` retention 与 `STOP-RF-PAGE-STABLE-BASE`；logical apply 不是 durable/restart proof |
| EX-SIDE-07 | exact-f076 没有已验证的 R4A、`recovery_private` 或 `RECOVERY_CANONICAL_SHARED` symbol/actor substrate | 本文不得宣称 recovery mutation substrate 已存在；实现前 G1/G1′/G1″/G3 必须重做 exact census |
| EX-SIDE-08 | replay dispatcher 只显式 divert XACT/CLOG/MULTIXACT/COMMIT_TS | 保留单 decoder/total route 的目标；删除第二白名单与 silent fall-through |

### §0.4 superseded history（非现行设计）

下列词只用于审计旧设计，全部 `HISTORICAL / REJECTED / SUPERSEDED`：

| stale mechanism | disposition |
|---|---|
| independent OUTCOME resource family `0xFA`、typed descriptor 与 standalone outcome authority | `REJECTED`；normal outcome 从 TT/undo/terminal redo 导出 |
| durable receipt、two-slot terminal、`RecoveryDomainManifest` | `REJECTED`；不再建立 side-domain persistent terminal family |
| per-master HWM snapshot/receipt | `REJECTED`；steady authority 改为 canonical metadata page |
| `GLOBAL_DONE -> LOCAL_READY -> RETIRE_CERTIFICATE` all-domain chain | `REJECTED`；不再作为 correctness 或 future-join barrier |
| “R4A recovery mutation substrate already exists” | `REJECTED AS UNSUPPORTED FACT`；exact-f076 未找到对应 symbol |

历史文字不能被 implementation、test 或 compatibility code 引用为现行 contract。

---

## §1 范围、ownership 与 prospective deliverables

### §1.1 本轮包含

- 只修改本 RF-SIDE 私有 spec。
- 冻结 transaction/2PC truth、derived projection、canonical space metadata、exhaustive route 与
  resource-scoped readiness 的业务合同。
- 消费 AD-019 `FND-01`–`FND-05`、`FND-08`–`FND-11`；消费 RF-ROOT future authority/retention proof
  和 RF-PAGE future page proof，但不定义它们的 exact field/API。
- 明确 exact-f076 已存在 substrate、G3 gap、Rule-26 STOP 与后续 TDD RED。
- 继承 `STOP-RF-PAGE-STABLE-BASE`，并新增仅针对未批准 space page/redo ABI 的
  `STOP-RF-SIDE-SPACE-ABI`。

### §1.2 prospective product deliverables（需单独授权）

下表只描述 responsibility 与目标文件面，不冻结 ABI、LOC、field、message 或 persistent layout：

| D | prospective scope | 最小交付与 hard gate |
|---|---|---|
| D-SIDE-01 | existing recovery dispatcher / new shared helper location待 G1 决定 | single decoder、total route registry、cold/online common primitive graph；unknown default BLOCKED |
| D-SIDE-02 | `cluster_undo_xlog.c`、`xact.c` 与 existing TT/undo accessors | 将 decode 与 apply 分离；normal TT/undo truth只走一份 primitive；不得宣称现有 recovery writer 已安全 |
| D-SIDE-03 | PG `twophase.c` 与 cluster 2PC binding | database-scoped PREPARED pending state、RECO-style recovery ownership、exact prepare/terminal binding |
| D-SIDE-04 | `cluster_remote_xact.c` 与 PG status accessors | CLOG/MULTIXACT/COMMIT_TS projection producer、invalidate、rebuild/fail-closed、verification；local store不作 authority |
| D-SIDE-05 | current HWM modules 与 prospective canonical metadata owner | WAL-logged shared HWM/extent/bitmap pages；在 Rule-26 approval 前只写 RED/STOP，不写 ABI |
| D-SIDE-06 | RF-PAGE integration call sites | canonical TT/undo/space pages消费 PageVersion/expected-before/post-read proof；不复制 page parser |
| D-SIDE-07 | resource access/serve call sites | per-resource/thread readiness gate与live consumer；healthy unrelated resource不被 side-wide阻塞 |
| D-SIDE-08 | retention proof exporter | 向 RF-ROOT 交付 TT/undo/pending/space affected-set durability与post-read proof；不自行删除 WAL |
| D-SIDE-09 | unit/TAP/fault corpus | route totality、2PC、projection、space crash cuts、stale authority、early-open、retirement denial |
| D-SIDE-10 | observability surfaces | route/domain/blocked/rebuild/durability events；counter只观测，不能成为 authority |

任何 deliverable 若需要新 actor、wire family、persistent side terminal、global barrier 或 approved
baseline 外 correctness dependency，必须 STOP，而不是在实现期补字段。

### §1.3 明确不包含

| 不做的事 | owner / 理由 |
|---|---|
| 不定义 failed-origin duty、membership/failure generation、serialization、four-layer fence 或 WAL remove caller | RF-ROOT 独占 |
| 不定义 PageVersion bytes、expected-before codec、page source selection、per-block contributor merge 或 release algorithm | RF-PAGE 独占 |
| 不选择 second-crash stable-base carrier | `STOP-RF-PAGE-STABLE-BASE` 仍 active |
| 不定义 canonical HWM/extent/bitmap page offset、page count、redo payload、rmgr/opcode 或 upgrade bytes | `STOP-RF-SIDE-SPACE-ABI`；public Oracle evidence不公开 literal codec |
| 不新增 standalone transaction-result store | TT/undo/redo 与 pending state 已是 approved truth |
| 不新增 terminal file、manifest、certificate、claim ledger 或 predecessor journal | AD-019 拒绝第二 authority 与 D1/D2 |
| 不建立 whole-instance join/serve gate | `FND-09` 要求 resource/thread scope |
| 不把 PostgreSQL FSM 自动称为 canonical space authority | 只有 exact code evidence证明完整可重建时才可列 hint |
| 不把 CLOG/MULTIXACT/COMMIT_TS miss 当 commit、abort、empty 或 zero | Rule 8.A fail closed |
| 不修改 vanilla tuple/WAL/catalog ABI | 当前 scope 无授权；若 census 推翻则 Rule-26 STOP |
| 不修改或运行 `/Users/sqlrush/linkdb` | `PRODUCT AUTHORIZATION = 0` |

### §1.4 non-overlapping ownership

| owner | RF-SIDE consumes | RF-SIDE produces | RF-SIDE may not redefine |
|---|---|---|---|
| AD-019 | evidence classes、stable vocabulary、`FND-01`–`FND-11`、single retirement formula | G1-G9 self-check与SIDE domain proof | shared invariant文字与retention公式 |
| RF-ROOT | exact duty/resource authority、freshness、fence、retained interval、retire request | affected TT/undo/pending/space proof与denial reason | root identity、fence、serialization、remove policy |
| RF-PAGE | page class、PageVersion、expected-before、source provenance、durable post-read、per-resource release proof | canonical metadata业务类型与所需page consumer | page fields、codec、source merge、stable-base carrier |
| RF-SIDE | — | transaction/2PC truth、derived projections、canonical space semantics、route、side readiness | — |

ROOT/PAGE 的 exact product symbol、field 与 API 仍是 prospective/unfrozen；本文只绑定已固定的语义
contract。bundle integrator 只验证 owner/reference，不把 body hash 写进 normative body，也不使用旧
draft 名字制造兼容假象。

---

## §2 接口与行为合同

### §2.1 verdict 与 single-parser contract

实现后的唯一 route verdict 语义固定为：

| verdict | 精确语义 |
|---|---|
| `APPLY` | 该 component 已由唯一 primitive 在 fresh resource authority 下应用；仍须完成 domain durability、post-read与resource gate |
| `PROVED_NOOP` | 已有 positive proof 证明该 component 对 exact failed-origin duty/resource 无 mutation；必须有 proof kind、inputs与negative test |
| `BLOCKED` | record/class/authority/source/identity/durability不完整或冲突；不推进coverage，不开放resource，不改判 |

实现接口必须满足以下形状，但本文不冻结 C prototype 或 struct field：

1. decode 一次 raw WAL record，产出 caller-owned immutable parsed components；不做 I/O 或 mutation。
2. preflight 对 record 的 **全部** page、TT/undo、2PC、projection、space、relfile、cache-hint component
   先求 route；任何一个 `BLOCKED` 时第一次 target mutation 必须为零。
3. apply 只接收 parsed component，不再次读取 raw record。
4. cold wrapper 仅把 `BLOCKED` 升级到 startup-fatal polarity；online wrapper 保持 resource frozen。
5. legacy handler 只能包同一 decoder/primitive；call-graph 中第二 opcode switch 为 RED。
6.每次 mutation、durability publish、resource release 前 fresh consume RF-ROOT authority proof；不能
   缩成 holder id、generation lower bound 或 cached boolean。

### §2.2 consumed cross-spec contracts（不发明字段）

RF-SIDE 只消费下列 logical proof：

| proof | owner | SIDE 必须验证的语义 | 未成立 |
|---|---|---|---|
| active-recoverer authority | RF-ROOT | exact failed-origin duty/resource、current membership、failure generation、serialization与four-layer fence均fresh | exact resource `BLOCKED` |
| retained-source interval | RF-ROOT | 当前 record 在不可回收的failed-origin interval内，retire尚未越过 | `BLOCKED`并deny retire |
| typed page dependency verdict | RF-PAGE | exact resource identity、`PageClass`/`PageIdentity`/`PageVersion`、contributor coverage、durability barrier、canonical post-read与fresh ROOT authority全部成立 | 只令交集resource `BLOCKED`并deny相关retention；不得扩大到其他domain |
| stable-base survival | RF-PAGE | durable post-read前发生recoverer death时至少一个approved stable base仍可认证重放 | `STOP-RF-PAGE-STABLE-BASE` |

本文不命名这些 proof 的 future C type、field、digest、file、message 或 generation layout。G1-G3 census
必须先证明已有 substrate；不存在时按 STOP 处理。

RF-ROOT 当前保留 `STOP-ROOT-CONTROL`、`STOP-ROOT-GENERATION`、`STOP-ROOT-SERIAL`、
`STOP-ROOT-IO-FENCE` 与 `STOP-ROOT-REUSE`。对应 STOP 未由其 owner关闭时，RF-SIDE 的 exact
mutation、release或retirement input保持`BLOCKED`；本文只消费结果，不重定义这些STOP。

### §2.3 transaction truth graph

#### Normal transaction

```text
failed-origin terminal redo
  + matching shared undo TT slot/version
  + matching shared undo chain/segment identity
    -> canonical transaction state
       -> derived CLOG projection
       -> derived COMMIT_TS projection when exact timestamp exists
       -> visibility/cleanup consumers
```

不变量：

1. `COMMITTED` 只在 terminal commit redo 与 matching TT/undo identity一致后成立。
2. `ABORTED` 只在 terminal abort/rollback completion 与 matching TT/undo identity一致后成立。
3. TT 单独出现 COMMITTED/ABORTED 但 terminal redo缺失或冲突时，transaction仍 `BLOCKED/UNKNOWN`；
   projection不得先发布 definitive result。
4. ACTIVE loser 在 roll-forward complete后才进入 undo rollback；rollback mutation同样消费 fresh authority、
   RF-PAGE rule与durability proof。
5. top transaction、subtransaction、xid wrap/origin/segment/slot identity不得折叠。
6. replay cursor、CLOG bit、mtime、local cache presence、counter或absence都不是 terminal proof。

#### PREPARED / in-doubt

```text
prepare redo
  + database-scoped durable pending entry
  + matching TT/undo identity
    -> PREPARED / IN-DOUBT
       -> RECO-style resolution owner
          -> commit-prepared terminal redo -> COMMITTED
          -> rollback-prepared terminal redo + undo completion -> ABORTED
```

PREPARED 合同：

- prepare 不等于 commit/abort，任何 status projection必须保留 in-doubt polarity。
- pending entry必须是database-scoped durable state；origin-local file或recoverer-local cache不能独立承重。
- pending entry missing、same transaction不同GID/identity、terminal-before-prepare without verified base、
  或 TT/undo mismatch 一律 `BLOCKED`。
- prepared transaction 的 locks/resources 只在 matching resolution durable verified 后释放；不能因
  recoverer或node重启自动 abort。
- current PG two-phase substrate可作为候选，但 exact-f076 cluster binding仍是 G3 gap；本文不定义新格式。

### §2.4 derived projection contracts

| projection | canonical producer | invalidation triggers | rebuild / recovery action | verifier | fail-closed boundary |
|---|---|---|---|---|---|
| `CLOG` | verified TT/undo state + matching terminal redo | failure-generation change、TT/undo version change、projection checksum/coverage mismatch、incarnation reset | 从canonical transaction truth按exact xid scope重建或重放已保留terminal redo | status与origin/xid/wrap/terminal coverage双向一致 | miss/UNKNOWN不得读本机ProcArray/CLOG猜结果 |
| `MULTIXACT` | exact origin-qualified MULTIXACT redo与仍有效的tuple/transaction identities | origin/incarnation或member/offset coverage漂移、truncate boundary冲突、checksum mismatch | 在source redo仍retained时重建并post-read；若retire后不存在独立可验证canonical source，相关tuple/resource保持BLOCKED | offsets、members、origin/full-id、truncate horizon与consumer引用全一致 | 不把empty/missing当无locker；source不可证时deny redo retirement |
| `COMMIT_TS` | verified terminal commit redo carrying exact timestamp + matching TT commit | TT/terminal identity change、timestamp range truncate/zero、projection corruption | 从verified terminal records重建exact range；timestamp未记录时保持unknown而非合成 | xid/origin/wrap/commit-state/timestamp/coverage一致 | 不允许projection timestamp反向把UNKNOWN变COMMITTED |

共同规则：

1. projection是可丢失、可失效的materialized view，不是transaction authority。
2. projection写入可在recovery path持久化，但“durable”不等于“authoritative”；每次serve前仍核对canonical
   producer identity/version/coverage。
3. 若rebuild source不能证明在failed-origin redo退休后仍存在，`FND-10` 的
   `no_exact_resource_or_thread_consumer_remains` 不成立，RF-SIDE必须拒绝retire；不得用永久可重建的口号绕过。
4. projection reset不建立全实例 barrier；只阻塞其consumer会访问的transaction/resource scope。
5. projection normal lookup不得新增同步network或durable I/O；不一致时关scope并异步/恢复路径重建，
   在重建前返回 fail-closed error。

### §2.5 canonical space metadata

Oracle-shaped responsibility 固定为：

```text
shared relation/segment identity
  -> WAL-logged canonical segment metadata page
       {HWM responsibility, extent-allocation responsibility, bitmap responsibility}
  -> RF-PAGE PageVersion + exact expected-before
  -> durable write + canonical post-read
  -> resource-scoped allocation readiness
  -> optional volatile allocator cache
```

Normative semantics：

1. canonical bytes 位于shared storage且由WAL恢复；volatile HWM hash/master cache只从canonical page派生。
2. reserve/extend/free/reuse 必须在exact segment/extent resource authority下更新canonical page；成功返回、
   shmem raise、counter或old checkpoint image都不能发布allocation authority。
3. update先通过RF-PAGE class、PageVersion、expected-before与source provenance；mismatch/unknown class
   `BLOCKED`，不得blind max或last-writer-wins。
4. metadata bytes完成durability barrier后必须post-read验证segment identity、version、integrity、
   allocation coverage；通过前禁止把extent/block分配给writer。
5. recoverer death后新actor从RF-ROOT/RF-PAGE approved canonical sources重新census；不接管private progress。
6. relation drop/truncate/reuse必须使old segment incarnation的metadata与cache不可serve；exact incarnation
   codec由future approved ABI定义，本文不发明字段。
7. PostgreSQL FSM 只有在exact code census证明其每个bit可从authoritative relation pages完整重建、
   丢失不影响correctness、unknown state不导致重复分配时，才可归`REBUILDABLE_HINT`。证明前未知
   nonlogged allocation state一律`BLOCKED`。

`STOP-RF-SIDE-SPACE-ABI`：public Oracle evidence未给出PGRAC可直接复制的page/redo layout；
exact-f076 `XLOG_HW_RESERVE` 也不更新canonical page。因此 page ownership、offset/width、redo payload、
rmgr/opcode、initialization/incarnation、upgrade/mixed-version codec 全部 **PROSPECTIVE / NOT APPROVED**。
在user批准Rule-26差异前，只允许source census、RED test与impact analysis，不得写产品ABI。

canonical metadata同样继承`STOP-RF-PAGE-STABLE-BASE`：failed-origin WAL retained不自动证明torn
target仍有stable preimage。

### §2.6 resource-scoped readiness、serve 与 retention

定义逻辑 predicate，不定义新persistent carrier：

```text
side_ready(resource) :=
    fresh_root_authority(resource)
AND all_routed_side_components_for(resource) terminal
AND canonical_truth_bytes_for(resource) durable_and_post_read_verified
AND required_projection_for_current_consumer verified_or_consumer_fenced
AND no_pending_unknown_for(resource)
AND page_proof_for_canonical_metadata(resource) satisfied
```

规则：

1. `side_ready(resource_a)` 不蕴含 `side_ready(resource_b)`，也不蕴含 node/instance ready。
2. unaffected resource或已恢复resource可在自身ROOT/PAGE/SIDE gate满足后尽早开放。
3. transaction resource若涉及PREPARED，必须先验证database pending census与该transaction binding；
   这只阻塞相关transaction/locks/objects和2PC resolution consumer，不把所有healthy pages绑在一起。
4. future join在访问某resource/thread前验证其authority、version、durability与所需projection；join membership
   本身不证明resource可serve。
5. unknown dependency只阻塞无法证明的scope；若dependency graph本身未知，则其保守闭包内scope BLOCKED，
   不能升级成未经Oracle证明的permanent whole-instance barrier。
6. readiness是可重验predicate，不需要side terminal file。若实现发现必须新增carrier，Rule-26 STOP。

RF-SIDE 向RF-ROOT只回交以下semantic proof：

- affected TT/undo/pending/space resource closed set；
- 每个resource canonical bytes durability + post-read verdict；
- projection consumer是否仍需要failed-origin redo；
- precise denial reason与blocked scope。

`FND-10` formula由AD-019唯一拥有；RF-ROOT负责retire decision、proof aggregation与caller census。
RF-SIDE只提交typed domain proof或deny，不得删除、truncate、reuse或覆盖failed-origin redo。

### §2.7 error、observability 与 lock boundary

- 不新增GUC/SQLSTATE；product TDD发现现有错误族不能表达fail-closed时先Rule-26/compatibility review。
- error至少携failed origin/thread、LSN、rmgr/info、route class、resource scope、authority freshness、
  canonical/projection verdict与denial reason；不得只报“redo failed”。
- counter语义单一：EVENT/GAUGE/TIMESTAMP不混用；counter不能作为completion或authority。
- network/remote wait前不得持buffer content、TT/undo content、SLRU、GRD shard、relation extension、
  allocator或coordinator lock。
- canonical mutation期间只持exact resource所需authority；不得以多resource lock形成side-wide原子事务。
- retry重新获取fresh ROOT authority与PAGE proof；cached success、lock owner id或较大generation不足。

---

## §3 Exhaustive exact-f076 routing

### §3.1 route lifecycle and totality

```text
read record inside RF-ROOT retained interval
  -> decode once
  -> enumerate every page and side component
  -> resolve each row below
  -> preflight all components
  -> APPLY or PROVED_NOOP every component
  -> canonical durability + post-read per affected resource
  -> advance coverage only for resources whose whole record is terminal
```

表中“carrier”表示现有或目标 durability source，不表示新增文件。凡目标 substrate尚未批准，action
明确为`BLOCKED/STOP`。page-family records的业务decode与mutation由RF-PAGE独占；RF-SIDE只验证route
totality并消费page verdict。

### §3.2 routing matrix

| rmgr / exact-f076 opcodes | producer | authority | durability carrier | verifier | recovery action | unknown/failure direction |
|---|---|---|---|---|---|---|
| `RM_XLOG_ID`: `XLOG_FPI`, `XLOG_FPI_FOR_HINT` | core WAL | RF-PAGE page resource | retained redo + approved page source | RF-PAGE class/version/source proof | route `PAGE`; consume apply/noop verdict | mixed/local/unknown page or stable-base gap => BLOCKED |
| `RM_XLOG_ID`: `XLOG_NOOP`, `XLOG_SWITCH`, `XLOG_RESTORE_POINT`, `XLOG_BACKUP_END` | core WAL | no side authority after exact decode | retained redo record | opcode/length and zero side-effect proof | `PROVED_NOOP(CONTROL_ONLY)` | malformed/extra component => BLOCKED |
| `RM_XLOG_ID`: checkpoint, allocator/config/control opcodes including `XLOG_CHECKPOINT_SHUTDOWN`, `XLOG_CHECKPOINT_ONLINE`, `XLOG_NEXTOID`, `XLOG_PARAMETER_CHANGE`, `XLOG_FPW_CHANGE`, `XLOG_END_OF_RECOVERY`, `XLOG_OVERWRITE_CONTRECORD` | core WAL | foreign control authority not owned here | source record only | exact context census | BLOCKED; do not apply failed-origin control state to survivor | any attempt to infer safe no-op => BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_COMMIT` and its legal `XLOG_XACT_HAS_INFO` modifier | transaction WAL + folded TT producer | shared TT/undo + terminal redo | TT/undo canonical bytes + retained terminal redo | exact xid/origin/wrap/slot/SCN/undo coverage and modifier/payload agreement | apply canonical TT/undo truth, then derive CLOG and optional COMMIT_TS; route rel/inval/stats separately | missing/conflict/partial or illegal modifier => transaction scope BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_ABORT` | transaction WAL | shared TT/undo + terminal abort redo | TT/undo canonical bytes + retained terminal redo | exact identity + rollback completion | apply abort truth; derive CLOG; route rel/stats | missing undo or terminal mismatch => BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_PREPARE` | PG 2PC + cluster TT binding | database pending state + TT/undo + prepare redo | existing durable 2PC substrate candidate + TT/undo + redo | prepare/GID/xid/origin/TT/undo binding | create/verify pending in-doubt state; do not publish commit/abort | cluster binding absent/conflict => BLOCKED G3 |
| `RM_XACT_ID`: `XLOG_XACT_COMMIT_PREPARED` | 2PC terminal producer | pending state + TT/undo + terminal redo | same canonical sources | exact pending/prepare/terminal identity and commit SCN | resolve pending to committed, then projections/effects | no matching pending/prepare => BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_ABORT_PREPARED` | 2PC terminal producer | pending state + TT/undo + terminal redo | same canonical sources | exact pending/prepare/abort/undo completion | resolve pending to aborted only after rollback proof | premature abort or missing undo => BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_ASSIGNMENT` | transaction WAL | canonical top/subxact binding in TT/undo/redo | retained redo + canonical binding bytes | parent/child/origin/full identity uniqueness | apply canonical binding or identical noop | alias/child ambiguity => BLOCKED |
| `RM_XACT_ID`: `XLOG_XACT_INVALIDATIONS` | parsed XACT record | local cache is rebuildable hint | terminal redo + catalog truth | exact relation/catalog identity and reset coverage | apply existing invalidation or require full reset before dependent resource serves | no existing reliable delivery/reset proof => dependent scope BLOCKED; no new wire invented |
| `RM_SMGR_ID`: `XLOG_SMGR_CREATE`, `XLOG_SMGR_TRUNCATE` | smgr WAL | canonical shared relfile/page owner | WAL + durable shared files/pages | locator/fork/incarnation + PAGE proof where metadata page involved | route canonical storage lifecycle | local/mixed/unknown locator or directory durability gap => BLOCKED |
| `RM_CLOG_ID`: `CLOG_ZEROPAGE`, `CLOG_TRUNCATE` | PG CLOG WAL | derived CLOG projection only | projection bytes + canonical TT/terminal source | projection coverage/horizon vs canonical truth | rebuild/zero/truncate projection only after canonical producer proof | absent source/coverage => BLOCKED; never no-op by record absence |
| `RM_DBASE_ID`: `XLOG_DBASE_CREATE_FILE_COPY`, `XLOG_DBASE_CREATE_WAL_LOG`, `XLOG_DBASE_DROP` | database WAL | shared database-directory authority not owned/verified | source redo only | G1/G3 census | BLOCKED until exact shared primitive exists and is approved | no raw survivor-local apply |
| `RM_TBLSPC_ID`: `XLOG_TBLSPC_CREATE`, `XLOG_TBLSPC_DROP` | tablespace WAL | shared tablespace-directory authority not owned/verified | source redo only | G1/G3 census | BLOCKED | no pathname-based success |
| `RM_MULTIXACT_ID`: `XLOG_MULTIXACT_ZERO_OFF_PAGE`, `XLOG_MULTIXACT_ZERO_MEM_PAGE`, `XLOG_MULTIXACT_CREATE_ID`, `XLOG_MULTIXACT_TRUNCATE_ID` | MULTIXACT WAL | canonical transaction/tuple identities; local store is derived projection | retained redo + durable projection | origin/full-id/offset/member/horizon/consumer coverage | rebuild/apply projection under §2.4; deny retire while sole source remains redo | empty/missing/conflict or raw-id alias => BLOCKED |
| `RM_RELMAP_ID`: `XLOG_RELMAP_UPDATE` | relmap WAL | existing shared relmap authority | canonical relmap bytes + redo | exact relmap identity/generation/digest | identical canonical state may `PROVED_NOOP`; else route existing authority | authority or generation unknown => BLOCKED |
| `RM_STANDBY_ID`: `XLOG_STANDBY_LOCK`, `XLOG_RUNNING_XACTS` | standby WAL | no primary side authority if exact context excludes consumer | source record | explicit primary physical-recovery context + standby consumer disabled | `PROVED_NOOP(PRIMARY_NO_STANDBY_CONSUMER)` | any logical/standby consumer => BLOCKED |
| `RM_STANDBY_ID`: `XLOG_INVALIDATIONS` | standby WAL | rebuildable local cache | catalog truth + source redo | identity/reset coverage | same invalidation/reset primitive as XACT route | no proof => dependent scope BLOCKED |
| `RM_HEAP2_ID`: `XLOG_HEAP2_PRUNE`, `XLOG_HEAP2_VACUUM`, `XLOG_HEAP2_FREEZE_PAGE`, `XLOG_HEAP2_VISIBLE`, `XLOG_HEAP2_MULTI_INSERT`, `XLOG_HEAP2_LOCK_UPDATED` and legal `XLOG_HEAP_INIT_PAGE` combinations | heap2 WAL | RF-PAGE | retained redo + approved page source | RF-PAGE exhaustive class/version | route PAGE | unknown flag/page => BLOCKED |
| `RM_HEAP2_ID`: `XLOG_HEAP2_NEW_CID` | logical decoding WAL | none in exact physical context | source record | physical-only context and no logical consumer | `PROVED_NOOP(LOGICAL_ONLY)` | logical consumer requested => BLOCKED |
| `RM_HEAP2_ID`: `XLOG_HEAP2_REWRITE` | rewrite WAL | rewrite mapping authority not verified | source record | G1/G3 census | BLOCKED | never create survivor-local mapping by guess |
| `RM_HEAP_ID`: `XLOG_HEAP_INSERT`, `XLOG_HEAP_DELETE`, `XLOG_HEAP_UPDATE`, `XLOG_HEAP_HOT_UPDATE`, `XLOG_HEAP_CONFIRM`, `XLOG_HEAP_LOCK`, `XLOG_HEAP_INPLACE` and legal `XLOG_HEAP_INIT_PAGE` combinations | heap WAL | RF-PAGE | retained redo + approved page source | RF-PAGE | route PAGE | any unknown modifier/ref => BLOCKED |
| `RM_HEAP_ID`: `XLOG_HEAP_TRUNCATE` | heap WAL | canonical shared relation lifecycle | redo + shared files/pages | locator/incarnation/extent closure | route storage lifecycle and canonical space metadata | incomplete extent/bitmap contract => BLOCKED/SPACE-ABI STOP |
| `RM_BTREE_ID`: `XLOG_BTREE_INSERT_LEAF`, `XLOG_BTREE_INSERT_UPPER`, `XLOG_BTREE_INSERT_META`, `XLOG_BTREE_SPLIT_L`, `XLOG_BTREE_SPLIT_R`, `XLOG_BTREE_INSERT_POST`, `XLOG_BTREE_DEDUP`, `XLOG_BTREE_DELETE`, `XLOG_BTREE_UNLINK_PAGE`, `XLOG_BTREE_UNLINK_PAGE_META`, `XLOG_BTREE_NEWROOT`, `XLOG_BTREE_MARK_PAGE_HALFDEAD`, `XLOG_BTREE_VACUUM`, `XLOG_BTREE_META_CLEANUP` | btree WAL | RF-PAGE | retained redo + approved page source | RF-PAGE | route PAGE | unknown opcode/ref => BLOCKED |
| `RM_BTREE_ID`: `XLOG_BTREE_REUSE_PAGE` | btree WAL | RF-PAGE or exact primary-conflict no-op | source redo | strict conflict-only predicate | proven conflict-only => no-op; otherwise PAGE | ambiguity => BLOCKED |
| `RM_HASH_ID`: `XLOG_HASH_INIT_META_PAGE`, `XLOG_HASH_INIT_BITMAP_PAGE`, `XLOG_HASH_INSERT`, `XLOG_HASH_ADD_OVFL_PAGE`, `XLOG_HASH_SPLIT_ALLOCATE_PAGE`, `XLOG_HASH_SPLIT_PAGE`, `XLOG_HASH_SPLIT_COMPLETE`, `XLOG_HASH_MOVE_PAGE_CONTENTS`, `XLOG_HASH_SQUEEZE_PAGE`, `XLOG_HASH_DELETE`, `XLOG_HASH_SPLIT_CLEANUP`, `XLOG_HASH_UPDATE_META_PAGE`, `XLOG_HASH_VACUUM_ONE_PAGE` | hash WAL | RF-PAGE; allocation metadata also SPACE contract | redo + approved page source | RF-PAGE + canonical metadata readiness | route PAGE; metadata mutation also requires SPACE ABI | exact space class/layout unresolved => affected route BLOCKED |
| `RM_GIN_ID`: `XLOG_GIN_CREATE_PTREE`, `XLOG_GIN_INSERT`, `XLOG_GIN_SPLIT`, `XLOG_GIN_VACUUM_PAGE`, `XLOG_GIN_VACUUM_DATA_LEAF_PAGE`, `XLOG_GIN_DELETE_PAGE`, `XLOG_GIN_UPDATE_META_PAGE`, `XLOG_GIN_INSERT_LISTPAGE`, `XLOG_GIN_DELETE_LISTPAGE` | GIN WAL | RF-PAGE | retained redo + page source | RF-PAGE | route PAGE | unknown => BLOCKED |
| `RM_GIST_ID`: `XLOG_GIST_PAGE_UPDATE`, `XLOG_GIST_DELETE`, `XLOG_GIST_PAGE_SPLIT`, `XLOG_GIST_PAGE_DELETE` | GiST WAL | RF-PAGE | retained redo + page source | RF-PAGE | route PAGE | unknown => BLOCKED |
| `RM_GIST_ID`: `XLOG_GIST_PAGE_REUSE` | GiST WAL | RF-PAGE or conflict-only no-op | source redo | strict predicate | proven conflict-only => no-op; else PAGE | ambiguity => BLOCKED |
| `RM_GIST_ID`: `XLOG_GIST_ASSIGN_LSN` | GiST WAL | none if declared rmgr no-op | source record | exact opcode/length | `PROVED_NOOP(DECLARED_RMGR_NOOP)` | malformed => BLOCKED |
| `RM_SEQ_ID`: `XLOG_SEQ_LOG` | sequence WAL | RF-PAGE | retained redo + page source | RF-PAGE | route PAGE | local/mixed/unknown => BLOCKED |
| `RM_SPGIST_ID`: `XLOG_SPGIST_ADD_LEAF`, `XLOG_SPGIST_MOVE_LEAFS`, `XLOG_SPGIST_ADD_NODE`, `XLOG_SPGIST_SPLIT_TUPLE`, `XLOG_SPGIST_PICKSPLIT`, `XLOG_SPGIST_VACUUM_LEAF`, `XLOG_SPGIST_VACUUM_ROOT`, `XLOG_SPGIST_VACUUM_REDIRECT` | SP-GiST WAL | RF-PAGE | retained redo + page source | RF-PAGE | route PAGE | unknown => BLOCKED |
| `RM_BRIN_ID`: `XLOG_BRIN_CREATE_INDEX`, `XLOG_BRIN_INSERT`, `XLOG_BRIN_UPDATE`, `XLOG_BRIN_SAMEPAGE_UPDATE`, `XLOG_BRIN_REVMAP_EXTEND`, `XLOG_BRIN_DESUMMARIZE` and legal `XLOG_BRIN_INIT_PAGE` combinations | BRIN WAL | RF-PAGE; revmap extend may require SPACE contract | redo + page source | RF-PAGE + exact metadata class | route PAGE; allocation mutation awaits approved SPACE ABI | unresolved metadata class => BLOCKED |
| `RM_COMMIT_TS_ID`: `COMMIT_TS_ZEROPAGE`, `COMMIT_TS_TRUNCATE` | COMMIT_TS WAL | derived COMMIT_TS projection | terminal redo + projection bytes | §2.4 timestamp/status/coverage verifier | zero/truncate/rebuild derived projection | projection cannot create transaction outcome |
| `RM_REPLORIGIN_ID`: `XLOG_REPLORIGIN_SET`, `XLOG_REPLORIGIN_DROP` | replication-origin WAL | origin authority not safely aliased across failed instance | source redo | G1/G3 census | BLOCKED | no survivor-local raw apply |
| `RM_GENERIC_ID`: implicit generic record | generic WAL | RF-PAGE for every shared ref | retained redo + page source | all refs shared + RF-PAGE delta proof | route PAGE | zero/mixed/local/unknown refs => BLOCKED |
| `RM_LOGICALMSG_ID`: `XLOG_LOGICAL_MESSAGE` | logical message WAL | none in physical-only context | source record | exact physical context and no logical consumer | `PROVED_NOOP(LOGICAL_MESSAGE_ONLY)` | logical output required => BLOCKED |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_SEGMENT_INIT` | cluster undo WAL | shared undo segment truth | retained redo + canonical undo bytes | segment/origin/generation + RF-PAGE class if paged | initialize/verify shared undo under fresh authority | recovery writer/substrate absent => BLOCKED G3 |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_TT_SLOT_COMMIT` | TT redo | shared TT/undo + matching terminal redo | TT canonical bytes + redo | exact xid/wrap/slot/SCN binding | materialize TT; do not alone publish committed projection | terminal missing/conflict => transaction BLOCKED |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_TT_SLOT_ABORT` | TT redo | shared TT/undo + terminal/rollback proof | TT canonical bytes + redo | exact identity | materialize abort input; definitive abort waits terminal/rollback | premature terminal => BLOCKED |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_TT_SLOT_SET_HEAD` | TT redo | shared TT/undo | TT/undo canonical bytes + redo | xid/wrap/slot/head/generation | attach exact undo head | ambiguity => BLOCKED |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_SEGMENT_RECYCLE`, `XLOG_UNDO_SEGMENT_REUSE` | undo WAL | shared undo/TT segment authority | canonical bytes + redo | horizon/generation/full-file coherence + PAGE proof | recycle/reuse only after all consumers released | missing horizon/incarnation/space metadata => BLOCKED |
| `RM_CLUSTER_UNDO_ID`: `XLOG_UNDO_BLOCK_WRITE`, `XLOG_UNDO_BLOCK_WRITE_MULTI` | undo WAL | shared undo block authority | retained redo + approved page/base source | block identity/version/expected-before/digest | apply canonical undo bytes, durable post-read | stable-base or contributor gap => BLOCKED/STOP |
| `RM_CLUSTER_UNDO_ID`: `XLOG_HW_RESERVE` | current HWM WAL | target canonical space metadata page, not volatile master | current 24-byte delta is insufficient target carrier | future PageVersion/expected-before + segment coverage | `BLOCKED` under `STOP-RF-SIDE-SPACE-ABI`; only RED/census allowed | never raise shmem and call complete |
| `RM_CLUSTER_RAW_LAYOUT_ID`: `XLOG_CLUSTER_RAW_LAYOUT_WRITE` | raw-layout WAL | separate raw-layout authority | source redo | owner-specific census | BLOCKED in RF-SIDE | no scope expansion |
| `RM_CLUSTER_ADG_ID`: `XLOG_CLUSTER_ADG_THREAD_BARRIER` | ADG WAL | ADG owner | source redo | exact primary-disabled or ADG context | physical primary with disabled consumer may proven no-op; ADG owner applies otherwise | context unknown => BLOCKED |
| `RM_CLUSTER_XID_STRIPE_ID`: `XLOG_CLUSTER_XID_STRIPE_JOIN`, `XLOG_CLUSTER_XID_STRIPE_RETIRE` | xid-stripe WAL | existing stripe metadata owner | canonical stripe state + redo | thread/slot/epoch/order identity | route existing canonical owner | conflict/missing owner => BLOCKED |
| unknown rmgr or known rmgr with reserved opcode/flag/illegal length | any | none | source bytes only | total-registry default | `BLOCKED(UNKNOWN_OR_UNSUPPORTED)` | no fall-through/no absence-based no-op |

exact-f076 census inherited for the implementation RED is `26/26` rmgr、`132/132` named opcode/modifier
symbols，加一个 implicit generic route。实现期必须从 exact object headers机械生成 expected set，与route
registry做双向set equality；不能从本文表解析 expected set来自证。source header新增/删除symbol必须先RED。

### §3.3 record atomicity across multiple routes

1. 同一record包含page与side components时，preflight全量通过后才能首写。
2. runtime mutation中途失败不伪造rollback；已写canonical bytes保持未ready，由下一fresh actor根据
   PageVersion/expected-before和truth identity幂等重验。
3. per-thread WAL order不改变；跨thread只消费ROOT/PAGE已经裁定的per-resource contributor set。
4. record coverage按resource保存逻辑事实即可；本文不新增persistent progress artifact。
5. 一个component成功不能让同record另一个blocked component对应resource ready。
6. same key/same version/different bytes或terminal polarity双向冲突均BLOCKED，不取mtime、node多数或较大LSN。

---

## §4 Crash、restart 与 idempotence matrix

| crash/fault point | required restart behavior | forbidden outcome |
|---|---|---|
| decode前 / preflight后mutation前 | 重读、重decode、重取fresh authority；target零修改 | cursor或coverage前进 |
| TT write中recoverer death | next actor验证stable base与TT version后重放或BLOCKED | 读local CLOG宣布commit |
| TT durable、terminal redo未验证 | TT保留非terminal input；transaction UNKNOWN/BLOCKED | definitive projection先serve |
| terminal redo verified、CLOG未更新 | transaction truth已定；projection rebuild后dependent consumer才serve | projection miss反向推翻truth |
| PREPARED pending write前/中/后 | durable pending+prepare+TT/undo全匹配才IN-DOUBT；新actor重验 | restart自动abort prepared |
| commit-prepared terminal后pending cleanup前 | exact terminal truth保持；idempotent resolution与cleanup | duplicate commit或资源提前释放 |
| rollback-prepared undo中再crash | pending保持，next actor继续verified undo；terminal only after completion | TT abort bit单独释放locks |
| MULTIXACT projection中断 | source redo retained则重建；否则相关tuple/resource BLOCKED | missing当empty/no locker |
| COMMIT_TS/CLOG projection corrupt | invalidate scope并从truth重建 | silent native fallback |
| canonical HWM update前 | old version仍authority | shmem reservation serve |
| canonical HWM target write中 | inherit stable-base STOP；next actor不得信target | max(old,new)猜测 |
| HWM durable barrier后post-read前 | new actor重读version/integrity/coverage | write return当ready |
| PageVersion/expected-before mismatch | preserve source与blocked evidence | blind apply/skip |
| stale membership/failure generation/serialization | every mutation/release拒绝 | cached-valid继续写 |
| resource A verified、resource B blocked | A可open，B保持fenced | A证明instance-wide ready或B阻塞A |
| database pending state corrupt | prepared-related transaction/lock/2PC consumer blocked | 全部healthy unrelated page永久全局阻塞，或prepared被猜终态 |
| projection仍需要failed-origin redo时收到retire请求 | precise denial返回ROOT | WAL被删后再发明capsule |
| all affected TT/undo/space bytes durable但post-read缺一项 | deny retire and readiness for exact scope | logical done替代post-read |
| recoverer death afterpost-read | next actorfresh revalidate ROOT/PAGE/SIDE proof；仅复用independently durable canonical bytes | adopt private progress |

---

## §5 Tests and verification contract

### §5.1 cluster_unit / static tests

| U | RED/GREEN target |
|---|---|
| U-SIDE-01 | generated exact-f076 rmgr/opcode registry双向totality；unknown/reserved默认BLOCKED |
| U-SIDE-02 | cold/online对同record产生相同routes与verdict，只差process severity |
| U-SIDE-03 | call graph证明每payload一个parser/primitive owner；第二switch或direct cold-handler edge使RED |
| U-SIDE-04 | malformed length、unaligned fields、illegal modifiers、mixed locator全部pre-mutation BLOCKED |
| U-SIDE-05 | normal commit/abort：TT、terminal redo、undo identity每一项one-at-a-time missing/conflict真值表 |
| U-SIDE-06 | PREPARE/COMMIT PREPARED/ROLLBACK PREPARED pending-state顺序与in-doubt不变量 |
| U-SIDE-07 | top/subxact、origin/wrap/slot/GID identity冲突对称BLOCKED |
| U-SIDE-08 | CLOG producer/invalidate/rebuild/verify；local bit不能覆盖TT/redo |
| U-SIDE-09 | MULTIXACT member/offset/truncate/source-retention与missing-not-empty真值表 |
| U-SIDE-10 | COMMIT_TS terminal binding、timestamp unknown、zero/truncate coverage |
| U-SIDE-11 | canonical HWM semantic tests先RED；未批准ABI时任何apply path保持BLOCKED |
| U-SIDE-12 | metadata PageVersion result-skip与expected-before apply两门分别负测 |
| U-SIDE-13 | per-resource readiness每一leg one-at-a-time false；A ready/B blocked不互相污染 |
| U-SIDE-14 | fresh authority proof每个semantic component stale时mutation/release零发生 |
| U-SIDE-15 | FND-10 side proof：TT/undo/pending/space affected-set、durability、post-read、consumer每项缺失都deny retire |
| U-SIDE-16 | metrics semantic type与live consumer；counter置大不能改变verdict |
| U-SIDE-17 | G1/G1′/G1″/G3 negative build fixtures证明“symbol看似存在但actor不可达”仍未成立 |
| U-SIDE-18 | `STOP-RF-PAGE-STABLE-BASE`与`STOP-RF-SIDE-SPACE-ABI`不能由config/test override |

### §5.2 cluster_tap / fault / e2e

| L | scenario and positive evidence |
|---|---|
| L1 | cold与online replay同一failed-thread corpus；route/verdict/domain affected-set一致 |
| L2 | every route row至少positive+negative corpus；unknown hit counter >0且resource保持fenced |
| L3 | normal commit在TT write、TT fsync、terminal verify、CLOG rebuild各cut crash；truth/projection顺序正确 |
| L4 | normal abort与active loser rollback在undo每cut repeated recoverer death；无false-abort/false-visible |
| L5 | PREPARE在pending create/file durability/TT/undo每cut crash；重启仍in-doubt |
| L6 | COMMIT PREPARED与ROLLBACK PREPARED的terminal/undo/cleanup每cut；RECO-style resolution幂等 |
| L7 | CLOG corruption/miss：从truth重建；重建前dependent lookup明确fail-closed |
| L8 | MULTIXACT projection loss在redo retained时重建；redo准备retire但consumer仍需时真实拒绝 |
| L9 | COMMIT_TS projection loss/unknown timestamp不改变commit truth |
| L10 | canonical HWM update semantic path在ABI STOP时mutation=0；批准未来ABI后需补write/fsync/post-read cuts |
| L11 | metadata PageVersion/expected-before mismatch和unknown page class阻塞allocation |
| L12 | recoverer在TT/undo/space target write中死亡；下一actor不adopt private progress |
| L13 | stale owner在membership/I/O/control-root/redo-reuse四边界各自真实拒绝side mutation/release |
| L14 | resource A recovered后真实read/write；resource B仍BLOCKED且不阻塞A |
| L15 | pending 2PC database census未完成时prepared resources保持fenced，unrelated healthy resource继续serve |
| L16 | projection reset只阻塞其consumer scope；normal healthy transaction instrumentation保持0/0/0新增同步税 |
| L17 | redo retire在TT/undo/space post-read缺任一leg时拒绝；完整proof后也只由ROOT caller决定 |
| L18 | stable-base未裁决fixture必须报告STOP/BLOCKED，不得skip、forced cancel或改judge生成绿色 |
| L19 | same identity/version different bytes与opposite terminal polarity按A→B、B→A均BLOCKED |
| L20 | future join只在访问exact resource时求其gate；不读取side terminal artifact，不等待unrelated domains |

### §5.3 compatibility and formal boundary

- vanilla `--disable-cluster` PG behavior不变；feature-off不产生SIDE authority。
- current scope不批准WAL/catalog/page ABI；若future ABI获批，必须有capability floor、mixed-version
  fail-closed、upgrade/rollback与catversion评估。
- no test may use mock success、silent skip、timeout、forced cancel、white-list或counter-only evidence。
- formal destination remains fresh real `4×1×3 + rate10/20/30` with unchanged judge/formulas/thresholds/
  workload identity。本文只定义prerequisite，未运行也未通过formal campaign。

---

## §6 Existing-code contract and G1–G9 governance

### §6.1 exact source surfaces

| exact-f076 surface | unchanged fact | prospective responsibility |
|---|---|---|
| `cluster_thread_recovery_replay.c` | reader存在，side dispatch只覆盖少数family | 保留reader/window；record交single total core |
| `cluster_undo_xlog.c` | TT/undo redo和direct replay存在 | pure decode + one canonical primitive；authority不足则BLOCKED |
| `xact.c` | normal folded TT与PG 2PC flows存在 | terminal/TT/pending exact binding |
| `cluster_remote_xact.c` | local per-origin status materialization存在 | 降为projection；删authority role |
| `twophase.c` / cluster 2PC header | durable DB 2PC与origin-local binding并存 | database-scoped pending owner；exact cluster mapping G3 |
| `cluster_hw_*` | volatile HWM/master/adoption path存在 | cache only；canonical page target等待Rule-26 ABI approval |
| PAGE replay/direct pwrite paths | recovery-generated successor WAL未发现 | inherit FND-10 + stable-base STOP；不假设carrier |

### §6.2 G1–G9 evidence gate

| Gate | RF-SIDE self-check |
|---|---|
| **G1 / G1′ / G1″** | exact symbols/files由§0.3/§6.1列出；implementation前必须证明symbol存在、cold/online actor可达、运行context真实拥有shared data。R4A-like recovery writer与canonical HWM writer当前不得写成existing。 |
| **G2** | route/rebuild/blocked/durability counters只计EVENT/GAUGE/TIMESTAMP声明的单一语义，不参与authority/readiness。 |
| **G3** | shared TT/redo producer是existing substrate；database pending cluster binding、safe recovery mutation、canonical space page均未成立，明确为prospective/STOP。 |
| **G4 / G4′** | every future accessor必须有route/serve/retention live consumer；every new field必须有producer且携独立信息。本文未冻结新field。 |
| **G5 / G5′** | Oracle official、PGRAC implication与PUBLICLY UNKNOWN分账；citation只承字面职责，不承PGRAC bytes/actor。 |
| **G6** | 无法literal对齐的space ABI/stable-base carrier保持Rule-26 STOP；未自行登记新Oracle偏离。 |
| **G7** | cold、online、recoverer death、stale owner、restart、future join、projection miss、PREPARED、space crash与retire request均已穷举。 |
| **G8 / G8′** | 保留single parser、total route、typed verdict、Rule 8.A、0/0/0 normal cost、formal公式；旧OUTCOME/terminal/global barrier tests明确retired。FND-10公式不重定义。 |
| **G9** | route row、producer、authority、carrier、verifier、action、failure和U/L test均给到陌生实现者可写TDD RED；unapproved ABI则明确STOP而不伪精确。 |

Exact required checkbox：

- [x] G1–G9（含 G1′/G1″/G4′/G5′/G8′）已逐条自检

### §6.3 inherited hard gates and metric formulas

| inherited gate | disposition |
|---|---|
| single decoder / route totality / `APPLY|PROVED_NOOP|BLOCKED` | `INHERIT` |
| unknown/unsupported/malformed fail closed | `INHERIT` |
| Rule 8.A no false-visible/false-commit/false-abort/native fallback | `INHERIT` |
| exact-f076 `26 rmgr / 132 named symbols / 1 generic` census | `INHERIT AS IMPLEMENTATION RED`; future source drift重新机械计数 |
| normal transaction sync RTT/fsync/shared-control I/O | `INHERIT EXACT 0/0/0` |
| formal rounds/rates/judge/threshold/workload | `INHERIT UNCHANGED`;未运行不得claim pass |
| FND-10 successor-or-retain formula | `CONSUME ONLY`;SIDE只交domain proof |
| L241 chunk completeness / L242 conflict symmetry / L243 live caller | `INHERIT`，但scope改成per-resource record closure |
| L341 faithful crash evidence | `INHERIT`; synthetic不能替代faithful |
| L380 durable truth不能被volatile epoch/cache过滤 | `INHERIT` for TT/pending/space truth |
| L415 single-writer identity | `INHERIT` per canonical resource；不再用于two-slot terminal |
| old three-family terminal and whole-instance chain | `RETIRE`;不得保留测试或implementation edge |

---

## §7 Definition of Done

- [x] status区分`BASELINE USER APPROVED`、`EXACT BODY PENDING CC`与`PRODUCT NOT AUTHORIZED`，exact product object固定。
- [x] complete normative content位于唯一一对marker内；mutable fingerprint metadata在marker外。
- [x] Oracle facts、PGRAC implication、PUBLICLY UNKNOWN与exact-f076 facts分账。
- [x] normal truth定义为shared TT/undo + terminal redo；没有standalone transaction-result authority。
- [x] PREPARED/in-doubt定义为database-scoped pending state + TT/undo + prepare/terminal redo。
- [x] CLOG、MULTIXACT、COMMIT_TS各有producer、invalidation、rebuild/fail-closed与verifier。
- [x] HWM/extent/bitmap authority改为WAL-logged shared canonical metadata responsibility。
- [x] canonical space page/redo exact ABI保持`STOP-RF-SIDE-SPACE-ABI`，未发明layout。
- [x] `STOP-RF-PAGE-STABLE-BASE`已继承，retained redo未被冒充stable preimage proof。
- [x] exact-f076未找到的R4A-like recovery writer没有写成existing substrate。
- [x] single decoder/total route/one primitive graph与cold/online polarity保留。
- [x] exhaustive route matrix为每family列producer、authority、carrier、verifier、action、failure。
- [x] resource/thread scoped readiness取代whole-instance side-domain barrier；unrelated resource可early open。
- [x] FND-10 formula由AD-019唯一拥有；ROOT唯一作retire decision/aggregation/caller census；SIDE只交TT/undo/pending/space typed proof或deny。
- [x] crash matrix覆盖TT/undo、prepared、projection、HWM、PageVersion、recoverer death、stale authority与retire denial。
- [x] tests删除rejected outcome/terminal-chain目标，新增projection和canonical metadata RED。
- [x] G1–G9正文与exact checkbox存在；G8/G8′ inheritance/formulas显式。
- [x] normal transaction 0/0/0与formal `4×1×3 + rate10/20/30`保持，未声称已运行。
- [ ] ROOT/PAGE并行稿停止修改后，由integrator绑定exact cross-reference，不使用旧字段。
- [ ] CC对exact fingerprint只回复`ACCEPT`或指出相对approved baseline的精确冲突。
- [ ] user review unresolved space ABI与stable-base STOP；没有批准前product TDD保持关闭。
- [ ] future product unit/TAP/fault/compat/performance gates真实GREEN，无skip/timeout/forced cancel。
- [ ] fresh formal campaign真实通过；通过前不得宣布本轮目标完成。
- [x] `PRODUCT AUTHORIZATION = 0`；未授权public repo edit/build/test/commit/push。

---

## §8 Risks

| ID | risk | probability / impact | mitigation |
|---|---|---|---|
| R-SIDE-01 | local CLOG bit覆盖TT/redo造成false commit/abort | 中/灾难 | authority graph + U05/U08 + Rule 8.A fail closed |
| R-SIDE-02 | PREPARED因origin node死亡被自动abort | 中/灾难 | database pending state + RECO-style resolution + L5/L6 |
| R-SIDE-03 | MULTIXACT被称可重建但redo退休后无source | 高/高 | consumer/source proof进入retire denial；U09/L8 |
| R-SIDE-04 | current 24-byte HWM delta被包装成canonical page ABI | 高/灾难 | SPACE-ABI STOP + mutation zero test |
| R-SIDE-05 | volatile master HWM较大值在restart后赢过canonical state | 中/灾难 | cache-only；PageVersion/expected-before/post-read |
| R-SIDE-06 | recoverer target write torn且stable base未知 | 高/灾难 | inherit PAGE stable-base STOP；不选carrier |
| R-SIDE-07 | route totality遗漏rare rmgr/opcode形成silent no-op | 中/高 | generated exact-object set equality + unknown default BLOCKED |
| R-SIDE-08 | cold/online各保留一份parser后语义漂移 | 中/高 | call-graph/link guard + L1 |
| R-SIDE-09 | resource-scoped gate漏依赖导致too-early serve | 中/灾难 | explicit dependency closure；unknown闭包BLOCKED；U13/L14/L15 |
| R-SIDE-10 | implementation为证明完成重新发明side terminal file | 中/高 | §1.3 exclusion + G4/G6/Rule-26 review |
| R-SIDE-11 | projection rebuild进入normal transaction同步路径 | 中/高 | 0/0/0 instrumentation + consumer-scope close/recovery rebuild |
| R-SIDE-12 | patent/Oracle术语被外推成PGRAC bytes/actor | 低/高 | evidence labels + G5/G5′ |
| R-SIDE-13 | same version conflict被mtime/max/majority掩盖 | 中/灾难 | symmetric BLOCKED L19 |
| R-SIDE-14 | SIDE自行批准redo retirement，漏掉PAGE/ROOT consumer | 中/灾难 | consume AD-019 FND-10 only；ROOT sole retire decision/caller |
| R-SIDE-15 | unknown FSM state被当rebuildable hint，造成duplicate allocation | 中/灾难 | exact complete-rebuild proof门；unknown nonlogged BLOCKED |
| R-SIDE-16 | database-scoped pending被误做成whole-instance availability barrier | 中/高 |只阻塞prepared dependencies/2PC consumer；healthy resource L15 |

---

## §9 Q&A — approved baseline and unresolved parameters

### Q-SIDE-01 normal transaction outcome从哪里来？

- A. ★ shared TT/undo + matching terminal redo。
- B. node-local status SLRU。
- C. new standalone result family。

**状态：USER-APPROVED BASELINE。** A对齐Oracle TT/undo/redo责任；B/C不再承权威。

### Q-SIDE-02 PREPARED由谁持久化？

- A. ★ database-scoped pending state + TT/undo + prepare redo，RECO-style resolution。
- B. failed-origin local file only。
- C. missing后推定abort。

**状态：USER-APPROVED BASELINE。** A；exact cluster binding仍G3，不能把目标写成现状。

### Q-SIDE-03 PG status stores是什么角色？

- A. authority。
- B. ★ derived projections with rebuild/verify/fail-closed。
- C. 可删除且所有consumer直接走network。

**状态：USER-APPROVED BASELINE。** B保留PG compatibility并保持normal path 0/0/0。

### Q-SIDE-04 HWM authority放哪里？

- A. per-master shmem/checkpoint image。
- B. ★ WAL-logged shared canonical metadata page。
- C. WAL delta本身永久作为allocation map。

**状态：USER-APPROVED RESPONSIBILITY。** B；exact page/redo ABI仍Rule-26 STOP。

### Q-SIDE-05 readiness scope是什么？

- A. 所有side domain完成后whole instance开放。
- B. 任意一项完成就开放instance。
- C. ★ exact resource/thread dependency闭包。

**状态：USER-APPROVED BASELINE。** C；unaffected/recovered resource可early open。

### Q-SIDE-06 unknown route怎么办？

- A. 无block ref即noop。
- B. warn后继续。
- C. ★ `BLOCKED`且不推进coverage/readiness。

**状态：APPROVED INPUT。** C满足Rule 8.A与totality。

### Q-SIDE-07 MULTIXACT projection source在WAL退休后不可证怎么办？

- A. 当empty。
- B. 从local raw id猜。
- C. ★ deny retirement while an exact consumer remains；若source已丢则相关scope BLOCKED。

**状态：BASELINE IMPLICATION。** C不发明新canonical store；future优化需另走Rule 26。

### Q-SIDE-08 exact canonical space ABI怎么定？

- A. 直接把current 24-byte delta当page record。
- B. 在spec中自行选择header/bitmap layout。
- C. ★保持`STOP-RF-SIDE-SPACE-ABI`，先做Oracle/PGRAC evidence与候选裁决。

**状态：USER DECISION REQUIRED BEFORE PRODUCT TDD。** 当前只能选择C。

### Q-SIDE-09 second-recoverer stable base怎么处理？

- A. 假定retained redo足够。
- B. 自行选择任一未经批准的stable-base carrier。
- C. ★继承`STOP-RF-PAGE-STABLE-BASE`，等待RF-PAGE/user裁决。

**状态：UNRESOLVED。** 本文不越权选carrier。

---

## §10 Prospective implementation plan（产品授权后）

| step | scope | prerequisite / exit gate |
|---|---|---|
| P-SIDE-00 | freeze ROOT/PAGE cross-contract names without fields | integrator verifies no ownership overlap |
| P-SIDE-01 | exact-f076 generated route and single-parser RED | 26/132/generic set equality RED for missing row |
| P-SIDE-02 | split TT/undo pure decode and canonical primitive | normal commit/abort identity matrix GREEN; no second switch |
| P-SIDE-03 | bind database pending 2PC substrate | prepare/resolution crash matrix GREEN; origin-local assumption removed |
| P-SIDE-04 | demote and rebuild CLOG projection | no local-bit authority; miss/corrupt tests GREEN |
| P-SIDE-05 | implement MULTIXACT/COMMIT_TS projection contracts | source/retention/coverage tests GREEN |
| P-SIDE-06 | obtain user approval for canonical space ABI | Rule-26 evidence/options recorded; no coding before approval |
| P-SIDE-07 | TDD canonical space pages after approval | PAGE version/expected-before/durability/post-read gates GREEN |
| P-SIDE-08 | wire per-resource serve and retention consumers | A-ready/B-blocked and retire-denial live-call tests GREEN |
| P-SIDE-09 | run repeated-recoverer/stale-owner/faithful crash suite | every cut hit>0; stable-base decision satisfied |
| P-SIDE-10 | run compatibility, 0/0/0 performance and hygiene | vanilla/feature-off/cluster modes GREEN |
| P-SIDE-11 | scoped CC review and user checkpoint | exact conflict list empty or resolved; still no formal-pass claim |

计划不估算或冻结LOC，因为ROOT/PAGE exact API与space ABI尚未批准。以LOC猜字段会违反G9和Rule 26。

---

## §11 Compatibility、rollback 与 formal handoff

1. 当前rewrite不冻结on-disk/wire/catalog/WAL ABI；future change必须独立capability/version gate。
2. mixed-version node不能理解canonical space page或pending binding时，相关resource fail closed；不得走old
   master-local path。
3. projection可丢弃/rebuild，但shared TT/undo/pending/space truth不可由projection rollback覆盖。
4. old master-local HWM image只可作为migration input candidate；若identity/version/coverage不可证则忽略，
   不能成为steady fallback。
5. rollback implementation只允许回到仍满足FND-10且没有资源由新canonical truth开放的边界；不能复活
   standalone authority或whole-instance terminal chain。
6. RF-SIDE向formal campaign只交route digest、fault provenance、resource readiness/denial、projection
   verification、canonical metadata durability与0/0/0 evidence；R15 judge不由本文修改。
7. fresh real `4×1×3 + rate10/20/30`通过后双方停止；在此之前spec green不等于campaign complete。

---

## 版本历史

| version | date | status | summary |
|---|---|---|---|
| v0.1–v0.3 | 2026-08-04 | `HISTORICAL / SUPERSEDED` | F1 three-family outcome、bounded terminal、global readiness与per-master HWM direction |
| v1.0 | 2026-08-05 | `REOPENED DRAFT — BASELINE USER APPROVED; EXACT BODY PENDING CC; PRODUCT NOT AUTHORIZED` | Oracle-first rewrite：shared TT/undo/redo、database pending 2PC、derived PG projections、canonical space metadata、exhaustive route、resource-scoped readiness与Rule-26 STOPs |

<!-- NORMATIVE-BODY-END -->

| Fingerprint metadata | 值 |
|---|---|
| body_sha256 | `17b062d1c5eed83516912e7158ab73fc2f5751148c7cfddf90ae6ea8ad62cdac` |
| body_lines | `734` |
| body_bytes | `64241` |

---

## 工作区本地增量 1：D-SIDE-06/07/08 落地（2026-08-20）

**交付**（spec §1.2 D-SIDE-06/07/08，judgement-only 语义层，与 RF-PAGE
PGDEL 同风格）：

- `src/include/cluster/cluster_side_recovery.h` + `src/backend/cluster/
  cluster_side_recovery.c`：
  - **D-SIDE-06** `cluster_side_page_consumer_ready`：canonical
    TT/undo/space 页消费 RF-PAGE proof——identity/class 已知 +
    expected-before 精确 + PGDEL-06 proof 完整（contributor coverage +
    durability + post-read + authority revalidated）；任一缺 →
    BLOCKED；**不复制 page parser**（只读 proof 字段）。
  - **D-SIDE-07** `cluster_side_resource_readiness`：严格 per-resource
    （FND-09）——判定只含本 resource 的事实，healthy unrelated
    resource 永不被 side-wide 阻塞，无 whole-instance barrier（§4 row）。
  - **D-SIDE-08** `cluster_side_retention_proof_ready`：FND-10 的 SIDE
    侧——affected set 全部 durable + 全部 canonical post-read + 无
    consumer → READY；否则精确 denial（NOT_DURABLE / NO_POST_READ /
    CONSUMER / INVALID）；**永不自行删除 WAL**；logical DONE 不替代
    post-read。
- 边界：route totality census（D-SIDE-01）、TT/undo/2PC/projection
  primitive（D-SIDE-02..04）、canonical space metadata（D-SIDE-05，
  STOP-RF-SIDE-SPACE-ABI）、observability（D-SIDE-10）保持 RED；零
  ABI 改动。
- `src/test/cluster_unit/test_cluster_side_recovery.c`：3 组 RED 单测
  全绿（page-consumer 合取、per-resource 隔离、retention 精确 denial）。
- **t274 L4/L5 闭环归属**：PCM-X runtime reformation（peer 新 session
  re-bind + gated re-activate）属于 D-SIDE-07 的 serve-readiness 落点
  ——`cluster_pcm_x_runtime_activate_bound` 已支持 RECOVERY_BLOCKED→
  ACTIVE 重入但要求 stranded-ACTIVATING marker（正常 fail-closed 的
  generation != 0 且 activation_retry_generation == 0 不满足）——
  reformation 新入口见下一步（独立 commit）。

---

## 工作区本地增量 2：t274 L4/L5 根因实锤 + PCM-X re-form 设计要点（2026-08-20）

### 根因（t274 两轮日志实证）

- L4/L5 均败于 `wait_for_pcm_x_active TIMEOUT: node0=0 node1=0`——**双节点
  PCM-X runtime 均非 ACTIVE**（日志：
  `cluster PCM-X runtime fail-closed (recovery blocked) at
  cluster_pcm_x_convert.c:2962` 双节点各一条，L4 后 node1 新进程
  01:06:23、node0 01:06:15；L5 同形）。
- **精确因果**：PCM-X formation binding（peer_frontiers/outbound_targets
  的 cluster_epoch + sender/target session）是 **activation 时快照**。
  L4/L5 的 clean stop/start 触发集群 reconfig（fail-stop epoch bump +
  peer 新 session），formation tick 的 ACTIVE 分支每 tick 用
  `cluster_pcm_x_runtime_peer_binding_revalidate_exact`（:2962）重验
  快照——epoch/session 任一变化 → STALE → `pcm_x_runtime_fail_closed`
  → RECOVERY_BLOCKED；BLOCKED 分支直接 return（"non-pristine"），
  `activate_bound` 的重入要求 stranded-ACTIVATING marker（正常
  fail-closed 的 generation != 0 且 activation_retry_generation == 0
  不满足）→ **任何 reconfig 后 runtime 永久冻结**（非仅 peer 重启）。
- 既有注释自认："permanently closed until the deferred crash-recovery
  protocol intervenes"——该协议缺失 = 增量 62 形态 2 的实质。

### re-form 设计要点（独立 commit，下一轮）

1. 触发：formation tick 的 BLOCKED 分支，当 collect_formation 双采样
   稳定（epoch 一致 + 全部 MEMBER peer auth OK + 新 session）时调
   `cluster_pcm_x_runtime_reform(self_session, bindings)`。
2. 变化证据（防空转重入）：至少一个 peer 的 binding session != 当前
   outbound target session，或 collect epoch != 绑定 epoch。
3. **master_session 语义问题**：ticket/payload/local-progress 全部按
   `master_session_incarnation == runtime session` 校验（:4256
   pcm_x_runtime_token_exact），gate generation 不在 ticket 校验内。
   本节点未重启时 qvotec incarnation 不变 → reform 若不换 master
   session，旧 in-flight ticket 可跨 reform 存活（prehandle 重置 1 后
   可能误匹配）——**二选一**：
   a. reform 派生单调新 master_session（如 gate generation 混合）——
      改变 master_session 语义（从"节点 incarnation"变为"activation
      世代"），需审计全部 6+ 处 master_session 消费点；
   b. ticket 校验增加 activation generation 维度——PcmXLocalProgress/
     PcmXLocalHolderProgress/PcmXLocalCutoff 等 ABI StaticAssert 结构
     扩字段（ABI 影响，需 product plan 批准？—— 均为 in-memory
     shmem/wire 结构，§8.2-4 冻结期需谨慎）。
4. 验收：t274 L4/L5（pair reformed 双断言）+ 无回归 t243。

### 归属

RF-SIDE D-SIDE-07（resource serve readiness）落点；PCM-X 是 block-
access serve 协议，re-form = 集群 reconfig 收敛后的 serve 门恢复。

---

## 工作区本地增量 3：PCM-X re-form 协议设计定稿（2026-08-20，v1）

### 决定性发现（wire/世代语义审计）

1. **master_session 的 wire 语义 = 本节点 qvotec incarnation**：
   `retire_request_ingress_valid` 要求 `request->master_session_incarnation ==
   authenticated_session`（对端 auth session = 对端观测 incarnation）；
   `retire_ack_ingress_valid` 要求 == 本地 runtime master_session。
   → **方案 a（reform 派生任意新 master_session）否决**：对端会拒绝
   本节点的 retire 帧。master_session 必须保持 == 本节点 incarnation。
2. **ticket/tag_slot 的 epoch 世代绑定**：ticket ref 的
   `identity.cluster_epoch` 与确认路径的
   `tag_slot->cluster_epoch != ref.identity.cluster_epoch → STALE`
   （:4240）——tag_slot->cluster_epoch 在**新 tag 创建时**写入
   （:3803）且之后不更新；同 tag 跨 reconfig 的所有 ticket（含新
   epoch 请求）均 STALE。→ re-form 必须**显式推进 tag 世代**
   （更新存量 tag_slot 的 cluster_epoch），否则新 epoch 请求被拒
   （假 ACTIVE 风险）。
3. formation binding（peer_frontiers/outbound_targets 的 epoch +
   session）是 activation 快照；`:3453` 只支持首次绑定或同
   epoch/session 确认；变化 → STALE → fail_closed（永久，无恢复
   → t274 L4/L5 双节点 0 的根因）。

### re-form 协议 v1

**触发**：formation tick（cluster_gcs_block.c:12529 BLOCKED 分支），
collect_formation 双采样稳定（epoch 一致 + 全 MEMBER peer auth OK +
session 非零）+ 变化证据（collect epoch != 绑定 epoch，或任一 peer
session != 绑定 session）→ `cluster_pcm_x_runtime_reform(bindings)`。

**执行**（cluster_pcm_x_convert.c 新函数，复用 activate_bound 主体）：
1. 前置：gate == RECOVERY_BLOCKED；bindings 非空；变化证据；master
   session 不变（== incarnation）。
2. CAS gate BLOCKED→ACTIVATING（generation+1）。
3. 对每个 peer：frontier/outbound 的 cluster_epoch ← collect epoch、
   sender/target_session ← collect session；**session 变化的 peer 的
   prehandle sequence 重置 1**（重启的新进程从 1 开始），**session
   不变的 peer 的 sequence 保持**（in-flight 连续性；无 peer 重启
   的 reconfig 不打断转换）。
4. **tag 世代推进**：遍历 master tag 目录（需新增 allocator 遍历
   API：pcm_x_allocator_visit/PCM_X_DIR_MASTER_TAG），把所有存量
   tag_slot->cluster_epoch 更新为 collect epoch——旧 epoch ticket
   全部 STALE（悬置持有保持 frozen，D3′/RF-ROOT recovery 重 census
   处置），新 epoch 请求可用。
5. 发布 ACTIVE（generation+1）。

**安全性**：
- 世代隔离由 epoch 绑定提供（旧 ticket 因 tag_slot epoch 推进而
  STALE；悬置持有 frozen = fail-closed 方向）。
- session 不变的 peer 的 in-flight 因 sequence 保持而正常收尾
  （其 ticket 的 epoch 若已因步骤 4 失效——注意：步骤 4 会让所有
  旧 ticket STALE，包括 session 不变 peer 的 in-flight！——取舍：
  要么 tag 世代推进放弃 in-flight 收尾（悬置 + D3′），要么只推进
  受影响 tag。v1 取前者：**reconfig 后旧世代全部悬置**，语义最
  简单、fail-closed 最干净；代价是 in-flight 转换需 recovery 重
  放——与 B′/RF-ROOT 的 crash-recovery 面一致）。
- 双节点时序：各自 formation tick 驱动；中间态（一方已 reform）
  对端仍 BLOCKED 时拒绝新帧（fail-closed），收敛后正常。
- master_session 不变 → wire 语义（retire/ack ingress）保持。

**验收**：t274 L4/L5（pair reformed + 服务）+ t243 无回归 +
test_cluster_pcm_x_convert 新增 re-form 单测（前置真值表、变化证据、
sequence 重置/保持规则、tag 世代推进、CAS 失败路径、revalidate
STALE 后 reform 恢复 ACTIVE）。

### 依赖/前置

- allocator 遍历 API（PCM_X_ALLOC_MASTER_TAG 域）——新增，纯
  shmem 内遍历（无 ABI 影响）。
- formation tick BLOCKED 分支接线。
- 悬置持有的 D3′ 处置与 RF-ROOT/PAGE 面（FND-10 已有 deny 语义）。

---

## 工作区本地增量 4：D-SIDE-01 落地（2026-08-20）

**交付**（spec §1.2 D-SIDE-01：single decoder、total route registry、
cold/online common primitive graph；unknown default BLOCKED）：

- `src/include/cluster/cluster_side_route.h` + `src/backend/cluster/
  cluster_side_route.c`：
  - **total route registry**（§3.2 matrix）：opcode 粒度行覆盖
    matrix 具名 opcode（XLOG 的 FPI/FPI_FOR_HINT→PAGE、NOOP/SWITCH/
    RESTORE_POINT/BACKUP_END→PROVED_NOOP(CONTROL_ONLY)、checkpoint/
    control 系列→BLOCKED；XACT 的 COMMIT/ABORT/PREPARE/COMMIT_PREPARED/
    ABORT_PREPARED/ASSIGNMENT→TT_UNDO（HAS_INFO 位用忽略位掩码）、
    INVALIDATIONS→BLOCKED；SMGR CREATE/TRUNCATE→STORAGE；CLOG/
    COMMIT_TS/MULTIXACT→PROJECTION；STANDBY LOCK/RUNNING_XACTS→
    PROVED_NOOP(PRIMARY_NO_STANDBY_CONSUMER)；CLUSTER_UNDO 的
    TT/undo 系列→TT_UNDO、XLOG_HW_RESERVE→BLOCKED（STOP-RF-SIDE-
    SPACE-ABI））+ rmgr 粒度行（mask 0xFFFF：页族→PAGE、DBASE/
    TBLSPC/RELMAP/REPLORIGIN/RAW_LAYOUT/ADG/XID_STRIPE→BLOCKED、
    LOGICALMSG→PROVED_NOOP(LOGICAL_MESSAGE_ONLY)）；未知
    rmgr/opcode 无行 → lookup false → BLOCKED。
  - `cluster_side_route_verdict`：§2.1 verdict **纯函数**（U-SIDE-02：
    cold/online 对同 record 同 route 同 verdict，差异只在 process
    severity）。
  - **single-parser 契约面**（U-SIDE-03）：registry 是唯一 route
    判定点——消费方只用 lookup+verdict，无第二 opcode switch。
  - 实现要点：exact-opcode-0 行（如 XLOG_CHECKPOINT_SHUTDOWN=0x00）
    与 rmgr 粒度行必须区分（lookup 对 mask==0 恒 exact 匹配含
    opcode 0；rmgr 粒度用 0xFFFF 掩码）——首版 wildcard 泄漏被单测
    抓住。
- 边界：132/132 opcode 的机械生成 census（G1，U-SIDE-01 全量）留
  增量后续；payload decoders（D-SIDE-02..04）、cold/online wrapper、
  observability（D-SIDE-10）保持 RED；零 ABI 改动。
- `src/test/cluster_unit/test_cluster_side_route.c`：3 组 RED 单测全绿
  （matrix 具名行、unknown 默认 BLOCKED、verdict 纯函数/冷热一致）。

---

## 工作区本地增量 5：D-SIDE-02 落地（2026-08-20）

**交付**（spec §1.2 D-SIDE-02：decode 与 apply 分离；normal TT/undo
truth 只走一份 primitive；不得宣称现有 recovery writer 已安全）：

- `src/include/cluster/cluster_side_undo.h` + `src/backend/cluster/
  cluster_side_undo.c`：
  - `cluster_undo_decode`：§2.1-1 纯解析——RM_CLUSTER_UNDO 单 record
    → caller-owned parsed 字段（kind/opcode/instance/segment_id/
    slot_offset/wrap/xid/commit_scn/block_no/has_payload），逐 opcode
    精确长度校验（与 production handler 同 shape）；未知 info / 错误
    rmgr / malformed length → false（BLOCKED，U-SIDE-04）；零
    I/O/零 mutation/不重读 raw record。
  - `cluster_undo_preflight`：§2.1-2——D-SIDE-01 route（TT_UNDO 行
    过；XLOG_HW_RESERVE 恒 BLOCKED，STOP-RF-SIDE-SPACE-ABI）+ 字段
    完整性（TT slot_offset < TT_SLOTS_PER_SEGMENT、xid 有效）——
    任一 false → 零 mutation（U-SIDE-05 one-at-a-time 面）。
  - **不得宣称现有 recovery writer 已安全**：apply 的执行仍由
    production redo handler 负责（RED，RF-ROOT/RF-PAGE 集成轮接线）。
- 边界：2PC binding（D-SIDE-03）、projection producer（D-SIDE-04）、
  canonical space metadata（D-SIDE-05，STOP）保持 RED；零 ABI 改动。
- `src/test/cluster_unit/test_cluster_side_undo.c`：4 组 RED 单测全绿
  （TT_COMMIT 字段解析 + preflight、malformed/unknown/错 rmgr
  BLOCKED、字段完整性逐项 + HW_RESERVE BLOCKED、BLOCK_WRITE 字段 +
  payload 标志）。

---

## 工作区本地增量 6：D-SIDE-03 落地（2026-08-20）

**交付**（spec §1.2 D-SIDE-03：database-scoped PREPARED pending state、
RECO-style recovery ownership、exact prepare/terminal binding）：

- `src/include/cluster/cluster_side_prepared.h` + `src/backend/cluster/
  cluster_side_prepared.c`：
  - `cluster_side_prepared_verdict`：§2.3 PREPARED 四事实合取
    （prepare terminal redo + **database-scoped durable** pending entry
    + 匹配 TT/undo identity + 精确 GID/identity）→ IN_DOUBT；任一缺/
    冲突 → BLOCKED（U-SIDE-06 顺序 + U-SIDE-07 identity 冲突对称
    BLOCKED；origin-local file / recoverer-local cache 不承重——由
    caller 的 pending_durable_ok 事实承载）。
  - `cluster_side_prepared_resolve_ready`：RECO-style resolution——
    terminal redo + 精确 pending/prepare 匹配 + 侧完成（COMMIT=TT
    匹配；ROLLBACK=verified undo 完成）全成立才 ready；terminal-
    before-prepare 与 premature abort 恒 BLOCKED（§4：restart 永不
    自动 abort；locks/resources 只在 matching resolution durable
    verified 后释放）。
- 边界：durable pending store 与 RECO resolution ownership 仍是生产
  2PC/TT wiring（RED）；零 ABI 改动。
- `src/test/cluster_unit/test_cluster_side_prepared.c`：2 组 RED 单测
  全绿（in-doubt 合取逐项、resolution 合取 + terminal-before-prepare/
  premature abort 拒绝）。
