# P6-RESUME — 编码会话重启交接文档 v2（2026-08-17 17:45 由 DSH 生成）

> 新会话第一件事：读本文件 + `~/pgrac-dsh/DSH-REVIEW.md`，然后开始编码。
> 工作目录：`~/pgrac-dsh`，分支：`rf-root-dev`。
> 注意：上一会话 17:41 有一轮 t243 在跑，新会话开工前先
> `pkill -9 -f walthreads_node` 清理（run-t243-loop.sh 里有同款清理段）。

## 1. 任务

**让 t243 全绿**（P6 完成条件四条：①未修改 workload/judge 的 t243 全绿；
②focused unit 全绿；③完整 build + cluster_unit 最小闭包；④immutable commit + push）。

## 2. 当前 HEAD 与已 Ship 进度（上一会话 15:37-17:26，全部已提交）

| 提交 | 内容 |
|---|---|
| `e920ca6800` | **contract 1 停机顺序**：shutdown checkpoint/STOPPED 发布先于 5.13 handoff（checkpointer.c/clean_leave.c） |
| `94791471d5` | **关闭 reconfig-epoch fence-token 窗口**（xlog.c/qvotec.c/write_fence.c） |
| `eee6832cbc` | specs-local 增量：STOP-01 contract 1 + fence-window 收窄（副本 + 增量 1/2） |
| `d244fec352` | TEMP：CSSD main-loop 冻结 bisect 探针 |
| `31e2b1ad58` | RFROOT-PLAN 更新（cast-leg pair-boot wedge 映射） |

稳定历史：`c4b2357723`（六环死锁解环）→ ok 1-21 反复通过（含 L4 crash-rejoin
核心腿 ok 18/19）；方案 D（THREAD_CLEAN_CLOSE/THREAD_OPEN）= `f87d539440`。

## 3. 当前卡点（v2）：cast 腿 pair-boot 编队楔死（老 flake 家族，今日 ~100%）

contract 1 已 ship，但铸根前的 pair-boot 仍楔死，三个独立子变体（全部先于本
会话存在，任意 binary 可复现）：

- **B1（CSSD 冻结）**：一节点 CSSD main loop 第 2 迭代冻结（证据：`TEMP cssd
  loop alive iters=1` 后无输出、`liveness lock enter` 缺失；冻结点在首个
  WaitLatch wake 与 liveness 锁之间 = CHECK_FOR_INTERRUPTS/shutdown_requested）
  → 对端 deadband 判死 → 假 fail-stop epoch 0→1 → joiner W2 verified CF r=10/13
  → phase4 FATAL。
- **B2（GRD seal 过期）**：joiner phase3 barrier 在 epoch 0 封 seal，join commit
  把 epoch 推到 1 → `cluster_grd_recovery_authority_is_current` epoch 精确匹配
  失败 → serving 永不发布 → 双端 phase4 互等。
- **B3（join-drive blocked）**：coordinator 的 join-drive 门
  `runtime_join_allowed=0`（online_join=off + offpath_fast_rejoin=0）卡住
  fresh-pair 的 node1 admission。

## 4. 下一轮最短路（上一会话已排定，沿用）

1. B1 收尾：用已提交的 bisect 探针再抓一次冻结轮（`TEMP cssd post-interrupts`
   vs `pre-shutdown-check` 谁最后出现）→ 定位 CHECK_FOR_INTERRUPTS
   （ProcSignalBarrier 吸收）还是 CssdShmem->lwlock 的 EXCLUSIVE 持有人。
2. 三个变体任一收敛后重跑 t243：ok 3 铸根 → L5（CLOSED 已由 contract 1
   保证发布路径）→ L6/L8/L9/L10。
3. **L5 前复核**：seed clean-close 的 CF(S) stale-hold drain 失败（CLOSED 跳过）
   问题——上会话留下的未闭环观察项。
4. 全绿后：删全部 TEMP（fence-block diag / contract1 marker / cssd 探针 + 存量
   TEMP）→ focused unit + build 闭包 → immutable commit + push。

## 5. 审核发现（详见 DSH-REVIEW.md，现行有效）

- F2（P1）：OWNER_REJOIN || THREAD_OPEN 共享 lineage 分支，需按
  expected_lifecycle 显式拆分；
- F3（P1）：authority bind allowlist 扩到三 reason，复核 checkpointer 与
  recovery/startup 的 authority 绑定独立；
- F5：unit 测试已有补充，继续补 THREAD_CLEAN_CLOSE/THREAD_OPEN 生命周期用例；
- 上会话留 DSH 两个观察项：①observer 侧残余 lag；②seed clean-close CF(S)
  stale-hold（已并入上面第 3 步）。

## 6. 纪律（必守）

1. `~/pgrac` 与 `~/linkdb` **只读**，绝不修改；
2. spec 增量只在 `~/pgrac-dsh/specs-local/` 做（原文一字不改，增量标日期）——
   上一会话已示范正确姿势（eee6832cbc）；
3. 每修一个可验证子步就 commit（上一会话做到了，保持）；
4. 提交前删除全部 TEMP 诊断；
5. 不得改 t243 workload/judge/断言/顺序/timeout；诊断期只能调本地测试配置；
6. 每次改动后读 `DSH-REVIEW.md` 最新追加（DSH 持续审核投递）。

## 7. 环境速查

```bash
cd ~/pgrac-dsh && git checkout rf-root-dev
# 清理上一轮残留：
pkill -9 -f walthreads_node 2>/dev/null
# 构建 + 跑 t243：
cd src/test/cluster_tap && make check PROVE_TESTS=t/243_wal_thread_2node_shared_root.pl PROVE_FLAGS=--verbose
# 连续 15 轮留存日志：
cd ~/pgrac-dsh && ./run-t243-loop.sh
# 日志：src/test/cluster_tap/tmp_check/log/；历史：~/pgrac-dsh/t243-runs/
```
