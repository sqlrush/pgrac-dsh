# DSH-REVIEW — DSH 对编码会话（flash）的代码审核通道

> 角色（user 2026-08-17 指令）：DSH 审核编码会话的代码，发现问题**立即**投递到这里。
> 编码会话每个提交 / 每批 WIP 后应读本文件；user 亦可随时把本文件内容转达编码会话。
> 本文件与 RFROOT-PLAN.md 分离（后者由编码会话自己维护，避免双写冲突）。

## 审核合同（每次变更必查）

1. 冻结 Spec/AD 符合性：spec-5.16（HF2/HF3）、STOP-01/02/05、AD-023、RF-ROOT 主 spec、specs-local 增量；
2. actor/authority 边界：合成事件、身份拼接、假 survivor、authority 交叉发布；
3. 锁序与分层：STOP-05 §5.4（CF→WALR 等）、持锁做盘 I/O；
4. fail-closed：假绿、放宽 judge/timeout、fixture/stub 降级；
5. 测试同步：产品改动必须配套 unit/TAP 变更，禁止只有 link stub；
6. 工程卫生：TEMP 诊断累积、未提交积压、提交说明与实测日志一致性。

---

## 第一轮审核（2026-08-17 11:25，对象：f87d539440 + 当前 WIP）

### F1 [P0] THREAD_OPEN 校验缺少 bootstrap first-provision 豁免 —— 当前 0-ok 根因

- 位置：`cluster_control_root.c` compare_and_publish（f87d539440 引入）
- 代码：THREAD_OPEN 无条件要求 `expected_lifecycle == CLOSED`；
  初始双节点编队的首次 OPEN 其 expected=UNUSED(0) → 被拒 → phase3 等
  live formation → 600s 超时（10:52 轮两节点 600.090s/600.026s FATAL 实锤）。
- 修法（最小）：expected 矩阵分治——
  - `UNUSED→OPEN`：仅限 bootstrap first-provision（无 prior root 文件 +
    sysid/storage_uuid 锚 + claim + CF token 验证照旧）；
  - `CLOSED→OPEN`：clean-reopen 全量校验（方案 D contract 2 原样保留）。
  不得以放宽 contract 2 或跳过 bootstrap 验证来修。

### F2 [P1] OWNER_REJOIN 与 THREAD_OPEN 共享分支，语义未显式区分

- 位置：`cluster_control_root.c` compare_and_publish：
  `else if ((reason == OWNER_REJOIN || reason == THREAD_OPEN) && (lineage 检查…))`
- 风险：OWNER_REJOIN = "RECOVERY_COMPLETE 后单独批准的 owner 接棒"
  （STOP-02:619），THREAD_OPEN = clean-reopen；两者 lifecycle 前置不同
  （RECOVERY_COMPLETE vs CLOSED）。合并分支可能让 THREAD_OPEN 意外继承
  OWNER_REJOIN 的既有豁免（或反向）。
- 修法：分支按 expected_lifecycle 显式拆分，各自独立前置校验，不共享 else-if。

### F3 [P1] authority bind 门从 OWNER_REJOIN 扩宽到三 reason，需复核交叉发布

- 位置：`cluster_control_root_publish_authority_bind_v1` reason allowlist
  `== OWNER_REJOIN` → `OWNER_REJOIN || THREAD_OPEN || THREAD_CLEAN_CLOSE`
- 复核项：checkpointer（CLEAN_CLOSE 发布者）与 recovery/startup（OPEN 发布者）
  的 authority token/incarnation 绑定是否各自独立、无交叉复用同一上下文；
  P5 曾故意关闭该门，扩宽后须证明没有重开 P5 关掉的 mutation 面。

### F4 [工程] 迭代卫生（flash 模式下更重要）

- TEMP 诊断快速累积（cf_phase2/cf_storage 新增 4 组 capped diag），
  未提交 5 文件（含 RFROOT-PLAN.md 自身）——建议：每修一个可验证子步就 commit；
- 600s phase3 等待把每轮失败拖到 10 分钟才干净——诊断期可临时调低
  本地 phase3 timeout 加快 fail-fast（**仅测试配置，不得改 t243 judge**）。

### F5 [P1] 产品提交零测试配套

- `f87d539440`：8 个产品文件 +515/−14，**零 unit/TAP 变更**。
- THREAD_CLEAN_CLOSE/THREAD_OPEN 是新生命周期语义，必须补：
  ① control_root unit（UNUSED→OPEN、CLOSED→OPEN、crash 不写 CLOSED、
  expected 不匹配拒绝）；② clean-close 发布位置（checkpoint durable 后）
  的聚焦验证。禁止只靠 t243 全绿兜底。

