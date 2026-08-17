# RF-ROOT P6-P9 实施计划与进度（~pgrac-dsh 工作区）

> 目标：在 sqlrush/pgrac-dsh 仓库完成 RF-ROOT P6-P9。
> SSOT 引用：~/pgrac/specs/ 下 RF-ROOT 主 spec、STOP-01~05、STOP-08、
> AD-019/AD-023；纪律 = CLAUDE.md（规则 6.A/21/8.A）+ AGENTS.md。
> 分支：rf-root-dev（base = d50c76b99cd，含 P6 checkpoint aa213230f9e）

## 已复现的 RED（本机证据）

- t243 运行：seed 单成员起+pg_basebackup ✓ → 严格双成员 ✓ → L1-L3 断言 ✓
  → L4 kill -9 重启 node1 → crash-rejoin：survivor 发布 fail-stop epoch 0→1、
  HW remaster done、但 join 停在 JOIN_PENDING，30s 后 53R61 → pg_ctl -w 超时
  （node1 之后 immediate shutdown 也卡）。
- 证据文件：src/test/cluster_tap/tmp_check/log/243_*_walthreads_node{0,1}.log

## 修复边界（Reader RETURN_MAINLINE，权威）

- 只在 t243 setup 调用既有 production ROOT producer 铸 node1(thread_2) canonical ROOT；
- 复用现有已验证格式与 authority；禁：ROOT bypass / 新持久格式 / 产品豁免 /
  新 authority / 改 workload-judge-顺序-timeout。
- 子代理 3ce728f2 正在产出精确配方（字段取值 + diff 草案）。

## 已确认的产品事实

- root 文件 = $shared_root/global/pgrac_control_root(.bak)，66048B =
  header + 128 个 per-thread slot（CLUSTER_CONTROL_ROOT_FILE_BYTES）。
- STRONG read 校验：GetSystemIdentifier()==root.sysid；current_storage_uuid()
  （cluster_shared_fs_get_storage_uuid，源自 CF contract record，在节点 pgdata）
  == root.storage_uuid；claim created_at/crc 与真实 claim 文件一致；CF ShareLock。
- authority_uuid 无运行时对照源（只查 UUID v4 形式 + token/duty 自洽）。
- 生产侧 create/activate authority 是故意拒绝（P5 关闭，R4 OPEN 批次才换
  一次性 coordinator proof）→ t243 只能 harness 铸造。
- fixture producer = src/test/cluster_unit/test_cluster_control_root.c
  fixture_root_main（--fixture-root …），内部走生产 create/activate API；
  当前硬编码 thread1/node0/合成值，需要扩展真实参数。

## P6 完成标准

- 未修改 workload/judge 的 t243 全绿（30 项断言左右）
- focused unit（control_root/startup_phase/wal_retention/ir 等）GREEN
- 完整 build + cluster_unit/cluster_regress 最小闭包
- immutable commit 到 rf-root-dev 并 push origin

## P7 合同（STOP-01 §17 + 批准字面量）

- W6 退休：删除两个 A1 writer（cold xlogrecovery、online orchestrator 的
  merge_recovered_lsn 写入）；forged 非零历史值对全部 correctness reader
  读作 0 且不得造 skip。
- correctness readers（f076 行号，需在当前树重定位）：
  xlogrecovery.c:2451-2467；cluster_hw_remaster.c:470-487；
  cluster_recovery_merge.c:941-965,1115-1127；cluster_recovery_plan.c:178-223；
  cluster_recovery_worker.c:181-195,233-254；orchestrator :541-573。
- 迁移目标：canonical control-root（cluster_control_root_read_canonical）
  + PAGE/SIDE proof；wal-state 仅作 telemetry。
- 静态 census：post-bit22 wal-state correctness reader/writer == 0。
- bit22 只在 PREPARED/ACTIVE 全成员 ACK 后打开。

## P8 合同（RF-ROOT §5）

- rebuild-first：recoverer crash 后下一 actor 从 canonical sources 重建
  （root/WAL/formation/fence），不接管前任 private progress。
- BGW_NEVER_RESTART 语义保持；新 episode 才可重启；STOP-ROOT-GENERATION/
  SERIAL 未关闭时同 episode replacement 保持 BLOCKED。

## P9 合同（RF-ROOT §7-9）

- §9.2 fault legs RL-01..RL-12（faithful TAP，禁止 mock 替代正式完成）
- §9.1 单元 RED matrix RU-01..RU-12
- §8.1 recovery-only observability（counter 语义 G2 分级）

