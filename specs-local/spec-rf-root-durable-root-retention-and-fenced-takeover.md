# RF-ROOT — Failed-origin duty, layered fencing, and redo retention

> **Status: EXACT BODY ACCEPTED BY CC — USER-APPROVED BASELINE; PRODUCT NOT AUTHORIZED**
>
> User 于 2026-08-05 批准“按照 oracle 策略推进”。本文只修订私有设计规范；
> `PRODUCT AUTHORIZATION = 0`，不授权修改、构建、测试、commit 或 push
> `/Users/sqlrush/linkdb`。任何超出 AD-019 baseline 的 field、carrier、actor、message、
> persistent artifact 或 lifecycle phase 必须重新触发 Rule 26。

| 可变元数据 | 值 |
|---|---|
| 决策日期 | 2026-08-05 |
| 权威上游 | `docs/ad-019-oracle-rac-recovery-foundation.md` v1.0 |
| 精确产品证据 | `f076653df977dfa67c1f8fdaa1f985daf0a240b4`（只读） |
| 规范正文 fingerprint | `3461d12cb564c13529e227094e151160032578046e332bece567013ddb183cd0` |
| 规范正文行数 / bytes | `789` / `50131` |
| SPEC EDIT AUTHORIZATION | `1` |
| PRODUCT AUTHORIZATION | `0` — **PRODUCT NOT AUTHORIZED** |
| formal 目的地 | 高性能真实 `4×1×3 + rate10/20/30`；本文不声称已运行或已通过 |

<!-- NORMATIVE-BODY-BEGIN -->

## §0 决策摘要与文档边界

RF-ROOT 只拥有 failed-origin duty/control root、active-recoverer authority、四层 fence、
failed-origin WAL retention、redo-reuse 拒绝和 recoverer 再失败后的 rebuild-first 行为。
它不拥有 page codec/source class，也不拥有 TT/undo/PREPARED/HWM 的 truth model。

本 revision 的结论是：

1. duty 始终锚定 **failed-origin redo thread + durable control root**。recoverer node、
   node-local anchor、local progress file、telemetry 和 wall-clock timeout 都不是 duty identity。
2. active recoverer 必须同时满足 current membership、failure generation、recovery/thread
   serialization 与 control-root identity 的 fresh validation。exact-f076 只提供部分 substrate；
   缺失部分保持 prospective/Rule-26 STOP。
3. stale owner 必须在 membership、I/O、control-root publication、redo-reuse 四个边界被拒绝。
   单独的 NON-SERVING、CSSD DEAD、provider request accepted 或 command exit 0 都不足。
4. recoverer crash 后的 correctness 路径是 D3' rebuild-first：重新读取 retained canonical
   failed-origin redo、validated CURRENT/PI、checkpointed pages/undo，并重新取得 resource authority。
   predecessor recoverer 的 private progress 不承重。
5. 独立持久 old artifact 只有在 lineage、version、control-root identity 全部重新验证后，才可作
   optimization；验证失败、缺失或 generation 不匹配时必须忽略并 rebuild。
6. failed-origin WAL/control-root inputs 一直 pin 到 AD-019 `FND-10` 成立。RF-ROOT 的 retire
   decision 必须消费 RF-PAGE 与 RF-SIDE 的 durable post-read proof；不得用逻辑 DONE、write return、
   local cache rehydrate 或 node join 替代。
7. `STOP-RF-PAGE-STABLE-BASE` 被完整继承。该 STOP 未关闭且 RF-PAGE 尚无 typed proof 时，affected
   page resource 不得 release、相关 failed-origin WAL 不得 retire，repeated-recoverer page correctness
   不得宣称闭环。
8. 本文不选择 control-root carrier、durable cluster-common failure-generation field、RT resource、
   completion certificate、successor WAL/checkpoint 或 predecessor artifact chain。

---

## §1 权威证据与 exact-f076 census

### §1.1 AD-019 imports（只消费，不重定义）

AD-019 唯一定义 evidence labels、stable vocabulary 和 `FND-01`–`FND-11`。RF-ROOT 不复制定义；
下表仅记录本文如何消费上游 ID、产出什么局部证明：

| Imported ID | RF-ROOT local obligation | 本文输出 |
|---|---|---|
| `FND-01` | 所有产品事实绑定 exact f076；Oracle claim 使用 AD 的 evidence class | §1 census、§10 G5/G5′ |
| `FND-02` | census failed-origin/control-root 与 active-recoverer substrate | §2 duty/authority predicates、`STOP-ROOT-CONTROL`、`STOP-ROOT-SERIAL` |
| `FND-03` | 四个 fence boundary 都有 admission、revalidation、caller census | §3 fence matrix、§7 fault legs |
| `FND-04` | D3' rebuild-first；old artifact 只作 validated optimization | §5 restart state machine |
| `FND-05` | buddy/replica/telemetry/local state miss 不改变 correctness | §5.3 optimization fallback |
| `FND-09` | root authority 与 release 保持 resource/thread scope | §2.5、§4.3、§6.3 |
| `FND-10` | ROOT 只拥有 retire decision；PAGE/SIDE 产 durable proof | §6 retention conjunction |
| `FND-11` | normal transaction 0/0/0；formal judge/口径不改 | §8 performance、§9 verification |

`FND-06`–`FND-07` 由 RF-PAGE 独占。RF-ROOT 只消费 PAGE 返回的 source/version/durable
post-read verdict，不定义 PageVersion、expected-before、page class 或 contributor algorithm。
`FND-08` 由 RF-SIDE 独占。RF-ROOT 只消费 TT/undo/PREPARED/space-metadata durable post-read
verdict，不定义其 bytes、route 或 transaction outcome。

### §1.2 Oracle evidence binding

本文引用 AD-019 的以下 evidence entries，不增加新的 Oracle internal claim：

| AD evidence | RF-ROOT 允许使用的结论 | 禁止外推 |
|---|---|---|
| `OE19-01` | failed-origin redo thread 位于 shared storage，可被 survivor/next opener 恢复 | Oracle control-root bytes、PGRAC file/API |
| `OE19-02` | 仍被 instance recovery 需要的 redo 不能 clear/reuse | exact PGRAC pin carrier |
| `OE19-04`–`OE19-05` | recovery/remaster/release 是 per block/resource；public material 字面列出 simultaneous/sequential failures | active recoverer 再失败后的 duty handoff 形状或 exact protocol |
| `OE19-09` | checkpoint/data durability 与 redo recoverability 有 ordering | logical completion 可替代 durable bytes |
| `SE19-02` 🟡 `NON-BEARING` | Recovery Buddy 名称材料只作易失加速 hint 的边界提示，不承重 | buddy 是 durable authority 或 Oracle product contract |
| `SE19-01` 🟡 `NON-BEARING` | Oracle-hosted expert answer 中 cache/media roll-forward apply 不生成新 redo 的窄边界；仅作边界提示 | successor WAL 是 Oracle 既定 carrier，或该 answer 是 product manual contract |
| `PE19-03` | failure/event freshness 阻止旧 completion 复活 resource | durable failure-generation layout |
| `PI19-01` | D3' 是 approved PGRAC mapping | D3' 是 Oracle 已公开内部协议 |
| `PI19-02` | exact-f076 无 successor carrier时使用 retain-until-durable/post-read 腿 | stable-base gap 已自动闭合 |

