# RF-ROOT P7-P9 交接文档（2026-08-18 07:00，DSH 撰写，供新编码会话启动）

## 0. 一句话状态

**P6 已完成并核验**（t243 33/33 ×4，单测闭包，公共仓库已推送）；但 DSH 交接
核验发现两处 P6 收尾欠账：cluster_regress 崩溃回归（clean_leave 视图 SIGABRT）
与 TEMP 残留（26 文件未清完）——见 §8，作为本会话前两个任务。
本会话的目标：**RF-ROOT 剩余合同 P7/P8/P9 全通过 + 全量回归**。

## 1. 启动必读（按顺序）

1. 本文件（RFROOT-NEXT.md）
2. `~/pgrac-dsh/DSH-REVIEW.md`（审查通道，含复审补记 1-8；改完代码必须重读）
3. `~/pgrac-dsh/P6-RESUME.md`（v5：P6 修复链与证据，含 t243 run-43→60 三层修复）
4. `~/pgrac-dsh/RFROOT-PLAN.md`（P6-P9 合同原文 + 回正清单 + L4/L5 根因史）

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

## 5. P8 合同（RF-ROOT §5）

- rebuild-first：recoverer crash 后，下一 actor 从 canonical sources 重建
  （root/WAL/formation/fence），**不接管前任 private progress**。
- BGW_NEVER_RESTART 语义保持；仅新 episode 可重启。
- STOP-ROOT-GENERATION / SERIAL 未关闭时，同 episode replacement 保持 BLOCKED。

## 6. P9 合同（RF-ROOT §7-9）

- §9.2 fault legs **RL-01..RL-12**：faithful TAP，禁止 mock 替代正式完成。
- §9.1 单元 RED matrix **RU-01..RU-12**。
- §8.1 recovery-only observability：counter 语义 G2 分级。

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
- [ ] 8 个 pre-existing 单测失败（reconfig 77/92 + r4_static_model 9-13 +
      r4_activation_record 50；P6-RESUME 原记 10 个，其中 reconfig 75/76
      系 test 55 泄漏污染、55 系掩盖性 stale，均随 P1 消解）
- [ ] P7 W6 退休 + 三 consumer 迁移 + census 0
- [ ] P8 rebuild-first 编排
- [ ] P9 fault legs + observability
- [ ] 全量回归（cluster_tap 272 + cluster_unit 232 + cluster_regress 13）
      + 推送 pgrac-dsh

## 9. DSH 工具（新 DSH 会话接手时可用）

- `.dsh-watch.sh`：900s 周期扫描（HEAD/未提交/t243 ok 数/最后编辑），
  卡住 2 轮、ok 回归、启动级 bail 三类告警写 DSH-REVIEW.md；新绿自动打
  `dsh-flash-wip-*` 快照 tag。
- `.dsh-change-watch.sh`：45s 轮询签名，编码会话一动代码即退出（job 结束
  通知唤醒 DSH 复审），复审后带新基线重启。