## 环境

- 构建：~/pgrac-dsh，configure 参数与主仓一致（cassert+injection-points），
  prefix /tmp/pgrac-dsh-install；已 make + make install。
- 单测跑法：cd src/test/cluster_tap && make check PROVE_TESTS=t/xxx.pl
- OrbStack 测试机：pgracbench-dsh（clone 自 pgracbench，rocky9 arm64，stopped），
  内含 /opt/pgrac、/u01/pgrac、RACvsRAC harness，用于编码后的多节点验证。

## 进行中

- [x] 环境搭建 + RED 复现
- [x] cluster_unit 构建修复（12 个测试的链接缺口），已 commit 67bfcb1024
- [x] t243 铸造：fixture 双记录 cast 模式（--fixture-root-cast，node0 OPEN + node1
      RECOVERY_COMPLETE，自读真实 registry/claim，零改写）
- [x] 产品修复批次 1（d7e2ad4175）：phase4 publish 重试 + W2 CF 重试
- [x] 产品修复批次 2（65862eec27）：phase-state 三字段 pg_atomic 无锁读 +
      phase3 barrier 重试并重抓 formation + survivor 采纳 joiner committed epoch +
      checkpoint 在 recycle 前释放 CF(X) + write_durable_image close() 卫生
- [x] L4 crash-rejoin 收敛验证（run20：re-declare complete — boot fence lifted）
- [ ] 剩余 flake：铸后重启的 W2 强制 checkpoint 在 E1 deny 后挂 ~25s
      （checkpointer 的 GES release 等 LMS；LMS serving init 疑似被对端卡住）
      —— 子代理 260558d5 调查中
- [ ] t243 全绿 + 移除临时诊断 + P6 immutable GREEN + push
- [ ] P7 W6 退休 + 三 consumer 迁移 + census 0
- [ ] P8 rebuild-first 编排
- [ ] P9 fault legs + observability
- [ ] 全量回归 + 推送 pgrac-dsh

## 🔴 回正清单（2026-08-16 20:55 由 DSH 会话逐条取证核实，请直接采用）

> 来源：codex 对 t243 当前 RED 的评估，DSH 已对当前工作区代码 + spec 原文 +
> 20:49 轮日志逐条核实，全部实锤。以下都能在冻结 Spec 内修正，无需用户裁决。

**最新一轮（20:49）事实**：ok 17 后 RED。node1 已打出
"re-declare complete — boot fence lifted"（node1.log:1025），随后
phase3_recovery FATAL："live formation did not become ready before recovery"
（node1.log:1534）。即合成事件喂饱了 re-declare，但通不过 formation witness
——治标不治本，必须回主线：

1. **[P0] ✅ 已修（b378bb4a96）删除 joiner 合成 survivor 事件**
   - `cluster_reconfig_maybe_publish_joiner_admission_event()` 整个删除 + 调用点删除。
   - admission 只由 durable JCMK 回调（qvotec → note_self_admitted）驱动。

2. **[P0] ✅ 已修（b378bb4a96）incarnation/epoch 拼接**
   - `record_observed_slot`：incarnation→epoch→generation（generation 最后写作发布门）。
   - `record_observed_committed_join`：epoch→incarnation（incarnation 作门）。
   - 读取侧（get_observed_slot / get_observed_committed_join）：门字段前后复读，
     torn 即重试。
   - JOIN_COMMITTED new_epoch：exact gated target 值 + incarnation 复验，禁止 max。

3. **[P1] ✅ 已修（随 #1 删除）durable voting-disk I/O 移出锁**
   - helper 是锁内 I/O 唯一来源；删除后 EXCLUSIVE 段内只剩纯内存 invalidate。

4. **[P1] ✅ 已修（b378bb4a96）REDECLARE_DONE 回声 once 门**
   - `grd_recovery_done_echo_{epoch,hash}` process-local 门：每 {epoch,hash}
     每进程至多一次 echo，新 episode 重新武装。

5. **[工程] TEMP 诊断仍在（未清）**：bind early-return、rollover gate、
   cssd 收发计数、reconfig-lock probe/predicate 分解。GREEN 前统一移除。

**保持不动（已确认正确）**：CF→WALR 锁序修复（5f9b635401）、startup atomic
对齐 + A1 unit 24/24（6c45c75bcc）、E1 recycle→remove fallback（STOP-05 §15.5）、
fail-closed 纪律（无假绿）。