exact Oracle adopt/resume/discard、private recovery progress、atomic control-root bytes、same-generation
successor handoff 仍是 **PUBLICLY UNKNOWN**。本文不得把这些未知变成“Oracle 就是这样做”的陈述。

### §1.3 exact-f076 product facts

以下事实只绑定 object `f076653df977dfa67c1f8fdaa1f985daf0a240b4`：

| ID | exact evidence | 可以依赖的事实 | 不能声称 |
|---|---|---|---|
| `RFX-01` | `cluster_recovery_anchor.h:55-85`; `cluster_recovery_anchor.c:6-14,31-33` | restart anchor 是 per-node，供本节点重启读取 | survivor-readable failed-thread control root |
| `RFX-02` | `cluster_wal_thread.h:43-81`; `cluster_wal_thread.c:423-489` | immutable write-once `{thread_id,node_id,created_at}` claim 存在 | incarnation、failure generation、OPEN/CLOSED 或 recoverer owner |
| `RFX-03` | `cluster_wal_state.h:100-134` | 每 thread 有 ACTIVE/STOPPED 与 watermarks；crash inference 合并 stale ACTIVE + CSSD DEAD | wal-state 是 durable control root 或 retention authority |
| `RFX-04` | `cluster_recovery_merge.c:128-229` | node-local `merged.authority` 有 origin/recovered LSN/CRC | failure generation、survivor-readable lineage 或 cluster authority |
| `RFX-05` | `cluster_membership.h:92-180` | membership 与 admitted-incarnation floor 存在 | `cluster_epoch` 在 postmaster crash 后 durable |
| `RFX-06` | `cluster_cssd.h:263-323` | local `dead_generation` 与 event_id 存在；不同节点 generation 可不同 | cluster-common durable failure generation |
| `RFX-07` | `cluster_ir.h:86-157`; `cluster_ir_lock.c:121-239` | `IR(X)` 以 dead node + 64-bit episode epoch 为 key；GES grant 是最近的 serialization substrate | RT resource；multi-survivor online recovery；same-generation successor contract |
| `RFX-08` | `cluster_recovery_merge.h:300-390`; `.c:423-580` | cold global claim 是 whole-crash `{sysid,node,CRC}`；同 node 可 readopt | dead peer automatic takeover 或 resource-scoped authority |
| `RFX-09` | `cluster_write_fence.h:9-15,114-169`; `cluster_write_fence.c:155-217,315-341,443-474`; `cluster_smgr.c:399-406,473-478,521-528,549-558,613-620,670-679`; `cluster_block_recovery.c:382-411`; `cluster_thread_recovery_replay.c:331-393`; `cluster_thread_recovery_orchestrator.c:326-408` | membership/cooperative durable write fence 与 cluster-routed create/unlink/extend/zeroextend/write/truncate choke points 存在；block/thread recovery 经 `smgrwrite` 进入该 family，authority publish 前有 durable-marker recheck | external I/O eviction、全部 canonical I/O coverage、failed-thread CLOSED fence、WAL-write/reuse fence |
| `RFX-10` | `xlog.c:7567-7733,8432-8497` | ordinary slot/wal_keep/backup pins 参与 `KeepLogSeg` | recovery duty、control root 或 `merged.authority` 已 pin WAL |
| `RFX-11` | `xlogrecovery.c:2451-2466`; `cluster_recovery_merge.c:953-965`; `cluster_hw_remaster.c:470-487` | wal-state authority 有三个 correctness consumer | 可删除旧 path 而不逐个迁移 consumer |
| `RFX-12` | `xlog.c:7567-7598` | owner anchor publish 绕过 CF/JOIN_READONLY，随后 checkpoint 可进入 recycle | stale-owner publish/reuse 已有 gate |
| `RFX-13` | `cluster_thread_recovery_replay.c:376-398` | recovery 用 `smgrwrite` 直接改 target | recovery-generated successor `XLogInsert` 已存在 |
| `RFX-14` | `cluster_thread_recovery_worker.c:84-97,208-290,294-305`; `cluster_thread_recovery.h:412-430` | online thread-recovery executor 异常退出使当前 slot BLOCKED；worker 为 `BGW_NEVER_RESTART`；当前 episode 不重注册，新 episode 可重启 | 所有 recovery worker 均无 same-episode 应用层重试；同 generation successor protocol |
| `RFX-15` | `cluster_gcs.c:240-265`; `cluster_grd.c:1445-1472,1475-1550`; `cluster_gcs_block.c:1813-1867,5765-5833` | per-tag static-home/recipient-epoch eligibility filter 存在；completion gate 实际是 current-episode all-survivor barrier，`tag` 未参与 completion 判定 | true per-resource completion/release 已闭合 |

### §1.4 Prospective STOP ledger

| STOP ID | exact missing substrate | 允许工作 | 禁止动作 |
|---|---|---|---|
| `STOP-ROOT-CONTROL` | survivor-readable failed-thread control root carrier、lifecycle 与 atomic publish contract 未找到 | caller census、required-property list、Oracle research | 冻结新文件/layout/slot/field |
| `STOP-ROOT-GENERATION` | durable cluster-common failure generation 未找到 | 比较 membership/CSSD/GRD existing identities | 把 local `dead_generation` 直接升级为 durable truth |
| `STOP-ROOT-SERIAL` | exact-f076 IR(X) 未证明 multi-survivor/same-generation succession；RT resource 未找到 | IR caller/hold/release census、wait graph、gap report | 发明 RT identity、claim ledger 或新的 lock resource |
| `STOP-ROOT-IO-FENCE` | external I/O eviction/terminal verification provider 未找到 | provider responsibility/caller census | 选择命令、IPC、receipt schema 或把 cooperative fence 冒充 external fence |
| `STOP-ROOT-REUSE` | control-root-aware `KeepLogSeg`/remove/recycle gate 未找到 | enumerate every reuse/remove caller | 在 proof 未闭合前允许 recycle |
| `STOP-RF-PAGE-STABLE-BASE` | repeated recoverer crash-cut stable base 未闭合 | 继承 RF-PAGE research/decision | 选择 successor WAL/FPI、doublewrite、private journal |

任一 STOP 未关闭时，本文仍可完成 specification/census，但产品 TDD 与相应 mutation/retirement
保持 fail closed。STOP 不能通过改名、默认值、test-only carrier 或“先实现再确认”绕过。

---

## §2 Scope 与 semantic interface

### §2.1 包含

本 spec 包含：

1. failed-origin duty 的逻辑身份和 root required properties；
2. active-recoverer admission 与每次 mutation/release 前的 fresh revalidation；
3. membership/I/O/control-root/redo-reuse 四层 fence；
4. exact-f076 lock/wait/caller census 与缺口 STOP；
5. recoverer crash 后 rebuild-first restart；
6. failed-origin WAL/control-root pin、PAGE/SIDE proof consumption 与 retirement denial；
7. stale wal-state correctness consumers 的迁移义务；
8. recovery-only observability、fault tests、G1–G9、formal performance honesty。

