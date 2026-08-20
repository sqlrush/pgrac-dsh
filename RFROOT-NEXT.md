# RF-ROOT P7-P9 交接文档（2026-08-18 17:50 v2，DSH 撰写，供新编码会话启动）

## 0. 一句话状态

P6 冻结 ✅；**P7 已完成（2026-08-19 审计修复后）**：W6 退休 ✅、G1a/G1a-2 ✅、
G3/G4/G5 机制 ✅、任务 4 bit22 首开轮 ①-⑤ ✅（补记 62 外部审计 8 finding 的
#1-#8 修复全部提交：NULL-identity、first-open 可达性、latch 跨重启、幂等、
coordinator 顺序、resid、link、P4/P9 honest BLOCKED——见 §6a 与提交
29781c8..ad83c93）。**P8 rebuild-first = 结构性满足（增量 49/50 + 2026-08-19
实证）。P9 = RU-01..12 ✅ + §8.1 ✅ + RL-01 ✅；RL-02..12 与
STOP-ROOT-IO-FENCE = 🔴 BLOCKED（外部审计确认）**。
本会话目标（补记 43 重排方向）：P7 收尾 + P8/P9 已按上述状态闭合。

⚠️ **本文件 v1（07:00）与补记 43 冲突处以补记 43 为准。** v1 的 §4 迁移目标、
§8 待办里的"迁移 → census 归零 → 开 bit22"顺序**已作废**。

## 1. 启动必读（按顺序）

1. 本文件（RFROOT-NEXT.md v2）
2. `~/pgrac-dsh/DSH-REVIEW.md`（审查通道，**最新 = 复审补记 43**；改完代码必须重读）
3. `~/pgrac-dsh/specs-local/spec-s8-stop-01-root-control.md` 尾部增量 36/37/38
   （36=勘误 BASE_BACKUP 撤销；37=④ ABSENT 二分【落地路径已被 38 废止】；
   38=补记 43 裁决落地 + 新方向）
4. `~/pgrac-dsh/P6-RESUME.md`（v5：P6 修复链与证据）
5. `~/pgrac-dsh/RFROOT-PLAN.md`（P6-P9 合同原文）

## 2. 环境与跑法

- 仓库：`~/pgrac-dsh`，branch `rf-root-dev`，HEAD=`62158031da`（已 push
  `origin/rf-root-dev` = github.com/sqlrush/pgrac-dsh 公共仓库）。
- 构建：树内 make；单测：`cd src/test/cluster_unit && make check`
  （232 二进制；已知 3 失败 = 10 个 pre-existing 断言：reconfig 75/76/77/92
  + r4_static_model 9-13 + r4_activation_record 50）。
- TAP：`cd src/test/cluster_tap && make check PROVE_TESTS=t/xxx.pl PROVE_FLAGS=--verbose`
- regress：`cd src/test/cluster_regress && make check`
- 每轮跑批前清理：`pkill -9 -f walthreads_node; ipcrm -m $(ipcs -m | awk '/sqlrush/{print $2}')`

## 3. 纪律（红线，违反即打回）

- `~/pgrac` 与 `~/linkdb` **只读**，任何时刻不得修改。
- 新方案先落 `~/pgrac-dsh/specs-local/` 增量（原 spec 不动，增量带日期+证据），
  再写代码。
- 小步提交：每个可验证子步一次 commit（increment N 模式，doc/fix 成对）。
- 修改任何代码后必须重读 DSH-REVIEW.md。
- t243 的 workload/judge/断言/顺序/超时**不可改**（仅本地测试配置例外）。
- TEMP 诊断推送前必须删除（P6 的 137 处清理是范本）。
- 跑批出绿 → 让 DSH 复审 → 再 commit；复审结论在 DSH-REVIEW.md。

## 4. P7 合同（STOP-01 §17 + 批准字面量）

- **W6 退休**：删除两个 A1 writer——
  ① cold xlogrecovery 路径；② online orchestrator 的 merge_recovered_lsn 写入。
  forged 非零历史值对全部 correctness reader 必须读作 0 且不得造 skip。
- correctness readers（f076 行号，**需在当前树重定位**）：
  - `xlogrecovery.c:2451-2467`
  - `cluster_hw_remaster.c:470-487`
  - `cluster_recovery_merge.c:941-965, 1115-1127`
  - `cluster_recovery_plan.c:178-223`
  - `cluster_recovery_worker.c:181-195, 233-254`
  - orchestrator `:541-573`