**注意**：本文件上方"剩余 flake"条目描述的 W2 checkpoint 挂 ~25s 已不是最新
失败点——20:49 轮的死亡点是 phase3 live formation 超时，回正顺序以本清单为准。

---

## 回正后追加发现（2026-08-16 21:20，DSH 逐条取证）

回正四项落地后 t243 前进到 ok 17（L4 survivor stream），死亡点移到
**L4 crash-restart 的 node1 卡 phase3**（pg_ctl start 61.9s 超时）。实锤链：

1. **自死锁族（回正清单外，已修）**：EXCLUSIVE mutation 段内
   `get_last_event_id()`（SHARED 重入）与 joiner helper（SHARED+EXCLUSIVE 重入）
   使 LMON 持锁自等 → waitlist=[LMON,QVOTEC] 全卡 → cssd 心跳停 → 互判 DEAD。
   证据：held_lwlocks 显示 LMON 自持 EXCLUSIVE + state=0x61000000。

2. **phase-gate clear（已修）**：phase4 窗口 recovery-allowlist 检查把
   "phase!=3" 误判为失效并 clear RECOVERY_READY → publish_serving 永久失败。

3. **剩余 L4 收敛缺口（未修）**：L4 的 immediate stop→restart 间隙 0.1-4s；
   node0 的 cssd DEAD 窗口（3s）与 node1 重启后心跳恢复竞争。run42 证据：
   - node0 cssd 判 node1 DEAD（21:13:40.0）→ 300ms 后 recovered ALIVE；
   - node0 的 LMON 未发布 fail-stop（DEAD 窗口未被 tick 捕获或已恢复）；
   - node1 侧 "self un-fenced"（durable JCMK admitted epoch 3 存在）但
     barrier_wait 的 `cluster_membership_is_member(self)` 不满足 → 卡。
   - node1 的 bind/barrier 循环每轮 ~25ms（barrier 失败分支），fail-closed。

   下一步：核实 node0 在 DEAD 窗口为何未发布 fail-stop（lmon_tick 的 dead
   set 构建与 cssd ALIVE 恢复的竞态），以及 node1 的 self MEMBER 采纳链
   （note_self_admitted → publish_self_current_floor_locked 的 gate：
   online_join=off 时 self_floor_authority && boot_decided）。

## 🔴 回正清单（第二轮，2026-08-16 22:45，DSH 会话核实后转发）

> 针对 22:38/22:45 两轮 not ok 3（fixture: "cannot load real thread-1 source"）的
> 评估。codex 评估 5 条 DSH 已逐条对代码/日志取证，全部成立，直接采纳；另补半环见第 5 条。

1. **判失败实验，不提交**：未提交的 `if (ShutdownRequestPending) return;`
   （cluster_reconfig_lmon_tick 入口，reconfig.c:5399+）。22:45 轮已含此代码
   仍 not ok 3，无效。

2. **接现有停机生产者，勿造新协议**：`cluster_lmon_request_shutdown()`
   （cluster_lmon.c:616，写共享 shutdown_requested，Assert(!IsUnderPostmaster)）
   目前**零调用者**；主循环 :1246 已在消费。应在 postmaster 接受停机后的安全
   主循环位置尽早置位 + 唤醒 LMON，禁止其再发布新 JOIN/FAIL_STOP。

3. **不放松 CF authority、fixture 不降级**：fixture
   test_cluster_control_root.c:837 坚持真实 STOPPED 是对的；任何用
   ShutdownRequestPending 放宽 CF 或接受 ACTIVE 槽的改法都是 false-green。

4. **最小接线后直接重跑原样 t243**；过 ok 3 只是恢复 P6 测试入口（回到
   ~ok 17 的 phase3/rejoin 战场），不代表 P6 闭环。

5. **DSH 补充半环（必查）**：22:45 轮 reconfig 已被 early-return 切断
   （node0 第一次停机 checkpoint 完整完成、running->shutdown 干净），但
   22:45:12 仍 FATAL "could not acquire the cluster control-file lock"，
   TEMP diag：shutdown_pending=1 / ges_available=1 / lms_ready=1 / eor=0
   ——前提全正常 CF(X) 仍拿不到 ⇒ "reconfig→GRD→CF" 单链不完整，停机窗口
   存在**第二个 CF 持锁者**。重点查 W2 stats 的 STOPPED 发布（WIP 已有
   TEMP publish_stopped 诊断）与 LMS serving-init CF(S) 的竞争。