### §2.2 明确不包含

| 不做的事 | owner / 原因 |
|---|---|
| 不冻结 control-root on-disk/wire/API carrier | `STOP-ROOT-CONTROL`；Oracle/public product证据不足 |
| 不新增 failure-generation persistent field | `STOP-ROOT-GENERATION` |
| 不新增 RT resource 或等价 GES class | `STOP-ROOT-SERIAL` |
| 不选择外部 fence provider、IPC 或 receipt bytes | `STOP-ROOT-IO-FENCE` |
| 不生成 recovery successor WAL/checkpoint | AD-019/RF-PAGE 尚未批准 |
| 不定义 predecessor recovery artifact chain | D1/D2 rejected；D3' rebuild-first |
| 不定义 PageVersion/expected-before/page class | RF-PAGE owner |
| 不定义 TT/undo/PREPARED/HWM bytes/route | RF-SIDE owner |
| 不设 all-domain whole-instance barrier | `FND-09` resource/thread scope |
| 不修改或测试公开产品仓 | `PRODUCT AUTHORIZATION = 0` |

### §2.3 逻辑输入（notation only，不是新 ABI）

为了让 TDD 可写，以下名称只表示必须由已批准 substrate 提供的逻辑事实；它们不是字段、结构体、
文件、token、certificate 或 wire contract：

| 逻辑事实 | 最低语义 | 现状 |
|---|---|---|
| `origin_thread` | failed redo thread 的稳定 identity | thread claim 部分存在；完整 control binding未成立 |
| `control_root_identity` | 可定位 checkpoint lower bound、validated tail、origin identity 与 lifecycle state | carrier `NOT FOUND` |
| `membership_current` | recoverer incarnation 当前 admitted，failed owner 当前 excluded | membership substrate存在，需 exact caller revalidation |
| `failure_generation_current` | 与本次 failure/reconfiguration 一致，旧 completion 不能跨代复活 | cluster-common durable form `NOT FOUND` |
| `serialization_held` | exact duty/resource 只有一个 active mutator，且 ownership 覆盖 mutation critical interval | IR(X) closest；完整性未证明 |
| `external_io_fenced` | stale owner 对 shared data/control/WAL 的 I/O 已由独立 plane 阻断并可终态验证 | provider `NOT FOUND` |
| `page_post_read_ok(resource)` | RF-PAGE 对 exact resource 的 durable post-read verdict | RF-PAGE produces |
| `side_post_read_ok(resource)` | RF-SIDE 对 exact side resource 的 durable post-read verdict | RF-SIDE produces |

任何实现 proposal 若把 notation 固化为 bytes/API，必须先关闭对应 STOP 并取得 user approval。

### §2.4 Failed-origin duty predicate

`duty_open(origin_thread)` 只可在下列事实都成立时为真：

1. failed-origin thread identity 可由 shared canonical evidence验证；
2. durable control root 可读且 identity/integrity/lifecycle 与 origin thread一致；
3. control root 指向的 recovery lower bound 与所需 failed-origin redo interval 可定位且仍 retained；
4. current membership 明确排除 failed owner 的旧 incarnation；
5. 该 thread/resource 的 recovery obligation 尚未由 canonical durable state证明解除。

这是一组可重算 predicates，不是持久 duty object。缺失、CRC/identity mismatch、thread state未知、
redo interval有 gap 时，结果必须是 `BLOCKED`，不能降级为 node-local anchor 或 wal-state watermark。

### §2.5 Active-recoverer predicate

`active_recoverer(resource)` 只可在同一 validation round 中满足：

~~~text
duty_open(origin_thread)
AND membership_current(recoverer_incarnation, failed_owner_incarnation)
AND failure_generation_current(failure_event)
AND serialization_held(origin_thread, resource, failure_event)
AND control_root_identity_is_current(origin_thread)
~~~

该 conjunction 不产生持久 identity。每次 canonical mutation、control-root publication、resource release
与 redo-reuse decision 前都必须重新验证。任一输入改变，当前 actor 立即变 stale；旧成功返回、缓存结果、
IR owner node id 或 local generation 不能跨 reconfiguration 复用。

### §2.6 Mutation admission

`may_mutate(resource)` 需要：

1. §2.5 在 mutation critical interval 内持续为真；
2. §3 的所有 applicable fence 已完成；
3. RF-PAGE 或 RF-SIDE 已为该 exact resource 给出 source/authority admission；
4. mutation caller 在写前做 final fresh check；
5. 写后不释放 serialization，直到该 resource 的 durability/post-read contract完成或明确 BLOCKED。

若 existing IR(X) 无法覆盖上述 interval，`STOP-ROOT-SERIAL` 生效。本文不以“check 后马上写”代替
原子 authority，也不通过新增 token 弥补 TOCTOU。

---

## §3 Layered fencing、lock order 与 stale rejection

### §3.1 Four-boundary fence matrix

| Boundary | admission | mutation/release 前 revalidation | exact-f076 substrate | 未闭合时 |
|---|---|---|---|---|
| membership | failed owner incarnation excluded；recoverer incarnation admitted | reread membership/incarnation floor与 failure event | `cluster_membership.h`、CSSD/GRD episode inputs | `BLOCKED`；不得 serve/recover |
| I/O | cooperative write fence成立，并且 external plane terminally阻断 old owner I/O | 在 first canonical mutation 前和 reconfiguration 后重验 terminal outcome | cooperative fence/`cluster_smgr.c` exists；external eviction missing | `STOP-ROOT-IO-FENCE` |
| control-root publication | publisher是当前 live owner或当前 authorized recovery actor；root identity仍 current | checkpoint publish前、bypass path前、publish后 recycle前各重验 | `xlog.c:7567-7598` caller存在但 bypass当前 gate | deny publish；pin WAL |
| redo-reuse | `FND-10`、PAGE/SIDE proofs、consumer census和 current root lifecycle同时允许 | 每次 `KeepLogSeg`/remove/recycle/overwrite decision重算 | ordinary pins only；recovery pin missing | deny reuse/removal |

“fence request queued/accepted”“timeout elapsed”“CSSD DEAD”“cooperative marker majority”“NON-SERVING”
只能作为输入或观测，不能单独把任何一行判成 complete。

### §3.2 Stale-recoverer rejection points

以下 caller class 必须在 canonical mutation 前拒绝 stale actor：

1. page/undo/space `smgrwrite` 或 buffer publication；
2. TT/undo/PREPARED truth mutation；
3. checkpoint/control-root publication，包括绕过 CF/JOIN_READONLY 的路径；
4. recovery-progress shortcut publication；
5. per-resource remaster/release；
6. WAL remove/recycle/overwrite；
7. HWM validated-minimum 等仍消费旧 wal-state authority 的路径。

拒绝结果必须保留 failed-origin WAL/control-root input，撤销本 actor 的 local work，且不得发布“已完成”。
没有 authority 的 actor不能通过 retry deadline转成成功。

### §3.3 Lock order

本节只使用 exact-f076 已知 primitive 和显式 STOP；不冻结新 lock class：

