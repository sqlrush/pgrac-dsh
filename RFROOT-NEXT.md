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

- [ ] **【P0 先修】cluster_regress 崩溃回归**（DSH 07:08 独立复跑取证）：
  - `cluster_clean_leave`：backend SIGABRT（signal 6，cassert Assert 失败），
    崩溃语句 = `SELECT count(*) FROM pg_cluster_clean_leave_state;`
    （视图/SRF 首查）。单节点模式（node_id=-1）下触发。
  - `cluster_node_remove`：连接丢失——系前者崩溃后服务器 reinitializing
    期间的连带失败（postmaster.log：`FATAL: database system is in recovery
    mode`）。修好 clean_leave 后单独复跑确认。
  - 怀疑面：增量 10/12 改过 clean-leave FSM（cl_leaver_reincarnated、
    survivor 释放条件）——先跑 `test_cluster_clean_leave` 单测（clean_leave
    11/11 据称绿）对照，再用 gdb/Assert 栈定位；**回归归属查清前勿大改**。
- [ ] **【P1】TEMP 清理不完整**：P6 声称"137 点清零"，实际 26 个文件仍有
  `TEMP ` 残留。其中 RF-ROOT P6 时代：`xlog.c`（5 处）、`checkpointer.c`
  （3 处）、`cluster_lock_acquire.c`（1 处）；其余为更早 stage 遗留
  （planner.c/catalog 等）。清 P6 时代的，其余登记待清。
- [ ] 10 个 pre-existing 单测断言（reconfig 75/76/77/92 + r4_static_model
      9-13 + r4_activation_record 50；若属 P7-P9 语义面则顺手修）
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