6. **纪律**：TEMP 诊断（lmon/cssd drain/wal_state/CF diag 等）最终提交前全部删除。

---

## L4 crash-rejoin 根因与修复（run68–73 证据，用户已批准方案）

**根因（已定位）**：node1 crash-rejoin 后 phase3 卡在
`cluster_phase3_wait_for_live_formation` 直到 pg_ctl 60s 超时 bail。
卡点 = `formation_witness_decide_live_v1` 的 settled-epoch 门：

    f2->local_epoch != f2->applied.new_epoch → UNSTABLE

- joiner 侧 last_applied 恒为空（AD-023 §9.2.3：IC 不载 ReconfigEvent、
  JCMK 无 event_id，JOIN_COMMITTED 不能镜像到 joiner）；
  run73 实测 applied_kind=0 / applied_new_epoch=0 / applied_event_id=0。
- note_self_admitted 采纳 JCMK epoch 3（local=3）⇒ 3 != 0 恒成立。
- 只有无关 reconfig（node1 自发的 fail-stop 3→4，bailout 后噪音）落地后
  witness 才 READY —— 结构性永不收敛，phase3 只能等 600s FATAL。

**修复（已合入，待 t243 验证）**：
1. `cluster_recovery_duty.c` `formation_witness_decide_live_v1`：
   epoch 门增加 self-join 例外
   `&& !(self_join_admitted && local_epoch > applied.new_epoch)`
   （JCMK = quorum-majority durable + publish-proven 的 settle 证明）。
2. `cluster_reconfig.c` `cluster_reconfig_note_self_admitted`：
   LWLock 内补 `cluster_membership_record_admitted(self,
   cluster_qvotec_get_self_incarnation())` —— 发布 admitted incarnation
   floor（witness owner 门 `last_admitted_incarnation==0` 的接棒卡点）。

**后续接棒风险（已推演，靠本次运行验证）**：phase3 通过后 authority
barrier：node1 请求 hash=H(空 applied.dead_bitmap)=H(0)；
node0 JOIN episode(epoch 3) 广播 hash=H(join_remaining_dead)=H(0) ——
key 一致 + 已有 done-key echo 机制兜底，预期收敛。

---

## L4 witness 修复进展（run74–83）

**已修复+日志闭环**：
1. `formation_witness_decide_live_v1` epoch 门：self_join 例外
   (`self_join_admitted && local > applied`) —— joiner 的 applied 恒空
   (AD-023 §9.2.3)。
2. 同函数 marker tuple 门：joiner 无法得知 JOIN_COMMITTED event_id，
   tuple 恒不等 —— self-join 例外豁免 identity 比较（majority+valid 仍查）。
3. `cluster_reconfig_note_self_admitted`：补 `record_admitted(self,
   qvotec_self_incarnation)`（witness owner floor）。
4. note_self_admitted 每 poll 无条件 invalidate fence cache → witness
   revalidate 饿死 —— 改为仅实际变更时 invalidate。
5. `cluster_grd_recovery_authority_barrier_wait` epoch 门：同 1 的例外
   （run82 实测 local=3 vs applied=0 卡死）。

**效果**：run83 首次跑过 cast leg 直到 ok 10（此前稳定 bail 在 pg_ctl
start 63s）；phase3 formation_ready 在 join 后 2ms 达成；authority
barrier terminal SUCCESS。

**剩余问题（下一轮）**：
A. run83 L1 DML 阶段 node1 的 cssd broadcast 在首个 tick 后冻结
   (iters=1/send_total=0 后无输出) → node0 cssd deadband 判死 → fail-stop
   0→1 → DML abort。查 cssd main loop 的 advance_liveness_tick 是否阻塞。
B. node 重启后 node0 收不到 node1 的 cssd 帧（run81/83）：node1 的
   LMS data-plane listener 在 phase4 serving 前不 bind → node0 的 tier1
   连 data 端口 ECONNREFUSED(errno=61) → node0 保持 node1 DEAD → DONE
   广播/echo 跳过 → join view 不重建（循环依赖链）。
C. cast-leg 变体 flake：`cannot establish bootstrap shared control-file
   authority on a multi-node cluster`（run65/72/77/80/82）——对端 phase2
   CF rendezvous 窗口内不可达时的分类竞态。

---

## L4 crash-rejoin 死锁闭环修复（run84–94，已提交 c4b2357723）

