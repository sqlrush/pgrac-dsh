# spec-5.16 online node join — GRD/PCM resource remaster

> **v1.0 FROZEN — Q1-Q11 user approve 2026-06-27**（v0.1 起草 → r1 → v0.2 → r2 → v0.3 → r3 → v0.4 → sr1 claude 自审 → v0.5 → r4 → v0.6 → **user approve + freeze**；4 轮 user 对抗式 review + 1 轮 claude 自审，共 7P1 + 6P2 全闭，reviewer 清零）。
>
> 规则 22.6：spec 永久 frozen 在 `specs/`，后续修订**只能 amend（加 changelog）不重写**（§0-§10 body 不动；新发现 → `## Hardening vX.Y` appendix）。**编码硬 gate = spec-5.15 shipped（5.15 编码硬 gate 又 = 5.13 shipped）+ 5.16 必带 5.15 commit_member fence-arm amend（D3b，规则 21）+ D0 re-ground**。Q 裁决：**全采纳推荐（★）**——Q1=C（PCM correctness 主轴 + GRD 可选）/ Q2=B（epoch=判据，freeze 串行化）/ Q3=A（平行新函数，不碰 4.6）/ Q4=A（复用 SQLSTATE）/ Q5=A（不 bump catversion）/ Q6=A（join_* counter）/ Q7=A（复用 wait event）/ Q8=A（>64 cap defer）/ Q9=A（fail-closed RECOVERING）/ Q10=A（D0 collision-check 测试号）/ **Q11=A'**（joiner-local arm + master-side hard gate + reply status `DENIED_RESOURCE_RECOVERING` 尾值 D0=14）。
>
> **r4 review（user，2026-06-27）抓 1 P1（事实撞号）+ 1 P2（测试缺口），全部成立，v0.6 已收敛**：
> - **r4 P1（enum 值撞号，事实性）**：spec 写 reply status `=9 / 现状最大 8`——**实证错**：`GcsBlockReplyStatus` 现已到 `=13`（`READ_IMAGE_FROM_XHOLDER`，spec-5.2），`=9` 已被 `X_GRANTED_FROM_HOLDER`（spec-2.36）占。根因=**r3 我只读了 enum 前段（`sed 100,125` 截到 value 8）就断言 max 8**（违 feedback_spec_cites_must_grep_linkdb：cite 须读全）。**修**：全文改"D0 分配下一尾值（截至 research=14），不硬编码"+L64 sweep 加 StaticAssert no-collision。
> - **r4 P2（pre-MEMBER 窗口缺 TAP）**：sr1-② 的 INV-R14 + master-side default-deny 设计对，但只有 U16（unit），无 faithful TAP；t/311 L12 测的是 post-MEMBER fence 期。**修**：加 **L13（injection-type TAP，ship blocker）**：node0 CSSD-ALIVE 但 `is_member=false`，远端请求路由到 node0 → 必回 `DENIED_RESOURCE_RECOVERING→53R9L` 不进 dedup/grant。
>
> **sr1（claude 自审，2026-06-27，承 r3 深挖 gate 拓扑）对 linkdb 实证后 1 真洞 + 1 refinement + 1 confirm，v0.5 收敛**：
> - **sr1-②（真新洞，P1 级）**：v0.4 master-side gate 只在 `commit_member` arm fence，但 routing `cluster_gcs_lookup_master` 在 joiner **CSSD-ALIVE 即 snap 回它**（早于 commit_member），且 block envelope handler **无 membership guard**（实证 `cluster_gcs_block.c:1937+`）→ `[CSSD-ALIVE, MEMBER-committed]` 窗口可 cold-serve。**修**：master-side gate **default-deny until (`in_quorum && is_member(self)`)**（新 **INV-R14**），覆盖 pre-MEMBER 窗口。
> - **sr1-③（refinement，L216/L243）**：v0.4 新建 `join_block_redeclare_scan_done_epoch` 与 4.7 既有 `recovery_done_epoch[]`（`cluster_grd.c:1758`）重复。**修**：`view_rebuilt = recovery_done_epoch[static_master(tag)] >= fence_epoch`，复用既有字段，不建平行机制。
> - **sr1-①（confirm，强化完整性）**：实证 GES master-side grant 已查 `cluster_grd_shard_phase() != NORMAL`（`cluster_ges.c:1059/1196`）→ **GRD 逻辑锁 join 侧无 r3 那种洞**（4.6 既有 master-side fence）；唯 PCM block envelope handler 缺 guard（已由 r3 + sr1-② 补）。GRD/PCM 不对称在 INV-R14 + §5 记录。
>
> **r3 review（user，2026-06-27）抓 1 P1 + 2 P2，对 linkdb 实证后全部成立，v0.4 已收敛**：
> - **r3 P1（Q11-A 否决）**：纯 joiner-local fence 不够——`phase_for_tag` **只在 requester-side**（`cluster_pcm_lock.c:1803/1808`）调用，master-side envelope handler（`cluster_gcs_block.c:1937`）从 range-guard→dedup→grant **不调 phase gate** → 远端 requester（视图未更新）路由到 joiner 后仍 cold grant。**修**：Q11 改 ★**A'** = joiner-local arm + **master-side hard gate（envelope handler 内）+ 新 reply status `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（**r4 修正：r3 误写 =9，实际 9 已被 `X_GRANTED_FROM_HOLDER` 占，尾值 D0=14**）→53R9L**。放宽"wire 零改"为"wire struct/routing-token 零改 + reply status +1 值"（§1.4 例外 1）。requester-side gate 降为优化，master-side 是正确性 backstop。
> - **r3 P2-①**：view-rebuilt 门粒度二义（`[…SHARD_COUNT…]`）——PCM home = `hash(tag)%declared_count`（`cluster_gcs.c:264`，节点域）**非** GRD 4096-shard 域。**修**：钉成 membership-keyed + epoch：`join_pcm_fenced_member_bitmap[16]` + `join_pcm_fence_epoch` + scan-done epoch（**sr1-③ 后改为复用既有 `recovery_done_epoch[]`，不新建字段**）；`active_for_tag = static_master(tag)∈fenced_member`，`view_rebuilt = recovery_done_epoch[home] >= fence_epoch`（§2.2）。
> - **r3 P2-②**：§5 contract 自相矛盾（D3b 改 `cluster_reconfig.c` 但表写"不改"）。**修**：表改 `cluster_reconfig.c` 必改 commit_member hook；.h 视声明位置（§5）。
>
> **r2 review（user，2026-06-27）抓 2 P1 + 1 P2，全部成立，v0.3 已收敛**：
> - **r2 P1-①**：PCM fence 作用域仍被 GRD moved-shard 集绑住（v0.2 D2 "受影响集 = master[] 变化"）→ `join_remaster_enabled=off` 时 GRD 不动 = moved 集空 = fence 不命中 = P1-A 重开。**修**：拆 **`pcm_fenced_home_set`（static PCM home，绑 online_join，forced，与 GRD moved 无关）** vs **`grd_moved_shards`（GRD master 变化，绑 GUC，可选）** 两套独立作用域；`active_for_shard` 按 static home 判（§1.2 D2/D3 / §2.2）。
> - **r2 P1-②**：INV-R13 目标对但机制不成立——5.15 `commit_member` 严格序末步即 open-gate，5.16 LMON tick 消费 JOIN_COMMITTED **结构上必晚于** open-gate，无法早于。**修**：fence-arm 做成 **5.15 `commit_member` open-gate 前的同步子步骤（D3b，5.15 Hardening amend，硬依赖，规则 21）**，绝不靠下一轮 LMON tick；不留给 D0 实测（规则 8.A）。新增 §8 Q11（同步 hook vs 显式子阶段）。
> - **r2 P2-③**：Q3 已翻"不碰 4.6"但 D1 正文 + §2.1 注释残留"failure 统一调用 / Used by BOTH"。**修**：正文/注释全改 join-only；统一仅 Q3-B 非默认。
>
> **r1 review（user，2026-06-27）抓 3 P1 + 2 P2，全部成立，v0.2 已收敛**：
> - **P1-A**：`join_remaster_enabled=off` 不能简单忽略 JOIN_COMMITTED——PCM 静态路由 snap-back 是 forced correctness（`cluster_gcs_block.c:662-664` 非-DEAD static master 早返回 NORMAL；`cluster_gcs.c:323` reroute 仅 DEAD）。**修**：PCM fence 脱钩本 spec GUC，绑 5.15 `online_join`；`join_remaster_enabled` 仅 gate 可选 GRD rebalance（§1.2 D6 / §2.4 / Q1）。
> - **P1-B**：Q2 "epoch 1:1 足够" 措辞过满。真问题是 **gate-open ordering window**（5.15 在 JOIN_COMMITTED 开 joiner 写 gate，而 remaster 下一 tick 才 P0 → joiner 把 home-block 路由到自己 cold-serve）。**修**：reframe Q2（JOIN_COMMITTED=episode 判据；正确性=epoch 跨-episode + freeze/RECOVERING fence + REDECLARE barrier）+ 新增 **INV-R13 gate-open ordering**（§3.3）+ per-shard/block **view-rebuilt serve 门**（今天代码无此标记，5.16 新增）。wire 维持不变，理由从"epoch 单独"换成"freeze 串行化"。
> - **P1-C**：D3 gate 伪代码不可达（早返回在 `recovery_in_progress` gate 之前）。**修**：join gate 前移到"非-DEAD static master ⇒ NORMAL"之前（§2.3）。
> - **P2-D**：GRD rebalance 与 PCM correctness 绑太紧。**修**：5.16 主轴 = **PCM snap-back correctness**；GRD recompute 降为同-episode **可选** rebalance（不作 Q1 硬依赖；Q3 默认翻成不碰 shipped 4.6）。
> - **P2-E**：bitmap ABI 裸 `uint64*` 不自洽。**修**：D1 改用既有 16-byte bitmap 类型/helper（§2.1）。
>
> 本 spec 是 **Stage 5 reconfiguration band 第 4 个功能点**，承接 spec-5.15（online declared-node join / rejoin — membership）。5.15 只把"已声明节点"安全发布成全集群承认的 `MEMBER`（heartbeat / quorum / epoch / incarnation），并严守 **INV-J6：join 不授予 joiner 任何 resource mastership**。本 spec 填补那条 seam 的另一半。**主轴（forced correctness）= PCM/GCS block snap-back 安全门**：block routing 是静态 declared-hash，joiner 一成为非-DEAD MEMBER，routing 自动 snap 回它，若不在它 block view 重建完成前 fence 住，会 cold-serve → split-master / double-grant（8.A）。**附带（可选）= GRD shard rebalance**：把 joiner home-shard 的逻辑锁 mastership 搬回它（不做仅负载不均，无正确性问题），复用同一 episode，受 GUC 控、为 Stage 6 DRM 提供 execution 原语。总目标：**节点成为 published MEMBER 后，其 home 资源在被它服务前 provably 重建，全程无 split-master / 无 double-grant / 无 false-serve**。
>
> 方向上本 spec 是 **spec-4.6（recovery-aware GRD/GES remaster）+ spec-4.7（GCS/PCM warm recovery）的 JOIN 镜像**：4.6/4.7 是 failure-driven（master 死 → survivor 接管），5.16 是 join-driven（survivor → 回家的 joiner）。4.6 §10 / 4.7 §10 都显式写明"node join 的 remaster 复用本 spec 原语 + ordering"。本 spec 的核心价值在于**最大化复用已 ship 的 remaster 原语（P0–P7 ordering、`cluster_grd_master_map_remaster`、REDECLARE barrier、episode-epoch-coherent barrier、re-declare/rebuild、RECOVERING gate）**，只新增 join 方向必需的：(a) JOIN_COMMITTED 触发、(b) membership-aware 确定性重算、(c) GCS/PCM block routing 的 snap-back 安全门。
>
> 配套 CLAUDE.md 规则：**规则 6 / 6.A**（5 阶段流程，approve 是编码硬门槛）+ **规则 8 / 8.A / 8.B**（实现完整性、MVCC/visibility/lock 正确性 fail-closed 不得 forward-link、建议必须推动真实功能闭环）+ **规则 21**（按设计文档编码）+ **规则 22**（spec 详细度，本 spec 对照 spec-1.2 模板）+ **规则 23**（实现状态以 linkdb 为准；本 spec 全部 linkdb 行锚在编码 D0 必须 re-grep）。
>
> 关联：
> - **AD**：AD-002（PCM 锁状态机 N/S/X + PI）、AD-005（Cache Fusion 全面）、AD-008（SCN / Lamport epoch）。
> - **feature**：feature-082（GRD/GES remaster 全 7 阶段 — 本 spec 落 join 子集）、feature-013（DRM 热点迁移 — 本 spec 提供其 execution 原语，policy 留 Stage 6）、feature-017（CF three-way）、feature-001（CSSD membership）。
> - **docs**：`docs/ges-lock-protocol-design.md`、`docs/pcm-lock-protocol-design.md`、`docs/cache-fusion-protocol-design.md`、`docs/development-roadmap.md`（Stage 5 行 5.16）、`docs/spec-drafting-lessons.md`（v2.10，L380–L389 reconfig band；frozen 前必读）。
> - **specs**：spec-4.6（GRD/GES remaster，**直接镜像源**）、spec-4.7（GCS/PCM warm recovery，**直接镜像源**）、spec-5.13（clean leave reconfig）、spec-5.14（fail-stop reconfig，shipped `v0.111.0-stage5.14`，`reconfig_kind` 枚举权威）、spec-5.15（online join membership，**直接前置**，handoff = published `MEMBER` + admitted_epoch）、spec-2.14（GRD routing substrate，`master_map` / declared-node-aware）。
>
> 决策日期：**2026-06-27（user approve「全 ★ + Q11=A'」，v1.0 frozen）**。**编码硬 gate = spec-5.15 shipped（5.15 编码硬 gate 又 = 5.13 shipped）+ 5.15 commit_member fence-arm amend + D0 re-ground**（见 §1.4 与 §7 DoD）。

---

## 1. 范围

### 1.1 包含（pgrac 仓改动）

- 本 spec 文件 `specs/spec-5.16-online-join-grd-pcm-remaster.md`（DRAFT → review → frozen）。
- **`specs/spec-5.15-...md` 追加 `## Hardening` 节**（r2 P1-②）：记录 5.16 在 `commit_member` open-gate 前插入的同步 `cluster_grd_arm_join_pcm_fence` 子步骤（D3b，规则 21 触碰 FROZEN spec 的合规留痕；body 不重写）。
- `docs/development-roadmap.md`：Stage 5 进度表行 5.16 从 "📋 计划" 更新为编码中 / shipped；补 5.16 与 4.6/4.7/5.15/Stage 6 DRM(6.6/6.7) 的依赖说明。
- `docs/spec-drafting-lessons.md`：frozen 前若产生新 lesson，同步 §3 checklist + §5 version history（规则 22.7）。
- `CHANGELOG.md`：ship 时记录 `v0.X.0-stage5.16` 与 linkdb tag 对应关系。
- feature-082 / feature-013：在"实施策略"章节标注 join-direction remaster execution 原语已落地（规则 10 三同步）。