- 迁移目标：**canonical control-root**（`cluster_control_root_read_canonical`）
  + PAGE/SIDE proof；wal-state 仅作 telemetry。
- 静态 census：post-bit22 的 wal-state correctness reader/writer == 0。
- bit22 只在 PREPARED/ACTIVE 全成员 ACK 后打开。

## 4b. ⚠️ P7 收尾路线重排（补记 43 裁决，2026-08-18 17:40，覆盖 §4 执行顺序）

**裁定**：冻结三处合起来——§17.8（Source R4 OPEN: wal-state remains selected;
root is not authority）+ §17.7-4（after bit22 ... statically unreachable →
bit22 前在用）+ §17.9（census 证明 **post-bit22** 状态）——意味着 **reader 在
bit22 前必须保持 wal-state 权威源**。"先迁 reader root-only → census 归零 →
才开 bit22" 的顺序把冻结语义做反了。

**配套事实（补记 43 E1/E2，绿跑日志实测）**：已提交树的五个 G1b step-4 站点
功能惰性——`STRONG + expected_identity=NULL` 恒返 INVALID_ARGUMENT=23，
17:17 绿跑 plan 实测 "0 alive, 127 unknown"（连 ALIVE 的 tid2 都 UNKNOWN），
plan 恒 0 candidates → worker 永不启动。127-unknown 是 NULL-identity bug 签名，
与 root 文件存在性无关。t243 绿 = plan "not acted upon" + 无 candidate 触发，
**green 不证明迁移正确 = 测试强度缺口**。

**新执行顺序（补记 43 背书）**：

1. **修 NULL-identity bug**：pin/plan 读要么传 expected_identity，要么用合法
   模式（BOOTSTRAP 仅限验证语义）。
2. **reader 双路径按 bit22 门控**：bit22 前走 wal-state（registry）权威源；
   bit22 后 root-only + ABSENT fail-closed（增量 37 的 never-minted 降级 /
   minted-lost fail-stop 语义在 bit22 后分支内继续有效）。
3. **reader 切换收进 G3/G5 的 all-member CLOSED-ACK 同一轮**（W6 事实 + reader
   切换同轮绑定，§17.7-3 的 "same migration round"）。
4. **census 重定义**：§17.9 的静态 census = 对 **post-bit22** 状态的证明
   （gate 建模），不是 pre-bit22 归零前置门；脚本 KNOWN-DEFERRED 语义翻转
   （deferred 站点 bit22 前合法，cutover 轮内关闭）。
5. **测试强度缺口**：补 t243 candidate>0 断言（或独立 crash 腿）。
6. hw_remaster 现 committed 的 registry 读**保持不动**——§17.8-correct 的
   bit22 前行为；site-4 "迁移" 不再是 bit22 前置任务。

**增量 37 处置**（增量 38 已落档）：语义二分/判别器/不持 gate 保留；
"site-4 迁移 → census 归零 → bit22 首开" 的落地路径废止。

## 5. P8 合同（RF-ROOT §5）

- rebuild-first：recoverer crash 后，下一 actor 从 canonical sources 重建
  （root/WAL/formation/fence），**不接管前任 private progress**。
- BGW_NEVER_RESTART 语义保持；仅新 episode 可重启。
- STOP-ROOT-GENERATION / SERIAL 未关闭时，同 episode replacement 保持 BLOCKED。

## 6. P9 合同（RF-ROOT §7-9）

- §9.2 fault legs **RL-01..RL-12**：faithful TAP，禁止 mock 替代正式完成。
- §9.1 单元 RED matrix **RU-01..RU-12**。
- §8.1 recovery-only observability：counter 语义 G2 分级。

### 6a. P9 审计状态（补记 62/63 外部审计确认，2026-08-19）

- ✅ **RL-01**：complete（`t/271_wal_first_recoverer_fresh.pl` 6/6 ——
  canonical HW rebuild + zero replay + honest dead-rejoin block）。
- 🔴 **RL-02..RL-12**：**BLOCKED（外部审计确认）**，非 complete。2 节点
  共享根基板限制下无法铸造 faithful TAP 腿：peer DEAD 时节点重启阻塞于
  phase3 live-formation（600s FATAL）；dead-rejoin 未实现（53R60，
  spec-5.22）；crash-rejoin 存在 epoch race；clean-leave→restart 存在
  phase3 witness 窗口（增量 40/41/51/53 记录）。RL-07 以单元面结论关闭
  （增量 40：primary-bad/bak-good 合法 DEGRADED；dual-copy tamper 失败于
  phase3 formation，非 root mismatch）。审计 finding 7：RL-03..12 无 TAP
  腿 —— 必须外部提供可 crash 的基板（或按合同豁免）后才可标 complete。