1. **Snapshot**：读取 membership/admitted incarnation、CSSD/GRD failure episode与 control-root identity；
   释放所有短期 latch/LWLock。
2. **External fence wait**：若需 terminal I/O fence，在不持 PG LWLock、buffer lock、WAL insertion lock、
   checkpoint interlock 或 GES resource lock时等待。provider未批准则 STOP。
3. **Root serialization**：取得现有 `IR(X)` candidate serialization；立即重新读取 membership、failure
   episode和 control-root identity。若 IR semantics不足以满足§2.5/§2.6，则 STOP，不升级成另一资源。
4. **Resource authority**：在 root serialization已验证后，进入 RF-PAGE/RF-SIDE owned per-resource
   authority。顺序固定为 root serialization先、resource authority后。
5. **Mutation**：持有能覆盖 mutation critical interval的 authority；在写前 final fresh check。
6. **Durability/post-read**：PAGE/SIDE完成其 own durability与 canonical post-read；随后释放 resource authority。
7. **Release root serialization**：只在该 resource/thread局部结果已发布或 BLOCKED cleanup完成后释放。
8. **Recycle caller**：checkpoint/recycler不等待 recovery actor；proof未就绪直接 deny reuse并返回。

任何实现若要求持 IR(X) 等待 external provider、或反向以 resource lock请求 root serialization，必须 STOP
并给出 wait-for graph；不得用 timeout掩盖环。

### §3.4 Wait-for graph

允许的 wait edge 只有：

~~~text
recoverer (no PG/GES locks) -> external I/O fence terminal result
recoverer                  -> IR(X) for failed node/episode
IR(X) holder               -> exact PAGE/SIDE resource authority
resource authority holder  -> PAGE/SIDE durability I/O
~~~

禁止边：

~~~text
external-fence waiter holding IR(X) or PG locks
PAGE/SIDE resource holder -> acquire IR(X)
WAL recycler              -> wait for recoverer/proof
checkpoint publisher      -> wait for external provider while checkpoint locks held
~~~

redo recycler遇到未就绪 proof只可保留 WAL并记录 denial；它不是 recovery wait participant。

---

## §4 Control-root and caller migration contract

### §4.1 Required control-root properties

RF-ROOT 冻结语义属性，不冻结 carrier/format。一个 future approved carrier 至少要证明：

- database/shared-storage identity与 failed-origin thread identity；
- immutable thread-claim binding与 owner incarnation；
- checkpoint/recovery lower bound；
- validated failed-origin redo tail或可重算 tail的 canonical input；
- integrity、version compatibility与 lifecycle state；
- publication先于相应 redo reuse，且 crash后 survivor可读；
- stale owner不能 publish更高 lifecycle/checkpoint state。

这些是验收属性，不是字段清单。`STOP-ROOT-CONTROL` 关闭前不得选择 fixed file、slot count、shared
control-file offset、WAL record或其他 carrier。

### §4.2 Existing object disposition

| Existing object | 新角色 | 迁移要求 |
|---|---|---|
| per-node recovery anchor | exact owner本地 restart hint | survivor path不得读取它当 failed-origin root |
| immutable thread claim | origin thread identity input | 不追加 recoverer/failure/lifecycle字段直到另行批准 |
| wal-state ACTIVE/STOPPED/watermark | telemetry与gap census input | 三个 correctness consumer必须逐个迁移或 fail closed |
| node-local `merged.authority` | local optimization/observability | 不能 authorize skip/replay start/HWM without canonical proof |
| cold global claim | historical whole-crash substrate | 不扩展成 recovery succession authority |
| `IR(X)` | closest existing execution serialization candidate | 必须完成 hold interval、multi-survivor、restart census；不足则 STOP |

### §4.3 Mandatory caller census

产品 TDD 前必须形成 exact caller table，至少覆盖：

| Caller family | exact known locations | required replacement gate |
|---|---|---|
| recovery skip | `xlogrecovery.c:2451-2466` | canonical control-root + PAGE/SIDE verified progress；wal-state单独不可用 |
| replay start | `cluster_recovery_merge.c:953-965` | failed-origin lower bound/tail + current authority |
| HWM validated minimum | `cluster_hw_remaster.c:470-487` | RF-SIDE canonical space truth + root authority |
| owner root/anchor publish | `xlog.c:7567-7598` | membership + control-root publication fence；bypass禁止漏检 |
| WAL retention/recycle | `xlog.c:7567-7733,8432-8497` | §6 retire conjunction；proof缺失直接 deny |
| cooperative shared-storage relation mutation | `cluster_smgr.c:399-406,473-478,521-528,549-558,613-620,670-679`; `cluster_block_recovery.c:382-411`; `cluster_thread_recovery_replay.c:331-393`; `cluster_thread_recovery_orchestrator.c:326-408` | 保留现有 `cluster_write_fence_reject_if_fenced` choke points与 publish 前 durable-marker recheck；recovery mutation 还必须先满足 terminal external I/O eviction，provider未批准则 `STOP-ROOT-IO-FENCE` |
| recovery target write | `cluster_thread_recovery_replay.c:376-398` | §2.6 + RF-PAGE/RF-SIDE authority + stable-base disposition |

G8/G8′ 要求继续 `git grep` 全 object，不得把此表当 complete list。发现新 caller先加入 census，不能先
删除旧 gate。对任何 live correctness consumer，迁移后的 producer/consumer必须在同一 product diff出现。

该 I/O family 只覆盖 `cluster_smgr_which_for` 路由的 shared relation；temp、stub backend、GUC-off、
部分 system catalog、WAL/reuse 与其他 metadata I/O 不得由此声称已覆盖。exact-f076 的
SCSI PR 仅 probe/register-own-key，未找到 cross-node preempt/evict、terminal receipt 或 provider call，
因此 cooperative gate 不能关闭 `STOP-ROOT-IO-FENCE`。

---

## §5 Recoverer failure and rebuild-first restart

### §5.1 First recoverer

第一次 recoverer 必须：

1. 从 shared canonical evidence重建 `duty_open`；
2. 验证 current membership/failure generation；
3. 完成 external I/O fence；
4. 取得并保持 recovery/thread serialization；
5. 对 exact resource请求 RF-PAGE/RF-SIDE source census；
6. 在每次 mutation前重验§2.5；
7. durable post-read后只 release exact resource；
8. WAL/control-root pins保持到§6 conjunction成立。

local progress、worker启动成功或 episode actor identity均不推进 durable truth。

### §5.2 Recoverer crash matrix

| Crash cut | 下一 actor必须做什么 | 允许复用 | 禁止结论 |
|---|---|---|---|
| before canonical mutation | 重新验证 root/authority/fence，重新 census source | validated shared canonical source | old actor“已开始”不构成事实 |
| during target mutation | 将 target视为可能 torn；继承 `STOP-RF-PAGE-STABLE-BASE` | 仅 RF-PAGE证明可存活的 canonical base | retained WAL本身自动保证可重放 |
| after durability write, before post-read | 重新读 canonical bytes并由 PAGE/SIDE验证 identity/version/integrity/coverage | durable bytes only after fresh verification | fsync return或local flag证明完成 |
| after durable post-read, before release | 重验 membership/failure generation/control root，再消费可重算 PAGE/SIDE proof | independently durable、可重验结果 | predecessor private progress授 authority |
| after resource release, before thread retirement | 重建尚未解除 resource/thread obligations，重复验证 retire conjunction | resource-scoped durable truth | 一个 resource完成代表整 thread/instance完成 |