**闭环（六边形依赖，run84–88 逐步证实）**：
```
boot_decided=0 → tick 把 self 置 JOINING
 → phase3 authority barrier 的 request-current 检查 is_member(self) 失败
 → GRD authority seal 永不 stamp
 → recovery_transport_is_current()=false
 → GES early-opcode gate 丢弃 REDECLARE_DONE 入站
 → done0 停在 2 → join_view_rebuilt()=false → boot_decided 继续 0
```

**修复（全部基于"durable admission = membership 证明"同一原则）**：
1. `formation_witness_decide_live_v1`：epoch 门 + marker tuple 门加
   self-join 例外（joiner 的 applied 恒空，AD-023 §9.2.3）；
2. `note_self_admitted`：补 record_admitted(self, boot incarnation)；
   fence-cache invalidate 改为仅实际变更时；
3. `cluster_grd_recovery_authority_barrier_wait` epoch 门同款例外；
4. `ges_readiness_allows_early_opcode`：REDECLARE_DONE 用
   `cluster_recovery_transport_components_current()`（无 seal、admission
   aware membership、无 formation revalidate、无 phase 门）；
5. tick self-state 门：`offpath_fast_rejoin_active_local` 时已 admitted
   的 self 保持 MEMBER（块级 boot fence 继续承担 fail-closed）；
6. `grd_recovery_authority_request_current`：self 的 membership 检查
   admission-aware。

**结果**：t243 的 L4 crash-rejoin 腿（ok 18-19）连续两次通过；
unit 回归 24/24 + 91/91 + 94/94 全绿。run93/94 均止步于 **L5-recovery
腿**（foreign-claim 拒绝后的第二次 rejoin，新 incarnation 需要 node0
的 fast-rejoin rollover 再跑一轮 join chain，60s 内未发生——下一轮主攻）。

**遗留**：L5-recovery 二段 rejoin；cast-leg bootstrap CF FATAL 变体
flake；全部 TEMP 诊断最终删除；shm 段清理（每轮 ipcrm）。

---

## L5 二段 rejoin：方案 D 实施进展（run99–110，提交 f87d539440）

**根因**（run99 revet 分解铁证）：L4 rejoin CAS 后 root=OPEN(owner=L4-inc)；
L5 clean stop 后 foreign-claim FATAL → root 停在 OPEN；node0 的 commit revet
（`cluster_recovery_owner_rejoin_v1`）OPEN 分支要求 exact owner → L5-inc≠L4-inc
→ 永久拒绝 → JOIN_COMMITTED 不发布。

**Writer 裁决 = 方案 D（Oracle clean-close/open 主线）**，已接线：
1. checkpointer：ShutdownXLOG + STOPPED 后发布 **THREAD_CLEAN_CLOSE**
   （OPEN→CLOSED，lineage 不变；immediate/error 永不至此）——run100 实证
   "thread 2 clean-closed" ✓。
2. offpath 分类：`already_running && !prior_unclean_death` = **clean reopen**
   （不 fence、不 demote sj_adm）；crash/immediate 仍走完整 REJOIN 臂——
   run103+ 实证 "clean reopen detected" ✓。
3. phase3 bind/barrier 循环：bind LMS generation 后重试 **THREAD_OPEN**
   （CLOSED→OPEN，owner=新 boot incarnation，lineage+1）直到落地；CAS 幂等。
4. `patch_shape_valid` + `compare_and_publish`：冻结 THREAD_OPEN/CLEAN_CLOSE
   的 lifecycle 契约 + THREAD_OPEN 的 lineage/incarnation 单调性。
5. S1 恢复锁门：components-only transport 证明（无 seal）+ postmaster
   （phase3 驱动器）准入 CF(S)/WALR(X)。

**剩余卡点（下一轮主攻）**：L5-recovery boot 里 root lookup 返回
STORAGE_CONTRACT_UNVERIFIED——anchor 文件（$PGDATA/global/pgrac_cf_contract）
实测 state=**LOCAL_PROBED**（被 provision 路径的
`cluster_cf_contract_persist(LOCAL_PROBED)` 覆盖），而 phase2 的 fresh
rendezvous（"cf phase-2 ... verified"）在 L5-recovery boot 从未成功——
需定位哪个 boot 跑了 provision、为何 fresh verify 不重建
CROSSNODE_VERIFIED（node0 在线且探针响应存在）。

**验证状态**：L4 腿持续 GREEN（ok 18-19 跨 10+ run 稳定）；L5 卡点单一化。