- 🔴 **STOP-ROOT-IO-FENCE（P4 external I/O eviction）**：**BLOCKED（外部
  审计确认）**，非 complete。external eviction/terminal verification
  provider 未选择、无 IPC/receipt schema —— `cluster_external_fence_*`
  恒 false（审计 finding 5，P0/gate）→ **P4/P9 不 complete**；cooperative
  fence 不能关闭该 gate（spec §8.4）。
- 📋 RU-01..RU-12 与 §8.1 observability：合同已落 spec §9.1/§9.2/§8.1
  （本会话映射完成）；执行状态随各 RL 腿。

## 7. 测试面盘点（RF-ROOT 相关 TAP）

- 已完成：`t/243_wal_thread_2node_shared_root.pl`（33/33）
- 相关待评估（按合同逐一对号）：
  `242_wal_thread_routing`、`244_wal_state_registry`、`245_recovery_plan`、
  `246_recovery_worker`、`247_merged_recovery`、`248_shared_merged_recovery`、
  `249_grd_recovery_remaster`、`250_grd_remaster_3node`、
  `251_gcs_pcm_warm_recovery`、`252_gcs_block_coherence`、
  `253_undo_tt_recovery`、`254_pi_cr_recovery_acceptance`、
  `256_block_apply_differential`、`257_block_recovery_d1`、
  `258_thread_apply_differential`、`269_write_fence_surface`、
  `273_stage4_recovery_acceptance_capability`、`201_stage2_acceptance_fault_matrix`
  （RL legs 若已铸造则在此或需新铸）。
- 全量回归（P7-P9 完成后）：cluster_tap 全 272 + cluster_unit 232 +
  cluster_regress。

## 8. 遗留清单（本会话开局时的已知红/未办）

- [x] **【P0 已修】cluster_regress 崩溃回归**（2026-08-18 本会话）：
  归因（DSH 补记 11 背书）= stale build artifact，非产品缺陷：views.o
  旧于 cluster_clean_leave.h（5861a6c700 加 shutdown_driven）→ 整结构
  拷贝写穿栈 canary → SIGABRT（lldb 实锤）。处置：src/backend 全量
  `make clean && make -j8` → cluster_regress **13/13 全绿**（含
  cluster_clean_leave + cluster_node_remove）；t243 复跑见下。
- [x] **【P1 已修】TEMP 清理**（2026-08-18 本会话）：实际 P6 时代残留 =
  xlog.c 6 处（include + 4 个 cfx diag 块 + errdetail）、checkpointer.c
  3 处；cluster_lock_acquire.c 的 "TEMP" 为合法注释（RELPERSISTENCE_TEMP
  语义），DSH 误报。其余 26 文件为合法 PG 语义引用，登记即可。同步清理
  7 个 dead 单测桩 + test 55 同步为增量 5/16 语义（原诊断块掩盖其 stale
  断言并泄漏 pending 状态污染 75/76；重写后 reconfig 失败 4→2，75/76
  转绿已用二进制复跑实锤 ×2）。TEMP 清理后构建的 t243 = **33/33 PASS**。
- [x] **【补记 13-A】增量 17 已回退**（5074881fa7）：head gate 恢复
  `owner != admitted`、捷径恢复无条件 `if (OPEN) return true;`、单测
  删除假绿用例、specs-local 标注回退。recovery_duty 18/18 PASS。
- [x] **【补记 13-B 已执行】增量 13 裁决 = 按 DSH 倾向（用户 2026-08-18）**：
  clean-reopen 走 THREAD_OPEN 冻结主线（958b941130，commit 时点路由：
  协调者持完整 proof 集执行冻结 CLOSED→OPEN CAS；OWNER_REJOIN 严格
  RECOVERY_COMPLETE-only，control_root allowlist 收窄）。执行者范围结论
  （AD-023 §4 = 恢复期 allowlist；serving 期协调者走 serving 准入）已落
  specs-local 增量 20 补记。L10 serving-stale 变体（clean-close 被拒 →
  root 停 OPEN(old)）由增量 21 修复（两段冻结 CAS：THREAD_CLEAN_CLOSE
  OPEN→CLOSED + THREAD_OPEN CLOSED→OPEN，clean-departed 证据门控；
  非 clean-departed 的 OPEN(old) 保持 fail-closed）。DSH 补记 18 的
  head gate lifecycle 拆分已照办（b4fb9ece30；CLOSED 分支靠 CAS 单调性
  兜底，验证记录见增量 21 补记）。t243 33/33 ×7 连绿（含变体轮）。