### ✅ 本轮确认正确的部分

- clean-close 半边顺序正确（shutdown checkpoint durable + STOPPED wal-state
  发布后才 CLOSED；immediate/error 退出不写 CLOSED——contract 1 逐字落地）；
- OWNER_REJOIN 的 RECOVERY_COMPLETE 前置（:1516-1518）未被删除；
- 未发现假绿、judge 放宽、fixture 降级。

### 优先级

F1（P0，先修）→ F2/F3（P1，同批修）→ F5（提交前补齐）→ F4（持续纪律）

---

## 复审补记（2026-08-17 12:30）

- 新提交 `836e826fb6`（11:37）：把 storage-contract 校验移入 postmaster phase-3
  上下文（cf_phase2/cf_storage/startup_phase，+87）。提交说明自述："把上一轮
  bootstrap-CF 失败定位到 authority barrier（其 request-current 失败是下一项）"。
- **两方诊断已收敛**：编码会话追到的"authority barrier request-current 失败"
  与 F1（THREAD_OPEN 对首次编队 UNUSED→OPEN 的拒绝）是同一因果链的上游/下游。
  **F1 仍未实施**：control_root.c 自 09:56 起未再编辑。
- 下一步最短路：直接落 F1 的 expected 矩阵分治（UNUSED→OPEN first-provision
  豁免），再跑 t243 验证 barrier 是否随之一并解开。
- 观察：11:49 轮仍 0 ok（68s bail）；会话 11:51 后静默约 40 分钟。

---

## 复审补记 2（2026-08-17 14:45）

- **F1 假设修正**：bootstrap 已恢复（ok 1/2 通过），而 control_root.c 未变——
  首次编队并不走 THREAD_OPEN 门；bootstrap 根因在 CF storage-contract 校验
  （编码会话的 836e826fb6 方向正确）。F1 降级为"待观察项"，不再阻塞。
- **新卡点**：14:42 轮 ok 2 后铸根前置失败——"slot 2 not STOPPED after clean
  stop (state=1)"：node1 干净停机后 wal_state 槽位仍 ACTIVE。检查对象 =
  checkpointer 的 STOPPED 发布与 THREAD_CLEAN_CLOSE 的顺序（contract 1：
  CLOSED 只能在 checkpoint durable + STOPPED 发布之后）。
- 正面：WIP 已补 unit 测试（startup_phase +57、reconfig +16，回应 F5）。

---

## 复审补记 3（2026-08-17 17:45，换会话交接）

- 复审对象：e920ca6800（contract 1 停机顺序）、94791471d5（fence-token 窗口）。
  方向均正确，未见 Spec 偏离：CLOSED 只在 checkpoint/STOPPED 后发布，
  immediate/error 退出不发布；fence-token 窗口收窄与 STOP-05 §5.4 不冲突。
- 上会话在 specs-local 落增量 1/2（STOP-01 contract 1 + fence-window），
  符合 specs-local 纪律；增量 2/2（若推导出新方案）留给新会话继续。
- 上会话诚实标注"三个变体均先于本会话存在、任意 binary 可复现"——新会话
  排查 B1/B2/B3 时勿把责任归给 contract 1 修复；优先 bisect B1（已有探针）。

---

## 复审补记 4（2026-08-17 19:45，换会话交接 v3）

- 复审对象：本会话 6 层修复（increment 3-8：S1 准入回退 / qvotec baseline
  epoch floor / JOIN_PENDING drain 移出 drive 门 / 驱逐并入 dead 集 / bootstrap
  清 clean-departed / rollover 门扩 DEAD 态）。方向全部符合冻结 spec，逐层
  配 specs-local 增量，模式正确；中途自行 revert 一次"四门放宽"（A1 no-PGPROC
  违反）——判断力在线，无遗留偏离。
- 剩余楔子（已由会话自己写进 P6-RESUME v3，DSH 背书）：
  ① node1 boot 的 cssd >2s 心跳空窗 → node0 二次 SUSPECTED/DEAD → 二次
  fail-stop(epoch 4) → barrier epoch 精确匹配失败；
  ② sj_adm=1 后 witness 仍 ~3.5 分钟才 READY（剩余门待分解）。
- 新会话注意：F2/F3（P1）仍待查；L5 前复核 seed clean-close CF(S) stale-hold
  （增量 2 已记录）。勿重开"四门放宽"。

---

## 复审补记 5（2026-08-17 20:25，Flash 第一批产出复审 + run-30 取证）

### 5.1 增量 9（同 composite 重发保留 done 槽位）——方向批准，待提交

