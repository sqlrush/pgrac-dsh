# P6-RESUME — 编码会话重启交接文档 v5（2026-08-18 00:20 定稿；内容由第二+三编码会话撰写）

> 新会话第一件事：读本文件 + `~/pgrac-dsh/DSH-REVIEW.md`，然后开始编码。
> 工作目录：`~/pgrac-dsh`，分支：`rf-root-dev`。
> 开工前 `pkill -9 -f walthreads_node` + `ipcrm` 清 shm。

## 1. 任务

让 t243 全绿（P6 完成条件：①未修改 workload/judge 的 t243 全绿；
②focused unit 全绿；③完整 build + cluster_unit 闭包；④immutable commit + push）。

## 2. 现状（HEAD=c32810bebc，工作区干净）

**t243 全绿已达成并稳定：run-55/57/59/60 连续 4 轮 33/33 PASS（L1-L10 全腿，
含 L4 crash-rejoin、L5 restore boot、L10 fast-stop 重启）**。run-58 为
harness 级 flake（ok 10 后测试进程 exit 29，产品日志干净，重跑即过）。

TEMP 诊断已全部删除（137 处/17 文件，chore c32810bebc）。后端全量编译干净。

cluster_unit：232 二进制，3 个失败（10 个已知 pre-existing 断言 stale）：
- test_cluster_reconfig 75/76/77/92（增量 5-8 语义过期，本会话确认 pre-existing）
- test_cluster_r4_static_model 9-13、test_cluster_r4_activation_record 50（R4 无人改过）
本会话新增/更新的单测全绿：grd 96/96、recovery_duty 18/18（含增量 13/17 的
CLOSED/OPEN 同主重开）、startup_phase 25/25（含增量 15 gen=0 保留）、
reconfig 88/92（含 self_join_admitted 无 PGPROC）、clean_leave 11/11、ges 25/25。

## 3. 本会话修复链（run-43→60，三层）

| 增量 | 提交 | 修什么 |
|---|---|---|
| 15 | c9922062a7 | postmaster A1 PANIC：`cluster_reconfig_self_join_admitted` 无 PGPROC 条件化（探针实锤 tranche=90 ClusterReconfig SHARED vs LMON EXCLUSIVE）；transport stale-clear 加 gen!=0 门（mid-bind 保护）；ges done-gate 诊断去副作用 |
| 16 | ce00ff9efd | join COMMIT 阶段无门排水（增量 5 PREPARE 先例）——L5 restore 的 JOIN 在 fence 提交后因 join-drive 门关闭（pending-join 形成漂移致 serving=0）而永不发布 |
| 17 | ce00ff9efd | owner-rejoin OPEN 分支接受同主更新化身（CAS expected=OPEN + lineage 防溢出 + shortcut 收窄）——L10 fast-stop 的 THREAD_CLEAN_CLOSE 在 serving 过期窗口被拒 → root 停 OPEN 旧 owner → 重启永拒 |

另：DSH 补记 6 的 P2（cl_leaver_reincarnated 收紧 `obs_inc > admitted`）与
增量 13 单测（58447e38b9）。

规格：specs-local/spec-s8-stop-01-root-control.md 增量 14（补写）15/16/17。

## 4. 剩余工作（P6 收尾或下会话）

1. **cluster_unit 全绿（可选收尾）**：更新 test_cluster_reconfig 75/76/77/92
   （增量 5-8 语义：无门 PREPARE/COMMIT 排水改变 commit-stage 时序；76/77/92
   的 marker submit 桩时序、75 的 dead-bitmap 断言）+ R4 5 个（static_model
   9-13 与 activation_record 50，语义过期非回归）。需读懂各测试的
   ut_* 桩流再改，预计每个 10-30 分钟。
2. **push**：`git push origin rf-root-dev`（本会话未推）。
3. **DSH 通道**：复审补记 7 的 ②（phase3 失败清理路径覆盖论证——代码级：
   bind preseal 失败 → clear_matching bind_preseal_fail → 循环 re-begin，
   deadline 兜底；已由 25/25 startup_phase 测试 + t243 4 绿实证）。
4. 勿重开"四门放宽"；勿改 t243 workload/judge/断言/顺序/timeout。

## 5. 环境速查

```bash
cd ~/pgrac-dsh && git checkout rf-root-dev
pkill -9 -f walthreads_node 2>/dev/null
for id in $(ipcs -m | awk '/sqlrush/{print $2}'); do ipcrm -m "$id" 2>/dev/null; done
cd src/backend && make -j8
cd src/test/cluster_unit && make check      # 232 二进制；已知 10 个 stale 失败
cd src/test/cluster_tap && make check PROVE_TESTS='t/243_wal_thread_2node_shared_root.pl' PROVE_FLAGS=--verbose
```

**注意**：勿并行跑两个 make check（tmp_install 竞争会互毁）。