- [x] **【补记 13-C 已完成】端到端 lifecycle 测试**（d7820ab33e）：真实
  文件根 + 真实 compare_and_publish/patch_shape_valid，断言 ① OWNER_REJOIN
  RECOVERY_COMPLETE 成功；② OPEN/CLOSED 前态 OWNER_REJOIN 被
  patch_shape_valid 拒（零 CF/文件 I/O）；③ THREAD_OPEN CLOSED→OPEN 成功
  （owner 重盖 + lineage+1）。control_root 26/26 PASS。
- [x] **【P6 重新冻结条件核对】**（供 DSH 裁定）：A ✓ + B ✓ + C ✓ +
      regress 13/13 ✓ + t243 33/33（多轮）✓ + 全树 TEMP 复核 0 ✓ +
      cluster_unit 232 闭包 ✓（3 二进制/8 测试文档化 pre-existing）。
- [x] **【P7 G3 step 1 已提交】**（2026-08-18 13:03，c448a57602）：
      R4 cutover create-authority coordinator proof 落地——recovery_duty.c
      `cluster_control_root_create_authority_current_v1` 替换 P5 拒桩（四重
      fail-closed：非协调者 fail-fast / ACK 未 COMPLETE / 未知 feature 位 /
      target 缺 bit22）；新 accessor `cluster_semantic_activation_ack_complete_matches`
      （COMPLETE 表 + round 身份绑定，seqlock snapshot）。证据：recovery_duty
      24/24、r4_activation_fsm 174/174、t243 33/33。**待 DSH 复审**；通过后
      按增量 23 步骤 2-3 接 ACK 消费（coordinator R4 驱动）+ activate/bit22
      门 + census strict 集成。
- [x] **【P7 G3 step 2-3 已提交】**（2026-08-18 13:4x，见下）：activate
      authority proof（bit22 OPEN 门）——seam + `cluster_control_root_activate_prepared`
      签名携带 round；ACK accessor 增加 minimum_stage（create=SAMPLE /
      activate=PREPARED，W6 条款 3 CLOSED 绑定）；census 运行时门
      `cluster_wal_state_correctness_census_ok`（静态 deferred 表，
      补记 28 硬性要求），脚本加 lockstep 交叉校验。证据：recovery_duty 25/25、
      r4_activation_fsm 174/174、wal_state_rmw 13/13、control_root 26/26、
      t243 33/33；census strict 仍 RED（5 deferred violation，按设计）。
      **待 DSH 复审**；剩余：coordinator R4 驱动接线（utility mailbox
      cutover）+ census strict 转 GREEN（deferred 站点关闭，G1b step 4）。
- [x] **【补记 29 已到达】**：G3 step 2-3 复审通过（activate proof 四门 +
      census 运行时门兑现；DSH 复跑 25/25+174/174+wal_state 21/21）。
      剩余定序：G1b step 4 关闭 5 个 deferred site → census 转 GREEN。
- [ ] **【P7 G1b step 4 设计稿已提交】**（2026-08-18，88d819eb38，
      specs-local 增量 25）：5 个 deferred 站点降级为 NODE_LOCAL_AUTHORITY
      类别（merged.authority 同型，解 R4 调度环）——plan.c:203 与
      worker.c:192 实证在 startup 上下文但含 registry 独有语义（SCN 观测 /
      写位置字段 root 无）；worker:247 / orchestrator:572 / hw_remaster:487
      为 episode worker（CF(S) 不可行）+ registry 独有数据。census strict
      转 GREEN 条件 = DEFERRED 空 + C 表与脚本 NODE_LOCAL_AUTHORITY 一致。
      **待 DSH 复审设计后再实施**。