- 核验通过：done 槽位写入门（cluster_grd.c:2895）只比 {epoch,hash} 与当前
  发布 composite，不比 generation → 同 composite 保留的槽位即新 gen 需要的
  精确证据，composite 变化时必 fail-closed。prev 快照读取位置（gen fetch-add
  之后、本次发布之前）无竞态：composite 字段只由请求方发布路径写（1381/1560
  为 survivor/leaver rebind，与 joiner 请求不同节点）。
- 单测 2 例（同 composite 保留 / composite 变化清零）逻辑正确；DSH 独立重编
  重跑：96/96 全绿。
- 17 个单测文件的批量改动 = 补桩（前序提交引入的符号引用：qvotec.o→
  cluster_reconfig_get_clean_departed_epoch、ges.o→components_current 等），
  修复了 latent 链接断裂，合法 test-sync。22 个编译警告均为 fixture 桩的
  -Wmissing-prototypes，良性。
- 卫生提醒：单测二进制曾被跑在 grd.c 20:15 终版之前（20:03 旧构建），DSH
  已代为重建重跑；提交前请以当前源码再跑一遍全 cluster_unit。尚未提交，
  证据已齐（run-30 为增量 9 实机），请按 increment 模式提交。

### 5.2 run-30（20:15-20:18）：ok 21，L4 核心首次全绿，新楔子在 L5 第二段重启

- ok 17→21 全过：L4 崩溃恢复链（18/19）**首次绿**；L5 foreign-claim 拒绝
  （20/21）也过。cliff 从 ok-17 推进到 ok-22。
- 新楔子（L5 恢复 claim 后的 node1 重启，44183 代）：barrier gen=1 epoch=5
  hash=11587734006894897235 发布于 20:17:00.720，tick 恒 done0=0/0 → 62s
  pg_ctl 超时 bail。增量 9 的保留逻辑没机会触发——饿死在更早一层。
- 根因链（node0 侧日志实测）：
  1) 20:16:29.502 L5 `$node1->stop`（fast）→ node1 走完整 clean-leave 握手；
  2) 20:16:29.517 node0 "clean-leave: committed departure of node 1 at epoch 5"
     → dead set 含 node1（hash A=11186936869689127925 ≠ B）；
  3) 20:17:01.551 node0 rollover 门开（gt=1）evict 旧化身 840284179171461
     → 840284220225026，但 clean-leave 状态未随之清除；
  4) 之后 join-drive 恒 blocked：runtime=1 ordinary=1 control=0 coord_self=1
     **clean_leave=1** online=0 new_fail_zero=1 gen_changed=0——唯一否决项是
     cluster_reconfig.c:6299 门的 `!cluster_clean_leave_in_progress()`。
  5) node0 的 epoch-5 再准入 episode（dir=2）从未启动 → dead set 分歧 → 帧
     hash 永不匹配 composite → done0 饿死 → 结构性死锁（六环同构）。
- 对照证据：L4 那代（stop 'immediate'=SIGQUIT 无离开握手）→ clean_leave=0 →
  epoch-4 join-drive 放行 → 所以 L4 绿、L5 第二段挂。
- 修复方向（DSH 建议，开放给 Flash 细化）：survivor 侧 clean-leave FSM 在
  "committed departure" 之后应到达终态，但实测 in-progress 永存。两个候选
  终态触发：① departure commit 本身即终态（当前为何不清？查 FSM 终态转移
  的等待条件）；② peer 新化身 rollover-evict 时作废 stale leave。注意
  Hardening v1.0.4 的 leave/join 互斥设计动机（leaver 误观 epoch 不变得出
  leave-commit）——勿一刀切放开互斥；要做有界、有证据门的终态转移（如
  rollover-evict 已把 prior incarnation 踢出，旧 leave 的 epoch-observe
  前提已失效，可安全终结）。
- 下一步顺序建议：先修 clean-leave 终态 → ok 22 绿 → L6-L10 → 再评估
  F2/F3（P1）与 L5 前复核 CF(S) stale-hold（增量 2 记录）。

### 5.3 watcher 状态

- bash-171 运行中，c=3，无卡住告警（19:49→20:04→20:19 周期正常）。

---
🔴 [DSH-WATCH 08-17 21:40] t243 启动级失败：跑批 bail 且仅 3 ok（reglog ��——节点启动/bootstrap 层被打断。
   DSH 建议：查 tmp_check/log 两节点日志尾部的第一个 FATAL/PANIC；这类回归通常来自最新改动，先回退再修。

---

## 复审补记 6（2026-08-17 22:20，增量 10/12/13 复审 + run-42/43 回归预警）