exact Oracle mid-recoverer handoff 仍 **PUBLICLY UNKNOWN**。以上 restart 是 user-approved D3'
evidence-based PGRAC mapping；不得写成 Oracle internal protocol。

### §5.3 Optimization artifact rule

old artifact 被读取前必须逐项通过：

1. artifact 自身独立持久且 integrity/version可验证；
2. origin thread与 control-root lineage exact match；
3. resource/page version与 RF-PAGE/RF-SIDE canonical truth相容；
4. current failure generation与 membership不把它判 stale；
5. artifact miss/corrupt/unknown version时可以完全丢弃，correctness路径仍可 rebuild。

任一项失败就忽略 artifact，不报 recovery success、不缩短 WAL pin、不跳过 source census。本文不定义
artifact bytes、namespace或跨 recoverer lifecycle；若某 optimization 需要这些机制才能正确，立即 Rule-26 STOP。

### §5.4 Worker restart semantics

exact-f076 的 online thread-recovery executor 使用 `BGW_NEVER_RESTART`；异常退出把当前
slot 置 `BLOCKED`，launch predicate 不重注册同 episode 的 `REPLAYING/DONE/BLOCKED`
slot，只允许新 episode 再启动。该结论只绑定 thread-recovery lane；例如 HW-remaster
lane 可在同 episode 由应用层重注册，不得把 `BGW_NEVER_RESTART` 外推为全局无重试。
产品方案不得只把 flag 改为 restartable：新 actor 必须重新经过 §2–§3 全部 authority/fence 门。
在 `STOP-ROOT-GENERATION`/`STOP-ROOT-SERIAL` 未关闭前，同 episode replacement保持 BLOCKED；新 episode
也不能继承旧 local progress。

---

## §6 Retention、resource release 与 root retirement

### §6.1 Pin acquisition

一旦 `duty_open(origin_thread)` 可成立或无法安全判定，系统必须 fail closed 地 pin：

- control root 指向的 checkpoint/recovery lower bound；
- 到 validated tail/required end 的 failed-origin WAL interval；
- tail/segment continuity验证所需的 control-root inputs；
- PAGE/SIDE 尚未完成 durable post-read的 exact resource obligations。

control root缺失/损坏时不能计算更靠后的 floor；安全结果是禁止相关 WAL removal，而不是用
`InvalidXLogRecPtr`、wal-state recovered watermark或本地 merge progress前推。

### §6.2 Retire conjunction

RF-ROOT 不重写 AD-019 `FND-10` 公式。对一个 failed-origin WAL interval，retire decision 必须消费：

1. RF-PAGE 对 interval覆盖的所有 affected page resource给出的 durable post-read verdict；
2. RF-SIDE 对 affected TT/undo/PREPARED/space-metadata resource给出的 durable post-read verdict；
3. RF-PAGE/RF-SIDE 都确认没有遗漏的 exact resource/thread consumer；
4. current membership/failure generation/recovery serialization仍 fresh；
5. control-root lifecycle与 redo-reuse caller在同一 decision round通过；
6. `STOP-RF-PAGE-STABLE-BASE` 已由其 owner关闭；若仍 active，结果固定为 deny。

PAGE/SIDE proof 的 carrier、bytes与内部算法由各自 spec拥有。RF-ROOT只消费 typed verdict与 scope；
不得复制或弱化其 predicates。

### §6.3 Resource release is not interval retirement

一个 page/resource只有在 RF-PAGE 给出 typed stable-base/source/version/durable post-read proof后，才可按
`FND-09` release并重新 serve。`STOP-RF-PAGE-STABLE-BASE` active且该 proof缺失时，affected page
resource必须保持BLOCKED；RF-ROOT不得假定任何candidate已获批准。即使proof存在，resource release也
不自动允许删除覆盖它的 WAL interval：该interval可能仍覆盖其他page、TT/undo、PREPARED或space
metadata obligation。反之，健康无关resource不等待此 duty；不得用whole-instance gate扩大scope。

### §6.4 Redo-reuse fence

每个 `KeepLogSeg`、remove、recycle、clear、overwrite caller都必须：

1. 读取 current control-root/retention view；
2. 重新计算 §6.2；
3. 对 missing/unknown/mismatch返回 deny；
4. 只有 exact interval全部条件成立才允许前推 floor；
5. publication与 reuse共用 ordering：control-root lifecycle未 durable前不能 recycle；reuse发生后旧 owner
   不得再发布引用被覆盖 redo的 root。

recycler不能等待 recoverer，也不能用 timeout强制前进。denial的唯一副作用是保留 WAL、记录原因和容量告警。

### §6.5 Root retirement boundary

本文不批准 control-root物理删除或 durable CLOSED carrier。`STOP-ROOT-CONTROL` 关闭前，“root retirement”
只表示：在§6.2成立后，exact interval不再需要由该 duty保持 recovery pin；它不授权 unlink、truncate、
overwrite未知 root artifact。restart后若无法从 canonical state重算 retirement，系统必须再次 pin而非猜测。

这种 rebuild/recompute 可能保守地延长 retention，但不会创建第二 authority。若未来要求 crash后持久记忆
retirement，必须先查 Oracle、说明 carrier必要性并经 user批准；本文不预埋格式。

### §6.6 Source loss

如果 failed-origin WAL、control root、所需 CURRENT/PI、checkpointed base、PAGE/SIDE canonical truth中
任何必需 source 在 retire conjunction之前丢失：

- exact affected resource/thread进入 `BLOCKED`；
- 禁止 blind replay、skip、fallback到 local progress或扩大到 formation-wide merge；
- 禁止把 source loss解释为“无需恢复”；
- 保留其余 source与 evidence，记录 first missing boundary；
- 触发 Rule 26/user裁决，而不是新增 recovery carrier。

---

## §7 Behavior and failure contract

### §7.1 Admission/revalidation truth table

| Case | membership | failure gen | serialization | external I/O fence | root | result |
|---|---|---|---|---|---|---|
| first valid recoverer | current | current | held | terminal | valid/current | enter per-resource census |
| membership changes after admission | stale | any | any | any | any | reject before mutation；restart validation |
| local dead generation differs across peers | current? | unproved | any | any | any | `STOP-ROOT-GENERATION` |
| IR conflict | current | current | not held | terminal | valid | wait without resource locks or BLOCKED |
| external request accepted only | current | current | candidate | not terminal | valid | `STOP-ROOT-IO-FENCE` |
| control-root identity changes | current | current | held | terminal | stale | reject before mutation/release |
| root corrupt/unknown version | current | current | held | terminal | invalid | preserve WAL；BLOCKED |
| redo pin missing | current | current | held | terminal | valid | no mutation that can destroy only base；deny recycle |

