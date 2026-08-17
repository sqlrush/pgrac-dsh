# P6-RESUME — 编码会话重启交接文档（2026-08-17 15:30 由 DSH 生成）

> 新会话第一件事：读本文件 + `~/pgrac-dsh/DSH-REVIEW.md`，然后开始编码。
> 工作目录：`~/pgrac-dsh`，分支：`rf-root-dev`。

## 1. 任务

**让 t243 全绿**（P6 完成条件四条：①未修改 workload/judge 的 t243 全绿；
②focused unit 全绿；③完整 build + cluster_unit 最小闭包；④immutable commit + push）。

## 2. 当前 HEAD 与进度

- HEAD = `836e826fb6`（wip: verify the storage contract in postmaster phase-3 context）
- 稳定基线：`c4b2357723`（六环死锁圈解环）让 ok 1-21 反复通过，含最难的
  L4 crash-rejoin 核心腿（ok 18/19）；
- 方案 D（STOP-01 THREAD_CLEAN_CLOSE/THREAD_OPEN 接线）= `f87d539440`（wip）；
- 当前实测：bootstrap 恢复（ok 1/2 通过）。

## 3. 当前卡点（最新一轮 15:27）

- ok 2 后测试进程 exit 29（异常退出，非 bail）；
- 直接失败：铸根前置断言 `slot 2 not STOPPED after clean stop (state=1)`——
  **node1 干净停机后 wal_state 槽位仍 ACTIVE(1)**，fixture 要求 STOPPED(2)；
- 探针线索（node1 log）：`serving rebind entry fail: state=3 ext_cur=0 gen_cur=1
  capture=1 moved=0 phase=6`（停机窗口的 serving/authority rebind 失败）。

## 4. 失败签名时间线（12 个，按出现顺序）

1. JOIN_PENDING 53R61（root 缺失）→ 铸根 fixture 解决
2. phase4 Stats READY 超时 → CF retry 解决
3. WAL ACTIVE CF result 3 → CF 解锁提前解决
4. startup unit SIGABRT → atomic 对齐解决
5. witness local_epoch(3)≠applied(0) → 六环解环 c4b2357723 解决
6. 合成事件方案违反 5.16 HF2 → review 打回，重接
7. re-declare complete 但 formation 超时 → 同 5
8. 停机 CF(X) 拿不到（ok 3 回退）→ 停机 reconfig 压制 6f38c8b353 解决
9. phase4 readiness 活锁 → 同 5
10. bootstrap 0 ok（方案 D 落地回归）→ 836e826fb6 解决
11. L5 恢复重启 600s phase3 楔死 → 方案 D（clean-close/OPEN 接线）针对它
12. **当前**：干净停机 slot 2 不落 STOPPED（contract 1 顺序问题）

## 5. 未提交 WIP（21 文件，+1058/−91，含新 unit 测试）

保留作为起点（已含 startup_phase +57 / reconfig +16 的单测补充）。
若重启时已提交为 wip 快照 commit，则从此 commit 继续；否则从 836e826fb6 + 工作区继续。

## 6. 审核发现（详见 DSH-REVIEW.md，只列现行有效的）

- **F1 已修正认知**：bootstrap 不走 THREAD_OPEN 门，首次编队无需 UNUSED→OPEN
  豁免（control_root.c 未动而 bootstrap 已恢复，实锤）；F1 不再阻塞。
- **F2（P1，待查）**：`OWNER_REJOIN || THREAD_OPEN` 在 compare_and_publish 共享
  lineage 分支——两者的 expected_lifecycle 前置不同（RECOVERY_COMPLETE vs CLOSED），
  需显式拆分，防止豁免交叉继承。
- **F3（P1，待查）**：authority bind allowlist 扩到三 reason，需确认 checkpointer
  与 recovery/startup 的 authority 绑定独立、未重开 P5 关闭的 mutation 面。
- **F5（部分回应）**：unit 测试已在 WIP 中补充，继续补 THREAD_CLEAN_CLOSE/
  THREAD_OPEN 生命周期用例。
- **当前主攻**：contract 1 顺序——"THREAD_CLEAN_CLOSE 只能在 shutdown checkpoint
  durable + STOPPED wal-state 发布**之后**"（specs-local 的 STOP-01 增量合同）。
  干净停机必须把 slot 落成 STOPPED(2)，否则 fixture 拒绝、L5 恢复重启也会走错路径。

## 7. 下一步最短路（建议顺序）

1. 修停机顺序：shutdown checkpoint durable → W2 STOPPED 槽位发布 →
   serving rebind/authority 转换 → THREAD_CLEAN_CLOSE(CLOSED)。核对
   checkpointer.c（13:41 编辑过）与 serving rebind 路径（phase=6 探针线索）。
2. 重跑 t243：过 ok 3（铸根）→ 应能一路到 ok 21；
3. L5 恢复重启（claim 还原后 THREAD_OPEN：expected=CLOSED + claim + fresh
   incarnation + CF token 验证，读回前不 admission）；
4. L6/L8/L9/L10 平推 → 全绿（约 33 项）；
5. 清理全部 TEMP 诊断 → unit 全绿 → 完整 build 闭包 → immutable commit + push。

## 8. 纪律（必守）

- `~/pgrac` 与 `~/linkdb` **只读**，绝不修改；
- spec 增量只在 `~/pgrac-dsh/specs-local/` 做（原文一字不改，增量标日期）；
- 每修一个可验证子步就 commit（别再攒 21 个文件）；
- 提交前删除全部 TEMP 诊断；
- 审核通道：DSH 会把发现追加到 `DSH-REVIEW.md`，每轮改动后读它；
- 600s phase3 等待拖慢迭代——诊断期可临时调低**本地** phase3 timeout
  （测试配置，不得改 t243 judge/workload/断言/顺序）。

## 9. 环境速查

```bash
cd ~/pgrac-dsh && git checkout rf-root-dev
# 构建 + 跑 t243：
cd src/test/cluster_tap && make check PROVE_TESTS=t/243_wal_thread_2node_shared_root.pl PROVE_FLAGS=--verbose
# 单测：
cd src/test/cluster_unit && make test_cluster_startup_phase test_cluster_control_root test_cluster_reconfig
# 日志：src/test/cluster_tap/tmp_check/log/
```