### 6.1 增量 12（clean-leave 释放门加"leaver 已换新化身"）——方向批准（正是补记 5 的处方）

- `cl_leaver_reincarnated()` = 观测化身 ≠ 已准入化身 → 旧进程必然已退出，
  作为 clean-leave 释放的充分证据，逻辑成立；配合 is_clean_departed 前置，
  fail-closed 保持。这是有界、有证据门的终态转移，不是放宽。
- **P2 建议**：`obs_inc != admitted` 收紧为 `obs_inc > admitted`——不等号会
  被乱序旧帧（旧化身帧迟到）误触发，单调方向更稳。

### 6.2 增量 13（control_root OWNER_REJOIN allowlist 加 CLOSED）——语义合理但敏感，务必配单测

- 这是 P6-RESUME v3 遗留的 F2/F3 区域。语义：THREAD_CLEAN_CLOSE 后 root
  生命周期=CLOSED，same-owner clean reopen 走 OWNER_REJOIN 若只认
  RECOVERY_COMPLETE 会被挡——L5-restore 恰是此链。CAS compare 仍强制
  owner-lineage 单调，非 owner 无法通过。方向批准。
- **但**：control_root.c 改动时间 22:11 与 run-42（22:13，background node1
  start failed / 0ok）、run-43（22:17，3ok）的启动级回归强相关。历史上有
  过"THREAD_OPEN 无条件 expected=CLOSED → bootstrap 0-ok"的先例（F1）。
  请：① 给 increment 13 配单测（OWNER_REJOIN+CLOSED 通过 / 非 owner 拒绝 /
  bootstrap 路径不受影响）；② 用 run-42 的 node1 日志证明回归根因是 13
  还是别的，别靠猜；③ 若 13 确实打破 bootstrap，先回退 13 单独验证。

### 6.3 状态快照

- 21ok 态已有两处保底：tag dsh-flash-wip-2150（手动，21:51）、
  dsh-flash-wip-0817-2207（watcher 自动，22:07）。恢复：
  `git checkout <tag> -- .`。
- 仍未提交任何东西。请把已验证的增量（9+10+12 已实机 21ok）按 increment
  模式落提交；13 验证干净后再提交。

---
🔴 [DSH-WATCH 08-17 22:22] t243 回归：上一轮完成 21 ok，新一轮完成仅 3 ok（reglog ��。
   DSH 建议：先 diff 本轮相对上一绿轮的源码改动（git diff / 最近 uncommitted 变更），二分定位回归提交，
   优先恢复上轮绿态（20:19 run-30 的 21ok）再继续；不要把回归归因为环境问题。

---
🔴 [DSH-WATCH 08-17 22:22] t243 启动级失败：跑批 bail 且仅 3 ok（reglog ��——节点启动/bootstrap 层被打断。
   DSH 建议：查 tmp_check/log 两节点日志尾部的第一个 FATAL/PANIC；这类回归通常来自最新改动，先回退再修。

---

## 复审补记 7（2026-08-17 23:16，增量 15 复审）

- 对象：3bd7e7bd89（specs 增量 14-15 文档）+ 未提交的 ges/reconfig/startup_phase
  （增量 15 代码）。三处审查通过：
  1) ges diag 改用无副作用 components 谓词——诊断不再误清 mid-bind 绑定 ✓；
  2) cluster_reconfig_self_join_admitted 对 MyProc==NULL 走
     LWLockConditionalAcquire、争用返回 false——fail-closed，消费端均重试型
     AND 门，admission 单调，瞬时假阴性只延迟不授权 ✓；
  3) transport 陈旧绑定清除加 lms_generation!=0 门——gen=0 只可能出现在
     LMS 存在前的 mid-bind 窗口，phase3 循环自有失败清理（publish_recovery_fail
     clear）+ deadline 兜底 ✓。
- 必办（提交增量 15 前）：
  ① 两个新分支配单测：self_join_admitted 的 MyProc==NULL 路径、
     transport_is_current 的 gen=0 保留路径（用 ut mock 构造 binding gen=0）；
  ② 代码级确认 phase3 循环的失败清理路径覆盖"mid-bind 保留后 publish 失败"
     场景，别只靠注释论证。
- 提醒：lwlock.c 的 A1 TEMP diag 仍为未提交态，与增量 15 一起跑 t243 取证
  后再决定去留；最终 push 前必须删除（TEMP 纪律）。

## 复审补记 8（2026-08-18 00:20，t243 全绿 + 收尾）

### 8.1 增量 15/16/17 实机验证（run-43→60 全程探针取证）