### 1.2 包含（linkdb 仓改动）

> 所有行锚来自 2026-06-27 research（linkdb 本地 HEAD `f0115e367b`，5.9 era）+ frozen specs 5.13/5.14/5.15。编码 D0 必须对 **5.15-shipped main** 全量 re-grep（L371/L372；§1.4）。

#### Deliverable 1：membership-aware 确定性 master-map 重算（GRD 逻辑层 remaster 核心）

- **修改** `src/backend/cluster/cluster_grd.c`（~120 LOC）
  - 现状：`cluster_grd_master_map_remaster(const uint64 *dead_bitmap, uint64 reconfig_epoch)`（`cluster_grd.c:996`）只搬"当前 master 命中 dead bit"的 shard 到 survivor（`:1033-1034` 注释 "master alive — failure-driven only, no affinity"）；`cluster_grd_master_map_refresh` 是 ALIVE→ALIVE 显式 no-op placeholder（`:962-971` "Stage 6 DRM placeholder"）。
  - 新增 `cluster_grd_master_map_recompute_for_membership(const uint64 *active_member_bitmap, uint64 epoch)`：对每个 shard `i`，`home = declared[i % declared_count]`，`desired = is_member(home) ? home : deterministic_survivor(active, i)`；`master[i]` 与 `desired` 不同则原子写入并 `master_generation[i]++`（沿用 `:1038` 语义）。**join 时把 joiner 的 home-shard 从 survivor 搬回 joiner；failure 纯死亡场景结果与旧函数逐 shard 等价**（无 home 复活 → 同 survivor）。
  - 输入 `active_member_bitmap` 来自 **5.15 `cluster_membership_is_member()` 投影**（INV-J8 SSOT），不读 ad-hoc CSSD `peer_state`（INV-R3）。
  - **r2 P2-③：本函数仅 join 方向调用；shipped 4.6 `cluster_grd_master_map_remaster` 零触碰**（Q3=A 默认）。统一 failure/join 调用仅 §8 Q3-B 非默认选项（需补 4.6 全量回归证明才允许）。

#### Deliverable 2：JOIN_COMMITTED 触发 join-remaster episode（复用 P0–P7 FSM）

- **修改** `src/backend/cluster/cluster_grd.c`（~100 LOC）
  - `cluster_grd_recovery_lmon_tick(void)`（`:1577`）P0 accept 分支（`:1589-1640`）：现状仅消费 `cluster_reconfig_get_last_event(&evt)` 的 `dead_bitmap`。扩展为识别 `evt.reconfig_kind == RECONFIG_KIND_JOIN_COMMITTED`（spec-5.14 枚举 + 5.15 值 4），以 JOIN 方向驱动同一 P1（freeze 受影响 shard）→ P3（scoped stale）→ P4（membership-aware recompute，D1）→ P5（REDECLARE broadcast + episode-epoch lock）→ P6（REDECLARE_DONE cluster gate + post-barrier sweep）→ P7（unfreeze）。
  - **r2 P1-① 两套独立作用域（关键，勿混）**：
    - **`pcm_fenced_home_set`（forced，绑 online_join）** = 本轮 rejoining MEMBER 的 **static PCM home 集** = `{ tag : cluster_gcs_lookup_master_static(tag) ∈ rejoining_member_set }`。**纯由 joiner 身份 + 静态 declared-hash 推出，与 GRD master[] 是否移动无关**；`join_remaster_enabled=off` 时**仍非空、仍 fence**（这才闭合 P1-A）。
    - **`grd_moved_shards`（可选，绑 join_remaster_enabled）** = 本 episode `master[i]` 实际变化的 shard（GRD 逻辑锁 freeze/REDECLARE 用）；`off` 时为空（GRD 不搬，逻辑锁留 survivor，无 GRD freeze）。
  - freeze 范围 scoped（沿用 P3 scoped sweep precedent I47/I48）：GRD freeze 只动 `grd_moved_shards`；PCM fence 只动 `pcm_fenced_home_set`；**不冻结 home 一直在世的 shard / block**。
  - **本函数仅 join 方向调用**（Q3=A 平行新函数）；**failure 路径（4.6 P4）零触碰**；统一 failure/join 仅 §8 Q3-B 非默认选项。
  - episode 方向记录在 shmem（新 `pg_atomic_uint32 recovery_direction` 或复用 `reconfig_kind` 投影），供观测与 recompute 选择；不改变 barrier / FSM 结构。

#### Deliverable 3：GCS/PCM block routing snap-back 安全门（join 方向 RECOVERING gate）

- **修改** `src/backend/cluster/cluster_gcs_block.c` + `src/backend/cluster/cluster_gcs.c`（~150 LOC）
  - 现状：block master = 静态 declared-hash `cluster_gcs_lookup_master(tag)`（`cluster_gcs.c:267`）= `declared[h % declared_count]`，D7 仅在 `static_master == DEAD` 时 re-route 到 live survivor（`:300-301` + recovery-aware 分支）。**joiner 重新 ALIVE 的瞬间 D7 条件翻转 → routing 自动 snap-back 回 home(joiner)，而 joiner 此刻无 block 协议态 → cold entry → 误 grant（split-master）**。这是 4.7 gate 没覆盖的 JOIN 方向 hazard。
  - 在 `cluster_gcs_block_phase_for_tag(BufferTag tag)`（`cluster_gcs_block.c:630`）**前移**补 join 分支（r2 P1-C，置于 "非-DEAD static master ⇒ NORMAL" 早返回之前）：当 `cluster_grd_join_remaster_active_for_shard(tag) && !cluster_grd_block_view_rebuilt(tag)` → 返回 `GCS_BLOCK_RECOVERING`，请求路径 fail-closed `53R9L`（INV-R8）。view-rebuilt 门置位后才 `NORMAL` + routing snap 到 joiner。
  - **r2 P1-① 判定基准**：`active_for_shard(tag)` 按 **static PCM home**（`cluster_gcs_lookup_master_static(tag) ∈ rejoining_member_set`）判断，**不依赖 GRD moved set**——故 `join_remaster_enabled=off` 时 PCM fence 仍命中（绑 online_join，forced）。
  - 安全门是 **scan-completion（INV-R6/L241）而非 redo-LSN（4.7 D5）**——见 §1.4 与 INV-R9。

#### Deliverable 3b：同步 fence-arm（5.15 amend）+ **master-side hard gate**（r2 P1-② + r3 P1，Q11=A'）

- **修改** `src/backend/cluster/cluster_reconfig.c`（5.15 `commit_member` 路径，~30 LOC）
  - **必须**（非"首选不改 5.15"）：5.15 D4 Phase-2 `commit_member` 严格序末步是 `open gate`（`self_join_admitted`）；5.16 LMON tick 消费 JOIN_COMMITTED 在更晚 tick → **结构上不可能** arm fence 早于 open-gate。故 fence-arm 做成 `commit_member` 内**同步步骤**，插在 `open gate` **之前**：
    ```
    COMMITTED marker durable → publish epoch+state MEMBER+... → joiner adopt+observe MEMBER
      → [NEW 5.16: cluster_grd_arm_join_pcm_fence(rejoining_set)  // 置 fence_epoch + fenced_member_bitmap]
      → open gate (self_join_admitted)
    ```
  - 触碰 5.15 已 FROZEN → 走规则 21：append `spec-5.15 ## Hardening`（§1.1）。
- **修改** `src/backend/cluster/cluster_gcs_block.c`（master-side gate，~50 LOC，**r3 P1 + sr1-② 核心**）
  - 在 `cluster_gcs_handle_block_request_envelope`（`cluster_gcs_block.c:1937`）**进入 dedup / 状态变更之前**插 hard gate（master-side 权威，不依赖远端视图）。**sr1-② 关键**：现状该 handler **无任何 membership/quorum guard**（实证：`:1937+` 仅 validator-reject + dedup）；而 routing `cluster_gcs_lookup_master` 在 joiner **CSSD-ALIVE** 即 snap 回它（早于 `commit_member` 的 fence-arm）→ `[CSSD-ALIVE, MEMBER-committed]` 窗口内 survivor 路由过来会 cold-serve。故 gate 必须 **default-deny until (in-quorum MEMBER ∧ view rebuilt)**：
    ```c
    /* sr1-②: pre-MEMBER 窗口 + post-MEMBER-pre-rebuild 窗口都 fail-closed */
    if (!cluster_qvotec_in_quorum()
        || !cluster_membership_is_member(cluster_node_id)
        || (cluster_grd_join_remaster_active_for_shard(req->tag)
            && !cluster_grd_block_view_rebuilt(req->tag)))
        reply GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING;  /* sender → 53R9L retry */
    ```
  - **新增 reply status** `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（`cluster_gcs_block.h` 枚举**尾追加**）→ sender 侧映射 `53R9L`。**值 D0 分配下一尾值，不硬编码**：r4 实证现 enum 已到 `=13`（`READ_IMAGE_FROM_XHOLDER`，spec-5.2），下一值 **14**（`=9` 已被 `X_GRANTED_FROM_HOLDER` 占，r3 误读截断 enum 说 max 8）。**这是 GCS reply status 协议扩展**（forward-compatible 同版本集群；触发 L64 cross-ref sweep + StaticAssert 新值 == 旧 max+1 防撞）。
  - requester-side gate（D3 `phase_for_tag`）保留为**优化**（视图已更新的 requester 早拦）；master-side gate 是**正确性 backstop**（覆盖传播延迟窗口 + 远端 stale 视图，INV-R8/R13）。
  - **绝不靠下一轮 LMON tick arm fence**（INV-R13）；LMON tick（D2）只负责 rebuild / scan-completion / 置 `scan_done_epoch` / unfreeze。§8 Q11=A'（vs B 跨节点 ack barrier）。

#### Deliverable 4：joiner block view 重建（复用 4.7 D2/D3 re-declare/rebuild + join scan-completion gate）

- **修改** `src/backend/cluster/cluster_grd.c`（block re-declare scan）+ `src/backend/cluster/cluster_pcm_lock.c`（~120 LOC）
  - 复用 4.7 survivor block re-declare scan（`grd_block_redeclare_step` `cluster_grd.c:1533`、`grd_block_redeclare_scan_complete` `:1571`、`grd_block_redeclare_cb` `:1521`）：join episode 中，全 survivor 把本地 `BufferDesc.pcm_state ∈ {S,X}` 且 `pd_lsn` 有效的 block 向 **joiner（新 block master）** re-declare；joiner 重建最小视图（`master_state` / `x_holder_node` / `s_holders_bitmap` / `pi_watermark_lsn`）。
  - 跨节点矛盾（两 X / X+S）→ `return false` fail-closed（单-X 不变式，INV-R7 / L242），不静默 overwrite。
  - **join scan-completion gate**：block re-declare scan 完成（cursor==NBuffers）是 REDECLARE_DONE announce 的合取项（4.7 user-P0 fix 同款）；episode 未 IDLE ⟹ 该 home shard 所有 block RECOVERING（INV-R6/R8）。

#### Deliverable 5：可观测性（counters + dump + 复用 wait events）

- **修改** `src/include/cluster/cluster_grd.h` + `src/backend/cluster/cluster_grd.c`（~80 LOC）
  - `ClusterGrdRecoveryCounters`（`cluster_grd.h:542`）扩 join 方向计数：`join_remaster_started` / `join_remaster_done` / `join_shards_remastered` / `join_block_views_rebuilt` / `join_block_recovering_failclosed`（或复用 `remaster_started/done` + direction tag；§8 Q6）。
  - `dump_grd` 类别补 join 行；不新增 dump category（避免 L219/L221 baseline 涟漪扩面），在既有 grd recovery 段内追加 emit_row。
  - 复用既有 `WAIT_EVENT_RECONFIG_GRD_REBUILD` / `WAIT_EVENT_RECONFIG_MASTER_SELECTION`（`wait_event.h:379-383`，已为 Reconfig class 注册），block-rebuild 等待包裹 `pgstat_report_wait_start/end`（L62）。**不新增 wait event**（§8 Q7）。

#### Deliverable 6：GUC + runtime gate

- **修改** `src/backend/cluster/cluster_guc.c`（~40 LOC）
  - **r1 P1-A 决策**：`cluster.join_remaster_enabled` **只 gate 可选的 GRD 逻辑锁回迁**，**不 gate PCM block snap-back fence**——后者是 forced correctness（§1.4 例外 4），**只要 `cluster.online_join`（5.15）on 就强制激活**，不可独立关闭。
  - 新增 `cluster.join_remaster_enabled`（bool，`PGC_POSTMASTER`，默认 **off**）：off 时 P0 对 JOIN_COMMITTED **不做 GRD GES mastership 回迁**（joiner home-shard 逻辑锁留 survivor，仅负载不均），**但 PCM block view 重建 + RECOVERING fence 仍按 online_join 执行**（INV-R13）。
  - **startup 校验**：`online_join=on` 时 PCM fence 路径无条件编入；绝不留 "online_join on 但 block hazard 敞开" 配置；耦合不清则 fail-closed 拒启动（`ERRCODE_CONFIG_FILE_ERROR`，规则 8.A）。
  - 复用 `cluster.grd_rebuild_timeout_ms`（`:1511`，barrier 截止）+ `cluster.grd_remaster_wait_ms`（`:1503`，frozen-shard 短等 → 53R9I）。

#### Deliverable 7：cluster_unit 测试

- **新增** `src/test/cluster_unit/test_cluster_join_remaster.c`（~400 LOC）
  - 纯函数 + 状态机层断言（确定性、不依赖多节点 harness）：membership-aware recompute 等价性 / 幂等性 / scoped-freeze / single-X reject / default-deny / publish-before-signal 顺序 / disabled no-op。详见 §4.1。

#### Deliverable 8：cluster_tap e2e 测试（2-node + 3-node）

- **新增** `src/test/cluster_tap/t/310_join_remaster_grd_pcm.pl`（2-node，~250 LOC）
- **新增** `src/test/cluster_tap/t/311_join_remaster_no_double_grant.pl`（3-node，~250 LOC，**不双 grant 强制门**）
  - 测试号 t/310/t/311 为**建议值**；D0 必须 `ls src/test/cluster_tap/t/` + grep frozen specs 5.13/5.15 确认未占用，撞号则 renumber（L372）。
  - 复用 ClusterPair / ClusterTriple harness（`shared_data`）+ 4.6/4.7 orphan-process / SysV-shmem 清理纪律（L388）。

#### Deliverable 9：stubs / baseline 涟漪同步

- **修改** cluster_unit / cluster_tap baseline（~60 LOC）
  - L104 standalone-test-stub 补新增 accessor 桩；`dump_grd` 行数变化 → 同步所有断言该计数的 TAP（L39 三维 grep / L371 全量 sweep）；shmem region count 不变（不新增 region）；catversion 默认不 bump（无新 SRF/view/SQLSTATE/pg_proc；§8 Q5）。

### 1.3 不包含（拆 spec / 后续 stage / 永不做）

| 不做的事 | 不做的理由 |
|---|---|
| **runtime ADD NODE（动态扩容未声明节点）** | topology 是 postmaster-static（declared set 在 `pgrac.conf`）；5.16 只处理**已声明**节点的 rejoin remaster，新增节点 → Stage 6+（与 5.15 §1.3 一致）|
| **intra-epoch / hotness-driven affinity remaster（DRM policy）** | 5.16 是 failure-remaster 的 join 镜像，**1:1 绑 JOIN_COMMITTED epoch bump**（INV-R2，保 Q3-C wire 零改）；access-count 热点迁移 = feature-013 二期 = Stage 6 6.6/6.7，**消费 5.16 的 execution 原语**|
| **block 数据内容跨节点 redo 重建 / lost-write 检测** | 5.16 只重建 block **协议态**（re-declare 纯协商）；clean join 无 dead-origin redo（INV-R9，依赖 INV-J5 joiner 自身 crash recovery 已完成）；数据内容由 joiner 自身 Stage-4 startup redo 落共享存储 → 不需 4.7 D5 redo-LSN gate |
| **serve-on-survivor during rebuild（重建期不 fail-closed 仍服务）** | v1 重建窗口 fail-closed RECOVERING（53R9L，可 retry，bounded by timeout）；重建期把 joiner home-block 继续路由到 survivor 服务是 perf 优化 → Stage 6 forward（§10）|
| **>64 节点 GRD dead-sweep cap 修复（RC-7）** | `cluster_grd.c:4572` uint64/`peer_id<64` vs 128-bit `dead_bitmap[16]`；但本项目 declared 节点 ≤ 16（AD-012 例外 10 xid 空间分段限制）→ 64-cap 当前不可达，非 blocking；留 §10 forward（§8 Q8 确认 defer）|
| **leave 方向 GRD/PCM drain（clean leave / fail-stop）** | spec-5.13（cooperative drain）+ 5.14（fail-stop touched_peers）已 cover leave 方向；5.16 只做 join 方向 |
| **新增 reconfig_kind / event_type** | remaster 不是新 membership 事件，是 **JOIN_COMMITTED 之上的 resource 动作**（INV-J11 单一 discriminator）；不加第 6 个 reconfig_kind |

### 1.4 例外说明（偏离常规设计 / frozen ABI 的项 + 理由）

1. **不引入 wire routing-token / struct ABI 变更（保 4.6 Q3-C；r1 P1-B 修正论证基础）**：5.16 join-remaster 1:1 绑 JOIN_COMMITTED epoch bump。**跨-episode** staleness 由 epoch 现成处理（53R9J epoch-drop）。**同-epoch 内 old(survivor)/new(joiner) master 歧义不靠 epoch 区分**（二者同处 epoch E、且 old master alive）——靠 **FREEZE 串行化**（old master P1 freeze 让出 shard 即拒服务，REDECLARE barrier 收编在途 grant），与 4.6 "freeze + dead-master-can't-reply" 同构。故 wire 路由 token `(epoch<<32)|lms_restart_gen` + 所有消息 struct 一字节不改（INV-R2），**论证基础是 "freeze + barrier 串行化"，非 v0.1 误写的 "epoch 单独充分"**。intra-epoch affinity move（→ Stage 6 才需 wire per-shard generation）v1 不做。

   **r3 P1 例外（GCS reply status 扩展，非 struct 改）**：master-side gate 需新增 reply status `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（现有 reply 消息 status 字段内**尾追加新枚举值**，D0 分配下一尾值=14，forward-compatible 同版本集群）→ 53R9L。这放宽了"wire 零改"为"wire struct/routing-token 零改 + reply status +1 值"。若坚持 GCS 协议完全零触碰 → 须改选 §8 Q11=B（跨节点 ack barrier，requester-side only）。