### §7.2 Required stale checks

Fresh validation至少发生在：

- recovery actor selection后；
- external fence完成后；
- IR(X)/serialization acquisition后；
- each PAGE/SIDE resource acquisition后；
- canonical mutation immediately before write；
- durability后、resource release前；
- control-root publication前；
- WAL reuse/removal decision前。

任一检查失败必须终止该 actor的 mutation lane。已经写入但尚未 post-read的 resource按§5 crash-cut处理，
不能通过 cleanup将其标成功。

### §7.3 Error classes

本 spec 不冻结新 SQLSTATE 数字；产品 TDD 前复用/新增错误码须另做 exact registry census。语义分类固定：

| Class | Trigger | Required action |
|---|---|---|
| `ROOT_INPUT_INVALID` | root missing/corrupt/wrong identity/version/tail gap | BLOCKED；pin WAL |
| `RECOVERY_AUTHORITY_STALE` | membership/failure generation/serialization drift | fail before mutation；restart census |
| `EXTERNAL_FENCE_UNPROVEN` | terminal I/O isolation absent/unknown | BLOCKED；不得写 shared state |
| `RESOURCE_PROOF_INCOMPLETE` | PAGE/SIDE durable post-read missing | keep resource scoped BLOCKED；deny retirement |
| `REDO_RETIRE_DENIED` | any §6.2 predicate false/unknown | keep interval；emit reason/counter |
| `STABLE_BASE_UNRESOLVED` | inherited PAGE crash cut active | `STOP-RF-PAGE-STABLE-BASE` |

Unknown 不得映射成 success、retry-success、clean abort或 invisible。

### §7.4 Historical/rejected semantics

以下旧术语只作为审计历史出现，全部 `HISTORICAL / REJECTED`，不得换名恢复：

| Stale term | Disposition |
|---|---|
| `persistent recovery duty` | `HISTORICAL / REJECTED` — duty改为 canonical facts可重算 predicate |
| `persistent claim` | `HISTORICAL / REJECTED` — 不新增 recovery ownership ledger |
| `deterministic successor` | `HISTORICAL / REJECTED` — current authority决定 actor，exact handoff公开未知 |
| `claim adoption` | `HISTORICAL / REJECTED` — predecessor private state不被接管 |
| `GLOBAL_DONE` | `HISTORICAL / REJECTED` — readiness/release按 resource/thread scope |
| `retirement certificate` | `HISTORICAL / REJECTED` — retirement从 canonical PAGE/SIDE/root facts重算 |
| `anti-ABA tombstone` | `HISTORICAL / REJECTED` — 不为旧 ledger派生第二持久物 |
| `immutable activation` | `HISTORICAL / REJECTED` — D2已拒绝 |

---

## §8 Observability and performance contract

### §8.1 Recovery-only observability

未来产品实现至少需要按 resource/thread输出以下语义；field名字与layout在产品授权后另定：

- duty/root validation success/failure与 first failure reason；
- membership/failure-generation/serialization revalidation pass/stale count；
- four fence boundary admission/reject count；
- external fence requested/terminal/unknown（不得把 requested合并为terminal）；
- rebuild start、canonical source class、optimization hit/fallback/reject；
- resource durable post-read success/failure；
- pinned failed-origin interval/bytes、reuse denial reason；
- recoverer crash-cut stage与 next-actor disposition；
- STOP gate当前状态。

counter必须遵守 G2：EVENT/GAUGE/TIMESTAMP不混用；normal-path热调用不能增加日志洪泛。

### §8.2 Performance hard boundary

normal transaction 新增成本保持：

| Cost | Budget |
|---|---:|
| synchronous network RTT | `0` |
| fsync/fdatasync/durable-rename wait | `0` |
| shared-control-file I/O | `0` |

root/fence/retention工作只在 failure/recovery/checkpoint/recycle控制路径发生。任何 implementation若把
failure-generation或root validation放入 ordinary commit hot path，必须 STOP并重做 Oracle对齐/性能设计。

### §8.3 Formal honesty

本文没有运行 formal `4×1×3 + rate10/20/30`。未来运行必须保持 judge、公式、阈值、workload identity、
fresh-run provenance不变；timeout、error、forced cancel、skip、whitelist、missing artifact不能制造绿色。
spec fingerprint agreement只证明文档一致，不证明产品或性能通过。

---

## §9 Test design

### §9.1 Static/unit RED matrix（产品授权后）

| ID | RED purpose | GREEN contract |
|---|---|---|
| `RU-01` | node-local anchor被 survivor当 control root | classifier拒绝；只允许 local restart hint |
| `RU-02` | local `dead_generation` 被跨节点当 canonical generation | `STOP-ROOT-GENERATION` / authority false |
| `RU-03` | IR owner node id单独授 mutation | authority conjunction false |
| `RU-04` | cooperative fence/accepted provider reply单独授 I/O | external fence仍 unproven |
| `RU-05` | control-root mismatch后 page write | stale check在 mutation前失败 |
| `RU-06` | `KeepLogSeg`忽略 recovery interval | reuse denied，floor不前推 |
| `RU-07` | wal-state watermark允许 skip/replay start/HWM | 三 caller迁移测试 fail closed |
| `RU-08` | invalid old artifact被当 progress | artifact ignored，canonical rebuild启动 |
| `RU-09` | one resource post-read允许 whole interval retire | retirement denied |
| `RU-10` | PAGE proof全、SIDE proof缺 | retirement denied |
| `RU-11` | inherited stable-base STOP active | retirement denied，WAL pinned |
| `RU-12` | recycler等待 recoverer | prohibited edge检测；recycler立即deny |

### §9.2 Faithful fault/acceptance legs

| ID | Scenario | Required assertions |
|---|---|---|
| `RL-01 first-recoverer` | one failed origin，first survivor enters | shared root valid；membership/failure/serialization/fence均 fresh；只开放完成resource |
| `RL-02 death-before-mutation` | recoverer在first write前被kill | next actor无 private adoption，重新census，WAL pin不丢 |
| `RL-03 death-during-mutation` | recoverer在`smgrwrite`中crash | target视为torn；stable-base STOP/BLOCKED；不得 retire |
| `RL-04 death-after-durable-before-read` | durability return后、post-read前crash | next actor fresh post-read；失败则 rebuild/BLOCKED |
| `RL-05 stale-owner-I/O` | old owner在new authority后写shared data/control/WAL | external/cooperative/control/reuse gate拒绝，canonical bytes不变 |
| `RL-06 membership-change` | actor已admit后 membership/failure event变化 | next mutation前stale reject；旧resource completion不释放新episode |
| `RL-07 control-root-mismatch` | root identity/tail/lifecycle在acquire后变化 | mutation/release拒绝，interval继续pin |
| `RL-08 invalid-optimization` | artifact CRC/version/lineage/generation任一错 | fallback到canonical source；结果不依赖artifact |
| `RL-09 source-loss` | required WAL/current/PI/checkpoint/side truth缺失 | exact resource/thread BLOCKED；不blind apply、不扩大merge |
| `RL-10 retirement-denial` | PAGE或SIDE post-read缺、consumer仍在或stable-base STOP | remove/recycle调用全部deny且记录reason |
| `RL-11 resource-scoped-open` | A resource完成、B仍blocked、C健康无关 | A/C可serve，B blocked；不出现whole-instance barrier |
| `RL-12 wait-graph` | external provider延迟 + IR contention + resource I/O | external wait不持locks；lock order无环；recycler不等待 |