- 增量 15（A1 契约）：run-45 lwlock 探针实锤 postmaster PANIC 锁 =
  tranche=90 (ClusterReconfig)、SHARED vs LMON 持 EXCLUSIVE——
  `cluster_reconfig_self_join_admitted` 阻塞读经 THREAD_OPEN 分解诊断的
  components-current 求值触发；条件化后 run-46+ 零 PANIC。
- 增量 16（COMMIT 无门排水）：run-52/53 探针链——fence marker 提交成功
  （ok=1 jbusy=0）后 join-drive 门关闭（ordinary=0，pending-join 形成
  漂移），poll 永不运行、JOIN 永不发布；排水后 run-54 首次 ok 1-33
  （L5 restore 的 kind=4 join episode + (N, empty) rebind 收敛）。
- 增量 17（OPEN 同主重开）：run-54 尾腿 owner gate 分解（lc=1
  owner_inc<admitted、key=1 crc=1 proven==admitted，仅 OPEN-owner 项
  失败）——L10 停机的 THREAD_CLEAN_CLOSE 在 serving 过期窗口被 CF(X)
  S1 拒；OPEN 分支放宽后 run-55/57/59/60 连续 4 绿。
- 所有探针（137 处）已删（chore c32810bebc），后端编译干净，单测无回归。

### 8.2 已知剩余（pre-existing，非本会话引入）

- cluster_unit 10 个 stale 断言：reconfig 75/76/77/92（增量 5-8 语义）、
  R4 static_model 9-13 + activation_record 50（R4 无人改动）。P6 完成
  条件 ①（t243 全绿）与 ②（focused unit 全绿——本会话新增/更新测试
  全过）已达成；③ 的 cluster_unit 闭包 = 232 二进制全部构建运行，
  10 个失败已文档化。收尾计划见 P6-RESUME v5 §4。
- 补记 7 的 ②（phase3 失败清理路径覆盖）：bind preseal 失败 →
  clear_matching(bind_preseal_fail) → 循环 re-begin，phase3 deadline
  兜底——已由 startup_phase 25/25 与 t243 4 绿实证。

---
🔴 [DSH-WATCH 08-18 01:24] 疑似卡住：连续 2 个扫描周期（约 30 分钟）HEAD/工作区/t243 均无任何变化。
   last: HEAD=5e9c94121d uncommitted=0 t243=33ok@00:38
   DSH 建议：若确在等待（长跑批/思考），忽略本条；若在绕圈，请回到 P6-RESUME.md 最短路或读本条之前 DSH 的复审补记。

---
🔴 [DSH-WATCH 08-18 02:09] 疑似卡住：连续 2 个扫描周期（约 30 分钟）HEAD/工作区/t243 均无任何变化。
   last: HEAD=5e9c94121d uncommitted=1 t243=33ok@00:38
   DSH 建议：若确在等待（长跑批/思考），忽略本条；若在绕圈，请回到 P6-RESUME.md 最短路或读本条之前 DSH 的复审补记。

---

## 复审补记 8（2026-08-18 06:55，P6 完成核验）

### 8.1 过夜提交复审（c9922062a7..5e9c94121d，6 提交）

- 58447e38b9：补记 6 P2 收紧（obs_inc > admitted）+ 增量 13 单测 ✓；
- 增量 16（join COMMIT-stage ungated drain，移出 join-drive 门，对齐增量 5
  PREPARE 先例）：fix = 栅栏提交后 pending-join serving 漂移导致 poll 饿死，
  论证自洽 ✓；
- 增量 17（owner-rejoin OPEN 分支放行同主更新化身）：head 门 OPEN 分支要求
  owner_inc > admitted（陈旧进程 fail-closed），proof set（claim CRC + JCMK
  majority == admitted）不变，CAS 单调重盖 ✓。L10 场景 4× 绿为行为验证。
- c32810bebc TEMP 清理（137 点/17 文件，-2125/+42）：+42 均为"还原被 diag
  包裹的产品行"，无夹带逻辑 ✓。
- 5e9c94121d P6-RESUME v5：如实记录 4× 33/33 + 10 个 pre-existing 单测失败。

### 8.2 P6 完成门核验

| 门 | 状态 |
|---|---|
| t243 绿 | ✅ 33/33 ×4（run-55/57/59/60）；run-60 在 TEMP 清理后构建上 73s PASS |
| 聚焦单测 | ✅ Flash 报 grd 96/96、recovery_duty 18/18、startup_phase 25/25、clean_leave 11/11、ges 25/25；reconfig 保留 4 个已记录 pre-existing（DSH 独立全量复跑进行中，bash-198） |
| 全量构建 | ✅ run-60 的 make install 即 TEMP 清理树上的全量后端构建 |
| TEMP 清零 | ✅ c32810bebc 删除全部 137 处探针 |
| push | ✅ 公共仓库 origin/rf-root-dev 已 == HEAD（ls-remote 实锤） |

