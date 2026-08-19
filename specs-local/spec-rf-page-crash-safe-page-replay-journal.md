# RF-PAGE — Oracle-first versioned page recovery

> **Status: EXACT BODY ACCEPTED BY CC — USER APPROVED; PRODUCT AUTHORIZATION=1; PAGE JIT GATES MANDATORY / OPEN**
>
> User 于 2026-08-05 批准 Oracle-first baseline，CC 随后对本 exact normative body 返回
> `ACCEPT`。User 已将 `PRODUCT AUTHORIZATION` 翻为 `1` 并批准 Stage-8 执行计划。
> `JIT-PAGE-AUTH` 与 `JIT-PAGE-ROUTE` 仍是 mandatory/open gate；本状态翻转不得
> 被解读为 stable-base/read-repair authority 或 info-opcode route gap 已闭合。

| 可变元数据 | 值 |
|---|---|
| 决策日期 | 2026-08-05 |
| exact 产品证据 | `f076653df977dfa67c1f8fdaa1f985daf0a240b4` |
| AD-019 body | `1237dd8d9534d4a062c679bfeeb250ed64ee072906d8312d0a4cf8848a2db562` |
| RF-ROOT body | `3461d12cb564c13529e227094e151160032578046e332bece567013ddb183cd0` |
| RF-PAGE body fingerprint | `c89746739171dc2698e4cf4dfaccbdbeca8dc417de9a865ed1d30b43414efb58` |
| RF-PAGE body lines / bytes | `932` / `47022` |
| SPEC EDIT AUTHORIZATION | `1` |
| PRODUCT AUTHORIZATION | `1` — **STAGE-8 EXECUTION ACTIVE** |
| Stage-8 JIT gates | **MANDATORY / OPEN (NOT CLOSED)** — `JIT-PAGE-AUTH`, `JIT-PAGE-ROUTE`, `JIT-SIDE-RESERVED`, `JIT-COLD-RETRY`; 本 spec 的受影响语义为前两项 |
| formal 目的地 | 高性能真实 `4×1×3 + rate10/20/30`；本文不声称已运行或通过 |

<!-- NORMATIVE-BODY-BEGIN -->

## §0 决策摘要与 ownership

RF-PAGE 只拥有 page recovery 的以下合同：

1. normal persistent page 的 `PageVersion`、redo `expected-before` 与
   `result-version`；
2. normal page、exception page 与 unknown page 的穷举分类；
3. `CURRENT`、`PI`、`STORAGE` source provenance 与可信度门；
4. exact block/resource 的 contributor closure、apply/skip、durability、
   `post-read` 与 release proof；
5. recoverer 再失败时的 D3′ rebuild-first page 行为；
6. `STOP-RF-PAGE-STABLE-BASE` 与 repeated-recoverer target-write RED。

RF-PAGE 不拥有 failed-origin duty、control root、failure generation、四层 fence、
redo retirement decision、shared TT/undo/PREPARED truth 或 canonical space metadata。
这些分别由 RF-ROOT、RF-SIDE 与 AD-019 唯一定义。

本 revision 的核心不是 predecessor recoverer 的私有进度，而是 canonical page-version
replay：可信 result version 只证明 skip；需要 apply 时必须 exact
`expected-before` match。`InvalidScn => BLOCKED` 只是 containment 地板，不能替代
normal persistent page 的 version contract。

### §0.1 AD-019 imports

本文消费而不重定义以下 shared invariants：

| AD invariant | RF-PAGE obligation |
|---|---|
| `FND-01` | 产品事实只绑定 exact f076；Oracle claim 严格分级 |
| `FND-02` | 每次 page mutation/release 消费 current active-recoverer authority |
| `FND-03` | stale owner 任一 fence 未闭合即 page mutation=0 |
| `FND-04` | D3′ rebuild-first；private predecessor progress 不承 correctness |
| `FND-05` | transient hint miss/corrupt 不改变 correctness verdict |
| `FND-06` | 本文细化 PageVersion/result skip/exact expected-before |
| `FND-07` | 本文细化 per-block source 与 contributor closure |
| `FND-09` | 只 release exact verified block/resource |
| `FND-10` | 本文产生 affected page durable post-read proof；ROOT决定 retire |
| `FND-11` | normal path 新增同步 RTT/fsync/shared-control I/O = `0/0/0` |

`FND-08` 由 RF-SIDE 独占。遇到 TT/undo/PREPARED/space-metadata record 时，
RF-PAGE 只按 routing table 移交，不定义其 authority。

### §0.2 RF-ROOT imports

以下是 semantic inputs，不是本 spec 新增 C ABI：

| 输入 | 必须证明 |
|---|---|
| `failed_origin_duty` | failed thread、durable control root、retained redo interval |
| `active_recoverer(resource)` | current membership + failure generation + recovery/thread serialization |
| `fence_ok(resource)` | membership、I/O、control-root publication、redo-reuse 四层均成立 |
| `retention_pin(interval)` | PAGE proof完成前 origin interval 不 remove/recycle/overwrite |
| `authority_revalidate(resource)` | mutation、durability publish、release 前 fresh exact revalidation |

任一 input 不成立，exact resource `BLOCKED`；本文不创建替代 ledger、token、actor、
message family 或持久 artifact。

---

## §1 证据账本与 exact-f076 gap

### §1.1 Evidence classes

| 标签 | 含义 | 是否可承重 |
|---|---|---|
| `ORACLE OFFICIAL FACT` | Oracle 官方 manual/concepts 字面支持 | 可约束职责与外部语义 |
| `PATENT-ONLY EVIDENCE` | Oracle assignee patent 披露 embodiment | 只能证明公开过该形状 |
| `ORACLE-HOSTED EXPERT` | Oracle-hosted Q&A 的专家解释 | secondary，不是产品合同 |
| `PGRAC IMPLICATION` | Oracle facts + exact-f076 constraint 联合推论 | 必须明确是 adaptation |
| `PUBLICLY UNKNOWN` | public corpus 未关闭内部问题 | 不承重；触发 Rule-26 STOP |

### §1.2 Admitted Oracle evidence