synthetic fault injection只能证明 mechanism。external I/O fence必须有 faithful provider/eviction证据；
环境不可用时结果是 honest BLOCKED/SKIP-with-reason，不能由mock PASS替代正式完成。

### §9.3 Regression matrix

- cluster disabled：PG 219 expected baseline unchanged；
- cluster enabled/no failure：normal workload 0/0/0新增同步成本；
- recovery enabled但所有 STOP未关闭：明确 fail closed，不进入 mutation；
- mixed-version peer不能理解 future root/generation contract：affected resource/thread BLOCKED；
- fresh formal runs只在产品授权、四规范agreement、fault gates完成后执行。

---

## §10 G1–G9 self-check and DoD

### §10.1 Governance gates

| Gate | RF-ROOT evidence |
|---|---|
| `G1/G1′/G1″` | §1.3逐 symbol/file/actor census；per-node、survivor、local/durable边界分开 |
| `G2` | §8区分 event/gauge/timestamp；requested不等于terminal |
| `G3` | §1.4把未成立 deliverable标 STOP；existing行为只写 unchanged substrate |
| `G4/G4′` | 本文没有新增字段/accessor；future proposal必须列 producer+consumer+distinct information |
| `G5/G5′` | Oracle facts只消费 AD evidence；PUBLICLY UNKNOWN不承重；literal entailment由AD拥有 |
| `G6` | 未批准偏离不落地；无法对齐直接 Rule-26 STOP |
| `G7` | §7 truth table与§9 fault legs覆盖 stale、temporary、missing、corrupt、source loss |
| `G8/G8′` | §4.3迁移三 correctness consumers、publish/recycle/write callers；§8保持0/0/0与formal口径 |
| `G9` | §2 predicates、§3 boundaries/lock order、§6 retire inputs、§9 RED assertions可供陌生实现者写测试 |

- [x] G1–G9（含 G1′/G1″/G4′/G5′/G8′）已逐条自检

### §10.2 Spec rewrite DoD

- [x] status精确写明 `USER-APPROVED ORACLE-FIRST BASELINE / PRODUCT NOT AUTHORIZED`。
- [x] `PRODUCT AUTHORIZATION = 0`；未修改、构建、测试、commit或push公开产品仓。
- [x] exact product facts只绑定 `f076653df977dfa67c1f8fdaa1f985daf0a240b4`。
- [x] AD-019 FND IDs只消费、不重定义；PAGE/SIDE ownership没有复制。
- [x] failed-origin thread/control-root duty与current authority predicates已结构化。
- [x] control-root carrier、durable failure-generation、RT resource、external provider均保持prospective/STOP。
- [x] membership/I/O/control-root publication/redo-reuse四层 fence完整定义。
- [x] stale actor在canonical mutation前拒绝；lock order/wait-for edge无新 lock class。
- [x] D3' rebuild-first与 PUBLICLY UNKNOWN exact handoff边界明确。
- [x] invalid old artifact只能fallback，不能推进 correctness或retention。
- [x] retention只消费 AD `FND-10` 与 PAGE/SIDE durable post-read proofs。
- [x] `STOP-RF-PAGE-STABLE-BASE` active时 retirement固定deny。
- [x] 不存在全域 readiness/join barrier；release按resource/thread scope。
- [x] 旧 ledger/certificate/tombstone语义只留在§7.4 rejected history。
- [x] first/repeated recoverer crash cuts、stale I/O、generation change、root mismatch、source loss、retire denial均有RED/acceptance leg。
- [x] normal transaction 0/0/0与formal `4×1×3 + rate10/20/30`口径继承且未冒充通过。
- [x] 完整正文位于唯一一对marker之间；fingerprint metadata在marker外。
- [ ] CC 对 exact body fingerprint返回 `ACCEPT` 或 exact conflict；silence不算agreement。
- [ ] RF-PAGE/RF-SIDE回交 typed durable post-read proofs并完成cross-spec binding。
- [ ] user另行授权 product TDD；当前仍 **PRODUCT NOT AUTHORIZED**。

---

## §11 Closed decisions and rejected alternatives

### Q1 Duty由什么标识？

- ★ A：failed-origin thread + durable control root + unresolved recovery obligation。
- B：recoverer node/local progress identity。
- C：node-local anchor或wal-state watermark。

选择 A，消费 `FND-02`；B/C在recoverer crash后不能提供survivor-readable canonical identity。

### Q2 Active recoverer由什么决定？

- ★ A：current membership + failure generation + recovery/thread serialization + current root identity。
- B：IR owner node id单独决定。
- C：lowest live node或timeout决定。

选择 A。exact substrate不足时STOP，不以B/C制造authority。

### Q3 外部 I/O fence未实现时怎么办？

- ★ A：保持 `STOP-ROOT-IO-FENCE`，禁止canonical mutation。
- B：cooperative write fence等价替代。
- C：provider接受请求即继续。

选择 A；B/C都不能阻断rogue old owner的shared-storage I/O。

### Q4 Recoverer再次失败后如何继续？

- ★ A：D3' rebuild-first，从canonical sources重建。
- B：接管前任private progress。
- C：把前任local digest当完成证明。

选择 A；exact Oracle handoff公开未知，B/C会恢复被拒绝的artifact authority。

### Q5 旧 artifact何时可用？

- ★ A：独立持久且lineage/version/control-root/failure freshness全验证后，仅作optimization。
- B：pathname/mtime/CRC任一有效即可。
- C：完全禁止任何optimization。

选择 A；它保留Oracle-shaped加速空间但不让hint承重。验证失败即fallback。

### Q6 何时允许释放resource？

- ★ A：exact resource完成authority + durability + post-read后立即release。
- B：等待所有side domain完成。
- C：第一次write return后release。

选择 A，消费 `FND-09`；B扩大availability scope，C缺durability/identity proof。

### Q7 何时允许retire failed-origin WAL？

- ★ A：只消费AD `FND-10`与完整PAGE/SIDE durable post-read verdict，且stable-base STOP已关闭。
- B：worker正常退出或local progress到tail。
- C：checkpoint完成就删failed-origin interval。

选择 A。B/C均可能丢失下一recoverer唯一canonical source。

### Q8 Root物理删除怎么做？

- ★ A：本 revision不批准；carrier/lifecycle公开证据与产品substrate未闭合，重启时保守重算/pin。
- B：新增durable completion artifact。
- C：unlink后依赖目录不存在表示完成。

选择 A。若未来必须持久记忆，先走Rule 26与user approval，不预埋新artifact。

---

## §12 Prospective implementation plan（product authorization 后）

下表是依赖顺序，不授权实施，也不冻结缺失机制的ABI：