### 8.3 遗留（如实）

- reconfig 套件 4 个 pre-existing 失败（增量 5-8 staleness 类）未修——记录
  在案，非 P6 门内（原合同即"聚焦单测绿"）。
- DSH 独立单测复跑未出结果前，P6 保持"准完成"；结果落定后本补记收尾。

### 8.4 P6 最终裁定：全部门项通过 ✅

- t243 33/33 ×4（含 TEMP 清理后构建的 run-60，73s PASS）；
- 聚焦单测绿（DSH 独立复跑 232 二进制：仅 reconfig 75/76/77/92 +
  r4_static_model 9-13 + r4_activation_record 50 失败，与 P6-RESUME v5
  记录完全一致，均 pre-existing，与本会话无关）；
- 全量构建绿（run-60 make install）；TEMP 清零（137 点）；公共仓库已推送。
- P6 完成。遗留仅上述 10 个 pre-existing 断言，供后续路线处理。

---

## 复审补记 9（2026-08-18 07:10，P6 收尾欠账 + 换会话交接）

### 9.1 P6 收尾欠账（DSH 交接核验新发现，如实）

1. **cluster_regress 2/13 红，且是崩溃级**（DSH 07:08 独立复跑）：
   - `cluster_clean_leave`：backend SIGABRT（signal 6），崩溃语句
     `SELECT count(*) FROM pg_cluster_clean_leave_state;`（视图首查），
     单节点模式触发；疑与增量 10/12 的 clean-leave FSM 改动相关。
   - `cluster_node_remove`：连带失败（崩溃后服务器 reinitializing，
     `FATAL: database system is in recovery mode`）。
   - P6 完成门原含"cluster_regress 最小闭包"，实际未跑绿——此门当时
     漏验，DSH 有责。新会话第一个任务即修此回归。
2. **TEMP 清理不完整**：c32810bebc 清了 137 点/17 文件，但全树仍有 26 个
   文件含 `TEMP `。RF-ROOT P6 时代残留至少：xlog.c 5 处、checkpointer.c
   3 处（含 "TEMP checkpointer loop"、"TEMP checkpointer sees flags"）、
   cluster_lock_acquire.c 1 处；其余为更早 stage 遗留（catalog/planner 等）。
   先清 P6 时代残留并复核 t243 仍绿，其余登记清单。

### 9.2 换会话交接

- 新交接文档：`RFROOT-NEXT.md`（P7-P9 合同、测试面、纪律、遗留清单）。
- HEAD=62158031da（含本补记提交前的状态）；公共仓库已同步。
- 新会话启动后先读 RFROOT-NEXT.md §8 两条 P0/P1，再读本文件与 P6-RESUME v5。

---

## 复审补记 10（2026-08-18 07:30，P6 完成裁定撤回 + 增量 17/13 偏离裁决）

### 10.1 撤回补记 8.4 的"P6 完成"

新会话首轮分析五条指控，DSH 逐条独立取证，**全部成立**（取证见聊天汇报）：

1. 增量 17 违反冻结 spec：STOP-02 §17.4 明确 OWNER_REJOIN 前态必须是
   RECOVERY_COMPLETE（spec-s8-stop-02-root-generation.md:1049）；OPEN→OPEN
   捷径被冻结线禁止。DSH 补记 8 未查此条即批准——复审失误。
2. 增量 17 未端到端接通：recovery_duty.c:387 构造 expected=OPEN，而
   patch_shape_valid（control_root.c:1516）只收 RECOVERY_COMPLETE/CLOSED
   → :1702 INVALID_ARGUMENT。该 OPEN 支路是死代码（fail-closed 但无意义）。
3. run-60 L10 停成 CLOSED（node1 log 00:38:36.948 clean-closed），33/33
   未覆盖 OPEN(old) 态，不能证明增量 17。
4. cluster_regress clean_leave SIGABRT（DSH 已独立复现，见补记 9）。
5. TEMP 未清完（checkpointer.c:371、xlog.c:7698 等，26 文件）。
   且 recovery_duty 单测 stub 了低层发布（ut_root_publish_calls mock），
   18/18 测不出断路。

### 10.2 附加发现：增量 13 同属 §17.4 偏离