2. **block 安全门用 scan-completion 而非 redo-LSN（与 4.7 D5 显式不同）**：4.7 failure 方向有 dead-origin → 需 `cluster_merged_instance_recovered_through(origin) >= required_lsn` 防 lost-write。5.16 clean join **无 dead-origin redo**（4.7 §10 "无 dead origin redo，纯协商"）：joiner 在 join 前已完成自身 crash recovery（INV-J5，5.15 只接 "已 ready" 节点，否则 53R6x REJECT_NOT_READY），其 dirty block 已由自身 startup redo 落共享存储。故 5.16 用 **block re-declare scan-completion（INV-R6/L241）作为 unfreeze 唯一前置**，替代 redo-LSN gate。**这是 join 方向与 failure 方向的根本安全门差异，必须在 review 中被独立审查**（§6 R1）。

3. **不触碰 4.6 shipped failure-remaster 函数（r1 P2-D，Q3 默认翻为平行新函数）**：D1 是**平行新函数** `recompute_for_membership`，shipped `cluster_grd_master_map_remaster` **零触碰**。GRD 回迁是可选附带项（§8 Q1=C），不为它冒 shipped 正确性险（规则 8.A）。统一改写留 Stage 6 DRM（§8 Q3=A）。

4. **GRD 与 PCM block 的"强制度"不对称（设计核心，决定主轴）**：GRD `master_map` 是**可变数组**——join 不重算则 joiner home-shard 逻辑锁继续在 survivor 工作（仅负载不均，**无正确性问题**）；GCS block routing 是**静态 declared-hash**——joiner 一非-DEAD MEMBER，`cluster_gcs_lookup_master` 停止 reroute、`phase_for_tag` 直接 NORMAL（`cluster_gcs_block.c:662-664`），若不加门则 cold-serve 误 grant（**有正确性问题，8.A**）。故 **PCM block snap-back fence = forced correctness 主轴（绑 online_join，不可关闭）；GRD rebalance = 可选附带（绑 join_remaster_enabled）**。r1 P1-A 即由此不对称触发：v0.1 误把二者对等绑同一 GUC。

5. **gate-open ordering 要求一个 5.15 amend（r1 P1-B 提出 / r2 P1-② 定死）**：joiner home 资源的 fence 必须先于 5.15 `self_join_admitted` 开。r2 实证：5.15 `commit_member` 严格序末步即 open-gate，JOIN_COMMITTED publish 在前，5.16 LMON tick 消费在更晚 tick → **异步 LMON arm fence 结构上不可能早于 open-gate**。故 **fence-arm 必须做成 5.15 `commit_member` 的同步子步骤（D3b，5.15 Hardening amend，规则 21）**——这不是"首选不改 5.15"，而是**本 spec 的硬依赖**。绝不把该 correctness 留给 D0 实测发现（规则 8.A 不得 forward-link）。

6. **D0 re-ground 强制**（band 通则 L371/L372 + 规则 23）：本 spec 所有 linkdb 行锚来自 5.9-era 本地树 + 5.14-shipped worktree（r1 验证用）+ frozen specs；编码 D0 第一步必须对 **5.15-shipped main** re-grep 全部：`reconfig_kind` 枚举最终 spelling（5.14 `RECONFIG_KIND_*` vs 5.15 `CLUSTER_RECONFIG_KIND_JOIN_*`，RC-9 未定）、`cluster_membership_is_member` 签名、`cluster_grd_recovery_lmon_tick` P0 行号、`master_generation[]` / `recovery_episode_epoch` / REDECLARE 行号、`cluster_gcs_block_phase_for_tag` 行号、53R9I/J/L/M 是否在 main、catversion、shmem region count、t/3NN 占用。

---

## 2. 接口设计

### 2.1 membership-aware 确定性重算（D1）

```c
/*
 * cluster_grd_master_map_recompute_for_membership
 *      Deterministically recompute the GRD shard->master map from an accepted
 *      membership snapshot. JOIN-DIRECTION ONLY (spec-5.16). The shipped
 *      failure-driven path (spec-4.6 cluster_grd_master_map_remaster) is NOT
 *      touched (r2 P2-③, Q3=A default). Unifying the two is the Q3-B
 *      non-default option and requires full 4.6 t/249/t/250/t/251 regression.
 *
 * active_member: set of node_ids whose cluster_membership_state == MEMBER in
 *      the accepted reconfig snapshot. Typed via the EXISTING 16-byte cluster
 *      node bitmap representation (P2-E: reuse the reconfig dead_bitmap shape,
 *      uint8[CLUSTER_RECONFIG_DEAD_BITMAP_BYTES]=uint8[16], or its
 *      ClusterNodeBitmap helper if one is introduced — NOT a raw uint64*; D0
 *      re-grep the canonical type/helper). MUST be projected from the 5.15
 *      membership SSOT (cluster_membership_is_member), NEVER from ad-hoc
 *      cluster_cssd_get_peer_state reads (INV-R3 / split-brain).
 * epoch: the accepted reconfig epoch this recompute is bound to (1:1, INV-R2).
 *
 * Per shard i: home = declared[i % declared_count];
 *      desired = is_member(home) ? home
 *                                : deterministic_survivor(active_member, i);
 *      if (master[i] != desired) { master[i] = desired; master_generation[i]++; }
 *
 * Returns the number of shards whose master actually moved (0 == no-op,
 * idempotent re-run). Total-membership-empty is a fail-closed precondition
 * checked by the caller (never reachable: self is always a member here).
 *
 * Q3 default (r1 P2-D): this is a PARALLEL new function; the shipped 4.6
 * cluster_grd_master_map_remaster(dead_bitmap, epoch) is NOT touched. Unifying
 * the two is a deferred option requiring full 4.6 t/249/t/250/t/251 regression
 * proof (§8 Q3 / §1.4 例外 3).
 */
extern uint32 cluster_grd_master_map_recompute_for_membership(
                  const uint8 *active_member /* [16] */, uint64 epoch);
```

### 2.2 join-remaster episode 方向标记（D2，shmem，无 wire）

```c
typedef enum ClusterGrdRemasterDirection
{
    GRD_REMASTER_DIR_NONE  = 0,   /* idle / never run */
    GRD_REMASTER_DIR_FAIL  = 1,   /* spec-4.6 failure-driven */
    GRD_REMASTER_DIR_JOIN  = 2    /* spec-5.16 join-driven */
} ClusterGrdRemasterDirection;

/* 追加到 ClusterGrdShared（cluster_grd.h:161），shmem-only，不上 wire。       */
/* r3 P2-① — fence 状态【membership-keyed + epoch】，对齐 PCM home 的 hash 域    */
/* (cluster_gcs.c:264 = hash%declared_count，节点域，【非】GRD 4096-shard 域)：   */
/*   uint8           join_pcm_fenced_member_bitmap[16]; // 本轮 rejoining MEMBER  */
/*   pg_atomic_uint64 join_pcm_fence_epoch;             // arm 时 = JOIN_COMMITTED */
/*   pg_atomic_uint32 recovery_direction;               // FAIL/JOIN，IDLE 复位     */
/* sr1-③：rebuild 完成【复用既有】recovery_done_epoch[node]（cluster_grd.c:1758, */
/*   grd_block_redeclare_scan_complete 写入），【不】新建 scan_done_epoch 平行字段 */
/*   (L216/L243 避免重复机制)。粗粒度但安全：scan 完成前该 member 全部 home-block */
/*   RECOVERING；完成后冷块 lazy rebuild。                                        */

extern bool cluster_grd_join_remaster_in_progress(void);

/* r1 P1-C / r2 P1-① / r3 P2-① — D3 + master-side gate 共用的两个谓词：         */
/* (a) active_for_tag = static_master(tag) ∈ join_pcm_fenced_member_bitmap        */
/*     (cluster_gcs_lookup_master_static;绑 online_join,不依赖 GRD moved set)。   */
extern bool cluster_grd_join_remaster_active_for_shard(BufferTag tag);
/* (b) sr1-③ view_rebuilt = recovery_done_epoch[static_master(tag)] >= fence_epoch */
/*     (复用既有 recovery_done_epoch[]，cluster-visible；远端 requester-side 与    */
/*     joiner master-side 共用判定)。                                            */
extern bool cluster_grd_block_view_rebuilt(BufferTag tag);

/* r2 P1-② — 由 5.15 commit_member 在 open-gate 前【同步】调用：置                */
/* join_pcm_fence_epoch = JOIN_COMMITTED epoch + fenced_member_bitmap。绝不靠 LMON。*/
extern void cluster_grd_arm_join_pcm_fence(const uint8 *rejoining_set /* [16] */);
```

### 2.3 block routing snap-back 门（D3）

```c
/*
 * cluster_gcs_block_phase_for_tag (扩展，cluster_gcs_block.c:630)
 *
 * r1 P1-C fix: 现状在 `static_master == self || peer_state != DEAD` 时早返回
 * GCS_BLOCK_NORMAL（:662-664），随后才是 cluster_grd_recovery_in_progress()
 * gate（:676）。join 时 joiner 是非-DEAD static master(home) → 在 :664 就 NORMAL
 * 走掉，任何放在 :676 之后的 join 分支【不可达】。故 join gate 必须【前移】到
 * "非-DEAD static master ⇒ NORMAL" 早返回【之前】：
 *
 *   static_master = cluster_gcs_lookup_master_static(tag);
 *
 *   // r1 P1-C: JOIN fence BEFORE the non-DEAD-static-master early NORMAL.
 *   if (cluster_pcm_is_active()
 *       && cluster_grd_join_remaster_active_for_shard(tag)   // home 正被 join-remaster
 *       && !cluster_grd_block_view_rebuilt(tag))             // view-rebuilt serve 门(新增)
 *       return GCS_BLOCK_RECOVERING;                         // 请求路径 53R9L fail-closed
 *
 *   if (static_master == cluster_node_id
 *       || cluster_cssd_get_peer_state(static_master) != CLUSTER_CSSD_PEER_DEAD)
 *       return GCS_BLOCK_NORMAL;                             // (现状早返回, 保留在 join 门之后)
 *   ... (4.7 D7 dead-master RECOVERING / materialized / redo gate 不变) ...
 *
 * `cluster_grd_block_view_rebuilt(tag)` 是【今天代码不存在】的 per-shard/block
 * view-rebuilt serve 门(5.16 新增, scan-completion 驱动, INV-R6/R8/R13)；
 * `recovery_in_progress()` 是 episode-global, 不足以表达 "这个 block 重建好了没"。
 * routing snap 到 joiner 也由同一 view-rebuilt 标记 gate(INV-R8), 非 CSSD ALIVE。
 */
```