- [ ] **【补记 30 + 用户裁决 C 已落地】**（2026-08-18）：DSH 复审增量 25
      技术分析通过但 NODE_LOCAL_AUTHORITY 与冻结 §17.9 exactly-zero 冲突
      → 用户三选一裁决 = **C（维持迁移 canonical 读原义）**。增量 26
      （d7a0151977）定稿 C 路线：无 CF 快照读（READ_SNAPSHOT，原子发布
      + CRC 双副本兜底，复用 BOOTSTRAP_VALIDATE 先例）+ 逐 site 迁移映射
      （orchestrator/hw_remaster → checkpoint_lower_lsn/validated_tail；
      worker/plan classify → lifecycle/published_at UNKNOWN fail-closed；
      plan max_highest_scn 观测处置）。**待 DSH 复审增量 26**（两个待背书
      项：validate_stream target-page 锚语义、plan verdict truth table）。
      实施顺序：READ_SNAPSHOT → orchestrator+hw_remaster → worker+plan →
      census 归零 → bit22 可开。
- [ ] **【补记 31 执行指令已收到】**（2026-08-18 14:40）：C 形状定稿 =
      **pre-IR pinned canonical projection**（STOP-02 §15：零资源锁 →
      STRONG read/revalidate → pin root identity+token+snapshot 字段 →
      进入 episode/CF(X) → bgworker 只消费本 episode immutable projection，
      IR 内禁止自行 CF(S) → episode 结束丢弃）。**撤回 READ_SNAPSHOT 方向**
      （撞 §17.7 no-mirror + §1.3 投影纪律）。五站点逐站提交等复审：
      ① startup（plan.c:203 + worker.c:192）pre-IR 直接 STRONG read；
      ② episode bgworker（worker:247 / orchestrator:572 / hw_remaster:487）
      消费 episode 前固定投影（构造者=同站 startup/coordinator）；
      ③ max_highest_scn 删除（无消费者）；④ registry 独有字段禁止镜像 →
      保守 root 判定或 BLOCKED；⑤ census 逐站双处移除。
- [ ] **【增量 27 站点 1 设计已提交】**（2026-08-18，dbd7e4d32c）：plan
      verdict 活性判定障碍——registry last_updated 由 cluster_stats 每
      1s tick 刷新（cluster_stats.c:672，interval=1000ms），root
      published_at 仅 checkpoint 粒度（THREAD_OPEN/CLOSE/
      CHECKPOINT_ADVANCE/OWNER_REJOIN 发布点）→ 10s stale 阈值不可直接
      迁移（活 peer 误判 CRASHED → merge NOT_COLD 门失效 → FATAL 53RA3）。
      选项 A 保守放大阈值（唯一 exactly-zero 合规）/ B plan 活性留
      registry（再踩 §17.9）/ C BLOCKED。推荐 A + truth-table 单测。
      **待 DSH 复审**。
- [ ] 8 个 pre-existing 单测失败（reconfig 77/92 + r4_static_model 9-13 +
      r4_activation_record 50；P6-RESUME 原记 10 个，其中 reconfig 75/76
      系 test 55 泄漏污染、55 系掩盖性 stale，均随 P1 消解）
- [ ] **【P7 收尾 —— 按 §4b 重排执行】**：
      ① 修 NULL-identity bug（STRONG+NULL→23，五站点惰性）；
      ② reader 双路径 bit22 门控设计（specs-local 增量 39，文档先行）；
      ③ 测试强度：t243 candidate>0 断言或独立 crash 腿；
      ④ G3/G5 bit22 首开轮（all-member CLOSED-ACK 绑定 W6 事实 + reader
      切换）；⑤ census 重定义为 post-bit22 静态证明后接入门。
      ⚠️ 原"P7 W6 退休 + 三 consumer 迁移 + census 0"表述已作废（补记 43）。
- [x] **#2 重做（durable Target OPEN 证明）**（2026-08-19，27dc616eb6 +
      ea8bbc358d）：latch 恢复基于 majority OPEN(P+2) voting-disk 记录与
      ACTIVE root 的交叉验证（增量 59b）；三态 latch（SOURCE/BOOTSTRAP/
      VERIFIED）+ CF(S) 强验证升级；first-open source-close BARRIER（增量
      61）让在线 cutover 可达（build 接受冻结 ACTIVE slot）。