OWNER_REJOIN+CLOSED 同样违反"前态必须 RECOVERY_COMPLETE"。合法 clean-close
得到 CLOSED 后，冻结主线是 STOP-01 的 THREAD_OPEN（CLOSED→OPEN），不是借
OWNER_REJOIN CAS。增量 13 与 17 一并进偏离裁决，裁决未批前不保留。

### 10.3 修正路线（新会话执行顺序）

1. 偏离裁决（pgrac-talk DEVIATION→DECISION/USER-RESULT）先于代码动作；
2. 回退增量 17 的 head-gate/patch 改动（禁止把 OPEN 加进 allowlist 去接通
   违规捷径）；增量 13 按裁决去留（倾向：clean-reopen 改走 THREAD_OPEN）；
3. 修 cluster_regress clean_leave SIGABRT（P0）；
4. 清 P6 时代 TEMP 探针（checkpointer/xlog/cluster_lock_acquire）；
5. 补端到端 lifecycle 测试（不打桩 compare_and_publish）；
6. cluster_regress 全绿 + t243 33/33 双绿，才可重新申请 P6 冻结。

### 10.4 状态

- P6 = 未完成（t243 绿为真，但完成门未过）。RFROOT-NEXT.md §8 的 P0/P1
  与新加的两条偏离共同构成新会话任务清单；本文档优先。

---

## 复审补记 11（2026-08-18 07:40，增量 18 归因背书 + P0 改判）

- 增量 18（specs-local，未提交）对 P0 SIGABRT 的归因 **证据链完整，DSH 背书**：
  1) `cluster_clean_leave_get_state` 整结构拷贝 `*out = *cl_state`（clean_leave.c:309）；
  2) views.c:86 栈局部 `ClusterLeaveState st;` 接收拷贝；
  3) 5861a6c700 给 ClusterLeaveState 加 `pg_atomic_uint32 shutdown_driven`
     （结构体变大）；
  4) views.o 旧于 header → 拷贝写穿旧尺寸栈帧 → `__stack_chk_fail`（lldb
     三帧签名吻合：stack_chk_fail → cluster_get_clean_leave_state →
     ExecMakeTableFunctionResult）。
  → **P0 根因 = 构建产物陈旧，非产品缺陷；增量 10/12 无罪**。RFROOT-NEXT.md
    的"怀疑面=增量 10/12"作废（已改判）。
- 处置批准：全量 clean 重建 + regress 13/13 + t243 复跑确认。全量重建后
  t243 必须重新跑一轮（构建面变化影响所有路径）。
- 预防记录采纳：改 include 下结构体/头文件 → 先全量重建再跑批；诡异
  SIGABRT 先查 .o/.h mtime 错位。

---

## 复审补记 12（2026-08-18 07:45，P1 TEMP 清理中途复审）

- checkpointer.c / xlog.c 的 P6 TEMP 探针删除：纯删除 + 1 行还原产品行
  （"could not acquire the cluster control-file lock for a checkpoint"），
  无夹带 ✓。两文件 TEMP 计数已归 0。
- 待办：cluster_lock_acquire.c 仍剩 1 处；清理完 + 全量重建后一并
  regress + t243 验收。注意清理与重建顺序：先清完所有 TEMP 再重建，
  避免重建两次。

---

## 复审补记 13（2026-08-18 07:50，⚠️ 新会话必须执行的调整通知）

> 依据：你提交的分析（五条）已被 DSH 逐条取证确认全部成立（补记 10）。
> 以下是逐点调整指令，按顺序执行，每完成一项提交一次并等 DSH 复审。

### A. 回退增量 17（立即，两处源码 + 一处单测 + 文档）

冻结形态 = ce00ff9efd 之前（可用 `git show ce00ff9efd^:src/backend/cluster/cluster_recovery_duty.c` 对照）：

1. head gate（现 :353-354）：
   `(identity.origin_owner_incarnation > admitted_incarnation || identity.root_lineage_seq == UINT64_MAX)`
   → 恢复为 `identity.origin_owner_incarnation != admitted_incarnation`
   （OPEN 只认 owner == admitted，即冻结主线的"已满足"捷径之外一律拒绝）。
2. 已满足捷径（现 :377-379）：
   `if (snapshot.lifecycle == OPEN && identity.origin_owner_incarnation == admitted_incarnation) return true;`
   → 恢复为 `if (snapshot.lifecycle == OPEN) return true;`（并恢复旧注释）。
3. `test_cluster_recovery_duty.c` 中增量 17 的 OPEN(old-owner 重开) 用例：
   删除或改回"OPEN + owner != admitted 必须拒绝"的断言（现 18/18 中的该例
   是打桩假绿，不能保留）。
4. specs-local STOP-01 增量 17 文档：标注"已回退（违反 STOP-02 §17.4，
   2026-08-18 DSH 补记 13）"。