---

## contract 验证时机修复（run112–117，提交 836e826fb6）

**根因**：storage contract 的 fresh verify 在 StartupXLOG（startup process）里跑，
而 postmaster 的 phase 机在 phase3 完成后才 fork startup process —— verify 永远
晚于 formation wait；cast/L5 腿的 THREAD_OPEN（root 强读需 CROSSNODE_VERIFIED）
与 bootstrap CF role gate 都 fail-closed → 早期变体（"cannot establish bootstrap
shared control-file authority"）与 L5 变体同根。

**修复**：phase_3_handler（postmaster 上下文、拓扑已载）开头先跑
`cluster_cf_phase2_verify_or_fail`（fresh rendezvous）；StartupXLOG 的调用保留
（幂等二次确认）。run117 实证两侧 "cross-node storage rename contract verified"，
cast 腿从 bootstrap-CF FATAL 推进到 authority barrier（新卡点：barrier
request-current result=2 + THREAD_OPEN 的 CF r=18/10——下一轮加分解诊断）。

**phase=4 之谜（run118 结案，非 bug）**：diag 打印的是
`cluster_current_phase()` 的原始枚举值，CLUSTER_PHASE_3_RECOVERY 的枚举值恰好
= 4（PRE_INIT=0 … 3_RECOVERY=4, 4_NORMAL=5）。phase 机全程正常，是诊断
可读性问题；后续 diag 用 phase 字符串或注明枚举语义。

---

## seed checkpointer TRAP 根因与修复（run118 铁证）

**崩溃**：seed 成员 fast stop 时 checkpointer（90130）TRAP
`failed Assert("!slot->held") cluster_cf_enqueue.c:126`，调用链 =
`cluster_control_root_thread_clean_close_publish` → `lookup_owner_by_node_runtime`
→ `cluster_cf_lock(ShareLock)`。后果：seed 停机变 abnormal →
node0 二节点 boot 被判 "crash-rejoin (prior unclean shutdown)" →
boot_decided=0 + witness 永不 settle → pg_ctl start 68s bail（run118）。

**根因链（证据闭环）**：
1. checkpointer 的 checkpoint WAL 删除 preflight（xlog.c:3874+ →
   `wal_reuse_preflight_roots` → `cluster_control_root_read_canonical(STRONG)`）
   在 fast-stop 排空窗口做了 CF(S) 协调获取；
2. 该 STRONG 读结束时 `release_cf` → `cluster_cf_unlock_confirmed` 的 S6 release
   无法确认 → 按 fail-closed 设计**保留 `slot->held=true`**（清掉会有双重授予
   风险——设计正确）；
3. 但 `cluster_cf_lock` 的非重入保护是 **Assert-only**（AGENTS.md 明令禁止的
   反例）：下一次同进程 CF(S) 获取（clean-close publish）直接 TRAP。
   `cluster_wal_state` 的 X 路径早有生产级 `cluster_cf_held()` 检查
   （"Do not trip cluster_cf_lock's deliberate non-reentrant Assert"），
   而 control-root 的 S 路径没有 —— 不对称漏洞。

**修复（run119 验证中）**：`cluster_cf_lock` 把非重入断言换成生产级
stale-hold drain：`slot->held` 时先 `cluster_cf_unlock_confirmed` 尝试确认释放
（未协调 hold 会被清除 → 可继续；协调 hold 确认释放 → 可继续；仍 UNCONFIRMED
→ 返回 false fail-closed，绝不 TRAP）。带 TEMP drain diag 验证排空在 shutdown
窗口是否可确认（若不可确认则 clean-close 会合法失败，需另查 S6 失败源）。

**下一轮**：run119 观察（a）drain 是否确认、seed 是否 clean stop；
（b）cast 腿 barrier request-current 的逐项分解（done0=0/0 + epoch 0→2 +
quorum 丢失——run118 被 seed TRAP 污染后的状态，需干净复跑重判）；
（c）L5 腿 THREAD_OPEN 后 revet 全链。

---

## run119/120 证据与用户裁决：L5 clean-reopen CF 冻结死锁（方案 2）

**run119/120 事实**（TRAP 修复后）：ok 1-21 全绿（cast 1-16 / L4 17-19 / L5
拒绝 20-21），死点 = L5 recovery boot 62s bail。分解铁证：
- `TEMP s4 shard frozen reject: resid_type=241 shard=1898 master=0` → 后
  `TEMP freeze gate: phase=2(REBUILDING) master=1 episode_epoch=6`：CF shard
  在 survivor 冻结（死 master 的 shard）→ remaster 后 joiner 本地 REBUILDING；
