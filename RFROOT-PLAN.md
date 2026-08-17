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