- [~] **t/243 fixture 保留**（诚实）：在线 cutover 已可达，但 post-bit22
      的**节点死亡恢复路径未完成**（2026-08-19 实证诊断：强制 latch 后，
      peer 死亡时 hw_remaster "structurally blocked"（bit22 分支 491）、
      GRD recovery WAIT_CLUSTER 卡、checkpointer 拿不到 CF 锁 →
      checkpoint 失败）——post-bit22 恢复需要 RF-PAGE/SIDE 的
      stable-base/post-read/retirement proof（DSH 队列拆分建议）；t/243
      fixture 与 t/274 重启腿在此路径完成后实施。
- [x] **P8 rebuild-first 编排**（2026-08-19）：结构性满足，无产品修复
      ——增量 49/50 审计 + 本会话重新实证：gap1 replay-slot pin 每 episode
      重写（episode_epoch 绑定，projection_current 拒 stale）；gap2 worker
      pool 每 launch generation++ + verdict/bitmap 重写；gap3
      BGW_NEVER_RESTART（worker.c:501 / thread_recovery_worker.c:353）+
      serial acquire 门（同 episode 无 replacement）。测试固化 = plan 单测
      （projection stale 拒）+ 集成断言归 RL 腿（2-node 限制，增量 50 裁决）。
- [x] **P9 状态定稿**（2026-08-19）：§8.1 观测性 ✅（增量 55，G2 分级）；
      RU-01..12 ✅；RL-01 ✅（t/271 6/6）；**RL-02..12 与 STOP-ROOT-IO-FENCE
      （P4）= 🔴 BLOCKED（外部审计确认，见 §6a）**——非 complete。
- [~] 全量回归：本会话已跑 t243 33/33 + cluster_regress 219/219 + 相关
      cluster_unit 全绿 + census GREEN；**cluster_tap 全量 272 未跑**
      （P9 BLOCKED 项完成后按合同再跑）+ 推送 pgrac-dsh（已推
      rf-root-dev @ ad83c93ab7）。

## 9. DSH 工具（新 DSH 会话接手时可用）

- `.dsh-watch.sh`：900s 周期扫描（HEAD/未提交/t243 ok 数/最后编辑），
  卡住 2 轮、ok 回归、启动级 bail 三类告警写 DSH-REVIEW.md；新绿自动打
  `dsh-flash-wip-*` 快照 tag。
- `.dsh-change-watch.sh`：45s 轮询签名，编码会话一动代码即退出（job 结束
  通知唤醒 DSH 复审），复审后带新基线重启。

---

## RF-PAGE / RF-SIDE 完成度修正（DSH 复审 2026-08-20）

准确口径（替代任何 "D 全部落地/完成" 表述）：

- **RF-PAGE（PGDEL-01..10）**：semantic/helper 层与聚焦单测层已落地
  （PageVersion 类型/classifier/decide、rmgr census+hints、action 表+
  状态机+outcome、source validators+selection、recovery set+closure、
  admission+sequence gates+crash matrix、FND-10 handoff、counters+dump、
  PU/PL 单元面、ABI 护栏；17 套件 80 RED 全绿）。**未完成**：
  production caller（§10.3——core 接口在 src/backend 无生产调用者）、
  native buffer/GCS apply + durability + canonical post-read 执行
  （§7.2，STOP-RF-PAGE-STABLE-BASE 下 mutation 面保持 RED）、PL-01..14
  fault TAP/formal。
- **RF-SIDE（D-SIDE-01..08、D-SIDE-10）**：semantic/helper 层已落地
  （route registry、TT/undo decode+preflight、2PC binding、projection
  判定、space STOP 门、PAGE integration verdict、per-resource
  readiness、retention exporter、observability）+ PCM-X 窄集成
  （re-form，t/274 12/12 闭环）。**未完成**：durable PREPARED pending
  store 与 RECO ownership、CLOG/MULTIXACT/COMMIT_TS 真实
  producer/invalidate/rebuild、TT/undo 真实 decode/apply caller、
  RF-PAGE proof 的 live consumer、retention proof 生产 exporter、
  **D-SIDE-09 完整 unit/TAP/fault corpus**（U-SIDE 全表 + L1-L20）。
- 纪律：生产 caller 是 D 的完成条件（§10.3），不得推迟到
  "integration round" 后仍宣称 D 完成；私有 Spec 副本（specs-local/
  spec-rf-page-*、spec-rf-side-*）已移出 git 跟踪（AGENTS.md），
  原版与增量记录留在 ~/pgrac 私库与本地工作区。

