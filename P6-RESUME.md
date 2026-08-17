# P6-RESUME — 编码会话重启交接文档 v4（2026-08-17 22:20 定稿；内容由第二编码会话撰写）

> 新会话第一件事：读本文件 + `~/pgrac-dsh/DSH-REVIEW.md`，然后开始编码。
> 工作目录：`~/pgrac-dsh`，分支：`rf-root-dev`。
> 开工前 `pkill -9 -f walthreads_node` + `ipcrm` 清 shm。

## 1. 任务

让 t243 全绿（P6 完成条件：①未修改 workload/judge 的 t243 全绿；
②focused unit 全绿；③完整 build + cluster_unit 闭包；④immutable commit + push）。

## 2. 本会话进度（HEAD=517d107a04，工作区干净）

**ok 1-19 已稳定**：bootstrap（ok 1-3）、cast reform（ok 4）、L1-L3、
**L4 crash-rejoin（ok 18/19，60s 窗口内 ~11s 完成）** 全部通过。剩余
L5 restore boot 一条腿。提交序列：

| 提交 | 内容 |
|---|---|
| `b59a8d7de0` | docs: specs-local 增量 9-14 |
| `517d107a04` | **fix: 增量 9-14**（见下） |
| `921cab5ee5` | chore: cluster_unit 闭包（补桩 + 2 新单测） |

### 增量 9-14 摘要（规格见 specs-local/spec-s8-stop-01-root-control.md）

- **增量 9**：authority barrier 同 composite 重发保留 done 槽位（清零只在
  composite 变化时）——修 publish 瞬时失败（reconfig 锁条件获取失败）后
  gen=2 重发永久饿死。run-29 根因实锤：`19:27:38.270 TEMP reconfig-lock
  conditional fail`。
- **增量 10**：LMON 逐迭代广播加 1Hz 下限（authority done key + clean-leave
  LEAVE_COMMITTED 重发）——修两节点互驱的帧风暴（实测 16k 帧/s/侧，
  cssd 心跳饿死 → 假 DEAD）。
- **增量 11**：DONE echo 触发面从 FSM self-done 扩到 authority self-done。
- **增量 12**：clean-leave 槽位按 observed 新化身释放（cssd 状态是 node
  级，快速重启永不 DEAD → leave 串行门永久卡 fast-rejoin 链）。
- **增量 13**：owner-rejoin 门 + control-root OWNER_REJOIN patch 接受
  CLOSED 生命周期的同主干净重开（head 门 + expected_lifecycle + patch
  校验三处）。
- **增量 14**：echo 块移到 FSM episode-hash 早退**之前**（原位置在
  episode_hash=0 时是死代码——bootstrap/cast reform 恰是 echo 设计场景）。

## 3. 当前卡点（最后一层，精确到行）

run-43 实测（L5 restore boot / cast reform 腿的通用形态）：

```
22:15:56.801 node1 LMON: TEMP transport-comp fail: state=1 phase=4
    boot_ok=1 lmsgen_ok=0 ... lms_match_ok=0  (binding lms_gen=0 vs live 1)
22:15:56.801 node1 LMON: TEMP clear_matching: recovery_transport_stale
22:15:56.802 node1 postmaster: PANIC: cannot wait without a PGPROC structure
```

**根因链**：phase3 的 STARTING binding 在 LMS restart generation 尚未
置 1 时创建（begin 把 authority_lms_generation 复位为 0）→ DONE 门
（`cluster_recovery_transport_components_current` 要求
`live_lms_gen == binding.lms_gen`）拒绝 peer 的 done 帧 → 循环清 binding
重试 → **postmaster（无 PGPROC）在某条路径上对阻塞 LWLockAcquire 触发
A1 PANIC**（lwlock.c:1111 "cannot wait without a PGPROC structure"）→
LMON 随 postmaster 死 → 心跳停 → 对端 3s 后关连接 + cssd DEAD →
fail-stop → 该腿 60s bail。

- PANIC 的精确调用点未定位（嫌疑：phase3 循环内 thread-open 的 CF(S)
  获取路径 / wait_for_live_formation 的 witness 路径；run-29 尾部
  (19:31:34) 同款 PANIC 出现过）。定位法：`gdb` 或对 postmaster 路径
  逐函数审计阻塞 LWLockAcquire（`cluster_phase_state_lock_acquire` 已
  条件化；其余未审计）。
- 候选修复方向：①binding 创建应等到 LMS gen 稳定（
  `cluster_lms_get_lms_restart_generation() != 0` 才 begin/bind——
  目前 loop 顶部读 live gen，但 begin 在 witness READY 后、gen 可能仍 0）；
  ②DONE 门对 lms_gen 失配的帧在 phase3 窗口内宽容（idempotent 帧）；
  ③postmaster 路径全部条件化锁获取（A1 契约）。
- 注意：ok 1-3/4/18/19 在 run-33/36/39/43 等轮次**已稳定**通过，失败
  腿在不同轮次间漂移（cast reform 或 L5 restore），都是同一族
  （binding lms_gen=0 → DONE 门拒 → PANIC/饿死）的时序变体。

## 4. 下一轮最短路

1. 定位并消掉 postmaster 的 A1 PANIC（"cannot wait without a PGPROC
   structure"）——这是 L5 腿的致命点。
2. 修 binding lms_gen=0 的创建时序（或 DONE 门宽容）——消除 DONE 帧
   被拒窗口。
3. t243 全绿（预期 L5 ok 20/21、L6/L8/L9/L10）后：更新 test_cluster_
   reconfig 的 5 个 stale 单测（增量 5-8 语义，见 DSH-REVIEW F4/F5）
   与 test_cluster_r4_static_model/activation_record 的 5 个 pre-existing
   失败 → cluster_unit 全绿。
4. 删全部 TEMP 诊断（本会话新增：ges entry 探针、mark_peer_done 计数
   （temp_mark_peer_done_count/temp_echo_count）、owner gate 分解、
   revet 分解、tier1 type=4 recv 全量日志、authority tick 计数扩展、
   "TEMP barrier request posted" 的 prev 字段）→ 完整 build 闭包 →
   immutable commit + push。

## 5. 审核通道状态

- DSH 复审补记 5（20:25）：增量 9 方向批准，待提交——本会话已按
  increment 模式提交（b59a8d7de0/517d107a04）。
- F2/F3（P1）仍待查；L5 前复核 seed clean-close CF(S) stale-hold。
- 勿重开"四门放宽"。

## 6. 纪律（必守）

1. `~/pgrac` 与 `~/linkdb` 只读；spec 增量只在 `~/pgrac-dsh/specs-local/`。
2. 每修一个可验证子步就 commit。
3. 提交前删除全部 TEMP 诊断（最终闭包时）。
4. 不得改 t243 workload/judge/断言/顺序/timeout。
5. 每次改动后读 DSH-REVIEW.md 最新追加。
6. 新技术方案先落 specs-local 增量再写产品代码。

## 7. 环境速查

```bash
cd ~/pgrac-dsh && git checkout rf-root-dev
pkill -9 -f walthreads_node 2>/dev/null
for id in $(ipcs -m | awk '/sqlrush/{print $2}'); do ipcrm -m "$id" 2>/dev/null; done
cd src/test/cluster_tap && make check PROVE_TESTS='t/243_wal_thread_2node_shared_root.pl' PROVE_FLAGS=--verbose
# 日志：src/test/cluster_tap/tmp_check/log/
# 关键观测点：node1 日志 "TEMP transport-comp fail"/"TEMP authority tick ... markpd=/echo="
# node0 日志 "TEMP owner gate"/"TEMP commit revet"
```