| Step | Deliverable | Gate / STOP | Expected RED first |
|---|---|---|---|
| `P0` | exact-f076全 caller/producer/actor census | G1/G8/G8′ | missing caller makes census fail |
| `P1` | Oracle/user裁决 control-root carrier与lifecycle | `STOP-ROOT-CONTROL` | survivor cannot locate durable root |
| `P2` | 裁决 cluster-common failure freshness substrate | `STOP-ROOT-GENERATION` | two peers disagree on local generation |
| `P3` | 证明existing recovery/thread serialization或请求裁决 | `STOP-ROOT-SERIAL` | two survivor actors both reach mutation |
| `P4` | external I/O eviction provider/terminal verification | `STOP-ROOT-IO-FENCE` | rogue owner write succeeds |
| `P5` | fence all control-root publish/bypass callers | P1–P4 | stale publisher advances root |
| `P6` | wire recovery retention into every reuse/remove caller | P1, RF-PAGE, RF-SIDE | WAL removed before proof |
| `P7` | migrate three wal-state correctness consumers | PAGE/SIDE contract | skip/start/HWM accepts local watermark |
| `P8` | rebuild-first worker orchestration | P1–P4 | killed recoverer requires private state |
| `P9` | faithful fault suites + observability | all STOP closed | required §9 leg RED |
| `P10` | fresh formal campaign | all correctness gates GREEN | no prior result reuse |

任何 step若发现新 field/actor/message/persistent artifact，先STOP并回到Oracle research/user裁决；不得让
implementation plan本身充当批准。

---

## §13 Compatibility、rollback and cross-spec outputs

### §13.1 Compatibility

1. 本 spec不冻结on-disk/wire/API，因此当前不触发catversion或protocol version。
2. future mixed-version peer不能理解approved root/generation/fence semantics时，exact resource/thread
   fail closed；不得silent old path。
3. wal-state仍可保留为telemetry，但所有 correctness consumers必须迁移；不能同时维持双authority。
4. old private/local artifacts默认忽略；只有满足§5.3才可作为optimization。
5. rollback implementation必须保持failed-origin WAL与canonical root inputs；不能回到旧ledger chain。

### §13.2 RF-ROOT outputs

RF-ROOT 向 sibling specs输出：

| Consumer | Output |
|---|---|
| RF-PAGE | `duty_open`/`active_recoverer` semantic admission、four-layer fence、retained failed-origin interval、stable-base STOP inheritance |
| RF-SIDE | 同一authority/fence binding、resource/thread scope、retention要求的side durable post-read verdict |
| AD-019 | exact caller census、STOP disposition、restart matrix、PAGE/SIDE proof consumption与retire denial |

输出是semantic contract，不是新的carrier或API。

### §13.3 Risks

| Risk | Probability / impact | Gate |
|---|---|---|
| 把per-node anchor当survivor root | high / wrong redo base | `STOP-ROOT-CONTROL`, RU-01 |
| local generation跨节点分叉 | high / two active recoverers | `STOP-ROOT-GENERATION`, RL-06 |
| IR(X) scope不足仍放行 | high / concurrent mutation | `STOP-ROOT-SERIAL`, RU-03 |
| cooperative fence冒充external eviction | high / stale-owner corruption | `STOP-ROOT-IO-FENCE`, RL-05 |
| xlog bypass漏control publication gate | high / stale root + early recycle | RFX-12 caller census |
| recovery WAL pin漏remove caller | high / unrecoverable source loss | `STOP-ROOT-REUSE`, RL-10 |
| wal-state旧consumer残留 | high / false skip/start/HWM | RU-07, P7 |
| target torn但retained WAL无stable base | high / corruption or permanent block | `STOP-RF-PAGE-STABLE-BASE`, RL-03 |
| PAGE proof被当SIDE proof | high / early retirement | RU-10 |
| resource completion升级为whole-instance barrier | medium / availability regression | RL-11 |
| old artifact变correctness root | medium / successor restart failure | RL-08 |
| normal transaction引入sync tax | medium / formal perf failure | §8 0/0/0, P10 |

---

## 版本历史

| Version | Date | Status | Summary |
|---|---|---|---|
| v0.x | 2026-08-04 | `HISTORICAL / SUPERSEDED` | two-generation custom root、durable owner ledger、artifact succession、all-domain readiness与derived cleanup chain |
| v1.0 | 2026-08-05 | `USER-APPROVED ORACLE-FIRST BASELINE / PRODUCT NOT AUTHORIZED` | failed-origin duty、current authority、four-layer fence、D3' rebuild-first、PAGE/SIDE proof-driven retention、resource-scoped release；所有missing carrier保持STOP |

<!-- NORMATIVE-BODY-END -->

| Fingerprint metadata | 值 |
|---|---|
| body_sha256 | `3461d12cb564c13529e227094e151160032578046e332bece567013ddb183cd0` |
| body_lines | `789` |
| body_bytes | `50131` |

---

## §13 工作区本地增量：crash-rejoin 死锁圈与 self-join 例外（2026-08-17）

> 本增量对应产品提交 `c4b2357723`，补全本文 §2.4/§2.5（failed-origin duty /
> active-recoverer predicates）在 crash-rejoin 场景下 formation-witness 的绑定细节。
> 原文 §0–§12 一字未改；本增量只在本工作区生效，并入私有库由 user 裁决。

### §13.1 本文 §0 判决与增量的关系

- §0 判决 1/2（duty 锚定 failed-origin thread + durable control root；active recoverer
  需 membership + failure generation + serialization + root identity 的 fresh validation）
  **保持不变**——本增量只是把 "fresh validation" 在 crash-rejoin 下的证据绑定写具体；
- §0 判决 7（STOP-RF-PAGE-STABLE-BASE 继承）与 §3 四边界 fence **不受影响**：
  self-join 例外不放开 membership 之外的任何 I/O/control-root/redo-reuse 边界。

### §13.2 六环死锁圈（§5 first-recoverer 路径的 wedge 形状）

```
boot_decided=0 → LMON tick 降级 self 为 JOINING
→ phase-3 barrier request-current 失败 → GRD authority seal 不盖章
→ transport 不 current → GES early-opcode 丢 survivor REDECLARE_DONE
→ join view 不重建 → boot_decided 保持 0
```

### §13.3 绑定增量（six narrow exceptions）

- 证明源：durable JCMK 准入（`self_join_admitted`）＝ membership 证明；applied event
  对 crash-rejoiner 恒为空（AD-023 §9.2.3 适用读法），不再要求内存事件证明；
- 六个门：formation witness（settled-epoch + marker 元组两门）、note_self_admitted
  floor 发布、recovery-authority barrier wait、GES early-opcode、LMON tick self-state、
  GRD request_current——全部只对 self-join + durable-admitted 组合放行；
- 与 §5 D3' rebuild-first 一致：放行的只是"进入 rebuild 的门票"，recoverer 仍需从
  canonical sources（root/WAL/formation/fence）重建，前任 private progress 仍不承重。

### §13.4 回滚边界

- 若 REDECLARE_DONE 或 serving 侧出现由本例外放行的回归，回滚 = 关闭六个门中的
  相应成员，恢复内存事件证明要求；不得以放宽 witness 或修改 t243 时序替代。
