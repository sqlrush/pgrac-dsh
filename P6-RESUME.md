# P6-RESUME — 编码会话重启交接文档 v3（2026-08-17 20:10 由 DSH 生成）

> 新会话第一件事：读本文件 + `~/pgrac-dsh/DSH-REVIEW.md`，然后开始编码。
> 工作目录：`~/pgrac-dsh`，分支：`rf-root-dev`。
> 开工前 `pkill -9 -f walthreads_node` + `ipcrm` 清 shm（run-t243-loop.sh 有同款段）。

## 1. 任务

**让 t243 全绿**（P6 完成条件：①未修改 workload/judge 的 t243 全绿；
②focused unit 全绿；③完整 build + cluster_unit 闭包；④immutable commit + push）。

## 2. 当前 HEAD 与本会话进度（18:10-20:10，全部已提交，工作区干净）

**ok 1-17 已稳定**（cast 腿 pair-boot 楔死完全解掉）；L4 crash-rejoin 链已全部跑通，
剩余 1 层楔子在收尾。提交序列（自 d4101df0b1 起）：

| 提交 | 内容 |
|---|---|
| `4501cb8b1c` | TEMP cfx 探针（CF/S4/S6/master-drain/W2 分解） |
| `2aeb583506` | （被撤销）四门放宽 —— 暴露 A1 no-PGPROC 违反，postmaster 远程 wire 静默死 |
| `555890d2df` | **第 1 层修复：回退 S1 半个准入**（幽灵 holder 根源）。增量 3 |
| `4eea30478d` | **第 2 层修复：qvotec baseline 抬到 clean-departed epoch floor**（重启后 fence token 停摆 PANIC）。增量 4 |
| `4d7d1ab1ac`/`f3046c3db9` | RFROOT-PLAN 修正 |
| `1262a9aaa2`/`24b38e5482`/`75d95d271d`/`df9b4c109a`/`cb4ef5a360` | TEMP：qvotec 矩阵/selfwrite、rollover 全分解、GRD barrier stall |
| `6ab005bfb8` | **第 3 层：join PREPARE drain 移出 drive 门**（增量 5）→ JOIN_PENDING 可发布、GRD JOIN episode 可启动 |
| `30382420b6` | **第 4 层：驱逐并入 JOIN_PENDING dead 集**（增量 6）→ episode 不再等 joiner 的 DONE（循环死锁破） |
| `f29641e763` | **第 5 层：bootstrap 重入清 clean-departed**（增量 7）→ 重入节点的真实死亡不再被 CL-I13 掩码吞掉（fail-stop 可发布） |
| `ef7c9d8ced` | **第 6 层：rollover 门扩到 DEAD 态**（增量 8）→ 死带竞态下 join 也有 runtime 腿 |

## 3. 当前卡点（最后一层，L4 收尾）

run-29 实锤：L4 全链已跑通——驱逐（27:35.48）+ fail-stop（27:35.48 epoch
1→2）+ JOIN_PENDING（27:35.66 epoch 3）+ episode done（27:36.9 epoch 3、
27:38.27 epoch 4）+ COMMITTED 写入（3/3）+ **node1 sj_adm=1（27:38.27，
自认成功）**——但 node1 的 phase3 authority barrier 在 60s pg_ctl 窗口内
未 terminal（bail @27:28:30），且 witness 直到 19:31:34 才 READY（会话后
节点仍活着跑完）。两个剩余问题：

1. **epoch 抖动**：node1 boot 的 cssd 心跳在 27:30.26 出现 >2s 空窗 →
   node0 二次 SUSPECTED/DEAD → 二次 fail-stop（epoch 4，"dir=2" episode）
   → node1 phase3 barrier 的 request-current epoch 精确匹配失败
   （`epoch_ok=0(5/4)`）+ 双方 snapshot 不稳 → witness 的 f1==f2 判定
   一直被新事件打断。**查 node1 boot 的 cssd 为什么有 >2s 心跳空窗**
   （node1 日志：4s qvotec age-out 后的 phase3 序列里 cssd 首播时间）。
2. **witness 自认后延迟**：sj_adm=1 后 witness 仍 3.5 分钟才 READY——
   需分解 witness 在 sj_adm=1 后的剩余门（marker 门/owner 门/f1==f2）。

预期解向：二次 fail-stop 用事件 dedup/epoch 宽容消化（node1 已自认的
事件不应再把它标死）；或 node1 的 cssd 心跳空窗消除后二次 fail-stop
不再发生。

## 4. 下一轮最短路

1. 抓 run-30 日志：node1 boot 的 cssd 首播时间 vs node0 二次 DEAD 时间
   （确认空窗根因——boot 序列还是 LMON 饥饿）。
2. 消二次 fail-stop（epoch 4）→ node1 phase3 barrier epoch 稳定 →
   60s 内 witness READY → ok 18/19。
3. ok 18/19 后：L5（两段 start/stop + foreign claim）、L6、L8、L9、L10。
4. 全绿后：删全部 TEMP（cfx/obs/selfwrite/rollover/barrier-stall/join
   gate/commit revet + 存量 TEMP）→ focused unit + build 闭包 →
   immutable commit + push。

## 5. 审核发现（详见 DSH-REVIEW.md，现行有效）

- F2（P1）：OWNER_REJOIN || THREAD_OPEN 共享 lineage 分支，需按
  expected_lifecycle 显式拆分；
- F3（P1）：authority bind allowlist 扩到三 reason，复核 checkpointer 与
  recovery/startup 的 authority 绑定独立；
- F5：unit 测试已补 THREAD_CLEAN_CLOSE/THREAD_OPEN 生命周期用例；
- 上会话留 DSH 两个观察项：①observer 侧残余 lag；②seed clean-close CF(S)
  stale-hold（增量 2 已记录，L5 前复核——checkpointer 的 CF(S) 释放门在
  停机窗口 serving=0 时走 recovery 分支、StartupProcess-only 拒——需在
  L5 的 clean-close 腿单独处理）。

## 6. 纪律（必守）

1. `~/pgrac` 与 `~/linkdb` 只读；spec 增量只在 `~/pgrac-dsh/specs-local/`。
2. 每修一个可验证子步就 commit。
3. 提交前删除全部 TEMP 诊断。
4. 不得改 t243 workload/judge/断言/顺序/timeout。
5. 每次改动后读 DSH-REVIEW.md 最新追加。
6. 新技术方案先落 specs-local 增量（本会话已示范增量 3-8）。

## 7. 环境速查

```bash
cd ~/pgrac-dsh && git checkout rf-root-dev
pkill -9 -f walthreads_node 2>/dev/null
for id in $(ipcs -m | awk '/sqlrush/{print $2}'); do ipcrm -m "$id" 2>/dev/null; done
cd src/test/cluster_tap && make check PROVE_TESTS='t/243_wal_thread_2node_shared_root.pl' PROVE_FLAGS=--verbose
# 日志：src/test/cluster_tap/tmp_check/log/
```