- `TEMP request-current fail: epoch_ok=0(4/3)→(5/4)→(6/5)`：node0 持续推高
  epoch（join commit 永不成功）；node0 侧 `commit revet owner_ok=0`（root 非
  OPEN+L5-inc）；node0 join episode hash=H({1}) vs node1 H(0)（AD-023 §9.2.3
  joiner applied 恒空）→ P7 永不收敛 → 解冻无望。
- **5 环死锁**：THREAD_OPEN 需 coordinated CF(S/X)（STOP-01 §17.4 冻结明文）
  → CF shard 冻结 → join 未 commit → epoch 动荡/冻结不解 → THREAD_OPEN 不落地
  → revet owner_ok=0 → …（spec 内无 CF 豁免先例；IR_M5 只覆盖 fresh-epoch resid）。

**用户裁决（方案 2，逐字要点）**：
- 复用 5.13 clean-leave 的 cooperative remaster/holder handoff（D4），
  **不得**另造 CF-only 移交协议；方案 1 的 IR_M5 类比不成立（CF 是跨
  episode singleton resid；root=CLOSED 不证明 survivor 无 CF 持有；D3 拒绝
  而非覆盖 → 无完整安全/活性证明；且已是第三层恢复期 gate 豁免 → 触发剥洋葱
  重评）。
- Oracle 行为边界：clean stop 必须在 GES/LMON 存活时把离开节点掌管的资源
  交给 survivor，而非让重启节点穿透冻结门自救（Oracle RAC 管理文档）。
- **冻结完成条件（序）**：停止新本地 CF 请求 → drain/移交 CF shard master +
  完整 holder 集 → survivor 确认新 generation 且 shard=NORMAL → 完成
  shutdown checkpoint / THREAD_CLEAN_CLOSE → 才允许实例退出。
- 任何 handoff 超时 / generation 漂移 / holder 校验失败不得假 clean-leave
  完成；fail-closed，回到既有 fail-stop reconfiguration。精确 wire/FSM 是
  PGRAC adaptation，但行为方向与 Oracle 一致。

**实施（本轮，run121 验证中）**：
1. `cluster_clean_leave.h`：announce payload 命名 `producer_kind`
   （OPERATOR=0/SHUTDOWN=1，原 _pad1[0] 字节，wire 兼容）+ 新入口
   `cluster_clean_leave_shutdown_drain()` 声明；ClusterLeaveState +
   `shutdown_driven` atomic。
2. `cluster_clean_leave.c`：survivor disabled-NAK 仅对 OPERATOR producer
   （shutdown mainline 非 opt-in 特性）；broadcast 盖 producer_kind；
   operator bind 清 shutdown_driven；新 `cluster_clean_leave_shutdown_drain`：
   门（enabled/managed/serving/IDLE/无 alive-peer 则 vacuous true）→ 绑 self
   → REQUESTED marker durable → drive_drain → 阻塞等 COMMITTED（或
   ABORT/ESCALATE/deadline fail-closed，barrier deadline 界）。
3. `cluster_clean_leave_policy.c`：payload validator 拒 producer_kind>1。
4. `checkpointer.c`：ShutdownRequestPending 块顶部（ShutdownXLOG 前）先跑
   handoff；THREAD_CLEAN_CLOSE 仅 handoff_ok 时发布，失败 LOG 跳过
   （root 留 OPEN → 重启走既有 crash-rejoin 链，fail-closed 不假绿）。
5. `cluster_cf_enqueue.c`：leaver drain 期（REQUESTED..COMMITTED）非
   checkpointer 的本地 CF 获取一律 fail-closed（"停止新本地 CF 请求"）。
- 依赖既有 5.13 已 ship 机制：survivor ACK（announce handler 不被 GUC gate）、
  coordinator 两阶段提交（COMMITTING→epoch bump CLEAN_LEAVE→COMMITTED）、
  clean_departed 抑制二次 fail-stop（CL-I13）、join commit 清 clean_departed
  （reconfig.c:3333）。t243 未开 clean_leave_enabled（冻结测试）→ shutdown
  producer 两侧不受该 GUC gate。