| ID | class | fact | source / boundary |
|---|---|---|---|
| `OP-01` | `ORACLE OFFICIAL FACT` | GCS recovery set按 resource/block形成；从 survivor current/PI 开始；无二者时才为该 block merge failed-instance redo；block写回后即可 release | [Oracle9i RAC Concepts pp.71–73](https://docs.oracle.com/cd/A97630_01/rac.920/a96597.pdf) |
| `OP-02` | `ORACLE OFFICIAL FACT` | RAC公开支持 simultaneous/sequential failures | 同上；相邻 during-recovery 句的主语是 shared server feature，不证明 generic recovery-duty handoff；不公开 mid-write carrier |
| `OP-03` | `ORACLE OFFICIAL FACT` | normal data block 有 block SCN/version；redo change vector 有 expected block SCN；失配按 corruption | [Oracle ODA 12.2 Backup and Recovery](https://docs.oracle.com/cd/E93461_01/doc.122/e92398/backup-recovery.htm) |
| `OP-04` | `PATENT-ONLY EVIDENCE` | compatible copy/persistent block + ordered redo 可恢复，可信结果版本可跳过已覆盖 change | [US8429134B2 claims 1,5,6](https://patents.google.com/patent/US8429134B2/en)；不证明产品内部 bytes |
| `OP-05` | `ORACLE-HOSTED EXPERT` | cache/media redo apply 本身不生成新 redo；ordinary rollback 会生成 redo | [Ask TOM direct answer](https://asktom.oracle.com/ords/f?p=100%3A11%3A%3A%3A%3A%3AP11_QUESTION_ID%3A621023586146%2C%7Bredo%7D+and+%7Blog%7D+and+%7Bbuffer%7D)；secondary/non-contract，不能外推 roll-forward successor carrier |
| `OP-06` | `PUBLICLY UNKNOWN` | recoverer 在 target write 中 crash 后使用的 stable preimage、atomicity 或 adopt/discard carrier | 不得自行补协议 |

### §1.3 exact-f076 facts

以下只描述 exact object，不描述工作树 HEAD：

| ID | exact evidence | disposition |
|---|---|---|
| `PX-01` | `cluster_thread_recovery_replay.c:331-373` 有 PI shortcut；PI unusable 后回 STORAGE | 保留 source-kind 概念；现有 shortcut 不证明 lineage/version/stability |
| `PX-02` | `cluster_thread_recovery_replay.c:376-398` 是 `smgrread -> apply -> smgrwrite` | target-first/direct-write 不满足 versioned source、native durability、post-read |
| `PX-03` | `cluster_thread_recovery_replay.c:126-146` 后续 `smgrimmedsync` touched relations | relation sync return 不等于 per-block canonical post-read proof |
| `PX-04` | replay/orchestrator path无 `XLogInsert`/`XLogBeginInsert` | exact f076 没有 recovery-generated successor WAL/FPI carrier |
| `PX-05` | existing page/redo records没有本文完整 PageVersion before/result producer-consumer contract | deliverable 未成立；不得把 LSN、checksum、InvalidScn 冒充版本 |
| `PX-06` | source、mutation、post-read、release没有同一 production per-block proof object/caller chain | G1/G3 RED；不能凭 helper/telemetry写 DONE |

### §1.4 Approved Oracle deviation

| scope | classification | approved registration | status / hard boundary |
|---|---|---|---|
| `PC-REBUILDABLE` ⚫ | `架构范式差异` | **FSM — 架构范式差异** — Oracle 的 ASSM 位图是分配器权威状态因而必须版本化；PG 的 FSM 是可丢失、可重建的真相缓存，权威在堆页与关系大小，Oracle 的版本化动因在此不成立 | `user approved 2026-08-05`；⚫ Oracle 侧无对应物；豁免只限 FSM，失效条件见 §4.4 |

---

## §2 Scope、deliverables 与 exclusions

### §2.1 Future product deliverables（仅产品授权后）

| D | prospective scope | current status |
|---|---|---|
| `PGDEL-01` | PageVersion semantic type、comparison、invalid/unknown classifier | RED；无 ABI 冻结 |
| `PGDEL-02` | applicable redo expected-before/result-version producer + decoder | RED；rmgr census未实现 |
| `PGDEL-03` | exhaustive page/record class dispatcher | RED；unknown default必须 BLOCKED |
| `PGDEL-04` | CURRENT/PI/STORAGE provenance validators | RED；必须有 production source owners |
| `PGDEL-05` | in-memory per-block recovery-set builder与 contributor closure | RED；不是 persistent artifact |
| `PGDEL-06` | native buffer/GCS apply + durability + canonical post-read | RED；carrier STOP不绕过 |
| `PGDEL-07` | per-resource proof handoff给 RF-ROOT/SIDE | RED；不创建 global barrier |
| `PGDEL-08` | counters/waits/dump与错误映射 | RED；G2/G4′ producer-consumer必查 |
| `PGDEL-09` | unit/TAP/fault/acceptance tests | RED；repeated-recoverer target-write保持 STOP |
| `PGDEL-10` | compatibility、manual与formal regression | RED；PRODUCT AUTHORIZATION仍为0 |

上述是 responsibility 列表，不冻结文件路径、struct bytes、wire opcode、persistent layout或actor。

### §2.2 明确不包含

| excluded | reason |
|---|---|
| 修改、构建或测试 `/Users/sqlrush/linkdb` | PRODUCT AUTHORIZATION = 0 |
| 新 persistent recovery authority | D1/D2 已拒绝；D3′从 canonical truth重建 |
| predecessor-private progress作为 correctness | recoverer crash 后不可独立验证 |
| all-resource/all-side whole-instance barrier | `FND-09` 要求 resource/thread scope |
| 默认 merge 所有 formation threads | Oracle只在该 block缺 current/PI 时merge所需 failed redo |
| checksum或裸 LSN作 version authority | detector/order domain不足 |
| FPI或`WILL_INIT`自动变可信 base | 必须先通过class/provenance/version/coverage门 |
| 新 carrier或storage前提 | `STOP-RF-PAGE-STABLE-BASE` 等 user裁决 |
| RF-SIDE transaction/space authority | 由 RF-SIDE独占 |
| RF-ROOT control/fence/retire算法 | 由 RF-ROOT独占 |

### §2.3 Historical/rejected semantics

以下只为 stale scan 保留，全部非 normative implementation choice：

| stale phrase | disposition |
|---|---|
| `journal namespace` / `journal commit` | `HISTORICAL / REJECTED AS CORRECTNESS` |
| `claim adoption` | `HISTORICAL / REJECTED AS AUTHORITY` |
| `repeated successor` private-state resume | `HISTORICAL / SUPERSEDED BY D3′` |
| `mandatory private journal` | `REJECTED` |
| `formation-wide` default merge | `REJECTED` |
| `A-only` containment / `B 后置` | `SUPERSEDED` by PageVersion + exact expected-before |

---

## §3 PageVersion 与 redo contract

### §3.1 Logical identities

以下是 semantic schema；不规定 C layout/on-disk width：

~~~text
PageIdentity := exact shared-storage database identity
             + exact physical relation/fork/block identity

PageVersion := PageIdentity
             + PageIncarnation
             + VersionToken

RedoPageChange := PageIdentity
                + PageClass
                + expected_before : PageVersion-or-explicit-class-state
                + result_version  : PageVersion
                + change_identity
                + failed_origin_thread
                + redo_record_identity
~~~

`PageIncarnation` changes whenever the same physical address can denote a newly created,
truncated, dropped/recreated or reused page. `VersionToken` 是 opaque exact-equality token；
其唯一顺序来自已验证的 `expected-before -> result-version` edge/dependency topology，本文不定义
numeric ordering。Oracle block-SCN evidence只支持“block version与redo expected version必须匹配”；
exact-f076 的 raw `xl_scn`/`pd_block_scn` 不能直接当VersionToken或完整顺序，除非future
producer/consumer census证明同一contract。SCN/LSN在此只能作locator/hint。

`InvalidScn`、zero、missing field、decode failure 和 unknown version 全是 invalid，不能映射为
oldest/newest/unformatted。unformatted 使用显式 class state，不复用 numeric sentinel。

### §3.2 Normal persistent page precondition

对每个 applicable normal-page redo change `c`，只允许：

~~~text
if trusted_source_version proves c.result_version is already covered:
    SKIP(c)
else if current_working_version == c.expected_before:
    APPLY(c)
    require resulting_version == c.result_version
else:
    BLOCKED_OR_CORRUPTION(c)
~~~

`>=`、裸 LSN 大小、checksum match、record already scanned、target header looks newer、
recoverer-local bitmap 均不能替代 exact predicates。

### §3.3 Trusted result-version skip

可信 skip 有且只有两种证明形状：

1. source exact PageVersion 等于 change `result-version`；或
2. per-block contributor chain 从该 result version 到 source version 连续闭合，且每一条
   `expected-before -> result-version` exact join，无 gap、duplicate divergence、unknown class。

因此 `trusted result-version skip` 是 chain proof，不是 numeric high-water。skip 前后均 fresh
验证 source provenance、control-root lineage、failure generation 和 exact block identity。

### §3.4 Exact expected-before apply

需要 apply 时：

1. working image必须来自已验证 source或前一已验证 result；
2. working PageVersion必须 exact equal `expected-before`；
3. redo decoder必须声明该 class下的 deterministic mutation；
4. apply后重新解析 page identity/incarnation/VersionToken；
5. result必须 exact equal `result-version`；
6. mismatch、unsupported decoder、multiple results或missing producer均 fail closed。

对 same block 的两条 change，只有 `c[i].result_version == c[i+1].expected_before` 才能邻接。
equal SCN但different incarnation/identity不是邻接。

### §3.5 State machine

~~~text
UNCLASSIFIED
  -> CLASSIFIED
  -> SOURCE_PROVEN
  -> CONTRIBUTORS_CLOSED
  -> VERSION_CHAIN_VERIFIED
  -> AUTHORITY_REVALIDATED
  -> MUTATED_IN_MEMORY
  -> WAL_BEFORE_DATA_SATISFIED
  -> PAGE_WRITE_DURABLE
  -> POST_READ_VERIFIED
  -> RESOURCE_RELEASED
~~~

任一阶段只能前进到相邻阶段。crash 后不读取 predecessor-private phase；新 actor按 D3′从
`UNCLASSIFIED` 重建。`RESOURCE_RELEASED` 不是 failed-origin WAL interval retirement。

---

## §4 Exhaustive page and record classes

### §4.1 Closed classifier

所有 page-affecting record 必须进入下表恰一行。multi-match、no-match、unknown rmid/opcode、
unknown fork/header 或 ambiguous lifecycle 全部 `BLOCKED`。

| ID | class | authority / producer | verifier / provenance | recovery action | release rule |
|---|---|---|---|---|---|
| `PC-NORMAL` | normal persistent data/index page | page codec + applicable redo producer | PageIdentity/incarnation/VersionToken + CURRENT/PI/STORAGE proof | result skip或exact-before apply | durable post-read + authority revalidate |
| `PC-NEW` | new/unformatted page | canonical create/extend lifecycle + initializing redo | explicit ABSENT/UNFORMATTED state、new incarnation、full initialized result | initialize only from declared full-init rule；否则BLOCKED | post-read confirms new identity/result |
| `PC-INCARNATION` | truncate/drop/recreate/reuse transition | canonical relation/block lifecycle | old/new incarnation、boundary order、no old contributor after transition | close old set，start new set；never merge incarnations | lifecycle + new page post-read both verified |
| `PC-TEMP` | temp/session-local page | owning live session/temp lifecycle | proof page has no shared persistent obligation | discard/recreate；不做 failed-origin replay | owner/lifecycle confirms absence or rebuild |
| `PC-REBUILDABLE` ⚫ | FSM only under the approved deviation | heap-page free-space truth + canonical relation size | exact-f076 exhaustive rebuild contract + no correctness consumer，见 §4.4 | invalidate and rebuild；不把hint当base | rebuild verifier passes for exact resource |
| `PC-HEADER` | file/control/segment header | RF-ROOT、RF-SIDE或PG core typed owner | typed owner identity/version/integrity | route away from generic page replay；unknown owner BLOCKED | typed owner returns durable proof |
| `PC-FULLIMAGE` | FPI/full-image record | applicable rmgr redo producer | exact PageIdentity/class/result-version/full-image integrity + lineage | may replace working image only after provenance proof | subsequent chain + post-read verified |
| `PC-WILLINIT` | `WILL_INIT` record attribute | exact rmgr-specific class rule | explicit full initialization coverage and result-version producer | attribute alone never authorizes init；missing rule BLOCKED | same as owning page class |
| `PC-CLEANOUT` | delayed cleanout/metadata normalization | TT/undo truth + page redo producer | old/result version + transaction authority from RF-SIDE | versioned deterministic apply；unknown codec BLOCKED | page + required SIDE proof complete |
| `PC-NONLOGGED` | nonlogged persistent metadata | declared canonical owner or rebuild owner | proof of complete rebuild/derive contract | rebuild/route；cannot silently treat as WAL-covered | canonical owner post-read/rebuild proof |
| `PC-UNKNOWN` | anything else | none | classification unavailable/ambiguous | mutation=0，fail closed | never release as recovered |

### §4.2 Normal persistent rule

`PC-NORMAL` is the only general delta-replay class。它必须有 full PageVersion before/result链。
缺任一 producer、decoder、source、contributor或result verifier即 `BLOCKED`，不能降级成
`InvalidScn` containment后继续。

### §4.3 New/unformatted and incarnation

`PC-NEW` 的 before state 是 typed `UNFORMATTED(PageIdentity, new_incarnation)`，不是
raw SCN/token zero。只有 canonical lifecycle证明该 address 在 new incarnation前不存在可见旧页，
且初始化record覆盖完整page bytes/required header时才可apply。

`PC-INCARNATION` 必须把旧/new contributor set分开。old-incarnation redo永远不能apply到
new-incarnation page；即使 LSN/SCN/checksum看起来匹配也必须拒绝。

### §4.4 Temp and rebuildable

`PC-TEMP` 与 `PC-REBUILDABLE` 的安全性来自“无需保留原page semantics”的 typed proof，
不是来自忽略redo。rebuild contract必须穷举所有消费者、source truth和完成 verifier。

| object | affirmative class | mandatory contract |
|---|---|---|
| FSM | `PC-REBUILDABLE` ⚫ | 确定分配；只按已批准偏离从堆页真实空间与关系大小 invalidate/rebuild，不做 generic redo apply |
| VM | `PC-NORMAL` | 必须走完整 PageVersion `expected-before -> result-version` 链；`XLOG_HEAP2_VISIBLE` 的存在不免除 producer/decoder/verifier census |
| index page | `PC-NORMAL` | 必须走完整 PageVersion 链；per-AM rmgr 的工程成本不构成豁免 |

exact-f076 `no correctness consumer` 穷举普查为 `8/8`：

| # | FSM consumer site | 取得 FSM 答案后的强制复核 / disposition |
|---:|---|---|
| 1 | heap `hio.c:683` | `PageGetHeapFreeSpace(page)` 取真值并比较 `targetFreeSpace <= pageFreeSpace`；不足则 `RecordPageWithFreeSpace` 记真值后重取 |
| 2 | heap `hio.c:861` | `PageGetHeapFreeSpace(page)` 取真值并比较 `targetFreeSpace <= pageFreeSpace`；不足则 `RecordPageWithFreeSpace` 记真值后重取 |
| 3 | nbtree `nbtpage.c:903` | `_bt_conditionallockbuf` 后检查 `PageIsNew` 与 `BTPageIsRecyclable` |
| 4 | gin `ginutil.c:306` | `ConditionalLockBuffer` 后检查 `GinPageIsRecyclable` |
| 5 | gist `gistutil.c:831` | `ConditionalLockBuffer` 后检查 `PageIsNew` |
| 6 | spgist `spgutils.c:391` | 检查 `SpGistBlockIsFixed` 并走 `ConditionalLockBuffer`；拿不到锁即放弃该答案 |
| 7 | brin `brin_pageops.c:710,866` | 检查 `InvalidBlockNumber` 并复核页内空间 |
| 8 | vacuumlazy `vacuumlazy.c:1434` | `GetRecordedFreeSpace(...) == 0` 只决定是否补记，不作correctness判断 |

结论是 `8/8` 零 correctness consumer；索引路径拿不到 conditional buffer lock 就放弃
FSM 答案，`fsm_does_block_exist()` 另外兜住 truncate 竞争。结构证据一致：
`rmgrlist.h` 中 FSM 命中 `0`、全仓 `fsm_redo` 定义 `0`，热路径是
`MarkBufferDirtyHint`（`freespace.c:235,668,750,906`）；`freespace.c:332`
的 `log_newpage_buffer` 也明示 optional。

本豁免严格只限 FSM，不得扩成“无版本页”类别。catalog、TT、undo、HWM
不得因名称相似自动归入。日后任一消费者把 FSM 答案当作权威，本豁免立即失效：
classifier 必须 fail closed，直到按 Rule 26 重新取证并获得 user 批准。

### §4.5 Header pages

generic RF-PAGE不能修改 file/control header。classifier必须 route到 exact typed owner；
owner missing、cross-owner overlap或返回无 version/post-read proof时 exact resource保持BLOCKED。

### §4.6 FPI and WILL_INIT

FPI是可能的 image payload，不是 authority。它只有在 record lineage、identity、page class、
incarnation、result-version和完整 contributor boundary均验证时才可成为 working image。

`WILL_INIT`只是record属性。除非 exact rmgr rule证明全页初始化、expected class state与
result-version，否则不能跳过 prior source或expected-before门。

### §4.7 Cleanout and nonlogged metadata

Oracle public evidence没有公开 cleanout/nonlogged exact codec。PGRAC必须显式声明 producer、
authority、before/result version与恢复动作；否则 class可识别但动作固定BLOCKED。
本文不借 RF-SIDE truth推断page bytes，也不让page projection反向决定transaction truth。

---

## §5 Source provenance

### §5.1 Logical proof

`PageSourceProof` 是一次 recovery attempt内的 typed proof，不是新 persistent authority：

~~~text
PageSourceProof := source_kind(CURRENT|PI|STORAGE)
                 + exact PageIdentity/PageVersion
                 + source_owner and stability witness
                 + integrity result
                 + control-root/failure-generation lineage
                 + covered contributor boundary
~~~

proof不能从pathname、mtime、counter、digest-only、target LSN或recoverer-local cache产生。

### §5.2 CURRENT

`CURRENT` 必须证明：

1. survivor GCS holder对 exact resource拥有 current authority；
2. copy前后 identity/version/stability witness一致；
3. source不是failed/stale incarnation的未验证buffer；
4. integrity与page-class verifier通过；
5. control-root/failure generation仍current；
6. source version覆盖哪些changes由per-block chain证明。

若 CURRENT version已是required terminal result，可产生空 replay set，但“空”必须有production
GCS stability witness；不能从tag、telemetry或numeric high-water推断。

### §5.3 PI

`PI` 必须证明 exact resource/tag、past-image version、ship/boundary SCN、source holder、
integrity和failure-generation lineage。PI在page write完成并通知resource authority前不得被当作
可随意discard的local copy。

PI corrupt、stale、wrong incarnation、holder变化或stability recheck失败时，丢弃该proof，
不把PI bytes传给STORAGE分支，不把PI miss写成page已恢复。

### §5.4 STORAGE

`STORAGE` 只有同时满足下列 conjunction 才可信：

1. exact PageIdentity/class/incarnation可验证；
2. physical integrity verifier通过；
3. PageVersion有效；
4. version锚定到 durable checkpoint/control-root lineage；
5. 从source version到per-block required end的contributor set完整；
6. full-page/init record、FPW状态及所有applicable rmgr exception均有明确处置；
7. source在本次mutation前仍是已验证bytes。

retained failed-origin redo本身不是STORAGE base。target已torn、version invalid或checkpoint anchor
不可证时，STORAGE不可用；不能用redo“从空开始”猜恢复。

### §5.5 Source conflict and absence

多个有效source若PageVersion/bytes/lineage冲突，结果是 corruption/BLOCKED；不选最大SCN、
最大LSN或多数cache。无valid CURRENT/PI/STORAGE时，`mutation=0`，exact resource BLOCKED。

---

## §6 Per-block recovery set and conditional merge

### §6.1 Recovery-set identity

`BlockRecoverySet` 是可重建的in-memory plan：

~~~text
BlockRecoverySet := failed_origin_duty
                  + exact resource/PageIdentity/PageClass
                  + selected PageSourceProof
                  + required terminal PageVersion
                  + ordered RedoPageChange contributors
                  + authority/control-root/failure-generation binding
~~~

它不是持久进度、不是successor authority、不是WAL retirement certificate。recoverer crash后
discard并重建。

### §6.2 Build algorithm

对每个affected block/resource：

1. 从RF-ROOT取得duty、retained interval与current authority；
2. classify exact page/record class；
3. census survivor CURRENT与PI；
4. 若有可信CURRENT/PI，选择满足identity/version/lineage的source并闭合其后所需changes；
5. 只有CURRENT和PI均不存在或均不可信时，才从checkpointed STORAGE base出发；
6. 只收集该block所需failed-thread redo；sequential failure涉及多个origin时逐个绑定其root；
7. 按exact before/result edge与declared dependency topology建立chain；SCN/LSN只作locator/hint；
8. gap、straddle、duplicate divergence、unknown rmgr/class、tail不完整即BLOCKED；
9. pre-scan closure完成前不mutation、不release。

### §6.3 Contributor closure

closure必须证明：

- scan lower/upper分别来自source version与RF-ROOT retained validated tail；
- every page-affecting record被分类为apply、trusted skip或typed route；
- same-block chain exact join；
- no applicable record被unknown/parse failure/filter漏掉；
- multi-thread merge只含该block需要的contributors；
- terminal PageVersion唯一；
- rerun同一canonical inputs得到相同chain/result。

跨thread裸LSN没有全局顺序语义。SCN相同但dependency不明时不能任意排序；必须由record
dependency/class rule裁决，否则BLOCKED。

### §6.4 Release scope

一个block只有在本block达到`POST_READ_VERIFIED`且RF-ROOT authority fresh时才release。
另一个block或side domain未完成不阻塞本block，除非dependency graph显式相交。
一个block ready不证明relation、thread、instance或WAL interval ready。

---

## §7 Apply, durability, post-read and D3′

### §7.1 Mutation admission

每次apply前必须 fresh 验证：

1. exact duty/control root；
2. active recoverer与failure generation；
3. four-layer fence；
4. exact resource serialization；
5. selected source proof仍valid；
6. working version exact expected-before；
7. retention pin覆盖全部contributors。

失败时不进行page mutation，不把temporary failure改成skip。

### §7.2 Native mutation sequence

在未来产品授权后，允许的语义顺序是：

1. 在detached working image完成deterministic apply与result-version验证；
2. 取得native buffer/GCS/content authority；
3. 再次验证working image target identity与current authority；
4. 满足所有applicable WAL-before-data ordering；
5. 通过native page write path安装；
6. 对exact relation/page执行durability barrier；
7. 从canonical storage重新读取page；
8. post-read验证identity、class、incarnation、PageVersion、integrity与expected terminal result；
9. fresh revalidate RF-ROOT authority；
10. 产生typed page proof并release exact resource。

write return、dirty bit、relation fsync counter、logical DONE或pre-write checksum均不足。

### §7.3 Page proof exported to ROOT/SIDE

logical export只包含可重算事实，不冻结ABI：

| proof element | meaning |
|---|---|
| exact duty/root/resource identity | proof属于哪个failed-origin obligation |
| PageClass/PageIdentity/PageVersion | post-read读到的canonical result |
| contributor coverage | source-to-terminal exact chain已闭合 |
| durability barrier result | relevant data write已完成durable ordering |
| post-read result | canonical bytes fresh read并验证 |
| current authority result | release前RF-ROOT revalidation通过 |

RF-ROOT只消费proof做resource release与`FND-10` conjunction；RF-SIDE只消费page dependency，
不得把此proof变成all-domain barrier。

### §7.4 FND-10 handoff

exact f076没有equivalent successor recovery WAL。故 failed-origin redo 必须继续retained，
直到所有affected page proof与SIDE proof满足AD `FND-10`，且无consumer。

保留redo只解决retirement，不自动提供torn target的stable base。任何实现或测试不得把
“origin redo仍在”单独当作repeated-recoverer correctness闭环。

### §7.5 D3′ restart

recoverer death后：

1. successor重新取得current ROOT authority；
2. 重新census CURRENT/PI/STORAGE与retained redo；
3. predecessor-private memory/progress默认丢弃；
4. 独立持久old artifact只有在lineage/version/control-root全验证后可作optimization；
5. optimization miss/corrupt/wrong generation回canonical rebuild；
6. target在post-read前一律视为untrusted；
7. stable base不能证明时，mutation=0，resource保持BLOCKED。

这是D3′ evidence-based PGRAC mapping，不声称Oracle公开了exact internal handoff。

### §7.6 STOP-RF-PAGE-STABLE-BASE

公开证据只字面支持 simultaneous/sequential failures；相邻 during-recovery 句的主语是
shared server feature，不证明 generic recovery-duty handoff。public corpus 没有公开 cache-recovery
mid-write 的 stable preimage/atomicity/carrier。exact f076又可能 direct-write target 且不生成
successor recovery WAL。

因此以下均未获批准：

| candidate | status |
|---|---|
| zero-mutation safety floor | normative fail-closed behavior；不是availability solution |
| canonical full-image/init anchor path | `PROPOSED / NOT APPROVED` |
| storage atomic-write dependency | `PROPOSED / NOT APPROVED` |
| shared doublewrite | `PROPOSED / NOT APPROVED` |
| successor recovery WAL/FPI | `PROPOSED / NOT APPROVED` |
| private/shared recovery journal | `REJECTED AS CURRENT CORRECTNESS`; any new proposal needs Rule 26 |

本 spec 不冻结上述任何candidate的API、ABI、layout、message、actor或acceptance。user裁决前，
repeated-recoverer target-write test必须保持`RED / STOP`，RF-PAGE不能freeze，产品TDD不能开始。

### §7.7 Crash matrix

| cut | trusted state | required outcome |
|---|---|---|
| before source proof | none | rebuild source census；mutation=0 |
| after source proof, before mutation | ephemeral proof | successor re-census；不adopt local plan |
| during target write | target may be torn | `STOP-RF-PAGE-STABLE-BASE`; BLOCKED without approved stable base |
| after write, before durability | target nondurable/untrusted | rebuild or BLOCKED |
| after durability, before post-read | bytes may be durable but unverified | fresh post-read；failure=>rebuild/BLOCKED |
| after post-read, before release | durable result可重验 | authority revalidate then exact release |
| after release | resource ready only | redo retirement仍由ROOT `FND-10`决定 |

---

## §8 Error, compatibility and performance contracts

### §8.1 Outcomes

| outcome | trigger | mutation/release |
|---|---|---|
| `APPLY` | source trusted + exact before + deterministic change | allowed under §7 gates |
| `SKIP` | trusted result-version coverage proof | no mutation；仍计coverage |
| `BLOCKED_SOURCE` | no trustworthy CURRENT/PI/STORAGE | mutation=0；resource held |
| `BLOCKED_CONTRIBUTOR` | redo gap/unknown/ordering ambiguity | mutation=0；retain interval |
| `BLOCKED_CLASS` | unknown/ambiguous page class | mutation=0 |
| `CORRUPTION_VERSION` | expected-before/result mismatch | mutation stops；resource blocked |
| `STALE_AUTHORITY` | ROOT revalidation fails | stop actor；no release |
| `STABLE_BASE_UNRESOLVED` | repeated-recoverer mid-write cut | RED/STOP；no false DONE |

具体 SQLSTATE/errcode尚未由产品授权冻结；必须复用现有typed error surface或另行获批，
不能在本文偷偷新增编号。

### §8.2 Compatibility

1. exact f076缺PageVersion before/result producer，现有行为不能宣称兼容新contract；
2. mixed-version peer不能产生/验证exact proof时相关resource fail closed；
3. 不从old private artifact迁移correctness authority；默认ignore并rebuild；
4. 不修改catalog/page/WAL/wire ABI，直到stable-base STOP与product plan获批；
5. rollback不得删除retained origin redo或放宽version/source/class gates；
6. checksum on/off只改变detector，不改变authority与replay semantics。

### §8.3 Normal path performance

| new normal-path cost | hard limit |
|---|---:|
| synchronous network RTT | `0` |
| fsync/fdatasync/durable rename | `0` |
| shared-control-file I/O | `0` |

PageVersion record/page-format cost在product ABI决定后必须实测。recovery-only source census、merge、
durability与post-read不能被错误接入normal transaction hot path。

### §8.4 Formal honesty

最终仍需fresh real `4×1×3 + rate10/20/30`，judge、公式、阈值、workload identity不变。
timeout、error、forced cancel、skip、whitelist或synthetic-only不能制造绿色。本文没有运行campaign。

---

## §9 Observability

### §9.1 Required recovery-only metrics

语义必须单一；exact名称待product plan冻结：

- source selected by CURRENT/PI/STORAGE；
- source invalid/missing/conflict by reason；
- result-version skip；
- expected-before apply/mismatch；
- page class and unknown-class BLOCKED；
- per-block contributor records/threads/gaps；
- page write, durability barrier, post-read success/failure latency；
- authority stale rejection；
- resource early release；
- failed-origin interval pinned bytes/retire denial；
- D3′ rebuild/optimization hit/miss；
- stable-base unresolved stops。

EVENT、GAUGE、TIMESTAMP不能混用。每个counter必须有唯一producer、dump/SQL consumer与触发测试。

### §9.2 Wait events

future implementation至少区分：

1. source/GCS stability wait；
2. per-block contributor scan/merge wait；
3. page durability wait；
4. canonical post-read wait；
5. resource release authority wait。

名称与catalog ripple在product plan定；本文不新增dead enum。

### §9.3 Dump

一次block attempt dump至少包含duty/root/failure generation、resource、page class、source kind、
source/terminal PageVersion、contributor count/thread set、apply/skip/mismatch、durability/post-read、
authority revalidation、release result与STOP reason。不得打印page content或私有设计文本。

---

## §10 Tests

### §10.1 Static/unit RED

| ID | exact RED | expected |
|---|---|---|
| `PU-01` | InvalidScn normal page | BLOCKED；证明containment，不算version success |
| `PU-02` | expected-before exact match | one apply；result exact |
| `PU-03` | expected-before mismatch | corruption/BLOCKED；zero target mutation |
| `PU-04` | trusted exact result | skip；zero apply |
| `PU-05` | numeric-higher但chain gap | no skip；BLOCKED |
| `PU-06` | same SCN different incarnation | mismatch |
| `PU-07` | unknown class/rmid/opcode | default BLOCKED |
| `PU-08` | normal persistent page | PageVersion chain required |
| `PU-09` | new/unformatted with full init proof | typed init succeeds |
| `PU-10` | new/unformatted missing lifecycle | BLOCKED |
| `PU-11` | incarnation transition with old redo | old contributor rejected |
| `PU-12` | temp class | discard/recreate only with owner proof |
| `PU-13` | rebuildable/FSM | invalidate+rebuild；no generic redo apply |
| `PU-14` | header class | route typed owner；generic mutation zero |
| `PU-15` | valid FPI provenance | accepted as image payload |
| `PU-16` | FPI wrong lineage | BLOCKED |
| `PU-17` | WILL_INIT without rmgr full-init rule | BLOCKED |
| `PU-18` | cleanout with exact TT+version input | deterministic apply |
| `PU-19` | cleanout codec unknown | BLOCKED |
| `PU-20` | nonlogged metadata with rebuild owner | typed rebuild |
| `PU-21` | nonlogged metadata no owner | BLOCKED |
| `PU-22` | CURRENT empty set without GCS witness | BLOCKED |
| `PU-23` | PI stale/corrupt | reject PI；no byte reuse |
| `PU-24` | STORAGE no checkpoint anchor | reject source |
| `PU-25` | STORAGE contributor gap | BLOCKED |
| `PU-26` | CURRENT/PI absent | only per-block failed-redo path considered |
| `PU-27` | raw cross-thread LSN ordering | rejected |
| `PU-28` | stale ROOT authority before mutation | zero mutation |
| `PU-29` | stale ROOT authority before release | no release |
| `PU-30` | post-read wrong version/checksum | no proof/release |

### §10.2 Fault TAP legs

| ID | injection | required result |
|---|---|---|
| `PL-01` | death before source proof | successor re-census；target unchanged |
| `PL-02` | death after contributor closure | local plan ignored；deterministic rebuild |
| `PL-03` | death during target write | `RED / STOP-RF-PAGE-STABLE-BASE` |
| `PL-04` | death after write before durability | no DONE/release |
| `PL-05` | death after durability before post-read | successor fresh read/rebuild/BLOCKED |
| `PL-06` | death after post-read before release | revalidate then idempotent exact release |
| `PL-07` | PI disappears mid-attempt | re-census；no fallback bytes smuggling |
| `PL-08` | target corrupted before STORAGE classify | reject target source |
| `PL-09` | failed-origin segment missing | contributor BLOCKED；retirement denied |
| `PL-10` | sequential failures, two blocks | each block exact contributor set |
| `PL-11` | healthy unrelated block | early release while affected block stays BLOCKED |
| `PL-12` | redo-retire request before PAGE proof | RF-ROOT denies removal |
| `PL-13` | old optimization artifact wrong lineage | ignore and canonical rebuild |
| `PL-14` | checksum off | same authority/version gates |

`PL-03` 不允许通过SKIP、expected-failure改绿或mock carrier。它必须保持可见RED/STOP，直到user
批准stable-base策略并相应修订本文。

### §10.3 Production caller test

测试必须让source classifier、contributor builder、apply gate、durability、post-read、release、
retention handoff在真实orchestrator caller中逐段fire。删除任一production gate时对应RED必须变红；
pure helper coverage不满足G1/G9。

### §10.4 Regression and acceptance

未来product TDD完成后至少要求：

- cluster disabled：PG 219原预期，无page recovery side effect；
- cluster enabled idle：PG 219原预期，normal path `0/0/0`；
- recovery unit/TAP所有非STOP legs真实PASS；
- repeated-recoverer target-write leg在STOP解除前明确RED；
- fresh `4×1×3 + rate10/20/30`无改judge/skip/timeout。

---

## §11 G1–G9 governance and DoD

### §11.1 Full gates

| gate | RF-PAGE exact self-check |
|---|---|
| `G1` | exact f076 symbol/caller存在性逐项census；prospective symbol不写成已有 |
| `G1′` | prospective helper放置必须能访问真实page/rmgr/GCS types |
| `G1″` | runtime caller必须真实拥有buffer pin/content authority/resource serialization/I/O能力 |
| `G2` | counter/field只表达EVENT、GAUGE或TIMESTAMP之一 |
| `G3` | PageVersion producer、source proof、post-read、release chain当前均标RED/未成立 |
| `G4` | 每个accessor有same-spec production consumer |
| `G4′` | 每个field有唯一producer并携带不可由其他field推导的信息 |
| `G5` | INFERENCE/PUBLICLY UNKNOWN不承担stable-base correctness |
| `G5′` | Oracle verified引用必须字面蕴含claim；patent/expert不冒充manual |
| `G6` | 偏离Oracle只可归既有三类并user批准；否则STOP |
| `G7` | classifier/source/error triggers穷举true event与temporary failure |
| `G8` | 4.10/4.11旧hard gates逐条inherit/strengthen/supersede/reject |
| `G8′` | 旧counter/tests/formal denominator逐项保留或精确替代 |
| `G9` | 每个promise落实到陌生实现者可直接写RED的input/action/outcome |

- [ ] G1–G9（含 G1′/G1″/G4′/G5′/G8′）已逐条自检

当前checkbox保持未勾选：spec静态presence不等于product caller/producer已经存在。

### §11.2 Predecessor gate census

| predecessor gate | disposition |
|---|---|
| exact block tag与block-ref filter | `INHERIT` |
| validated scan lower/tail upper与record integrity | `INHERIT + ROOT BIND` |
| complete base before delta replay | `STRENGTHEN` to source proof + PageVersion |
| target pd_lsn retry skip | `REJECT` for recovery correctness |
| raw `smgrwrite` + touched-rel sync | `SUPERSEDE` by native durability + post-read |
| PI ship_scn sanity | `INHERIT + STRENGTHEN` with provenance/version/stability |
| catchable recovery error returns BLOCKED | `INHERIT`；FATAL/PANIC不吞 |
| `blocks_applied` means mutation not durability | `INHERIT`；新增proof不改旧counter语义 |
| synthetic reconstruction tests | `RETAIN AS UNIT ONLY`；不替代faithful fault |

### §11.3 Spec rewrite DoD

- [x] journal-centric summary已替换为Oracle-first versioned page replay。
- [x] `InvalidScn => BLOCKED`明确只是containment。
- [x] PageVersion/incarnation/opaque VersionToken semantic identity已定义。
- [x] expected-before/result-version apply/skip state machine已定义。
- [x] normal/new/incarnation/temp/rebuildable/header/FPI/WILL_INIT/cleanout/nonlogged/unknown已穷举。
- [x] CURRENT/PI/STORAGE authority、producer、verifier、action、release已定义。
- [x] per-block recovery set、conditional merge与contributor closure已定义。
- [x] durable page write、post-read、authority revalidation与scoped release已定义。
- [x] D3′不依赖predecessor-private progress。
- [x] failed-origin redo retention与PAGE proof handoff消费FND-10。
- [x] STOP-RF-PAGE-STABLE-BASE仍active且未选择carrier。
- [x] repeated-recoverer target-write test明确RED/STOP。
- [x] exact-f076 gaps未虚报为已实现。
- [x] observability、tests、G1–G9、Q&A、plan已写入。
- [x] PRODUCT AUTHORIZATION=0；未触碰公开产品仓。
- [ ] AD/ROOT/SIDE cross-spec integration验证完成。
- [ ] CC对exact fingerprint返回ACCEPT或exact conflict。
- [ ] user批准stable-base boundary/strategy。
- [ ] product TDD另行授权并真实完成。
- [ ] fresh formal `4×1×3 + rate10/20/30`真实通过。

---

## §12 Q&A — closed and stopped decisions

### Q1 Normal page correctness核心是什么？

- ★ A：PageVersion result skip + exact expected-before apply。
- B：只做InvalidScn containment。
- C：只比较target LSN。

选择A。B只检测一类invalid input；C跨thread且不能识别torn/old incarnation。

### Q2 何时允许skip？

- ★ A：可信source exact result或连续before/result chain证明coverage。
- B：source SCN数值更大。
- C：checksum匹配。

选择A。B/C不证明change已存在。

### Q3 Source优先形状是什么？

- ★ A：per-block验证CURRENT/PI；缺两者才从checkpointed STORAGE + required redo恢复。
- B：永远读target storage。
- C：默认合并全部thread。

选择A，对齐OP-01且缩小recovery scope。

### Q4 FPI/WILL_INIT是否自动可信？

- ★ A：否；必须通过identity/class/version/lineage/coverage。
- B：FPI总是可信。
- C：WILL_INIT总是无需before。

选择A；payload或flag不授authority。

### Q5 unknown page class怎么办？

- ★ A：fail closed，mutation=0。
- B：按normal page尝试。
- C：按rebuildable丢弃。

选择A；B/C可能silent corruption。

### Q6 block何时release？

- ★ A：本block durable post-read + fresh ROOT authority后立即release。
- B：所有side domains全完成后。
- C：write return后。

选择A，符合resource-scoped Oracle形状；C缺durability，B扩大barrier。

### Q7 failed-origin redo何时retire？

- ★ A：ROOT按FND-10消费全部PAGE/SIDE proofs并确认无consumer。
- B：本block release即删整个interval。
- C：logical replay DONE即删。

选择A；resource release与interval retirement不是同一事实。

### Q8 recoverer再次crash如何处理？

- ★ A：D3′重新census canonical sources；无stable base则BLOCKED。
- B：信任predecessor private progress。
- C：从torn target继续。

选择A。B/C无independent proof。

### Q9 stable-base carrier选什么？

- A：canonical full-image/init anchor。
- B：storage atomicity/doublewrite/successor WAL。
- ★ C：当前不选；保持STOP与zero-mutation floor。

当前只能选择C。A/B均未获user批准，本文不得freeze其API/ABI。

### Q10 normal path性能边界？

- ★ A：新增sync RTT/fsync/shared-control I/O=`0/0/0`。
- B：每事务写recovery proof。
- C：每次buffer transfer持久化progress。

选择A，recovery correctness不能扩散成normal-path同步税。

---

## §13 Prospective implementation plan

仅在stable-base裁决、四文档closure与PRODUCT AUTHORIZATION后执行：

| step | dependency | RED/GREEN objective |
|---|---|---|
| `P1` | approved spec | exact-f076 rmgr/page/source/caller census |
| `P2` | P1 | PageVersion semantic producer/decoder RED then GREEN |
| `P3` | P2 | exhaustive class dispatcher，unknown default BLOCKED |
| `P4` | P2 | CURRENT/PI/STORAGE provenance validators |
| `P5` | P3/P4 | per-block contributor builder + conditional merge |
| `P6` | P5 | exact expected-before apply/result skip |
| `P7` | user stable-base decision | approved crash-safe mutation substrate；不得提前build |
| `P8` | P6/P7 | native durability + canonical post-read |
| `P9` | P8 + ROOT | resource proof/release + FND-10 handoff |
| `P10` | P2-P9 | observability/error/wait producer-consumer closure |
| `P11` | P2-P10 | unit/TAP/fault tests；PL-03 only after approved carrier |
| `P12` | all GREEN | fresh formal `4×1×3 + rate10/20/30` |

任何步骤冒出新field、actor、message、persistent artifact、global barrier或correctness dependency，
先按Rule 26查Oracle/报告user，不在implementation中自行设计。

---

## §14 Cross-spec exports, risks and version history

### §14.1 Exports

| consumer | RF-PAGE export |
|---|---|
| RF-ROOT | per-resource source/version/contributor/durable-post-read verdict；STOP active时deny release/retire |
| RF-SIDE | exact page dependency ready/BLOCKED；不传global page barrier或page authority |
| AD-019 | exhaustive class、PageVersion matrix、source survival assessment、STOP disposition |

### §14.2 Risks

| risk | impact | mitigation |
|---|---|---|
| target torn且无stable base | silent corruption/permanent block | active STOP；zero mutation/BLOCKED |
| PageVersion producer不完整 | wrong skip/apply | G3/G4′ + PU-02..06 |
| exception class遗漏 | wrong decoder | closed classifier + PU-07..21 |
| CURRENT empty set无witness | missed redo | production GCS witness + PU-22 |
| PI lifecycle过早结束 | source loss | stability/holder revalidation + PL-07 |
| STORAGE checkpoint/contributor不闭合 | wrong base | conjunction + PU-24/25 |
| cross-thread raw SCN/LSN排序 | wrong replay order | exact expected/result edge topology；SCN/LSN只作locator/hint + PU-27 |
| post-read被write return替代 | false durable | PL-04..06 |
| per-block release遗漏dependency | early visibility | exact dependency graph；unknown blocks scope |
| PAGE proof误授权WAL retire | source loss | ROOT owns FND-10 decision + PL-12 |
| old artifact复活authority | split recovery | D3′ validation/fallback + PL-13 |
| normal path引入sync tax | formal perf failure | FND-11 0/0/0 + formal matrix |

### §14.3 Version history

| version | date | status | summary |
|---|---|---|---|
| v0.x | 2026-08-04 | `HISTORICAL / SUPERSEDED` | private page journal、claim-linked adoption、A containment核心 |
| v1.0 | 2026-08-05 | `REOPENED DRAFT — BASELINE USER APPROVED; EXACT BODY PENDING CC; STOP ACTIVE; PRODUCT NOT AUTHORIZED` | Oracle-first PageVersion、exact expected-before、CURRENT/PI/STORAGE、per-block recovery、post-read、D3′；stable-base carrier未选择 |

<!-- NORMATIVE-BODY-END -->

| Fingerprint metadata | 值 |
|---|---|
| body_sha256 | `c89746739171dc2698e4cf4dfaccbdbeca8dc417de9a865ed1d30b43414efb58` |
| body_lines | `932` |
| body_bytes | `47022` |

---

## 工作区本地增量 1：PGDEL-01 落地（2026-08-20）

**交付**（spec §2.1 PGDEL-01，RED→GREEN 于语义层）：

- `src/include/cluster/cluster_page_version.h` + `src/backend/cluster/
  cluster_page_version.c`：§3.1 PageIdentity/PageIncarnation/VersionToken
  语义类型（in-memory，无 ABI 冻结）；`cluster_page_identity_valid/equal`、
  `cluster_page_version_valid/equal`（仅 valid 间的 exact equality；
  invalid——InvalidScn/zero/missing/decode-failure/unknown——永不相等，
  永不映射 oldest/newest/unformatted，§3.1/PU-01）；§3.4 UNFORMATTED
  显式 before-state；§3.2 `cluster_page_version_decide`（expected-before
  -> result-version 准入 + §3.3 形状 1 trusted-source==result SKIP；
  无 numeric ordering，PU-05）；§4.1 closed `cluster_page_classify`
  （PC-NORMAL..PC-UNKNOWN 恰一行；multi-match/unknown → UNKNOWN=BLOCKED；
  FSM=REBUILDABLE 走已批准偏离；WILL_INIT 无 full-init rule → UNKNOWN，
  PU-17；header 需显式 typed owner，PU-14）。
- rmgr/opcode known-set 注册表（`cluster_page_class_register_known_opcode`，
  固定容量 64，满则拒绝 fail-closed，幂等）：**编译期空 census**——PGDEL-02
  负责 rmgr census；未注册的 main-fork record → UNKNOWN（PU-07）。
- `src/test/cluster_unit/test_cluster_page_version.c`：PU-01..08、PU-13、
  PU-14、PU-17 + identity/before-state/closed-rows/registry 共 14 个 RED
  单测，全绿。
- 边界（G1/G3，不得抹除）：现有 thread-recovery replay 路径
  （exact-f076 PX-01..PX-06：smgrread -> LSN-gated apply -> smgrwrite）
  **未触碰、未宣称 versioned**；producer/source-proof/mutation/
  durability/post-read/release 链全部仍 RED，属 PGDEL-02..06。

---

## 工作区本地增量 2：PGDEL-02 落地（2026-08-20）

**交付**（spec §2.1 PGDEL-02：applicable redo expected-before/result-
version producer + decoder；rmgr census 实现）：

- `src/include/cluster/cluster_page_rmgr.h` + `src/backend/cluster/
  cluster_page_rmgr.c`：
  - **rmgr census**：opcode 粒度行（RM_HEAP INSERT/DELETE/UPDATE/
    HOT_UPDATE = NORMAL + known_delta=true——byte-for-byte differential
    证据 t/256；LOCK/CONFIRM/INPLACE = NORMAL 但 known_delta=false——
    现有 matrix 8.A/R11 拒绝；INIT_PAGE = NEW + will_init 属性行——
    非 §4.6 规则，PU-17 保持 UNKNOWN）+ rmgr 粒度行（SLRU/relmap/undo =
    HEADER + typed owner，§4.5 禁止 generic replay；索引/SEQ = NORMAL
    未证明；控制/事务/文件级 = 非 page-affecting）。未知 rmgr 无行 →
    fail-closed。
  - **census → classifier 接线**：`cluster_page_rmgr_populate_known_set`
    只注册 known_delta=true 的行；未证明 opcode 继续 UNKNOWN（§4.2）。
  - **decode**：`cluster_page_redo_decode` 从 record block ref 提取
    PageIdentity + §3.1 hints（xl_scn/EndRecPtr/FPI/WILL_INIT 属性）——
    显式 locator/hint，非 VersionToken；不做版本判定、不 mutation。
- 边界（G1/G3，不得抹除）：`decoder_registered` 全行 false——§3.4
  deterministic-mutation 声明与 VersionToken producer 契约（§3.1
  producer/consumer census 证明）留 PGDEL-03/06；现有 replay 路径
  未触碰。
- `src/test/cluster_unit/test_cluster_page_rmgr.c`：10 个 RED 单测全绿
  （census 行归属/证据状态/typed-owner/非 page-affecting/未知 rmgr/
  INIT_PAGE 属性行/接线只注册已证明项/decode 事实提取/FPI+WILL_INIT/
  fail-closed 路径）。注意：rmgr opcode 用 `XLR_RMGR_INFO_MASK`(0xF0)，
  非 XLR_INFO_MASK(0x0F)。

---

## 工作区本地增量 3：PGDEL-03 落地（2026-08-20）

**交付**（spec §2.1 PGDEL-03：exhaustive page/record class dispatcher；
unknown default 必须 BLOCKED）：

- `src/include/cluster/cluster_page_recovery.h` + `src/backend/cluster/
  cluster_page_recovery.c`：
  - **§4.1 recovery-action 闭表**：`cluster_page_class_recovery_action`
    ——NORMAL/CLEANOUT=APPLY、NEW=INIT、INCARNATION=INCARNATE、TEMP=
    DISCARD、REBUILDABLE/NONLOGGED=REBUILD、HEADER=ROUTE、FULLIMAGE=
    IMAGE、WILLINIT/UNKNOWN/UNCLASSIFIED=BLOCKED（mutation=0，永不
    release）。
  - **§3.5 状态机**：`cluster_page_state_advance` 只允许相邻推进；跳步/
    重复/终态再推进/NULL 全拒；crash 后从 UNCLASSIFIED 重建（D3′，
    不读 predecessor-private phase）。
  - **§8.1 outcome 面**：`cluster_page_dispatcher_verdict`（class +
    §3.2 decide → APPLY/SKIP/BLOCKED_CLASS）；BLOCKED_SOURCE/
    BLOCKED_CONTRIBUTOR/CORRUPTION_VERSION/STALE_AUTHORITY/
    STABLE_BASE_UNRESOLVED 归 PGDEL-04..06 的证明所有者，本层不猜
    （G9）。
- 边界：纯内存、零 mutation/I/O/authority；source/contributor/
  mutation/durability/post-read 链仍 RED。
- `src/test/cluster_unit/test_cluster_page_recovery.c`：5 个 RED 单测
  全绿（action 闭表全行、unknown 默认 BLOCKED、状态机相邻链、跳步/
  重复/终态拒绝、verdict 组合）。

---

## 工作区本地增量 4：PGDEL-04 落地（2026-08-20）

**交付**（spec §2.1 PGDEL-04：CURRENT/PI/STORAGE provenance validators；
必须有 production source owners）：

- `src/include/cluster/cluster_page_source.h` + `src/backend/cluster/
  cluster_page_source.c`：
  - `ClusterPageSourceKind`（CURRENT/PI/STORAGE）+ 统一 typed fact 集
    `ClusterPageSourceValidateInput`（identity/source_version/
    integrity/stability/lineage/owner/ship_boundary/anchored/coverage/
    fresh/contributors_closed）——每个 fact 由具名 production owner
    声明（GCS holder、past-image 子系统、shared-storage smgr）；
    validator 是纯判定，不读盘/不持锁/不拷字节（G1′）。
  - §5.2 CURRENT 合取（identity + valid version + integrity + GCS
    stability witness + lineage + owner；PU-22 空集无 witness 不可承重）；
    §5.3 PI 合取（+ ship/boundary SCN proof；失败即丢弃，字节不得
    流入 STORAGE，PU-23）；§5.4 STORAGE 七条合取——`contributors_closed`
    为 false（PGDEL-05 未落）时 STORAGE 恒失败，诚实关闭（G3，PU-24）。
  - §5.5/§6.2 `cluster_page_source_select`：无 valid → BLOCKED（PU-26）；
    多 valid 版本冲突 → BLOCKED（绝不 max-SCN/LSN/多数）；同版本 →
    CURRENT > PI > STORAGE 优先序。
- 边界：contributor boundary（§5.4-5）归 PGDEL-05；mutation/
  durability/post-read 归 PGDEL-06；现有 replay 路径未触碰。
- `src/test/cluster_unit/test_cluster_page_source.c`：6 个 RED 单测全绿
  （三 validator 合取真值表 + select 的 BLOCKED/冲突/优先序）。

---

## 工作区本地增量 5：PGDEL-05 落地（2026-08-20）

**交付**（spec §2.1 PGDEL-05：in-memory per-block recovery-set builder
与 contributor closure；不是 persistent artifact）：

- `src/include/cluster/cluster_page_set.h` + `src/backend/cluster/
  cluster_page_set.c`：
  - `ClusterPageRedoChange`（§3.1：identity/class/expected_before/
    result_version/change_identity/failed_origin_thread）+ §6.1
    `ClusterBlockRecoverySet`（source kind/version、terminal、有序
    contributor 链）——可重建 in-memory plan，crash 即弃（D3′）。
  - §6.3 `cluster_page_contributor_closure`：same-block、非 UNKNOWN
    class、版本 valid、`c[i].result == c[i+1].expected` 精确邻接
    （含 incarnation；等 SCN 异 incarnation 不邻接，PU-06/27）、首
    expected == source、末 result == terminal（唯一，不猜）；空链仅
    source==terminal 时 OK（空 replay set 的 witness 半边，另半边在
    PGDEL-04 CURRENT）。GAP/UNKNOWN_CLASS/INCARNATION_CROSS/
    TERMINAL_MISMATCH/INVALID_INPUT 全 fail-closed；纯函数 rerun
    确定（§6.3-9）。
  - §3.3 形状 2 `cluster_page_contributor_chain_covers`：仅闭合链可
    证明覆盖；numeric high-water 永不覆盖（PU-05）。
- 边界：recovery set 的 live census（CURRENT/PI/STORAGE 填充）与
  mutation/durability/post-read 链（PGDEL-06）仍 RED；本层零
  mutation/I/O。
- `src/test/cluster_unit/test_cluster_page_set.c`：6 个 RED 单测全绿
  （闭合链 + rerun 确定、gap/terminal mismatch、unknown class +
  incarnation cross、空链、invalid inputs、shape-2 skip）。