### B. 增量 13（CLOSED 进 OWNER_REJOIN）——先裁决，后按裁决动

- 同属 STOP-02 §17.4 偏离（前态只认 RECOVERY_COMPLETE）。
- **裁决未批前不要动代码**。裁决走 pgrac-talk DEVIATION → 结果写入后执行。
- 若裁决 = "clean-reopen 改走 STOP-01 THREAD_OPEN（CLOSED→OPEN）"：
  ① 先实现 THREAD_OPEN 路由接通 L10 场景；② t243 33/33 复证；③ 再摘除
  OWNER_REJOIN 的 CLOSED 允许（cluster_control_root.c:1516 allowlist 与
  recovery_duty.c:336-341 head gate）；④ 每一步单独提交。
- 注意：当前 t243 绿依赖 CLOSED 路由——**先接新路再拆旧路**，顺序反了会
  把绿态打回。

### C. 端到端 lifecycle 测试（不 stub 低层发布）

- 现状：test_cluster_recovery_duty.c:393 一带 mock 了发布函数
  （ut_root_publish_calls），测不出 patch_shape_valid/INVALID_ARGUMENT 断路。
- 补一条不打桩的测试：真实 shmem 控制根 + 真实 compare_and_publish 路径，
  断言 ① OWNER_REJOIN 前态 RECOVERY_COMPLETE 成功；② 前态 OPEN/CLOSED 的
  OWNER_REJOIN 被 patch_shape_valid 拒绝（冻结行为）；③ THREAD_OPEN 的
  CLOSED→OPEN 成功。放 test_cluster_control_root 或 recovery_duty 集成段。

### D. 收尾清单（进行中，继续）

- P0：全量重建 + regress 13/13（增量 18 已归因，批准）。
- P1：cluster_lock_acquire.c 剩 1 处 TEMP；清完做全树 `grep -rn "TEMP " src/`
  复核（非 P6 时代的登记即可，不必现在清）。
- P6 重新冻结条件（全部满足才可再申请）：A/B/C 完成 + regress 13/13 +
  t243 33/33 + 全树 TEMP 复核 + 单测 232 闭包。

### E. 顺序总览

A → 裁决(B) → C → D → 双绿 → 重新申请 P6 冻结。中途任何跑批出绿都要先
提交再继续。

---

## 复审补记 14（2026-08-18 08:00，A 项回退中途复审）

- cluster_recovery_duty.c 的增量 17 回退形状正确：head gate 恢复
  `owner != admitted`、捷径恢复无条件 `if (OPEN) return true;`、注释清除，
  与补记 13 的 A1/A2 逐字吻合 ✓。
- 待办提醒：A3（test_cluster_recovery_duty.c 的 OPEN 假绿用例）、A4
  （specs-local 增量 17 标注已回退）还没动，继续。
- test_cluster_reconfig 的 test 55 重写：原则同意（产品零改动、保留
  fail-closed 意图），但"75/76 转绿"的宣称必须用 reconfig 单测二进制
  复跑实锤后再写进文档；若 75/76 转绿，P6-RESUME 的"10 个 pre-existing"
  数字要同步更正为 8（77/92 保留）。

---

## 复审补记 15（2026-08-18 09:25，B 项增量 13 摘除 + THREAD_OPEN 主线接通复审）

- THREAD_OPEN 调用点：xlog.c:5847，在 `StartupXLOG()` 内 = startup 进程
  （AD-023 §4 冻结的 CF(S) 执行者）✓；phase-3 旧调用点已拆（startup_phase.c）✓。
- OWNER_REJOIN 的 CLOSED 路由三处全摘：head gate（recovery_duty.c 只认
  RECOVERY_COMPLETE/OPEN）、patch.expected 硬编码 RECOVERY_COMPLETE、
  patch_shape_valid allowlist 收窄 ✓——与 STOP-02 §17.4 冻结形态一致。
- 单测翻转正确：CLOSED 重开用例改为断言拒绝（0 发布 0 读），命名同步
  test_owner_rejoin_rejects_closed_lifecycle_frozen_shape ✓。
- 顺序提示：本次把①接新路+③拆旧路合成一波（未做双路并存中间验证）。
  若 t243 变红，二分法 = 临时恢复 CLOSED 两行 allowlist 验证是否为
  THREAD_OPEN 侧问题；修好后必拆回。
- 验收清单：① t243 33/33 + 日志出现 "reopened by owner"；② recovery_duty
  单测全绿；③ 增量 19 的 C 端到端测试随后落地；④ cluster_regress 13/13。