**进展（2026-08-20 晚）**：
- ① production caller 已落地（78b5daba95）：§10.3 探针在真实 replay
  路径逐 record+block fire 全链（classify→decode→decide→D-SIDE-06/07
  消费）+ durability barrier 后 fire FND-10/retention exporter（只读，
  mutation 面受 STOP 约束保持 RED；t243 无行为变化）。
- ② D-SIDE-09 fault corpus judgement face 已落地（108bdf6dbc）：
  U-SIDE-17 + L1..L20 单元 RED 全绿；faithful TAP cast 仍受 2-node
  基板限制保持 RED/BLOCKED（与 RL-02..12 同因）。
- DSH 复审 5 点全部闭环：P0 私有 Spec 移出 git（80ab984975）、PCM-X
  re-form fail-closed 加固（20a56a7c7d，allocator_lock + 失败回滚 +
  负测 288/288）、external-rejoin 保留合取加强（20a56a7c7d，96/96）、
  状态表述修正（d6fa29efc8）、本项。
- **R4-OPEN 已闭环（2026-08-20）**：r4_static_model 9-13 与
  r4_activation_record 50 全部消解；顺带修复同类 pre-existing 断言
  （r4_activation_fsm 186/193/195、cluster_qvotec link+26、
  cluster_ic 17/18/19/24、cluster_sf_dep 15）——cluster_unit
  **232/232 全绿**。性质全部为 B′/审计 #2 语义过期（test mock/stub
  或证据锚点 stale），非产品回归：
  - activation_record 50：utility mailbox mock 缺 ENABLE_ALL/
    R4_SYNC_CR_V1 字段（pgrd formation binding 检查）；64：
    shmem_size 缺 source-close shmem 项；link 需 superuser +
    bootstrap_validate_active_round_fields stub。
  - static_model：9 区域锚点（try_r4_request80 插入）、10 锚点
    （enter_internal 重构）、11 contract-17 证据改指真实 D6 符号
    （heap_hot_r4_updated_xmin_needs_full →
    cluster_gcs_block_cr_fetch_and_wait → heap_hot_r4_search_scratch +
    HeapTupleSatisfiesMVCCScratch）、12 RED 标记过期、13 contract-10/11
    证据（ClusterCrBuildReason 在 gcs_block.h；
    cluster_semantic_activation_record_cas_write 在 cluster_qvotec.c）。
  - fsm 136/142/144：B′ self-observed（observed=0x01）与 PREPARE CAS
    两步链（BARRIER COMPLETE 先 mint gen-1 记录再 build/create；
    新增 bit22_prepare_cas_* 静态需 test_gate_reset）。
  - qvotec：B′ reconfig/control-root/formation-marker/superuser link
    stubs；26 文件尺寸断言改 LOCAL_OFFSET(127)+512（B′ P0 懒物化，
     attested 容量 8N+3 ≠ 运行文件）。
  - ic：ACK-v1 位（0x8000）随审计 #2 广告（wire 0x0039BFFE）；
    sf_dep 15：gen 0 → 1（首连映射）。
- **t/274 重启腿（L4/L5）= 已知阻断，确定性复现**：L3 judge 曾用
  "bit22.*OPEN" 匹配到 "OPEN(P+2) CAS submitted" 行，停止动作可能
  抢在 latch 翻转前 → 依赖时序侥幸通过。已把 judge 收窄为完成证据
  （OPEN durable / OPEN_APPLIED / TARGET_BOOTSTRAP）——现在
  L1-L3 恒绿、L4 恒 RED（post-bit22 peer 干净重启 → 幸存者
  hw_remaster "minted-lost" blocked_structural（bit22 分支 491）、
  GRD recovery WAIT_CLUSTER 卡、peer phase3 "recovery LMS generation
  could not be bound"，与上方实证诊断一致）。此路径依赖
  RF-PAGE/SIDE 的 stable-base/post-read/retirement proof
  （P9 RL-02..12 / STOP-ROOT-IO-FENCE），外部条件具备后实施。

**剩余 RED**：native apply/durability/post-read 的 mutation 执行
（STOP-RF-PAGE-STABLE-BASE 未解除）、PL-01..14 的 faithful TAP cast
（2-node 基板限制）、production stores/executors（durable pending
store、RECO ownership、projection 存储/重建执行、SQL consumer 镜像）、
t/274 L4/L5 重启腿（post-bit22 恢复路径未完成，确定性 RED）。
**下一步队列**：外部条件具备后 P9 RL-02..12 / STOP-ROOT-IO-FENCE /
全量 TAP 272。