### 2.4 GUC 表

| GUC | 类型 | 默认 | context | 备注 |
|---|---|---|---|---|
| `cluster.join_remaster_enabled` | bool | **off** | `PGC_POSTMASTER` | **仅 gate 可选 GRD 逻辑锁回迁**；off = joiner home-shard GES mastership 留 survivor（负载不均）。**PCM block fence 不受此 GUC 控**（绑 `cluster.online_join`，forced correctness，INV-R13）|
| `cluster.grd_rebuild_timeout_ms` | int | 5000 | `PGC_SIGHUP` | **复用**（4.6 D4）；REDECLARE barrier 截止；join 复用同截止 |
| `cluster.grd_remaster_wait_ms` | int | 200 | `PGC_SIGHUP` | **复用**（4.6 D4）；frozen-shard 短等 → 53R9I |

### 2.5 错误码（全部复用，不新增 SQLSTATE — §8 Q4）

| SQLSTATE | macro | 触发路径（join 复用语义）|
|---|---|---|
| `53R9I` | `ERRCODE_CLUSTER_GRD_SHARD_REMASTERING` | 请求落在 join-remaster FROZEN/REBUILDING shard 且短等超时；errhint 文本补 "node rejoin" |
| `53R9J` | `ERRCODE_CLUSTER_GRD_STALE_MASTER_GENERATION` | 请求携旧 routing_generation / 收到旧 master 回包 → drop + retry |
| `53R9L` | `ERRCODE_CLUSTER_GCS_BLOCK_RESOURCE_RECOVERING` | joiner home-block view 重建窗口 RECOVERING；**两条来源**：requester-side `phase_for_tag`（直接 ereport）+ **master-side reply `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（尾值 D0=14）→ sender 映射 53R9L**（r3 P1，INV-R8 双闸）|
| `53R60` | `ERRCODE_CLUSTER_RECONFIG_IN_PROGRESS` | reconfig epoch 推进期 writable backend（5.15/2.29 substrate，可 retry）|

> 不新增 SQLSTATE；新增的是 GCS **reply status** 枚举值（`cluster_gcs_block.h`，→ 既有 53R9L），见 §5 + §8 Q11=A'。

---

## 3. 行为契约

### 3.1 触发与默认语义

- **触发源**：`cluster_grd_recovery_lmon_tick` P0 accept 消费的 `ReconfigEvent.reconfig_kind == JOIN_COMMITTED`（5.15 Phase-2 publish 产出）。
- **PCM block fence（forced，绑 online_join）**：只要 `cluster.online_join` on，JOIN_COMMITTED 必触发 joiner home-block 的 view 重建 episode + RECOVERING fence；**与 `join_remaster_enabled` 无关**（P1-A）。这是本 spec 的正确性主轴。
- **GRD 逻辑锁回迁（可选，绑 join_remaster_enabled）**：`join_remaster_enabled = on` 时，同一 episode 额外做 membership-aware recompute（D1）把 joiner home-shard 的 GES mastership 标记移动 → freeze（scoped）→ REDECLARE barrier → unfreeze；off → 跳过 GRD 回迁（mastership 留 survivor，仅负载不均，无正确性影响）。
- **idempotent**：同一 membership snapshot 重入 = no-op（generation 不动；INV-R12）。无 home 复活 → 0 移动。

### 3.2 边界条件语义

| 场景 | 语义 |
|---|---|
| joiner 尚非 MEMBER（pending/JOINING）| recompute 不把任何 shard 给它（`is_member(home)=false` → survivor）；INV-R1 fail-closed，绝不 remaster 到非 MEMBER |
| **gate-open window（P1-B 核心）：joiner 已开写 gate（JOIN_COMMITTED）但 remaster episode 尚未 fence 其 home-block** | joiner 的 backend 把 home-block 路由到【自己】（`phase_for_tag` static_master==self 早返回 NORMAL）→ cold-serve while survivor 持 X = double-grant。**修：INV-R13——home-block 的 RECOVERING fence 必须在 5.15 开 joiner 写 gate 之前/同时就位**（block-view-rebuilt serve 门默认 closed），绝无 "MEMBER 可写但 home 资源未 fence" 的瞬间 |
| **pre-MEMBER window（sr1-② 核心）：joiner CSSD-ALIVE 但尚未 commit_member**（routing 已 snap，fence 尚未 arm） | survivor 路由 block 请求到 joiner，joiner envelope handler 无 membership guard → 可能 cold-serve。**修：INV-R14——master-side gate default-deny，未 `in_quorum && is_member(self)` 一律 `DENIED_RESOURCE_RECOVERING→53R9L`** |
| episode 进行中收到请求（moved shard）| FROZEN/REBUILDING → 短等 `grd_remaster_wait_ms` 后 `53R9I`（retry-safe）|
| episode 进行中 routing 携旧 generation | `53R9J` drop + retry 到新 master |
| joiner home-block view 未重建完 | `cluster_gcs_block_phase_for_tag` → RECOVERING → `53R9L`（retry-safe）|
| barrier 超时（`grd_rebuild_timeout_ms`）| shard 维持 FROZEN，re-broadcast；**绝不**半重建 unfreeze（fail-closed，4.6 `:1788-1789` 同款 WARNING + 53R9I）|
| 重建期跨节点矛盾（两 X / X+S）| `return false` fail-closed（单-X 不变式，INV-R7/L242），episode abort-to-idle，shard 维持 FROZEN |
| 重建期 epoch 再次 bump（第三节点抖动 / joiner 再死）| episode 锁 `recovery_episode_epoch`，`cur_epoch != episode_epoch` → `grd_recovery_abort_to_idle`（INV-R5/L235），shard 维持 FROZEN，下轮重消费 |
| joiner 在 episode 中途再次离开（DEAD edge）| FAIL_STOP 事件覆盖；join episode abort，failure-remaster 接管（4.6 路径），joiner home-shard 回 survivor |
| `cluster.join_remaster_enabled` off→on（postmaster 重启）| postmaster-static GUC，重启生效；仅影响**可选 GRD 回迁**；PCM fence 始终随 online_join（历史 join 不补做 GRD 回迁）|
| `online_join` on 但 `join_remaster_enabled` off | **合法配置**：PCM block fence 全程激活（forced correctness），仅不做 GRD 逻辑锁回迁；绝不暴露 P1-A hazard |
| pg_upgrade / 单机模式 | `cluster_enabled=off` → 全路径短路；GUC 无效；零影响 |

### 3.3 不变式（INV-R1 … INV-R14，全部 fail-closed）

- **INV-R1（membership-gated）**：只 remaster 到 published `MEMBER`（`cluster_membership_is_member`，INV-J8 SSOT）；非 MEMBER → 不给资源，fail-closed。
- **INV-R2（episode 判据 = epoch；同-epoch 串行靠 freeze，非 epoch 单独；wire 零改）**：JOIN_COMMITTED 的 epoch 是 episode 判据 + **跨 episode** staleness（现成 53R9J epoch-drop）。**同一 epoch 内 old(survivor)/new(joiner) master 的歧义由 FREEZE 串行化**——old master 一旦 P1 freeze 让出的 shard 即拒服务（53R9I），REDECLARE barrier 收编在途 grant。故 wire token 维持不变（保 4.6 Q3-C），**理由是 "freeze + barrier 串行化" 而非 "epoch 单独充分"**（r1 P1-B 纠正）。v1 无 intra-epoch affinity move（→ Stage 6 才需 wire per-shard generation）。
- **INV-R3（确定性 membership-aware 重算）**：所有 MEMBER 从同一 accepted membership snapshot 算出同一 map；不读 ad-hoc CSSD peer_state。
- **INV-R4（freeze-before-move）**：moved shard 先 FROZEN 再写 master；请求 fail-closed `53R9I` 直到 episode IDLE + unfreeze。
- **INV-R5（episode-epoch-coherent barrier）**：整 episode 锁 `recovery_episode_epoch`；mid-episode epoch 变 → abort-to-idle；防跨节点 double-grant（L235）。
- **INV-R6（scan-completion gate barrier & serve）**：GRD holder re-declare + PCM block re-declare scan 完成是 REDECLARE_DONE 前置；episode 非 IDLE → serve fail-closed（L241）。
- **INV-R7（单-X / 不 double-grant）**：joiner 重建视图拒跨节点矛盾（两 X / X+S）fail-closed；冲突者 requeue，绝不误 grant（L242）。
- **INV-R8（block snap-back gated，双闸，r3 P1）**：joiner home-block 在 view 重建完成前必须 fail-closed `53R9L`，由**两道闸**保证：① **requester-side**（`phase_for_tag` join 分支，前置于 "非-DEAD static master ⇒ NORMAL" 早返回，r1 P1-C）= 优化，拦视图已更新的 requester；② **master-side hard gate**（`cluster_gcs_handle_block_request_envelope` 进 dedup/grant 前，r3 P1）= **正确性 backstop**，回 `DENIED_RESOURCE_RECOVERING→53R9L`，覆盖远端 stale 视图 + 传播延迟窗口。判定门 = `active_for_shard(tag)（static home ∈ fenced_member）&& !view_rebuilt（scan_done_epoch < fence_epoch）`，绑 fence 而非 CSSD ALIVE。
- **INV-R9（无 dead-origin redo 依赖；依赖 INV-J5）**：clean join 的 block view 重建是纯协商（re-declare），不依赖跨节点 WAL merge；4.7 D5 redo-LSN gate 由 scan-completion gate 替代。joiner 未完成自身 crash recovery → 5.15 拒 join → 5.16 不运行。
- **INV-R10（result enum default-deny）**：lock state machine S4 后任何新 FAIL 结果 default-deny（L237），绝不 fall-through 到 grant。
- **INV-R11（publish-before-signal）**：coordinator 先 publish membership/master_map recompute 态，再 signal `PROCSIG_CLUSTER_GRD_REDECLARE`（L387）；survivor 读到一致的（joiner=MEMBER、新 epoch）态。
- **INV-R12（idempotent / balanced no-op）**：同 snapshot 重入 no-op；disabled（仅 GRD 回迁）或无 home 复活 → 零 GRD 移动；PCM fence 不受 disabled 影响。
- **INV-R13（gate-open ordering，r1 P1-B 提出 / r2 P1-② 定死机制）**：joiner home 资源的 RECOVERING fence（view-rebuilt serve 门 = closed）**必须由 5.15 `commit_member` 在 `open gate (self_join_admitted)` 之前【同步】 arm（D3b，`cluster_grd_arm_join_pcm_fence`）**，**绝不依赖下一轮 LMON tick**（异步消费 JOIN_COMMITTED 结构上必晚于 open-gate，r2 实证）。fence 的作用域 = `pcm_fenced_home_set`（static PCM home，绑 online_join，与 GRD moved set 无关，r2 P1-①）。view 重建后才同时（unfreeze + 置位 view-rebuilt 门 + routing snap）。**绝不存在 "joiner 已 MEMBER 可写、但 home 资源未 fence" 的瞬间**（8.A）。
- **INV-R14（pre-MEMBER serve guard，sr1-② 新增，关 CSSD-ALIVE 窗口）**：routing `cluster_gcs_lookup_master` 在 joiner **CSSD-ALIVE** 即 snap 回它（早于 `commit_member` fence-arm），而 block envelope handler **现状无 membership guard**（实证 `cluster_gcs_block.c:1937+`）→ `[CSSD-ALIVE, MEMBER-committed]` 窗口可 cold-serve。故 master-side gate **default-deny**：未 `cluster_qvotec_in_quorum() && cluster_membership_is_member(self)` 一律回 `DENIED_RESOURCE_RECOVERING`（53R9L）。membership guard 覆盖 pre-MEMBER 窗口，view-rebuilt 门覆盖 post-MEMBER-pre-rebuild 窗口。**注**：GRD 逻辑锁侧无此洞——GES master-side grant 已查 `cluster_grd_shard_phase() != NORMAL`（`cluster_ges.c:1059/1196`，4.6 既有）；唯 PCM block envelope handler 缺 guard（4.7 requester-side-only 在 failure 方向够用因死 master 全员可见，join 方向 alive master 不够，r3）。

### 3.4 错误传播路径

- 请求层（`lock.c` / `cluster_lock_acquire.c`）：FROZEN shard 短等超时 → `CLUSTER_LOCK_ACQUIRE_FAIL_SHARD_REMASTERING`（`cluster_lock_acquire.c:742,750`）→ 映射 `53R9I`（retry-safe，Class 53）。
- block 层（`cluster_gcs_block.c`）：RECOVERING → `ereport(ERROR, errcode(ERRCODE_CLUSTER_GCS_BLOCK_RESOURCE_RECOVERING))` = `53R9L`，errhint "node rejoin block recovery in progress; retry"。
- barrier 超时：`ereport(WARNING, errcode(ERRCODE_CLUSTER_GRD_SHARD_REMASTERING))`（LMON 侧，非 throw），shard 维持 FROZEN，下轮重试。
- 所有码 Class 53/53R = retry-safe，应用 retry 逻辑兼容（与 4.6/4.7 一致）。

### 3.5 兼容性保证

- **零行为变化基准是 `cluster.online_join = off`（5.15）**，不是本 spec GUC：online_join off → 无 join 事件 → 全路径不进入。**online_join on 时 PCM fence 必然激活**（forced，P1-A）；`join_remaster_enabled = off` 仅省去 GRD 逻辑锁回迁（counters GRD 段恒 0），不省 PCM fence。
- 不改 wire ABI（INV-R2，理由 = freeze 串行化）；不改 on-disk page/undo/WAL（无持久格式变更）；catversion 默认不 bump（§8 Q5）。
- 4.6/4.7 failure-driven 路径回归门：t/249 / t/250 / t/251 全绿（§4.4）。

---

## 4. 测试用例

### 4.1 cluster_unit（`test_cluster_join_remaster.c`，编译期 + 状态机断言）

| 编号 | 断言 |
|---|---|
| U1 | membership-aware recompute：joiner home-shard `is_member(home)` → desired==home；移动计数==joiner home-shard 数 |
| U2 | 等价性：纯 failure 场景（无 home 复活）recompute 结果逐 shard == 旧 `cluster_grd_master_map_remaster`（保 4.6 回归）|
| U3 | 幂等：同 active_member_bitmap 重入 → 0 移动，generation 不变（INV-R12）|
| U4 | scoped freeze：只 freeze master 实际变化的 shard；home 一直在世的 shard 不 FROZEN（INV-R4）|
| U5 | INV-R1：joiner 非 MEMBER（active bit=0）→ 不分配任何 shard 给它 |
| U6 | single-X reject：重建视图注入两 X / X+S → `return false` fail-closed（INV-R7/L242），三方向全覆盖 |
| U7 | default-deny：S4 后注入 `FAIL_SHARD_REMASTERING` → S7 cleanup 返回原错误，不进 S5 promote（INV-R10/L237）|
| U8 | episode-epoch coherence：mid-episode epoch bump → abort-to-idle，shard 维持 FROZEN（INV-R5/L235）|
| U9 | publish-before-signal：断言 master_map recompute publish 在 REDECLARE broadcast 之前（INV-R11/L387，顺序探针）|
| U10 | GRD-disabled 但 PCM fence 在：`join_remaster_enabled=off` + `online_join=on` → GRD 回迁 counters 恒 0，**但 PCM block fence/view-rebuilt 门仍激活**（INV-R13，P1-A 回归）|
| U11 | scan-completion gate：block re-declare scan 未完（cursor<NBuffers）→ REDECLARE_DONE 不 announce，phase=RECOVERING（INV-R6/L241）|
| U12 | StaticAssert：`ClusterGrdShared` 扩 `recovery_direction` 后 sizeof / 对齐不破坏既有 offset（L45）|
| U13 | **gate-open ordering（P1-B）**：构造 "joiner 写 gate 已开 + view-rebuilt 门未置位" → `phase_for_tag` 必返回 RECOVERING（不被 static_master==self 早返回绕过）；置位后才 NORMAL（INV-R13；纯状态机层，证 gate 前移正确）|
| U14 | **fence-arm 同步序（r2 P1-②）**：模拟 `commit_member` 调用序，断言 `cluster_grd_arm_join_pcm_fence` 置 `fence_epoch` **发生在** open-gate 之前；fence 作用域 = static PCM home 集（`join_remaster_enabled=off` 仍非空，r2 P1-①）|
| U15 | **master-side gate（r3 P1 核心）**：构造 envelope handler 入口，fence 期（`recovery_done_epoch[home] < fence_epoch`）对 fenced member 的 home-block 请求 → 返回 `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`，**不进 dedup/grant**；`recovery_done_epoch[home] >= fence_epoch` 后才正常 grant（证 master-side backstop，不依赖 requester 视图）|
| U16 | **pre-MEMBER serve guard（sr1-② 核心）**：构造 "self CSSD-ALIVE 但 `is_member(self)=false`（或 `!in_quorum`）" → envelope handler 对任意 home-block 请求一律 `DENIED_RESOURCE_RECOVERING`，不进 dedup/grant（证 INV-R14 关 CSSD-ALIVE 窗口；与 view-rebuilt 门正交）|

### 4.2 cluster_tap（每条 L 编号 + 目的）

**t/310（2-node，`shared_data`）**
- L1：D0 gap-pin — disabled 时 rejoin → joiner home-shard 留 survivor（measure-first，证 baseline）。
- L2：enable + node1 rejoin（先 fail-stop node1 → 再 5.15 rejoin）→ join-remaster 触发，`join_remaster_started/done` ++，`join_shards_remastered>0`。
- L3：ordering 日志断言 P0–P7（freeze → recompute → REDECLARE → barrier → post-sweep → unfreeze）。
- L4：moved shard 请求在窗口内得 `53R9I`（retry-safe），unfreeze 后成功。
- L5：joiner home-block 在重建窗口 `53R9L`；scan-completion 后 routing snap 到 joiner，访问成功。
- L6：stale generation 注入 → `53R9J` drop + retry。
- L7：barrier 超时注入（block REDECLARE skip）→ shard 维持 FROZEN + 53R9I，老 holder 不变（fail-closed）。

**t/311（3-node，`shared_data`，不双 grant 强制门 — ship blocker）**
- L8：node0 absent → node1/node2 survivor，node1 持某 home(node0)-shard 的 X，node2 等 X；node0 rejoin remaster：重建后 X 仅一 holder，node2 requeue（`waiters_requeued>0`），**绝不双 grant**（INV-R7，3-node 强制，等价 cluster_unit U6 不接受同节点替代为最终门）。
- L9：block single-X — node0 home-block 被 node1 持 X、node2 持 S；rejoin 重建拒第二 X（`return false`），单-X 收敛。
- L10：unaffected shard 不受扰 — node2 master 的 shard 在 node0 rejoin 后 holder 不被误删/误搬（scoped，I47/I48）。
- L11：**gate-open ordering e2e（P1-B/INV-R13，ship blocker）**：node1 持 node0 home-block 的 X；node0 rejoin，**在 view 重建完成前**让 node0 自己 backend 访问该 home-block → 必得 `53R9L`（fence 在写 gate 开之前就位），绝不 cold-serve 误 grant；重建完成后 node0 服务成功且仍单-X。
- L12：**master-side gate e2e（r3 P1，ship blocker，post-MEMBER fence 期）**：node0 rejoin view 重建期，让 **node2（远端 requester）** 访问 node0 home-block（模拟 node2 视图未更新）→ 请求路由到 node0，node0 master-side handler 必回 `DENIED_RESOURCE_RECOVERING→53R9L`，**绝不 cold grant**（证 backstop 覆盖远端 stale 视图，非仅 joiner-local）。
- L13：**pre-MEMBER serve guard e2e（sr1-②/INV-R14，ship blocker，CSSD-ALIVE 窗口）**：注入型——令 node0 处于 CSSD-ALIVE 但 `is_member(node0)=false`（join 未 commit；用 injection point 钳住或 SIGSTOP 5.15 commit），node2 远端请求路由到 node0 home-block → node0 master-side handler 必回 `DENIED_RESOURCE_RECOVERING→53R9L`，**不进 dedup/grant**（与 L12 区分：L12 是 post-MEMBER fence 期，L13 是 pre-MEMBER 窗口）。窗口时序难自然稳定 → 用 injection-type TAP（L44/L37 范式）。

### 4.3 cluster_regress / 030_acceptance 同步

- `cluster_smoke` / 030_acceptance：join_remaster disabled 默认 → 输出无变化（零回归）；如新增 GUC 出现在 `pg_settings`，同步 expected out（L236 5th-form：`expected/*.out` 两处）。

### 4.4 PG 219 + 4.6/4.7 回归

- PG 219：219/219（无 PG 核心行为变更）。
- **4.6/4.7 回归强制**：t/249（2-node remaster）/ t/250（3-node 不双 grant）/ t/251（GCS warm recovery）全绿——D1 若统一 recompute（Q3）必须证 failure 路径零回归。

---

## 5. 与现有代码的 contract

| 文件 | 改 / 不改 | 理由 |
|---|---|---|
| `cluster_grd.c` | **修改** | recompute_for_membership（D1）+ P0 JOIN_COMMITTED 分支（D2）+ join counters（D5）+ block re-declare scan join 复用（D4）|
| `cluster_grd.h` | **修改** | `recovery_direction` 字段 + recompute prototype + join counters（D1/D2/D5）|
| `cluster_gcs_block.c` | **修改** | `phase_for_tag` join 分支前移（D3）+ **master-side hard gate 在 envelope handler `:1937`（r3 P1，D3b）** + block view rebuild（D4）|
| `cluster_gcs_block.h` | **修改（GCS status 扩展，r3 P1）** | 新增 reply status `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（**尾追加，D0 分配下一尾值=14**；r4 实证现 enum 已到 13 `READ_IMAGE_FROM_XHOLDER`，`=9` 已占）→ 53R9L。forward-compatible；L64 sweep + StaticAssert no-collision |
| `cluster_gcs.c` | **修改** | routing snap-back 受 episode gate（D3）+ `phase_for_tag` 早返回前插 join fence（结构性，P1-C，`:662-664`）|
| `cluster_pcm_lock.c` | **修改** | block view rebuild single-X reject join 复用（D4）|
| `cluster_guc.c` | **修改** | `cluster.join_remaster_enabled`（D6）|
| `cluster_reconfig.c` | **修改（r3 P2-②，纠正 v0.3 自相矛盾）** | `commit_member` open-gate 前插同步 `cluster_grd_arm_join_pcm_fence`（D3b）|
| `cluster_reconfig.h` | **改否取决于声明位置** | 若 `cluster_grd_arm_join_pcm_fence` 声明放 `cluster_grd.h` 则本文件不改；仅消费 5.14/5.15 `reconfig_kind`/`ReconfigEvent`，无新字段（INV-J11）|
| `cluster_membership.c/.h`（5.15） | **不改，只读** | `cluster_membership_is_member` 作为 active 集 SSOT（INV-J8）|
| **5.15 `commit_member` / `self_join_admitted`（FROZEN）** | **必须 amend（D3b，规则 21）** | **INV-R13 / r2 P1-②**：异步 LMON arm fence 结构上必晚于 open-gate，故在 `commit_member` open-gate 前【同步】插 `cluster_grd_arm_join_pcm_fence(rejoining_set)`。append `spec-5.15 ## Hardening` 记录。这是硬依赖，非可选协调 |
| `postgres.c` / `lock.c` PG 核心 | **不改** | reconfig writable gate / 53R9I 映射 5.14/4.6 已落；5.16 不新增 PG 原文件改动（无 PGRAC MODIFICATIONS）|
| `errcodes.txt` | **不改** | 复用 53R9I/J/L/M + 53R60；新 reply status 映射现有 53R9L，不新增 SQLSTATE（§8 Q4）|
| `cluster_grd.c`（shipped 4.6 `master_map_remaster`）| **不改（Q3=A 平行新函数）** | r1 P2-D：GRD 回迁是可选附带，不为它触碰 shipped 4.6 failure 路径 |
| wire struct / on-disk / WAL ABI | **不改** | INV-R2（freeze 串行化，非 epoch 单独）；无持久格式 / 消息 struct 变更 |
| GCS reply **status 枚举** | **扩展（r3 P1，Q11=A'）** | +`DENIED_RESOURCE_RECOVERING`（尾值 D0=14），现有 reply 消息字段内新值，forward-compatible 同版本集群（非 struct ABI 改）|

兼容性表态：**不改 wire struct ABI / 不改 on-disk / 不 bump catversion（默认）/ 不触碰 shipped 4.6 remaster 函数（Q3=A）**。结构性改动三处（r3 修正）：① `phase_for_tag` 早返回前插 join fence（P1-C）；② 5.15 `commit_member` 同步 fence-arm（D3b，5.15 Hardening amend，硬依赖）；③ **master-side hard gate + GCS reply status `DENIED_RESOURCE_RECOVERING`（r3 P1，Q11=A'；放宽早前 "wire 零改" 为 "wire struct 零改 + reply status +1 值"）**。

---

## 6. 风险

| 风险 | 概率 | 缓解 |
|---|---|---|
| **R1 安全门差异审查不足**：join 用 scan-completion 替 4.7 redo-LSN gate，若 joiner crash recovery 未真完成（INV-J5 假设破）→ 旧版本 block 被当 current 服务（false-serve，8.A）| 中 | INV-R9 显式依赖 5.15 INV-J5（5.15 拒非 ready 节点）；§1.4 例外 2 标记必须独立 review；U11 + t/310 L5 scan-completion gate 实测；review 必须 opus-level 审 join vs failure 安全门（L339 同款）|
| **R2 block snap-back / gate-open race（本 spec 主轴 hazard，r1 P1-A/B/C + r2 P1-①/② + r3 P1 + sr1-②）**：① `phase_for_tag` 早返回绕过 gate（P1-C）；② joiner 写 gate 开在 fence 前 cold-serve（P1-B）；③ off 不建 fence（P1-A）；④ fence 作用域绑 GRD moved set（r2 P1-①）；⑤ LMON 异步 arm 晚于 open-gate（r2 P1-②）；⑥ master-side handler 不调 phase gate（r3 P1）；⑦ CSSD-ALIVE 早于 commit_member fence-arm（sr1-②）| **高** | ① fence 前移（§2.3/INV-R8）；② 同步 arm 在 commit_member（D3b/INV-R13）；③④ fence 绑 online_join + static PCM home（P1-①）；⑤ D3b 同步；⑥ **master-side hard gate + reply status**（r3/INV-R8）；⑦ **master-side default-deny until in_quorum&&is_member**（sr1-②/INV-R14）；U13/U14/U15/U16 + t/311 L8/L9/L11/L12/L13 ship blocker |
| **R3 触碰 4.6 shipped 函数引回归**（Q3 统一路径）：membership-aware recompute 改变 failure 行为 | 中 | U2 等价性单测 + t/249/250/251 全绿回归门；Q3 若选平行新函数则规避（零触碰）|
| **R4 publish-before-signal 漏序**：master_map recompute publish 落后 REDECLARE broadcast → survivor 读 stale 态误 rebind（L387 同款 false-visible）| 中 | INV-R11 + U9 顺序探针；仅真 2-node/3-node e2e（t/311）能稳定抓（单测掩盖，L387 教训）|
| **R5 episode mid-epoch bump 抖动**：第三节点心跳抖动 / joiner 再死 bump epoch → P6 sweep 误删合法 holder（cross-node double-grant，8.A）| 中 | INV-R5 复用 `recovery_episode_epoch` 锁（L235）；U8 + t/311 注入 mid-episode bump |
| **R6 fence 窗口拖累健康集群**：join 是自愿操作，PCM fence 的 fail-closed 窗口比 failure（不可避免）更刺眼；超时长 → 应用大面 53R9L | 中 | scoped fence（只 joiner home-shard/block，非全集群）；窗口 bounded by `grd_rebuild_timeout_ms`；serve-on-survivor-during-rebuild 留 Stage 6 forward（§8 Q9 / §10）；整个 join（online_join）默认 off opt-in |
| **R9 startup 配置歧义（P1-A 派生）**：`online_join=on` 但实现误把 PCM fence 也挂在 `join_remaster_enabled` 上 → 又回到 hazard | 中 | INV-R13 强制 PCM fence 绑 online_join；startup 校验耦合不清则 fail-closed 拒启动；U10 显式断言 GRD-off+PCM-on |
| **R7 baseline 涟漪漏改**：join counters → dump_grd 行数变 → TAP 计数断言 stale（fast-gate 红）| 中 | L39 三维 grep + L371 rebase 全量 sweep；不新增 dump category（控面）；D0 + ship 前各扫一次 |
| **R8 test 号 / oid / enum 撞号**：t/310/311 或 `recovery_direction` enum 值与并发 ship 的 5.13/5.15 撞 | 中 | D0 `ls t/` + grep main 树确认唯一（L372）；撞则 renumber |

---

## 7. DoD（Definition of Done）

- [x] spec-5.16 自检过规则 22.2 量化门（588 行 / 10 Deliverable / 7 不包含 / 9 风险 / 16 DoD / 11 Q&A / 10 实施）+ 4 轮 user review + 1 轮自审收敛 + **user approve + freeze 2026-06-27**。
- [x] Reviewed cross-spec lessons doc (docs/spec-drafting-lessons.md) and inherited applicable patterns to current spec.
- [x] §1.4 例外说明继承 reconfig/remaster band lessons：L380 / L381 / L235 / L236 / L237 / L240 / L241 / L242 / L243 / L387 / L388 / L376 / L91 / L371 / L372 / L39 / L46 / L5 / L257 / L389 + L64/L216/L243（已写入 §1.4 / §3.3 / §6）。
- [ ] D0 re-ground：对 5.15-shipped main 全量 re-grep §1.4 例外 6 清单（reconfig_kind spelling / membership API / cluster_grd 行号 / `phase_for_tag` 早返回结构 / 53R9* / catversion / region count / t/3NN 占用）。
- [ ] D1–D6 + **D3b（5.15 commit_member 同步 fence-arm，5.15 Hardening amend）** 实装；零行为变化基准 = `cluster.online_join` off；`online_join=on`+`join_remaster_enabled=off` 仍激活 PCM fence（作用域 = static PCM home，与 GRD moved set 无关）验证（r2 P1-①）。
- [ ] D7 cluster_unit U1–U16 全绿（含 U2 4.6 等价性 / U6 single-X / U7 default-deny / U11 scan-completion / U13 gate-open / U14 fence-arm 同步序 / **U15 master-side gate** / **U16 pre-MEMBER serve guard**）。
- [ ] L64 GCS 协议 cross-ref sweep：新增 reply status `DENIED_RESOURCE_RECOVERING` 在 .c/.h/.pl/manual/spec 一致；**值 = D0-grep 当前 enum 旧 max + 1（截至 research 14；不硬编码）+ `StaticAssertDecl(... == 旧max+1)` 防撞**（r4 P1：r3 误写 =9 已被占）；sender 映射 53R9L 有触发用例。
- [ ] spec-5.15 append `## Hardening` 记录 fence-arm 子步骤（规则 21 触碰 FROZEN spec 留痕）。
- [ ] D8 cluster_tap t/310（2-node L1–L7）+ t/311（3-node L8–L13）全绿；**L8/L9 不双 grant + L11 gate-open + L12 master-side gate（post-MEMBER）+ L13 pre-MEMBER guard（CSSD-ALIVE 窗口，injection-type）为 ship blocker**（不接受同节点替代为最终门）。
- [ ] INV-R13 gate-open ordering 与 5.15 Phase-2 写 gate 次序协调已落实（跨 spec，§5）；绝无 "MEMBER 可写但 home 未 fence" 瞬间。
- [ ] 4.6/4.7 回归门：t/249 / t/250 / t/251 全绿。
- [ ] PG 219：219/219；cluster_regress 全绿；catversion 默认不 bump（如 Q5 决定 bump 则三维 grep L46）。
- [ ] baseline 涟漪：dump_grd 行数 / shmem region count / GUC `pg_settings` expected out 同步（L39/L371）。
- [ ] 本地 4 surfaces（cluster_unit / cluster_regress / cluster_tap / PG219）+ 远端 fast-gate 全 5 job 绿（规则 20.A，引 run ID）。
- [ ] ship：nightly full CI 当前 commit 绿（引 run ID）；tag `v0.X.0-stage5.16`；CHANGELOG / roadmap / feature-082/013 三同步（规则 10）。
- [ ] post-impl code review（code-reviewer agent）——design review 0 P0 ≠ 免编码后 review（L389）。

## 8. Q&A（user approve 2026-06-27 — 全采纳 ★；Q11=A'）

### Q1（r1 P2-D 重构）：5.16 主轴定位 + scope？

- A：GRD-only（逻辑锁层），PCM block 留 5.16b。
- B：GRD + PCM 都做，**对等绑定**（v0.1 旧 C）。
- ★ **C**：**PCM snap-back correctness 为主轴（forced，绑 online_join）+ GRD rebalance 为同-episode 可选（绑 join_remaster_enabled，非硬依赖）**（**推荐**）。

**理由（推荐 C，r1 P2-D）**：§1.4 例外 4 不对称——PCM block 静态 router snap-back 是 **forced correctness**（不做则误 grant，8.A），GRD rebalance 仅负载不均（无正确性问题）。v0.1 旧 C 把两者对等绑定，导致 GUC-off "零变化" 与 forced 项冲突（P1-A）。**C 把 PCM correctness 立为不可关闭的主轴、GRD 降为可选**，既满足 forced correctness（规则 8.B 不留退化），又不让可选的 GRD 回迁绑死正确性面。A（PCM 留后续）会让 forced 项 forward-link（违规则 8.A）。

### Q2（r1 P1-B 重构）：JOIN_COMMITTED epoch 的角色？

- A：v0.1 旧措辞 "epoch 1:1 单独充分 → wire 零改"。
- ★ **B**：**JOIN_COMMITTED epoch = episode 判据 + 跨-episode staleness；同-epoch old/new master 串行由 FREEZE，不靠 epoch 单独；wire 仍零改但理由是 "freeze + barrier 串行化"**（**推荐**）。

**理由（推荐 B，r1 P1-B）**：A 措辞过满——join 里 old master（survivor）alive 且与 new master（joiner）同处 epoch E，epoch 无法区分二者；真正串行的是 **freeze**（old master P1 freeze 让出 shard 即拒服务，REDECLARE barrier 收编在途 grant），与 4.6 "freeze + dead-master-can't-reply" 同构。故 wire 维持不变（INV-R2）成立，但论证基础换成 freeze。**关键补充**：membership 写 gate（5.15）与 resource fence 的 ordering 是真问题 → INV-R13（gate-open ordering）。**不需要** wire per-shard generation（那是 Stage 6 intra-epoch affinity 才需）；需要的是 per-block view-rebuilt serve 门（shmem，非 wire）。

### Q3（r1 P2-D 翻默认）：membership-aware recompute——平行新函数 vs 统一改写 4.6？

- ★ **A**：**平行新函数**（join 专用 `recompute_for_membership`，shipped 4.6 `cluster_grd_master_map_remaster` 零触碰）（**推荐**）。
- B：统一（failure 与 join 共用，旧 dead-only 退役）——**仅在补 4.6 全量 t/249/250/251 回归 + 3-node no-double-grant 证明后才允许**。

**理由（推荐 A，r1 P2-D）**：GRD 回迁是**可选**附带项（Q1=C），为它去触碰 shipped frozen 4.6 failure-remaster 代码，风险/收益不成比例（规则 8.A 不为可选功能冒 shipped 正确性险）。A 零触碰、零回归面。B 的 Oracle "单一确定性函数" 优雅性可留 Stage 6 DRM 统一时再做（届时本就重构 remaster）。v0.1 旧默认 A=统一已翻为保守 A=平行。

### Q4：错误码——复用 53R9I/J/L/M，还是新增 join 专属码？

- ★ **A**：**复用**（errhint 文本补 "node rejoin"）（**推荐**）。
- B：新增 53R63（join-remaster in progress）。

**理由（推荐 A）**：join-remaster 的请求侧语义与 failure-remaster **完全相同**（shard/block 正在 remaster，retry）——53R9I（shard remastering）/ 53R9L（block recovering）语义精确覆盖，应用 retry 逻辑无需区分触发源。新增码徒增 SQLSTATE 面与测试面（每码须触发用例，规则 7）。errhint 文本区分触发源即可（用户可观测）。

### Q5：catversion 是否 bump？

- ★ **A**：**默认不 bump**（无新 SRF/view/SQLSTATE/pg_proc；GUC + counter + shmem 字段不需 catversion）（**推荐**）。
- B：bump（若 Q6 决定加 `pg_cluster_grd_recovery` SRF join 列 / 新 view）。

**理由（推荐 A）**：5.16 默认只加 GUC（不 bump）+ shmem counter（不 bump）+ dump_grd 行（不 bump）。仅当 Q6 选"扩 SRF 列"才需 bump（catversion + L46 三维 grep）。A 保持最小持久面，降 ship 风险。

### Q6：join 观测——新增 counter 字段，还是复用 remaster_started/done + direction tag？

- ★ **A**：**新增 join_* counter 字段**（join_remaster_started/done/shards/block_views_rebuilt/block_recovering_failclosed）（**推荐**）。
- B：复用 remaster_started/done，加 direction tag 列。

**理由（推荐 A）**：A 让 failure 与 join 计数独立可观测（运维区分两类 remaster 频率），dump_grd 段内追加行，不新增 category（控 L219/L221 涟漪）。B 省字段但混淆两类事件计数，违 L87 counter-must-match-doc-claim。

### Q7：wait event——复用现有，还是新增 join 专属？

- ★ **A**：**复用 `WAIT_EVENT_RECONFIG_GRD_REBUILD` / `MASTER_SELECTION`**（**推荐**）。
- B：新增 `WAIT_EVENT_RECONFIG_JOIN_REMASTER`。

**理由（推荐 A）**：两 wait event 已为 Reconfig class 注册且语义匹配（GRD rebuild / master selection 对 join 同义）；新增需 4-处对称更新（L62/F12）+ 触发用例，收益低。block-rebuild 等待包裹 `pgstat_report_wait_start/end` 复用 GRD_REBUILD。

### Q8：>64 节点 GRD dead-sweep cap（RC-7）是否本 spec 修？

- ★ **A**：**defer（留 §10 forward）**（**推荐**）。
- B：本 spec 一并修（uint64 → 128-bit）。

**理由（推荐 A）**：本项目 declared 节点 ≤ 16（AD-012 例外 10 xid 空间分段限制），64-cap 当前**不可达**（非 P0/P1，规则 8.A 不命中）。RC-7 user disposition 即 "scope handoff，non-blocking"。A 保持 5.16 聚焦 join-remaster 闭环。若 user 要求一并修，B 也只是 D1/D2 触碰路径上的小改（~30 LOC）。

### Q9：block 重建窗口——fail-closed RECOVERING，还是 serve-on-survivor？

- ★ **A**：**fail-closed RECOVERING（53R9L，retry，bounded）**（**推荐**）。
- B：重建期把 home-block 继续路由 survivor 服务（无 fail-closed 窗口）。

**理由（推荐 A）**：A 与 4.7 现成 RECOVERING 模式一致，provably safe，窗口 scoped + bounded。B 需 router 维护 per-shard "rejoined-but-not-rebuilt → route survivor" 态，循环依赖复杂，是 perf 优化 → Stage 6 forward（§10）。correctness-first（规则 8.A），perf 后置。

### Q10：测试号 t/310/t/311 是否最终值？

- ★ **A**：**建议值，D0 collision-check 后定**（**推荐**）。
- B：现在锁死 t/310/t/311。

**理由（推荐 A）**：t/300–t/307 已占用，5.13/5.15 并发 ship 可能抢 t/308/309；A 让 D0 `ls t/` + grep main 确认唯一（L372），撞则 renumber，避免 ship-storm 撞号（5.12/5.53 历史已现）。

### Q11（r2 P1-② 提出 / r3 P1 修正）：fence-arm 机制 — A'（master-side gate）vs B（跨节点 ack barrier）？

- ~~A（原）：纯 joiner-local 同步 hook，靠 `phase_for_tag` 拦远端~~ —— **r3 实证否决**：`phase_for_tag` **只在 requester-side**（`cluster_pcm_lock.c:1803/1808`）调用；master-side envelope handler `cluster_gcs_handle_block_request_envelope`（`cluster_gcs_block.c:1937`）从 range-guard→dedup→grant **不调 phase gate** → 远端 requester（视图未更新）路由到 joiner 后仍 cold grant。joiner-local fence 只护 joiner 自己的 backend。
- ★ **A'**：**joiner-local 同步 arm（D3b）+ master-side hard gate（envelope handler 内）+ 新 reply status**（**推荐**）。
- B：显式 `RESOURCE_FENCE_ARMED` 跨节点子阶段 + ack（open-gate 等所有 survivor arm 完 requester-side fence 才开）。

**理由（推荐 A'，r3 P1）**：A' 在 `cluster_gcs_handle_block_request_envelope` 进入 dedup/grant **之前**插判定（含 sr1-② 的 `!in_quorum||!is_member` default-deny）→ 回 **新 reply status `GCS_BLOCK_REPLY_DENIED_RESOURCE_RECOVERING`（尾值 D0=14，映射 53R9L）**，sender retry。这是**权威 fail-closed 点**：joiner 最清楚自己的 fence 状态，不受远端 stale 视图影响。requester-side gate（D3）降为优化（视图已更新的 requester 早拦，省一趟）。**代价 = GCS reply status +1 枚举值**（forward-compatible，同版本集群；触发 L64 protocol cross-ref sweep）——这**放宽了早前 "wire 零改" 表态**（见 §1.4 例外 1 修正）。B 不加 status 但引入跨节点 barrier + ack 失败处理（survivor 慢/死的边界），更复杂且仍需处理传播延迟窗口。**A' 比 B 简单且更鲁棒（master-side 是 backstop，与 requester 视图无关）**。**此 Q 决定 D3b/D4 形态 + 是否动 GCS status，请 user 裁决；若坚持 GCS wire/status 零触碰则只能选 B。**

## 9. 实施计划

| 步骤 | 仓 | 估时 | 状态 |
|---|---|---|---|
| S0：D0 re-ground（对 5.15-shipped main re-grep 全锚 + collision check）| linkdb | 0.5 day | 待 5.15 ship |
| S1：D1 membership-aware recompute + U1–U5/U12 单测（RED→GREEN）| linkdb | 1 day | — |
| S2：D2 JOIN_COMMITTED 触发 P0–P7（复用 FSM）+ U8/U9/U10 | linkdb | 1 day | — |
| S3：D3 block routing snap-back gate（前移）+ D3b 5.15 commit_member 同步 fence-arm（amend）+ U11/U13/U14 | linkdb + pgrac | 1.5 day | — |
| S4：D4 block view rebuild（4.7 复用）+ single-X reject U6/U7 | linkdb | 1 day | — |
| S5：D5 counters + dump + D6 GUC | linkdb | 0.5 day | — |
| S6：D8 t/310（2-node）e2e | linkdb | 1 day | — |
| S7：D8 t/311（3-node 不双 grant，ship blocker）e2e | linkdb | 1 day | — |
| S8：4.6/4.7 回归（t/249/250/251）+ baseline sweep（L371）| linkdb | 0.5 day | — |
| S9：fast-gate + nightly 双门 + tag + 三同步 + post-impl code review | both | 0.5 day | — |
| **总计** | | **~8 day** | roadmap 行 5.16 未给独立估时；与 4.6（~多日）+ 4.7 比，因重原语复用，8 day 持平偏紧 |

## 10. 后续 spec 关联

- **Stage 6 6.6 DRM remastering decision / 6.7 DRM remaster execution**：消费 5.16 的 join-direction remaster **execution 原语**（`recompute_for_membership` + episode FSM）；6.6/6.7 在其上加 **hotness/access-count affinity policy**（intra-epoch move → 届时才引入 4.6 Q3 deferred 的 wire per-shard generation）。5.16 的 INV-R2（epoch 1:1）是 Stage 6 打破点。
- **Stage 6 6.4a Smart Fusion / RDMA**：serve-on-survivor-during-rebuild（本 spec §8 Q9 B / R6 forward）+ async remote-redo 是 6.4a 性能优化版；5.16 是保守正确版。
- **spec-5.17 / 5.18（reconfig band 后续）**：复用 5.16 的 join-remaster episode 方向标记 + membership-aware recompute；若引入 multi-node 同时 join，5.16 的确定性重算需扩 batch（forward-link）。
- **feature-013 二期（DRM affinity）/ feature-082 二期（full 7-phase remaster）**：5.16 落 feature-082 的 join 子集 + feature-013 的 execution 原语；二期扩 access-count-driven。
- **>64 节点 cap（RC-7，§8 Q8 defer）**：节点数突破 16（AD-012 例外 10 放宽）时，`cluster_grd.c:4572` dead-sweep + 本 spec recompute 的 64-cap 需同步扩 128-bit。

---

## Hardening v1.1（2026-06-28，编码 D0 re-ground 发现 + user approve；§0-§10 body 不动，规则 22.6）

> 编码硬 gate S0（D0 re-ground，对 origin/main `2056233cb7` = 5.15 shipped + 5.55/5.57/5.58 实证）时，对 linkdb 逐行核 sr1-③ 的 `view_rebuilt` 谓词，发现 **frozen spec 一处 P0 正确性洞（规则 8.A：false-serve / double-grant）**。按规则 21 STOP + 升级 user，user approve 推荐修法（2026-06-28）。本 appendix 留痕；INV-R8/§2.2/U13/U15/L11/L12 的 `view_rebuilt` 语义按本节收紧。

### HF1（P0，sr1-③ view_rebuilt 谓词过弱）

**spec 原文（§2.2 / INV-R8 / sr1-③）**：
```
view_rebuilt(tag) = recovery_done_epoch[static_master(tag)] >= fence_epoch
```
对 joiner-home block，`static_master(tag)` = joiner，门 = `recovery_done_epoch[joiner] >= fence_epoch`。

**linkdb 实证为何不安全（worktree `linkdb-spec-5.16-join-remaster`）**：
- `recovery_done_epoch[X]` 仅两处写：节点 X 自己本地 barrier+scan 完成（`cluster_grd.c:1758`，WAIT_BARRIER→WAIT_CLUSTER）/ 收到 X 的 REDECLARE_DONE 广播（`cluster_grd.c:1458` `cluster_grd_recovery_mark_peer_done`）。两者都表示"**X 宣布它自己**的本地重声明做完"。
- joiner 刚 rejoin，自身 buffer pool 不持任何 home-shard 的 S/X（缺席期间由 survivor 持有）→ joiner 本地 redeclare scan 立即完成；`grd_recovery_barrier_complete`（`cluster_grd.c:1388`）只等**本地 backend** ack，不等 peer inbound 重声明 → joiner 的 `recovery_done_epoch[self]` 在 WAIT_BARRIER 末即置位，**早于** survivor 把持有的 joiner-home block 重声明给 joiner。
- joiner view 真正重建完成 = **所有 survivor** 都重声明给了 joiner = 所有 declared 节点 `recovery_done_epoch >= fence_epoch`（WAIT_CLUSTER 的 all_done，`cluster_grd.c:1853-1862`），**非** joiner 自己的 done_epoch。
- 后果：`view_rebuilt` 在 joiner 自己 barrier 完成时翻 true → master-side hard gate（INV-R14）+ requester-side gate（INV-R8）提前放行 → joiner 在 survivor 仍持 X 时 cold-serve home block → split-master / double-grant（正是本 spec 主轴要防的 8.A）。failure 路径无此洞（用 episode-global `recovery_in_progress()`，IDLE 又要求 all_done）；join 换成 per-(static_master) 才暴露。

**修法（spec-consistent，保 INV-R8/R13/R14 意图，仍复用 `recovery_done_epoch[]`、不建平行字段）**：
```
view_rebuilt(tag):
    fence_epoch = atomic_read(join_pcm_fence_epoch)
    if fence_epoch == 0: return true        // 无 fence
    for each declared node n (cluster_conf_lookup_node(n) != NULL):
        if recovery_done_epoch[n] < fence_epoch: return false
    return true                              // all_done == joiner episode 到 P7/IDLE
```
即把谓词从"只看 joiner 的 done_epoch"改成"**所有 declared member 的 done_epoch >= fence_epoch**"。joiner 只在收齐所有 survivor 的重声明后才解 fence。粒度仍粗（per fence-epoch 整体解，非 per-block），但安全（sr1-③ "复用既有 recovery_done_epoch[]、粗粒度但安全" 的正确实现）。

**受影响（语义朝更安全收紧，不改 wire / 不改 ABI / 不 bump catversion）**：
- §2.2 `cluster_grd_block_view_rebuilt(BufferTag)` 实现按上式（all declared member，非 static_master 单点）。
- INV-R8 / INV-R13 / INV-R14 的 `view_rebuilt` 判定基准同步。
- U13 / U15：断言 fence 解除发生在**所有** member done 之后（不是 joiner 单点 done）。
- ship-blocker L11（gate-open）/ L12（master-side post-MEMBER）：在 survivor 仍未 REDECLARE_DONE 时 joiner-home block 必 53R9L；所有 member done 后才 serve。
- `view_rebuilt` 用 `min over declared recovery_done_epoch >= fence_epoch`；`active_for_shard` 仍按 static PCM home ∈ fenced_member（不变）。

---

## Hardening v1.2（2026-06-28，D8 编码实测发现 + user approve；§0-§10 body 不动，规则 22.6）

> D8（cluster_tap t/325 2-node 绿 → t/326 3-node）实测暴露**两处 spec 的 P0–P7 reuse 假设与 5.15 substrate 不符**的问题。HF2（recipient 排除）我在 D8 直接修（朝更安全、与 HF1 同向）；HF3（3-node survivor 参与）是 frozen 5.15 跨节点传播缺口，按规则 6.A 硬门槛升级 user，**user approve「修法 A：扩 5.15 传播」（2026-06-28）**。

### HF2（barrier 必须排除 rejoining recipient + 用 member 集，承 HF1）

HF1 把 `view_rebuilt` 改成 all-declared-member barrier；D8 实测进一步发现：**rejoining 节点（joiner）是 re-declare 的接收方，不是 re-declarer**——fresh joiner 不持任何 home-block，且（见 HF3）根本不 observe 自己的 JOIN_COMMITTED 作为 reconfig episode，永不 announce REDECLARE_DONE。若 barrier 等它 → 永挂。**修**：
- `cluster_grd_block_view_rebuilt` 与 GRD FSM 的 WAIT_CLUSTER `all_done`（JOIN 方向）都**跳过 fenced（rejoining）集**（`join_fenced_member_test`），只要求 survivors（member 集中、非 fenced 的节点）`recovery_done_epoch >= fence_epoch`。
- `view_rebuilt` 的 barrier 集用 `cluster_membership_is_member`（dead/joining 节点不 re-declare，不计入），既闭合 joiner-redeath（joiner 掉出 member 集 → fence 解除 → failure 路径接管，§3.2），又不会被一个先前 dead 的节点永久 wedge。
- 安全性：绑定条件仍是"所有 survivor 重声明完成"；joiner master-side gate 是 authoritative backstop（INV-R8/R14）。

### HF3（3-node：survivor 必须 observe JOIN 并参与 re-declare barrier）

**实测**：t/325（2-node）绿，t/326（3-node）`join_remaster_done=0`、shards 永久 FROZEN。**根因（linkdb 实证）**：
- LEAVE：每个节点独立 publish 自己的 last_applied（coordinator publish coordinator-role；survivor publish **observer-role** FAIL_STOP，`cluster_reconfig.c:1310-1323`）→ 所有节点 GRD FSM 参与。
- JOIN：**只有 coordinator** drive + publish（`:1352-1353` `drive_joins`；`commit_member` coordinator-only）；survivor membership tick 对 rejoin 节点保持 DEAD（"no auto-readmit"，`:1246`），`MembershipTable` 是 per-node（`cluster_membership.c:43`）。
- ⇒ 3-node 中 survivor node1（持 node2-home grant）既不 observe JOIN、又不跑 GRD episode → 不 re-declare 给 node2、不 announce done → coordinator `all_done` 永等 node1 → FROZEN。2-node 能过仅因 coordinator 排除 joiner 后独立完成。

spec §2/D2 "复用 P0-P7 FSM（所有节点参与）" 隐含假设 survivor observe JOIN，但 5.15 只把 JOIN 传播给 coordinator（疑为 5.15 自身 3-node join 传播缺口，未测——t/315 仅 2-node）。

**修法 A（user approve 2026-06-28，symmetric to LEAVE observer，durable via voting disk）**：
- **qvotec**（唯一 disk reader）每 poll 额外 observe 每个 peer 的 region-3 **COMMITTED join marker**（majority + `cluster_join_marker_is_committed_basis` 校验），publish `observed_committed_join_incarnation/epoch[node]` 到 shmem（新 2 个 `ClusterReconfigState` atomic 数组）。
- **LMON membership tick**：DEAD peer + CSSD-alive + `online_join` + `observed_committed_join_incarnation > last_admitted` → set MEMBER + `record_admitted`（INV-J1 monotonic floor）+ 收集 `newly_joined`。
- 锁释放后 publish **observer-role JOIN_COMMITTED 事件**（join_bitmap=newly_joined；镜像 leave observer publish）→ survivor 的 GRD FSM 跑 JOIN episode（re-declare 自己持有的 joiner-home blocks 给 joiner + announce done）。
- 只在 survivor 触发（coordinator 上 peer 已 MEMBER，readmit 分支不命中）→ 无 double-publish。不改 wire / 不改 catversion。
- **触发 5.15 ## Hardening amend**（survivor observe 是 5.15 join 传播的对称补全）。

### HF2/HF3 受影响
- 新增 `ClusterReconfigState.observed_committed_join_incarnation[]` / `observed_committed_join_epoch[]`（shmem-only，per-node，atomic）+ accessor `record/get_observed_committed_join`。
- `cluster_grd.c`：`join_fenced_member_test` helper；`view_rebuilt` + WAIT_CLUSTER all_done 排除 fenced 集。
- `cluster_qvotec.c`：poll 增 peer COMMITTED-marker observe loop。
- `cluster_reconfig.c`：membership tick survivor-readmit + observer JOIN publish。
- 回归门：2-node 5.15 rejoin（t/315）+ 5.16（t/325）+ 3-node（t/326）+ 4.6/4.7 failure（t/249/250/251）全绿。

## Hardening v1.3（2026-06-29，编码实测发现 + fix；§0-§10 body 不动，规则 22.6）

> 编码实装 + D8 3-node t/326 反复跑时发现 **t/326 非确定性（~25% 失败，误报 `reply wait table full`）**。逐层 systematic-debug 实证根因 **不是** v1.2 的 survivor-observe-JOIN（HF3 已修、生产逻辑对），而是一个 **frozen spec-2.23 的 latent 正确性 bug（GES reply-wait 5-tuple key 非全局唯一）**，被本 spec 的 orphan-grant 处置（长命 tombstone）暴露。按规则 8.A（GES lock 正确性 fail-closed）+ 规则 21（触碰 frozen spec-2.23 留痕）记录。本节为编码实测留痕，§0-§10 设计 body 不动。

### CF1（根因：GES reply-wait 5-tuple key 非全局唯一 — spec-2.23 latent bug）

GES reply-wait HTAB key = 5-tuple `{request_id, source_node_id, dest_node_id, request_opcode, cluster_epoch}`（spec-2.23 §3.2 HC17）。但 `request_id` 由 **backend-local** 计数器生成（`cluster_lock_acquire.c` 的 `static pg_atomic_uint64 request_id_counter`）→ 每个新 backend 首个 acquire 都用 `request_id=1`。两个不同 backend 对**同一 master/epoch** 的请求生成**同一 key**（key 还不含 resource，故不同锁也撞）。spec-2.23 设计隐含假设「entry 短命（wake/timeout 立即删）使同-key 共存窗口极小」，故该碰撞长期被掩盖。

**暴露路径**：本 spec 为修 orphan-grant 把 REQUEST timeout 从 plain-delete 改为留 abandoned tombstone（30s TTL）→ entry 长命 → 下一个同-key backend insert 撞 `found==true` → 返回 NULL → caller 误报 `reply wait table full`（实为 duplicate-key，非 1024 满）。t/326 的 `poll_query_until`（每 ~210ms 起一个新 psql，全 `request_id=1`，全打 dead node2 的 K_home2）密集触发。

### CF2（修复：request_id 全局唯一 — spec-2.23 cross-spec hardening）

- `ClusterGesReplyWaitShared` 加 `pg_atomic_uint64 request_id_seq`（node-global 单调）+ 访问器 `cluster_ges_reply_wait_next_request_id()`（shmem-NULL 时退回 backend-local fallback，非 cluster 路径不建 entry 故够用、永不返 0）。
- `cluster_lock_acquire.c` 两处取号（`fill_request_holder` + redeclare 路径）改从该访问器取；删 backend-local `request_id_counter`。
- 结果：5-tuple key 真全局唯一，长命 tombstone 不再撞 key。**reply-wait region 仅加字段、不加 region** → t/020 region count/names baseline 不破。

### CF3（orphan-grant 处置三件套，承本 spec 的 #4，配 CF2 后才正确）

实验先证 **#4（orphan auto-release）必需**：neuter 回 plain-delete → t/326 0/7 过，主导失败 `G6 L9: node0 acquires K_home2 after sessA release → timeout`（orphan grant 留 phantom holder 挡 re-acquire，master-side P6 sweep 太慢）。故保留 #4 + 三件套：
- **Fix A**：abandon 时若 master 已 `CLUSTER_CSSD_PEER_DEAD` → plain delete（死 master 不再发 grant，在途 grant 由 fail-stop remaster 回收，不可能留 orphan）；SUSPECTED 不当 DEAD（可能恢复后迟发）→ 留 tombstone。
- **Fix B**：`cluster_ges_reply_wait_sweep_timeout` 接进 LMON tick（spec-2.23 骨架期定义却从未接 caller）；**仅扫 abandoned tombstone**（不碰仍在 `entry->cv` 上睡的 live waiter——否则 HASH_REMOVE 出睡眠 backend 的槽 + 槽复用 = use-after-reuse race，反成 8.A 隐患）。tombstone 的 backend 已返回，无人睡其 CV，回收 race-free。
- **Fix C**：insert 满时 evict 最老 abandoned tombstone（绝不 evict live waiter），让 live request 永不 fail-close；被 evict 的 tombstone 其 orphan 退回 master-side P6 sweep 兜底（tombstone 是优化、master P6 才是正确性 backstop）。

### CF4（编码副带：test_cluster_reconfig mock buffer rebase 遗留）

rebase 期 reconfig 状态结构因 5.15 H1.3 `observed_fresh_alive[]` + 本 spec HF3 `observed_committed_join_incarnation/epoch[]`（3 个 `pg_atomic_uint64[CLUSTER_MAX_NODES=128]`，+3 KiB）涨过 `test_cluster_reconfig.c` 的 `reconfig_shmem_storage[8192]` mock buffer → `make check` 时 init 越界 segfault。rebase session 只 `make`（build）没 `make check`（run）故漏。修：buffer 8192→16384。

### 验证 + 受影响
- **t/326 ×10 = 10/10 确定性绿**（从 ~25% flake）。全本地门绿：cluster_unit 134/134 binaries、cluster_regress 12/12、PG 219 219/219、foundation 001-030 407（t/020 region baseline 不破）、t/325 PASS。clang-format v18 全 0 diff。
- 改动文件：`cluster_ges_reply_wait.{c,h}`（request_id_seq + 访问器 + sweep abandoned-only + insert evict）、`cluster_ges.c`（ges_abandon_wait_or_release Fix A）、`cluster_lmon.c`（sweep 接线）、`cluster_lock_acquire.c`（取号改全局）、3 个 cluster_unit test（stub + buffer）。无 wire/catversion 变；shmem 仅 reply-wait region 内加 1 字段。
- **触发 spec-2.23 ## Hardening amend 留痕**（request_id 全局唯一是 reply-wait key 正确性的 cross-spec 必需条件；规则 21）。
- 教训（同步 docs/spec-drafting-lessons.md）：①「per-backend 计数器 + 字段判别 ≠ 全局唯一 key」——长命 entry 会暴露被短命掩盖的 key 碰撞；②「`make check`（run）才抓得到 mock-buffer 越界 segfault，build-only 漏」；③ 误判（先当 table-full 接 sweep/evict，ZZZRW 插桩证 evict-fail 从不触发）才定位到 caller 的 duplicate-key 路径——**插桩证伪比假设修复快**。

### CF5（post-fix adversarial code review：P0=0、P1=1、P2=1，全修）

opus-级 code-reviewer agent 对 topics 1-5（request_id 唯一性 / orphan tombstone / sweep / eviction / WAIT_EPOCH+IC）逐条对抗审计，全部判定正确（验证细节略）。抓到 2 个 finding，皆 correctness，编码后即修（design/前序审无关，规则 8.A/8.B 先修再 ship）：

- **P1（must-fix，cluster_ges.c）**：`ges_abandon_wait_or_release` 的 `send_opcode != REQUEST → delete` 早退把 **`REQUEST_NOWAIT`** 也直接删了。但 NOWAIT 也是 lock-acquiring（free 即 grant→建 master-side holder），若 master work queue 积压使 reply 迟于 requester 的 bounded wire round-trip→迟到 GRANT 落 NO_WAITER→drop→phantom holder（与 REQUEST 同构）。注释「只有 REQUEST 建 holder」对 NOWAIT 是错的。**修**：predicate 改为 `!= REQUEST && != REQUEST_NOWAIT` 才 delete；NOWAIT 同走 tombstone+auto-release。REDECLARE 仍 delete（幂等 rebind 不建新 holder）。
- **P2（窄 8.A，cluster_grd.c `cluster_grd_arm_join_pcm_fence`）**：`join_pcm_fenced_member` 被两个进程在 rejoining 节点并发 arm——qvotec（`note_self_admitted`，`{self}`）与 LMON tick（`{evt.join_bitmap}`，多-joiner episode）——原用 `pg_atomic_write_u64`（last-writer-wins）。多-节点同时 rejoin 时 `{self}` arm 可把 co-joiner 的 bit 清零→其 home block UNDER-fence→cold-serve→8.A double-grant（需 join_remaster_enabled=off，PCM fence 是唯一正确性机制）。**修**：改 `pg_atomic_fetch_or_u64`（并发 arm 取 union，无 under-fence）。跨-episode 残留 bit 仅 OVER-fence（该 block 等本 epoch 的 view_rebuilt barrier 后即解），是 benign liveness 非正确性，故不需 per-bit clear（reviewer 同意）。
- 复核：cluster_unit 134/134 重绿、clang-format 0 diff、t/326 重跑确定性绿。

## Hardening v1.4（2026-06-29，post-ship adversarial review r5：2 P1 全经 linkdb 实证成立 + 修；§0-§10 body 不动，规则 22.6）

> 外部 reviewer 对已编码的 5.16（worktree `spec-5.16-join-remaster` @ `31ceb493f4`）做新一轮对抗审，提 2 条 P1。逐条对照 linkdb 实证：**两条全成立**，且 RF1 实为 **P0/8.A**（false-visible / double-grant）。按规则 8.A（visibility / lock 正确性 fail-closed、不得 forward-link）+ 规则 8.B（修真功能、不降 scope）本节内闭环。**RF1 直接推翻 v1.3 CF5 P2 的「跨-episode 残留 bit benign、不需 clear」结论**——该结论只论证了 `active_for_shard`（over-fence）方向，漏了同一 bitmap 在 barrier-exclusion 的相反极性（under-wait）。

### RF1（P0/8.A：JOIN fence bitmap 跨 episode OR 累积 → barrier under-wait → double-grant）

**根因（linkdb 实证）**：`join_pcm_fenced_member` 自 v1.3 CF5 P2 起用 `pg_atomic_fetch_or_u64` 累积、**除 init 外永不清**（`cluster_grd.c:634-636` init / `:1261` OR）。同一 bitmap 被两个 barrier 用作「跳过 rejoining recipient」：
- per-block serve gate `cluster_grd_block_view_rebuilt`（`:1385` `join_fenced_member_test(i) → continue`，被 `cluster_gcs_block.c:679/2068` PCM serve/grant 消费）；
- GRD FSM WAIT_CLUSTER re-declare ACK barrier（`:2313` `is_join && join_fenced_member_test(i) → continue`）。

**场景（可达，8.A）**：node1 rejoin（episode-1）留 bit1 永久 set；之后 node2 rejoin（episode-2）OR 进 bit2、fence_epoch 抬到 node2 epoch。两个 barrier 因 bit1 仍 set 而**跳过 node1**——但 node1 此刻是正常 survivor，node2 缺席期可能持 X 于 static-home=node2 的块（该块缺席期被 failure-remaster 到别处）。barrier 只等 node3 → `view_rebuilt` 提前 true → node2-home 解 fence → node2 cold-serve 一个 node1 持 X 的块 → **double-grant / false-visible**。v1.3 CF5 P2 的 benign 论证只覆盖 over-fence 方向，未覆盖此 under-wait 方向。

**修（per-node armed-epoch keying，无 reset race）**：
- struct：`join_pcm_fenced_member[words]` 位图 → `join_pcm_fence_member_epoch[CLUSTER_MAX_NODES]`（per-node：该节点最后被 arm 为 recipient 的 fence epoch；0=从未）。
- arm：对 `rejoining_set` 每节点 `member_epoch[node] = max(prev, epoch)`（per-node monotonic-max CAS）。同 episode 两个并发 arm（qvotec `{self}` + LMON `{join_bitmap}`）写同一 epoch 到各自节点 → union 无 lost-update（**保留 v1.3 修 under-fence 的目的**）；上一 episode 残留节点保留更低 epoch < 当前 fence_epoch → recipient 判定自动排除（**无需 clear，根除 reset race**）。
- recipient 判定 `join_fence_is_recipient_for(node, ref_epoch) := member_epoch[node] == ref_epoch`：`view_rebuilt` 用 `fence_epoch`、WAIT_CLUSTER 用 `episode_epoch`；stale（< ref）→ false → 该 now-survivor 被正确等待。`active_for_shard` 同改为 `member_epoch[home] == fence_epoch`（顺带消除 v1.3 的 over-fence，更精确）。
- shmem 仅 GRD region 内字段变大（per-node uint64 数组，对齐既有 `recovery_done_epoch[CLUSTER_MAX_NODES]` 范式）；size 动态（`cluster_grd_shmem_size`）→ 无硬 byte baseline；无 wire / 无 catversion 变。
- 测试：cluster_unit `test_jr_u17_stale_recipient_not_excluded_next_episode`（RED 先实证 episode-2 barrier 误跳 node1 → GREEN：必须仍等 prior-rejoiner node1）。

### RF2（P1：qvotec peer-observe JOIN_COMMITTED 不按 commit identity 分组 → false-majority readmit）

**根因（linkdb 实证）**：三处 marker 多数派判定不对称——
- self-admit（`cluster_qvotec.c:966-977`）+ startup-seed（`cluster_reconfig.c:2414-2425`）：用 `cluster_join_marker_same_commit`（全 identity / nonce，HF-3 / INV-J13）求 same-commit majority；
- **peer-observe（`cluster_qvotec.c:909-919`）：只用 `is_committed_basis` + 取 max incarnation/epoch**——任何 committed-basis marker 即 `agree++`，不要求同一 commit，并把 max incarnation / max epoch 跨不同 attempt 拼合。

消费侧 survivor LMON readmit（`cluster_reconfig.c:1665-1687`）直接据 `observed_committed_join` 把 DEAD peer 翻 MEMBER + `record_admitted` + publish observer JOIN 事件，**无 same_commit 复核**。失败窗口（coordinator commit 中途 crash + 新 incarnation 重试，不同 nonce/epoch 落不同盘，单一 attempt 均未达多数）下，peer-observe 把不同 attempt 的 minority marker 聚成假多数 → survivor readmit 一个 join 从未 durable-commit 的 peer（甚至 joiner 自身因 HF-3 还没开 gate）→ membership 身份分叉 → 8.A。这正是 self / startup 侧 P1-3 / INV-J13 已防、peer 侧漏防。

**修（抽共享 selector，消除第三处 drift）**：
- 新 `cluster_join_marker_select_majority(markers, n, majority, *out_agree)`（`cluster_membership.c`）：在 committed-basis marker 数组里求 same-commit majority，返回胜出 marker 下标（+ 该 commit 的 agree 数），否则 -1。distinct-attempt minority → -1（永不聚成假多数）。
- 三处统一调用：peer-observe（收集 `committed[]` 后 select → 只记胜出 commit 的 incarnation/epoch）、self-admit（替换内联 O(n²) 环、删 `win_agree`）、startup-seed（保留 LOG 的 agree 数走 `out_agree`）。
- 不改 wire / 不改 catversion / shmem 不变。
- 测试：cluster_unit `test_marker_select_majority_groups_by_commit`（RED→GREEN：三 distinct-nonce → -1；same-commit 对 → 选中 + agree=2 + 空/NULL 防御）。

### 验证 + 受影响
- 改动文件：`cluster_grd.{c,h}`（per-node armed-epoch + recipient 判定 + 两 barrier + 注释）、`cluster_gcs_block.h`（注释同步）、`cluster_membership.{c,h}`（`select_majority` helper）、`cluster_qvotec.c`（peer-observe 修 + self-admit 复用 + 测试 stub）、`cluster_reconfig.c`（startup-seed 复用）、3 个 cluster_unit test。
- **本地 4-surface 全绿**：cluster_unit 129 binaries 0 fail（grd 74 / membership 18 / qvotec 14 / reconfig 45，含 2 新测）+ cluster_regress 12/12 + **多节点 e2e `t/325`（2-node join remaster）+ `t/326`（3-node no-double-grant）= 35 tests PASS**（finding RF1 的直接 e2e，本轮无 flake）+ PG219 219/219；full tree build+link 绿、clang-format v18 全 0 diff。
- **ship（SHIPPED `v0.120.1-stage5.16` @ linkdb `f2f40018ca`，2026-06-29）**：commit 父 = `31ceb493f4`（origin/main tip，clean fast-forward）→ push main → **fast-gate `28355855941` 5/5 绿** → tag `v0.120.1-stage5.16` → **nightly `28356216335`**（规则 20.A 双门）。
- 教训（已同步 `docs/spec-drafting-lessons.md` v2.27 = L427 + L428）：①「**同一份状态承担两种相反安全极性的角色**」是 8.A 温床——v1.3 CF5 P2 只论 over-fence benign、漏 barrier under-wait；per-state 的每个 reader 必须单独验极性，不能用一个方向的 benign 论证覆盖另一方向（L427）。②「**correct 模式抽单一 helper**」防 drift——RF2 正因 same-commit 校验在 self / startup 各写一遍、peer 漏跟而生（L428）。
- 触碰范围：本 spec 内闭环（无 frozen 跨-spec amend；RF1 / RF2 均 5.16 自身代码）。三同步：本 appendix + lessons v2.27 + CHANGELOG + roadmap。

---

## 附录（工作区本地增量，2026-08-17）：crash-rejoin self-join 例外与 HF2 的一致性

> 对应产品提交 `c4b2357723`。本附录只作跨 spec 绑定说明，不改本文任何正文；
> 只在本工作区生效，并入私有库由 user 裁决。

- 本文 Hardening v1.2 HF2 冻结的 actor 边界**继续成立**：joiner 仍是 re-declare 接收方，
  不 observe 自己的 JOIN_COMMITTED，永不 announce REDECLARE_DONE；
- `c4b2357723` 的六个 self-join 例外**没有**让 joiner 消费任何 JOIN_COMMITTED 事件——
  它们把六处门的证明源从"内存 applied event"切到"durable JCMK 准入"
  （`self_join_admitted`）。这是证据绑定变更，不是事件流变更；
- 与 HF2/HF3 的方向一致：survivor 侧 re-declare 与 coordinator 驱动 join 的原合同不变；
  例外只覆盖 crash-rejoin（online_join=off）路径，online join 路径仍走 §9 能力合同。
- 此前被 review 打回的"joiner 本地合成 JOIN_COMMITTED + OBSERVER_SURVIVOR"方案
  违反 HF2，已废弃；本文无需为其记录例外。