- 预期链：L5 fast stop → handoff commit（epoch bump + clean_departed[1]）→
  CLOSED → FATAL 拒绝腿不变 → recovery boot THREAD_OPEN 从 survivor-mastered
  NORMAL CF shard 拿锁 → reopen → revet owner_ok=1 → JOIN_COMMITTED → ok 22+。

### 实施后逐轮剥洋葱（run121-131，全部日志实证）

1. **run121**：handoff 已 commit（"committed departure of node 1 at epoch 1"），
   但 test 的 node0 CHECKPOINT（handoff 后立即跑）撞 serving 过期窗口 →
   CF(X) r=10 → 死。修：LEAVE_COMMITTED 发送门控在 survivor serving rebind。
2. **run122**：首条 LEAVE_COMMITTED 在 `cl_drive_committed_marker_stage` 内
   **未门控**（我只改了 step-2a 重发）+ leaver 自己 shutdown checkpoint 的
   CF(X) 撞自己 serving 过期 FATAL。修：两处都门控 + leaver 侧等本地 rebind。
3. **run123/128（cast 腿变体 C）**：node0 cast boot phase4 "Cluster Stats did
   not publish READY"（26s）——W2 checkpoint 的 checkpointer CF(X) 阻塞
   （sees flags 后无 "checkpoint starting"）。老 flake（计划书"剩余 flake：
   W2 强制 checkpoint 挂 ~25s"）。
4. **run127/129（cast 腿变体 B）**：node0 cast boot phase3 publish_recovery
   竞态失败（diag 全好但 valid=false——join 事件在 barrier 与 publish 间推高
   epoch）→ 重试 barrier gen=2 epoch 过期 → 双 phase3 互等 DONE → 68s bail。
   老 flake（"L1/cast 腿时序 flake 家族"）。
5. **run124**：cast 腿全过（ok 1-16+，证明 handoff 没破坏 cast 腿）→ 死在
   test CHECKPOINT（第 2 层，修后 run131 验证）。
6. **run126（rebind 根因铁证）**：survivor serving rebind 的 done-key 门要求
   clean-departed 节点（dormant MEMBER）的 DONE（done gate fail: node=1
   want=1）——离开节点永不广播 DONE；episode 自己的 P6 门跳过 dead set、
   rebind 门不跳 → 不一致永堵。修：rebind 门镜像 episode 门跳过 applied
   dead set（CL-I2 零 leftover → 跳过安全；FAIL_STOP 不受影响）。
7. **run130/131（leaver 侧第三层）**：handoff COMMITTED 后 leaver 自己的
   serving rebind **结构性不可能**（离开节点对自身 departure 永不 arm 本地
   episode → `recovery_episode_epoch==epoch` 门永败）→ phase-2 等满 30s →
   shutdown checkpoint CF(X) r=10 FATAL → abnormal → registry STOPPED 未写
   → test "slot 2 not STOPPED (state=1)" bail。修（本轮）：
   `cluster_grd_serving_authority_rebind_leaver`（无 episode/event-hash/peer-
   done 门，凭自身 applied CLEAN_LEAVE 证据 + quorum/inc/lms/member/准入 +
   map-current 重 stamp seal）+ `cluster_authority_serving_rebind_leaver`
   （phase-state 锁下重捕获 binding formation）+ reconfig tick 双 rebind。
   （未走 S1 allowlist 扩展——冻结 §8.3 只允许 CF(S)/WALR(X)，leaver 的
   shutdown checkpoint 需要 CF(X)，不能动冻结 allowlist。）

### 遗留（最终 GREEN 前）

- **cast 腿变体 B/C flake 家族**（publish_recovery 竞态 / W2 checkpoint 挂）
  ——老问题，run124/119/120 证明可过，最终需稳定化（P6 全绿要求）。
- **unit 链接面**：test_cluster_startup_phase 已修（补 stub：membership/
  sj_adm/episode/join_remaster/verify/thread_open/epoch/DataDir，24/24 过）；
  test_cluster_reconfig 已补 stub（ShutdownRequestPending/grd_done_epoch_for/
  lmon_reconfig_suppressed）但 **1/91 失败**（test_join_commit_root_gate_failure
  ut_owner_rejoin_calls 2!=1——HEAD 已 stale，与本次改动无关，待核）；
  grd/ges/grd_outbound/lock_acquire/wal_state_rmw/recovery_duty/formation_
  witness/cf_*/cssd/debug 等链接失败 = TEMP diag 新符号 + HEAD 既有 stale——
  TEMP 诊断清理时一并收敛。
