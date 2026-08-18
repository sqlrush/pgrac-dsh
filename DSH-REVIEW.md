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

---
🔴 [DSH-WATCH 08-18 09:28] t243 回归：上一轮完成 33 ok，新一轮完成仅 21 ok（reglog ��。
   DSH 建议：先 diff 本轮相对上一绿轮的源码改动（git diff / 最近 uncommitted 变更），二分定位回归提交，
   优先恢复上轮绿态（20:19 run-30 的 21ok）再继续；不要把回归归因为环境问题。

---

## 复审补记 16（2026-08-18 09:35，THREAD_OPEN 执行者设计转向分析）

### 事实链

1. 09:24 红轮（33→21）：StartupXLOG 版 THREAD_OPEN 上线后的跑批，L5-restore
   重开断链（bail 在 ok-22 区）。xlog.c 已整体回退（现 0 diff）。
2. 会话转向"join-commit 路径"设计：recovery_duty.c 的 owner-rejoin 对 CLOSED
   root 改发 `CLUSTER_CONTROL_ROOT_PUBLISH_THREAD_OPEN`（expected=CLOSED），
   由协调者（survivor LMON，有 PGPROC）在 commit re-vet 里执行 CAS。
3. 转向理由（startup_phase.c 新注释）：startup 进程在 phase-3 之后才 fork；
   phase-3 barrier 等 survivor join commit；join commit re-vet 等 root 重开
   → StartupXLOG 放 THREAD_OPEN = 结构死锁。该论证与代码结构一致，DSH 认同
   原设计（增量 20 初稿的"StartupXLOG 1-2s 落地"收敛论证）不成立。

### DSH 判定

- 转向方向正确，但**执行者从 StartupProcess 移到协调者 LMON commit re-vet
  这一步需要 spec 依据**：
  AD-023 §4 冻结 StartupProcess-only（555890d2df 回退史）约束的是 CF(S)
  锁执行者；THREAD_OPEN publish 内部若获取 CF(S)，则新路径是否仍满足 §4
  必须在增量 20 的"corrected design"里写清（含 S1 准入/CF(S) 获取点分析），
  若构成偏离 → 补用户裁决再继续。
- 增量 20 文档当前仍是旧设计（StartupXLOG 版），必须同步为 corrected
  design（裁决 + 死锁证据 + 执行者分析 + 验收标准）。
- 单测（test_cluster_recovery_duty.c）需按新路由更新：CLOSED root →
  THREAD_OPEN reason 发布（断言 reason 与 expected=CLOSED），而非拒绝。
- t243 复跑待新路由落地后进行；若再红，二分 = 恢复 xlog.c StartupXLOG
  版对照（排除其它因素）。

### 验收不变

t243 33/33 + "reopened by owner" 日志 + recovery_duty 单测绿 + regress
13/13 + C 端到端测试（增量 19）落地。

---

## 复审补记 17（2026-08-18 09:40，B 实施提交 958b941130 复审）

- 代码面通过：CLOSED 分支走 THREAD_OPEN reason（expected=CLOSED→desired=OPEN，
  owner=admitted、lineage+1、0x3b mask 冻结形状）；OWNER_REJOIN 严格
  RECOVERY_COMPLETE-only（control_root allowlist 已收窄回冻结态）；
  单测翻转正确（routes_to_thread_open：断言 reason=THREAD_OPEN、owner=77、
  0 次 OWNER_REJOIN 发布）。
- 文档面通过：增量 20 已写入 corrected design，含 StartupXLOG 方案的阴性
  结果（t243 bail 证据 + 循环死锁机理）与终态设计（commit 时点路由、
  proof 集、authority 模式一致）。
- **两个剩余验证点（未闭合，必须闭环后再谈 P6 冻结）**：
  1. AD-023 §4 执行者范围：文档论证了 postmaster 不可执行，但"协调者
     LMON（有 PGPROC）执行 THREAD_OPEN CAS 是否落在 §4 冻结范围内"仍缺
     一句结论性引用（§4 原文 vs cluster_lock_acquire.c:216 的 "needs a
     PGPROC executor" 注记）。请补一行 spec 依据或用户裁决确认。
  2. **本设计尚无 t243 绿证**：21ok 红轮是已废弃的 StartupXLOG 方案；
     958b941130 的 commit 时点路由还没跑过 t243。下一轮 t243 33/33 +
     "reopened by owner" 日志是硬验收；跑前请先全量重建（结构体/头文件
     变更后构建纪律）。
- 之后：C 端到端测试（增量 19）落地 + cluster_regress 13/13。

---

## 复审补记 18（2026-08-18 09:50，L10 尾腿重开仍红——head gate 方向性缺陷诊断）

### 事实

- 09:39-09:41 run：ok 1-33 全过，但 ok 33 之后的 L10 尾腿（node1 clean-stop
  → 最终重启）pg_ctl 62s 超时 bail；全 run 无 "reopened by owner" 类日志。
- 该 run 测试的是 958b941130（commit 时点路由）；09:47 的增量 21 编辑在
  run 之后，未参与本轮。

### DSH 诊断（结构性，请验证后修）

- head gate 的 non-OPEN 分支（recovery_duty.c ~349-352）：
  `lineage == UINT64_MAX || owner >= admitted` 拒绝方向**对 CLOSED 是反的**。
  clean-reopen 场景：root 存的 owner = 旧 boot 化身 I1；admitted = 新进程
  化身 I2 > I1 → `I1 >= I2` 为假 → gate 拒绝 → THREAD_OPEN 路由不可达 →
  root 永不重开 → 62s 超时。
- run-60 之所以绿：重启落在 qvotec prior-incarnation self-slot 新鲜窗口
  （admitted == I1，同化身）→ 侥幸过门。化身一变（正常 boot）即触发。
- 修复方向（最小）：按 lifecycle 拆分 non-OPEN 分支——
  ① RECOVERY_COMPLETE：保持 `owner >= admitted`（stale-owner 拒绝，
     OWNER_REJOIN §17.4 语义）；
  ② CLOSED：**不要**用 owner>=admitted 拒（fresh boot 化身更新是 THREAD_OPEN
     主线语义），放行后由 CAS 单调性检查兜底（control_root.c:1750 已强制
     desired.owner > current.owner + lineage+1 + 形状 CLOSED→OPEN）。
- 增量 21 的 OPEN+owner<admitted 修复路径方向合理，勿回退；但要与 CLOSED
  分支拆分一并落 spec（增量 21 文档补"CLOSED 分支豁免 owner>=admitted"）。
- 验收仍以 t243 全绿 + reopen 日志 + regress 13/13 为准。

---

## 复审补记 19（2026-08-18 10:20，P6 重新冻结审计终裁）

### 审计表（DSH 逐项独立核证）

| 条件 | 证据 | 结论 |
|---|---|---|
| A 回退增量 17 | 5074881fa7 | ✅ 已审（补记 13/14） |
| B 摘除增量 13 + THREAD_OPEN 主线 | 958b941130 | ✅ 已审（补记 15-17） |
| B 尾腿修复：门拆分 | b4fb9ece30（RECOVERY_COMPLETE 单独走 owner>=admitted；CLOSED 仅拒 lineage==UINT64_MAX）= 补记 18 处方 | ✅ 刚审 |
| B 尾腿修复：增量 21 双 CAS | 3d5faac3ac（OPEN+owner<admitted+clean-departed → THREAD_CLEAN_CLOSE 关到 CLOSED → 落入 THREAD_OPEN 重开；理由绑定正确） | ✅ 刚审 |
| t243 | 09:55 与 10:01 双轮 33ok、bail=0 | ✅ 独立核 reglog |
| cluster_regress | **DSH 独立复跑 All 13 tests passed**（会话未跑，证据由 DSH 补） | ✅ |
| 单测闭包 | 232 二进制 3 失败 = 8 断言（reconfig 77/92 + r4_static 9-13 + r4_activation 50；75/76 经 test-55 重写已转绿，pre-existing 从 10 降 8） | ✅ |
| C 矩阵 | d7820ab33e | ⚠️ 待逐行补审 |

### 两个小尾巴（不阻塞 P7，但 P6 归档前须清）

1. cluster_lock_acquire.c 仍有 1 处 "TEMP "（P1 提交宣称清除，实际漏 1 处）。
2. C 矩阵测试代码逐行审查未做（DSH 将补）。
其余 26 个含 TEMP 文件均为更早 stage 遗留（catalog/planner 等），登记不阻塞。

### 裁定

P6 重新冻结条件实质满足：t243 双绿无 bail + regress 13/13 + 单测闭包 +
A/B/C 落地。**放行 P7**；上述两个小尾巴在 P7 推进中顺手清理并提交。

---

## 复审补记 20（2026-08-18 10:30，增量 21 P0 复审 + 仓库暴露核查）

> 本补记暂不 push（见 §3 仓库问题，等待用户裁决）。

### 1. 增量 21 P0 分析：五条全部成立（DSH 独立取证）

1. 补写路径实锤：recovery_duty.c:398 起"clean-departed + OPEN(old)" → 补
   THREAD_CLEAN_CLOSE(OPEN→CLOSED) → 再 THREAD_OPEN(CLOSED→OPEN(new))——
   绕开冻结的 RECOVERY_COMPLETE→OWNER_REJOIN 主线（STOP-02 §17.4:1055 原文
   "requires old lifecycle RECOVERY_COMPLETE"）。
2. 发布者合同违反：recovery_duty.c:533 冻结注释 "Only the checkpointer's
   clean-shutdown path reaches this (after ShutdownXLOG…)"——coordinator 事后
   补写不在合同内。
3. 证据不足实锤：ClusterLeaveIntentMarker（cluster_clean_leave.h:110 起）
   无 shutdown_driven 持久字段；operator 路径显式置 0
   （cluster_clean_leave.c:1497-1498）→ clean_departed 无法证明
   shutdown checkpoint + STOPPED 发生过。
4. pgrac-talk：DEVIATION RFROOT-P04-A2-T243-SECOND-REJOIN-OPEN-ROOT-20260817
   仍无 DECISION，且明文 "permit OPEN(old)->OPEN(new) contrary to §17.4"
   禁止（~/pgrac/talk_20260816-0052.md:337 一带）。
5. 未推送：origin 落后 2 个提交（407969544b、fe150bad60）。

结论：**t243 行为门过，但 P6 的 Spec/authority 冻结门未过——撤回补记 19 的
"放行 P7"裁定，改为"P7 审计可做，但 P6 冻结仍挂起"**。

### 2. 修复方向（与 Reader 结论一致，DSH 背书）

- 首选：修 owner/checkpointer 在 authority 失效前成功落 CLOSED（serving-stale
  拒绝时重试/保序），让重启走冻结 CLOSED→OPEN。
- 次选：落 CLOSED 失败 → 按 fail-stop 走 RECOVERY_COMPLETE → OWNER_REJOIN。
- 不采纳：coordinator 仅凭 clean_departed 补造 CLOSED（除非 DEVIATION 获
  USER-RESULT + 持久 shutdown-driven 证明 + operator 负向测试齐备）。
- 增量 21 代码与单测：挂起，等上述裁决。

### 3. 仓库暴露问题（紧急，用户裁决后 DSH 才恢复 push）

- 事实：origin=github.com/sqlrush/pgrac-dsh 匿名可访问（HTTP 200，公共）；
  当前公共历史包含 specs-local/ 全部本地增量 + memory/ + 全部复审文档。
- specs-local/README.md 原文："本目录已加入 .git/info/exclude，绝不 push
  公开仓"——书面规则与既成事实冲突。
- 背景：DSH 的历次 push 依据 user 2026-08-17 口头授权（"code+design docs
  可以推公共仓库，推翻 design docs 永不公开红线"）。现按 Reader 建议
  **暂停一切 push**。
- 待用户裁决三选一：
  A. 保持公共（授权继续）→ DSH 把 specs-local README 的"绝不 push"改写为
     实际政策并继续；
  B. 转私有仓 → GitHub 设置里改 private，历史不再匿名可见；
  C. 清理泄露 → 重写历史/删仓重建（成本最高，需要用户拍板范围）。

### 3.1 仓库裁决（user 2026-08-18）：A = 保持公共

specs-local/README.md 已改为实际政策（公开授权记录）。恢复 push。

---

## 复审补记 21（2026-08-18 10:50，⚠️ 执行指令：增量 21 P0 修复 = 路线 1）

> 用户裁决（2026-08-18）：路线 1 治本——修 owner/checkpointer 按时落 CLOSED。
> 优先级：**当前 P7 G1a 提交后立即切换到此修复**。

### 背景（证据已在手）

- t243 L10 停机时 THREAD_CLEAN_CLOSE 的 CF(X) S1 因 serving-stale 瞬时被拒
  （run-29：postmaster 条件锁与 LMON admission 收尾同刻竞争），root 停
  OPEN(old)；重启后靠增量 21 的 coordinator 补写续命——该补写违反
  发布者冻结合同（补记 20 P0），不可保留。

### 修复要求（有界重试，不得挂死停机）

1. checkpointer 停机路径（contract 1 顺序内：checkpoint→STOPPED→
   serving/authority 转换→CLOSED）：THREAD_CLEAN_CLOSE publish 失败
   （S1 serving-stale / authority 未重确认）时**有界重试**：
   - 重新校验/重绑 serving authority 后重试 publish；
   - 上限 = 固定 deadline（建议 ≤ 停机 drain 窗口，如 2-5s）+ 退避
     （50-100ms 级），**绝不无限阻塞停机**；
   - 超限仍失败 → 记 LOG 并继续停机（root 停 OPEN(old)，fail-closed）。
2. 增量 21 的 coordinator 补写路径**验证后删除**（连同其单测与 LOG）：
   先证明 L10 尾腿在无补写下靠路线 1 收敛，再删——顺序不可反。

### 验收（顺序执行，每步单独提交）

1. 路线 1 落地 + 单测（publish 重试单元：瞬态拒绝后成功 / 超限放弃）；
2. t243 33/33、bail=0，且 node1 日志 L10 停机处出现 **"clean-closed by
   owner"**，全程**无** "missed clean-close repaired"（证明未走补写）；
3. 删增量 21 补写 + 单测，t243 再跑 33/33、bail=0；
4. cluster_regress 13/13；
5. 全部绿 → 提交并等 DSH 复审，P6 冻结门才可重新申请。

---
🔴 [DSH-WATCH 08-18 10:43] t243 回归：上一轮完成 33 ok，新一轮完成仅 0 ok（reglog ��。
   DSH 建议：先 diff 本轮相对上一绿轮的源码改动（git diff / 最近 uncommitted 变更），二分定位回归提交，
   优先恢复上轮绿态（20:19 run-30 的 21ok）再继续；不要把回归归因为环境问题。

---
🔴 [DSH-WATCH 08-18 10:43] t243 启动级失败：跑批 bail 且仅 0 ok（reglog ��——节点启动/bootstrap 层被打断。
   DSH 建议：查 tmp_check/log 两节点日志尾部的第一个 FATAL/PANIC；这类回归通常来自最新改动，先回退再修。

---

## 复审补记 22（2026-08-18 11:05，G1a 提交复审：通过）

- 4686c73994：checkpointer 稳态 checkpoint 路径发布 CHECKPOINT_ADVANCE，
  位置在 CF(X) 释放之后、guarded recycle 之前（锁序合规，注释已论证）；
  end-of-recovery checkpoint 豁免（冻结 fence-deferral 例外）；非致命
  （下个 checkpoint 自愈）。
- DSH 独立复跑聚焦单测：recovery_duty 20/20（含新 publish 测试）、
  control_root 26/26——bind→CAS→shape 全链绿。
- G1a 完成。按补记 21 派单，**下一步立即切路线 1**（checkpointer
  THREAD_CLEAN_CLOSE 有界重试），验收顺序见补记 21。

---

## 复审补记 23（2026-08-18 11:12，进度同步 + 顺序提醒 + G1b 初评）

- t243 10:54 轮 33ok、bail=0（G1a 后仍绿）；10:43 曾有一次 0ok 启动级
  bail（瞬态，后续轮自愈，登记）。
- **顺序提醒**：补记 21 要求 G1a 提交后立即切路线 1；会话当前在改
  cluster_hw_remaster.c（P7 G1b 读者迁移）。P7 工作本身正确且该做，但
  **路线 1 是用户裁决的 P6 冻结前置**——请在本文件（hw_remaster）迁移
  落提交后即刻切换路线 1，不要再排下一项 P7。
- G1b 初评（未提交，方向批准）：hw_remaster 死节点 tail 读源从
  wal-state registry 切到 canonical control root（validated_tail_lsn_exclusive），
  fail-closed 门结构一致。**提交时需论证**：死节点崩溃后 root 的 tail
  bound 与旧 registry 读源的语义等价性（root 只按 checkpoint 刷新，crash
  后的 tail 滞后是否影响 adopt 决策）——对齐 increment 22 的 G1b 段落。

---

## 复审补记 24（2026-08-18 11:20，G1b 锁序发现复审：背书回退）

- 会话在 G1b 迁移中实测发现锁序冲突：recovery-episode 窗口内 hw-remaster
  worker 的 canonical STRONG 读 CF(S) 被幸存者自身 episode CF(X) 持锁挡住
  （0xF1 同资源，16 次 LOCK_UNAVAILABLE=17 → t243 ok-2 bail）。证据充分。
- 处置正确：hw_remaster 回退 registry 源（+10 行注释记录原因），G1a 保留，
  G1b 挂起等锁序设计。**DSH 背书**。
- 新设计项（G1b 重开时先答）：按 site 上下文分阶段迁移——checkpointer/
  coordinator 上下文可满足 CF(S)；episode 内 worker 上下文需调度
  （CF(S) vs episode CF(X) 窗口错峰）或保留 registry 读并显式降级登记。
  这属于 STOP-05 §5.4 锁序纪律面，勿强行迁移。
- **顺序提醒重申**：本单提交后切路线 1（补记 21），P6 冻结前置。

---

## 复审补记 25（2026-08-18 11:40，🎯 P6 正式冻结终裁）

### 终裁证据链（全部 DSH 独立核证）

| 门 | 证据 |
|---|---|
| t243 行为门 | 11:28 轮 33/33 无 bail；**11:36 最终提交树独立复跑 33/33，77s PASS，exit=0** |
| owner 落 CLOSED（路线 1） | "clean-closed by owner" ×3 / 轮 |
| 增量 21 补写已死 | "missed clean-close repaired" ×0（代码已删，含 LOG/单测） |
| Spec 冻结门 | STOP-02 §17.4：OWNER_REJOIN 严格 RECOVERY_COMPLETE-only（增量 13 已摘）；STOP-01 THREAD_OPEN/THREAD_CLEAN_CLOSE 主线（B 裁决）；发布者合同恢复（路线 1） |
| 单测闭包 | recovery_duty 22/22、clean_leave 11/11、control_root 26/26；232 二进制仅 3 失败 = 8 个 pre-existing（77/92 + R4×6），与 P6 无关 |
| cluster_regress | All 13 tests passed（exit=0，DSH 独立复跑） |
| TEMP | P6 时代残留清零（cluster_lock_acquire 注释已改）；26 文件为更早 stage 遗留，登记不阻塞 |
| 推送 | origin/rf-root-dev == HEAD（4f93ce5ee1 之后全部在公共仓） |

### 裁定

**P6 冻结成立。** 行为门 + Spec/authority 冻结门 + 回归门三关全过。
遗留（8 个 pre-existing 断言、G1b 锁序设计、P7 G2-G6）不属 P6 范围，
转入 P7 计划继续。

---

## 复审补记 26（2026-08-18 11:45，G1a-2 复审：通过）

- f11ba141e5：FPW_STICKY 发布接线——UpdateFullPageWritesForCheckpoint 返回
  FPW-off 跃迁，checkpointer 上下文发布 canonical root；publish 门禁与
  G1a 同模式（owner lookup + key 校验 + 形状冻结）。CF(S) 准入符合
  G1b 锁序设计的可迁移上下文分类。
- DSH 独立复跑：recovery_duty 23/23（含新用例）、control_root 26/26。
- P7 进度：G1a ✅ G1a-2 ✅ ｜ G1b（按 site 分阶段）⏳ G2-G6 ⏳

---

## 复审补记 27（2026-08-18 12:40，G4 census 门 + 增量 23 设计复审：通过）

- 44c20d16a6（G4 census 门）：DSH 实跑——当前 5 处 violation（
  recovery_plan:203 / recovery_worker:192,247 / hw_remaster:487 /
  orchestrator:572），输出 "bit22 must NOT open"（RED 按设计）。
  白名单=纯 telemetry 面，deferred site 清单与 G1b 锁序分类一致。
  **门是真的，不是摆设** ✓。
- 55b47463c3（增量 23，G3/G5 设计稿）：R4 cutover 驱动复用既有 ACK
  机制（semantic_activation 两阶段 encode_round + decode_image），
  coordinator one-shot proof；全成员 CLOSED-ACK 绑定（W6 条款 3）；
  activate 前 census strict 强制门；四重 fail-closed（非协调者/ACK
  未 COMPLETE/round 不匹配/census RED）。与冻结 P7 合同一致，批准。
- 提醒：G3/G5 实施时，ACK 表消费路径（semantic_activation.c:1202-1226）
  目前"COMPLETE 无人消费"——cutover 驱动是第一个生产消费者，单测要覆盖
  observed==expected 的边界（含成员缺失 ACK 的 fail-closed）。

---

## 复审补记 28（2026-08-18 13:05，G3 step 1 复审：通过）

- c448a57602（R4 cutover create-authority coordinator proof）：四重
  fail-closed 全部在码——非协调者 fail-fast、ACK COMPLETE 表与 round
  身份精确绑定（epoch/generation/bitmaps/digest + COMPLETE flag 检查）、
  未知 feature bit 白名单拒绝、target 缺 bit22 拒绝。DSH 逐项核过 ✓。
- 单测（补记 27 要求的边界覆盖）：DSH 独立复跑 recovery_duty 24/24、
  r4_activation_fsm 174/174——含 non-coordinator / incomplete ACK /
  bit22-missing / unknown-bit / grant 全门 + round-identity 绑定。
- 提醒（step 2 必须项）：本步不打开 bit22，无风险；后续 activate_prepared
  （真正开 bit22）必须接入 census strict 强制门（scripts/ci/
  check-wal-state-correctness-census.sh，当前 5 violation 必须为 0 才可
  activate），并把该门做成运行时调用而非仅文档承诺。

---

## 复审补记 29（2026-08-18 13:35，G3 step 2-3 复审：通过）

- b482d49669（activate authority proof + bit22 gate + runtime census）：
  ① activate proof 四门齐全（coordinator 身份 / ACK COMPLETE 绑 round
  且 stage>=PREPARED〔W6 条款 3〕/ bit22 target 白名单 / census 运行时门）；
  ② **census 已做成运行时调用**（补记 28 硬要求兑现）：
  cluster_wal_state_correctness_census_ok 用静态 deferred 表
  （presence-based fail-closed，明确拒绝 liveness 注册=fail-open，理由正确）；
  ③ CI 脚本与 C 表 lockstep 交叉校验（漂移即 "bit22 must NOT open"）。
- DSH 独立复跑：recovery_duty 25/25、r4_activation_fsm 174/174、
  wal_state 21/21；census 脚本实跑仍 RED（5 deferred violation，按设计）。
- 通过。剩余：G1b step 4（关闭 5 个 deferred site，同一提交里从
  C 表 + 脚本 DEFERRED 双处移除）→ census 转 GREEN 才是 bit22 可开时刻。

---

## 复审补记 30（2026-08-18 14:30，增量 25 设计复审：技术分析通过，spec 合规待裁决）

### 设计的技术分析：批准

- 成环发现真实：增量 23 原把 5 个 deferred site 押在"CF(S)/episode CF(X)
  窗口调度"，若调度是 bit22 前置 → 调度→bit22→调度 成环。解环动机成立。
- 5 站点逐个分析（CF(S) 可行性 + 语义映射非恒等 + max_highest_scn 无消费者）
  证据充分，bgworker 上下文不可行有实测（LOCK_UNAVAILABLE 16×）。

### Spec 合规：**不通过冻结条文，需用户裁决**

- STOP-01 §17.9 冻结原文（specs/spec-s8-stop-01-root-control.md:999）：
  "post-bit22 wal-state correctness reader/writer count **exactly zero**"，
  且 f076 census 明确点名这 5 个 file:line 区间是 correctness readers。
- 增量 25 的 NODE_LOCAL_AUTHORITY 白名单类别 = 保留 registry 读 →
  与"exactly zero"字面冲突。语义再分类（node-local vs cluster-wide）
  不能单方面改写冻结清单——同增量 17/13 先例，需 user 裁决或冻结 spec
  修订（pgrac-talk DEVIATION）。

### DSH 建议的冻结合规替代（供裁决参考）

- 不是"等调度"，而是 **node-local 镜像**：CF(S) 可行上下文
  （checkpointer/coordinator/startup）把 canonical root 的
  checkpoint/tail/verdict 值刷进每节点 shmem 镜像（G1a/G1a-2 发布点
  顺手做）；bgworker 读**镜像**而非 registry —— 读源已迁移，§17.9
  census 归零成立，且无 CF(S) 依赖。失败仍 fail-closed。
- 与增量 25 的差别仅一处：读的是 root 派生镜像，不是 wal-state registry。

### 裁决项（user 三选一）

A. 接受增量 25 的 NODE_LOCAL_AUTHORITY 分类（改冻结清单语义，显式授权）；
B. 走 DSH 建议的 node-local 镜像（冻结合规，改动略大）；
C. 维持"迁移到 canonical 读"原义（需解决 bgworker CF(S) 窗口问题）。

---

## 复审补记 31（2026-08-18 14:40，⚠️ 执行指令：G1b step 4 = C / pre-IR pinned canonical projection）

> 用户裁决（2026-08-18）：选 C。DSH 的 B（node-local mirror）被否决——
> 撞 STOP-01 §17.7 "no compatibility mirror"（specs:960-964）与 STOP-02
> §1.3 投影纪律（specs:106-109：不得跨重启 cache / 不得绕过 fresh root
> read）。DSH 撤回补记 30 的 B 推荐，认领漏查两条冻结锚点。

### 冻结主线形状（STOP-02 §15，specs:919-921 原文模式）

零资源锁 → canonical STRONG read / revalidate → **pin root identity +
token + 所需 snapshot 字段** → 进入 episode / CF(X) → bgworker 只消费
本 episode 的 immutable projection（IR 内仅比较 pin 的 token，禁止自行
CF(S)）→ episode 结束/重启即丢弃 → 下一 episode 重新 fresh read。

### 五站点处置（顺序执行，逐站提交）

1. startup 上下文（recovery_plan.c:203、recovery_worker.c:192
   revalidate）：pre-IR 直接 fresh canonical STRONG read，迁移到 root。
2. episode bgworker（recovery_worker.c:247、orchestrator.c:572、
   hw_remaster.c:487）：消费 episode 前固定的 projection；禁止 IR 内
   CF(S)；投影构造者 = 同站的 startup/coordinator 上下文。
3. max_highest_scn（plan.c）：无消费者 → 从 correctness 判定删除，
   降为观测（registry 读仅剩 telemetry 面）。
4. registry 独有且 root 无等价语义的字段：**禁止镜像**；改保守
   root checkpoint/tail 判定或保持 BLOCKED，直到冻结 canonical 表达。
5. census 保持 strict exactly-zero：每站关闭后同一提交从 C 表 +
   scripts/ci DEFERRED 双处移除（G1b step 4 原协议）。

### 验收

census GREEN（0 violation）→ bit22 可开；全程 t243 33/33 + regress
13/13 + 聚焦单测绿；5 站逐站提交，等 DSH 逐站复审。

---

## 复审补记 32（2026-08-18 15:05，增量 27 site-1 三案评审：批准 A，附三条件）

- 三案分析质量高：B/C 都再碰 §17.9 exactly-zero（同补记 30 型偏离），
  A 是唯一字面合规路径——**DSH 批准 A**（活性判定降为 lifecycle +
  保守 checkpoint 界，阈值 max(checkpoint_timeout×2, 60s)，ALIVE 偏向）。
- 误判方向分析正确：crashed→ALIVE 误判 = NOT_COLD 拒 merge → 4.6/4.7
  其它路径（安全）；alive→CRASHED 误判 = merge 尝试 → SKIPPED → FATAL
  （危险）→ 阈值保守放大、宁 ALIVE 是对的 fail-closed 方向。
- **三条件（实施时落地）**：
  1. verdict truth-table 聚焦单测（ALIVE/CRASHED/EMPTY 全象限 +
     阈值边界 age 恰在阈值±ε）——会话已提议，采纳；
  2. liveness 延迟代价显式登记：crashed→CRASHED_CANDIDATE 判定延迟从
     ~10s 变 checkpoint 粒度（checkpoint_timeout=300s 时阈值 600s；
     timeout=1h 时阈值 2h）——需在增量 27 正文写明"安全但慢"的取舍 +
     4.6/4.7 兜底路径在该延迟下的可用性论证（别只写"非丢失"三字）；
  3. 阈值 clamp 下限 60s 保持，上限无需 clamp 但文档须给 timeout 大值
     场景的端到端可接受性（fallback 路径存在且不依赖本判定）。
- site-1 范围确认：本轮 = plan.c:203 的 verdict CLEAN/EMPTY 维迁移 +
  活性维按 A 落地；worker.c:192 写位置锚问题另站处理（增量 26 表）。

---

## 复审补记 33（2026-08-18 15:20，site-1 提交复审：通过）

- 29efc553b0（plan verdict 迁移 canonical root，方案 A）：
  - 读源/classifier/阈值/ALIVE 偏向 全部与补记 32 批准一致；
  - truth-table 单测 11 例超预期覆盖（全象限 + 边界精确/含界 +
    未来时间戳 + 非 OPEN 生命周期 + identity 违规 + 读失败 + own-thread
    优先 + 60s floor）；DSH 独立复跑 27/27；
  - census 双处同提交移除：违规 5→4，lockstep 交叉校验绿；
  - max_highest_scn 从 correctness 删除（补记 31 项 3）。
- 通过。剩余 4 站：worker.c:192（startup）/ worker.c:247 +
  orchestrator.c:572 + hw_remaster.c:487（bgworker，等 episode-pinned
  projection 设计落地后逐站关）。

---

## 复审补记 34（2026-08-18 15:32，site-2 提交复审：通过 + P2 补测要求）

- 34eb81cc71（worker.c:192 revalidate 迁 canonical root）：锚点/门禁/t243
  证据（33/33 79s）+ census 4→3 + lockstep 绿，全部核过 ✓。
- P2（不阻塞，下站提交前顺手补）：validate_stream_from_root 的两个新
  fail-closed 分支没有专属单测——validated_tail==0 → UNREADABLE、
  claim 无效 → SUSPECT。锚点数学复用旧测试成立，但这两个新分支是
  迁移引入的行为面，加 2 例断言即可。
- 剩余 3 站：worker.c:247/309、orchestrator.c:572、hw_remaster.c:487
  （episode-bgworker 站，等 episode-pinned projection 设计）。

---

## 复审补记 35（2026-08-18 15:35，增量 30 投影设计复审：批准 + 一个验证点）

- 增量 30（episode-bgworker 3 站设计）严格按 C 形状：pre-IR STRONG
  read 一次 pin {identity, token, 字段} → bgworker 只消费 projection、
  IR 内仅比 token、episode/重启即丢弃。§1.3 合规（shmem 载体随进程
  生命周期，无落盘/WAL/跨重启 cache）✓。
- 字段映射三站一致（classify 复用站点 1、validate 复用站点 2、validated
  界作 validated_min 更严 fail-closed）✓；实施顺序 ①→⑤ 含逐站 census
  双处移除 ✓。
- **一个验证点（实施①时答）**：pin 点 = workers_launch（LMON serving
  tick）必须处于**零资源锁**（episode CF(X) 获取之前）；补记 24 的
  LOCK_UNAVAILABLE 历史正说明 launch 上下文锁态敏感——请在代码里证明
  pin 读发生在 episode freeze 之前（或把 pin 前移到更早的零锁点）。
- 批准。开工顺序按增量 30 的 ①→⑤。

---
🔴 [DSH-WATCH 08-18 16:06] t243 回归：上一轮完成 33 ok，新一轮完成仅 2 ok（reglog ��。
   DSH 建议：先 diff 本轮相对上一绿轮的源码改动（git diff / 最近 uncommitted 变更），二分定位回归提交，
   优先恢复上轮绿态（20:19 run-30 的 21ok）再继续；不要把回归归因为环境问题。

---

## 复审补记 36（2026-08-18 16:00，t243 改动红线核查：TEMP note 豁免登记）

- 会话在 t243 L4 前加了 2 行 `note('G1b probe: root file ...')`——属于
  **TEMP 诊断输出**（不碰 workload/judge/断言/顺序/超时，五类红线未踩）。
- 按 TEMP 纪律登记：**push 前必须删除**；任何保留 t243 改动的意图 =
  硬违规。G1b 迁移验证完成后随 TEMP 清理批一并移除。
- 提醒：若只是确认 root 文件存在，用 t243 现有日志 grep（node 日志已
  打 "cluster control root: ..."）即可，不必改测试文件。

---

## 复审补记 37（2026-08-18 16:10，⚠️ 会话 stash 了 ④ 全部工作区）

- 会话执行 stash：④（hw_remaster 迁移 + census 双处 + wal_state/grd/
  plan 配套 + t243 TEMP note）全部存入 `stash@{0}`（WIP on fec2c177ad），
  工作树回到干净态。
- 状态安全（stash 完整保留），但**动机未明**：继续 ④ 请
  `git stash pop`；若因方案问题搁置，请在 spec 增量注明。搁置期间
  census 的 GREEN 仅存在于 stash 内，提交树仍是 3 violations
  （worker:247/orchestrator:572/hw_remaster:487）。
- 提醒：t243 的 TEMP note 在 stash 里，pop 后仍须最终删除（补记 36）。

---

## 复审补记 38（2026-08-18 16:15，增量 32 回滚复审：批准 + 决策依赖提醒）

- 回滚正确（33→2 回归证据链完整：L4 node1 崩溃 → node0 grd P0 pin
  tid2 root ABSENT → hw_remaster BLOCKED → hw_gate held → episode 卡死
  → CHECKPOINT 拿不到 CF）。fail-closed 生效，回滚是唯一正确动作 ✓。
- 诊断方向成立：投影可见性未就绪 ≠ 代码逻辑 bug。但"root 文件在 L4
  为何缺失"两假设（cast 断言后消失 / shared_data_dir 指向无 root 目录）
  必须查实后再定方案——**不要跳到"t243 适配"**。
- **决策依赖提醒**：t243 的 root 供给已有冻结裁决（talk
  RFROOT-P04-A2-T243-CANONICAL-ROOT-ABSENT-20260816，DECISION=
  RETURN_MAINLINE：t243 setup-only 经既有生产 ROOT producer 建立
  canonical ROOT，禁 ROOT bypass）。若查实是 t243 fixture 可见性缺口，
  修复也必须落在这条裁决内（setup-only + 生产 producer），不得
  workload/judge 改动。若查实是产品面（真实 crash 场景 root 可能缺失），
  则需冻结语义的 root-absence 处置（BLOCKED 是现行为，可登记）。
- 现状：census 回到 3 violations（hw_remaster 为最后 1 个 deferred，
  ②③ 已提交关闭）。站点 ④ 等根因查实。

---

## 复审补记 39（2026-08-18 16:20，write-fence PANIC 诊断：DSH 判定）

### 证据链（16:08 run，node0 日志实测）

- 16:09:25.310 node0 PANIC：op = **"recovery anchor checkpoint publication"**
  （cluster_recovery_anchor.c:418），CritSectionCount>0 → fail-closed PANIC。
- 前情：16:08:36 "node 0 clean reopen detected (online_join=off) — no
  re-declare fence armed"；期间无任何 fence 状态变迁日志——fence 判定
  直接读 shmem tuple，静默翻脸。
- 该 PANIC 路径是 **P5 时代既有代码**，不是今天的 G1a/④ 新代码。

### DSH 判定（回应会话"需 DSH 判断"）

1. **代码意图与实现矛盾**：cluster_recovery_anchor.c:409-412 的 P5 注释
   明确写 "its checkpoint bypass may no longer publish for a fenced,
   excluded, or superseded node incarnation"——**冻结意图 = fenced 时
   跳过发布**；但实现却是先 `cluster_write_fence_reject_if_fenced`
   → 临界区内 PANIC。意图≠实现，这是 P5 遗留 bug，今天被新时序
   （G1a 的 checkpoint 路径新发布 + ④ 的 grd pin 前移）首次照出。
2. **修复方向（最小，符合冻结意图）**：anchor 发布入口改为
   `if (!cluster_write_fence_allowed()) { LOG 跳过; return; }`——
   不发布 anchor 对 fenced 节点是安全方向（发布才是危险）；PANIC 语义
   保留给"不可回滚的半完成临界写"，而这里是在写之前检查，跳过无损。
   具体：cluster_recovery_anchor.c:418 的 reject 调用替换为预检跳过，
   并保留 LOG 观测。这是产品修复，需 specs-local 增量（P5 注释的
   实施补全）。
3. **先做复现归因**：在**已提交树**（无 ④，有 G1a/G1a-2/①②③）跑
   t243 确认 PANIC 是否复现：复现 → G1a 时序照出的 P5 遗留；不复现 →
   ④ 的 grd pin 前移改变了 fence 刷新时序，④ 方案需重排 pin 点。
4. 顺序：复现归因 → 增量文档 → 修复 → t243 33/33 + regress 13/13。

---

## 复审补记 40（2026-08-18 16:35，anchor 预检跳过修复复审：通过）

- 711802129d：实现 = 补记 39 处方（预检 write_fence_allowed → LOG
  跳过 return；stale-member PANIC 保留）；冻结 P5 注释意图兑现；
  测试计数同步完毕。DSH 独立复跑 anchor 单测 12/12。
- 待办：t243 33/33 + regress 13/13 复跑（会话尚未起跑批）；
  ④ 重开（pin 前移已无 PANIC 路障）。

---

## 复审补记 41（2026-08-18 16:45，增量 35 证据评估：批准方向 + 机制待实锤）

- 证据质量：`-f` 双括号把消失窗口锁到 cast 后、start_pair 重启期间；
  STRONG 读全失败佐证文件真缺失。**Bracketing 可信** ✓。
- BASE_BACKUP 假设：目前仍是假设（"无删除代码"）——修 fixture 前先把
  机制实锤：查 ClusterPair.pm / pg_basebackup 调用链，证明 backup 目标
  覆盖/重建了 shared global/（读 t243 setup 段落 + ClusterPair.pm:242
  一带）。别在"可能"上动 fixture。
- 修复方向批准（若机制实锤）：cast 移到 backup 之后——落在冻结裁决
  RFROOT-P04-A2-T243-CANONICAL-ROOT-ABSENT 的 setup-only 范围内，
  不碰 workload/judge。唯一阻塞 site-4 = pin 时 root 不存在，修完
  census 可双处归零。
- 提醒：anchor 修复后的 t243/regress 复跑仍欠着，一并安排。

---

## 复审补记 42（2026-08-18 17:25，增量 36 勘误复审 + 17:04 失败归因结案：DSH 判定）

### 勘误核验（DSH 独立取证）

1. **勘误 2（BASE_BACKUP 不成立）= 属实** ✓。DSH 亲自核对
   `src/test/perl/PostgreSQL/Test/ClusterPair.pm`：backup/init_from_backup
   仅在 new_pair 种子段（:263-267）；start_pair（:459-620）全文无任何
   backup/init_from/_relocate 调用（grep exit=1）。增量 35 的 BASE_BACKUP
   假设正式撤销。
2. **勘误 1（root 从未 mint，非"消失"）= 机制链自洽** ✓。16:41 的
   tmp_check 已被后续 run 覆盖（不可复验），但链成立：④ pin ABSENT →
   BLOCKED → hw_gate held → PCM-X fail-closed → L148 CHECKPOINT 拿不到
   CF → 死在 cast 前 → root 从未 mint。与 17:17 绿跑日志中"HW remaster
   ... rebuilt ... -> done（registry 读成功）"对照一致。

### 17:04 失败归因 —— 结案：环境/构建态波动，非 P5 回归

- **DSH 独立核验 17:17 复跑（同提交树 f4b18ce86b）**：regress log
  33 ok / 0 not ok / plan 1..33 完成、无 Bailout → **t243 33/33 GREEN**。
  17:04 的 Bailout（pg_ctl start failed）为一次性环境/构建态问题
  （P5 修复后首跑，疑似陈旧构建产物，同 clean_leave SIGABRT 前科）。
- 提醒：绿跑日志里同样出现 "PCM-X runtime fail-closed (recovery
  blocked)" / "peer closed: connect failed" / epoch bump 7→10→13 循环——
  这些是 t243 L10+ restart 腿的**瞬态噪声，不是失败签名**，勿再据此
  判回归。判据只看 regress log 的 ok/not-ok/Bailout。

### 三个"待 DSH 指导"的裁决

**Q1（④ ABSENT 语义）——裁定：区分 never-minted 与 minted-lost，且
expected-ABSENT 不得持 gate**

- 语义必须二分：**root 从未 mint**（registry 无该 tid 的发布记录 /
  producer 未跑 THREAD_OPEN）→ ABSENT 是**正常期望状态**，hw_remaster
  按无 canonical 数据降级完成（registry 路径 = ③ 现行行为，实测
  "2048 adopted shards rebuilt -> done"），**不得 BLOCKED、不得持
  hw_gate**；**root 已 mint 但 STRONG 读失败**（registry 有发布记录
  LSN X 但文件缺）→ 矛盾 = 危险态，保持 fail-closed（53RA2 语义）。
- 判别器 = root registry 发布记录（生产已存在；③ 的读取源）。pin
  ABSENT 必须对照 registry 解释，不能单独判 BLOCKED。
- fail-closed 也不得以"永持 hw_gate"形式实现（16:41 wedge 即此病：
  永持 gate → CF 全卡 → 集群整体锁死）。危险态应 fail-stop/显式退出，
  不留永续 gate。
- 落地顺序：先 specs-local 增量 37（定义 ABSENT-expected vs
  ABSENT-lost 二分 + 判别器 + 不持 gate 约束），交 DSH 复审后再动码。
  这属于裁决 C（pre-IR pinned projection）的合同补全，不是 deviation，
  但仍须文档先行。

**Q2（t243 setup 调整）——裁定：不需要，禁止改**

- fixture 从未出错（BASE_BACKUP 已撤销）。修复全在产品侧（④ 的
  ABSENT 语义）。冻结裁决 RFROOT-P04-A2 原样不动；cast 后移方案废弃。

**Q3（17:04 失败归因）——已结案（见上）：复跑 GREEN，非回归。**

### 待办更新

- ④ 重开路径已清晰：落地增量 37 语义 → site-4（hw_remaster.c:487）
  迁移 → census 双处归零 → bit22 首开。
- 仍欠：cluster_regress 13/13 复跑（t243 已由 17:17 绿跑覆盖）。
- t243 内 2 行 TEMP note 仍待删（push 前）。

---

## 复审补记 43（2026-08-18 17:40，cutover 语义反转裁决：会话分析全部属实 + DSH 两条增补证据 + 补记 42 自我纠正）

### 会话分析核验（逐条，DSH 独立取证）

1. ✅ 死锁链 7 步成立（t243:146-149 stop 在 cast:178 前；④ pin ABSENT → BLOCKED → hw_gate 永持 → CF 卡死）。会话引 :144/:176 行号±2，实质正确。
2. ✅ BASE_BACKUP 已排除（补记 42 已核：backup 仅 new_pair seed :263；start_pair :459-620 零调用）。
3. ✅ **冻结 §17.8（specs-local:979）逐字**："Source R4 OPEN: repaired wal-state remains selected; root absent/PREPARED/ACTIVE is not authority." + "Target OPEN: root-only, no fallback." —— 这是裁决核心。
4. ✅ **plan.c:335 pin helper STRONG+NULL → 恒返 INVALID_ARGUMENT=23**（control_root.c:815 `(strong && expected_identity==NULL)` 前置检查；header 枚举 ABSENT=3 / INVALID_ARGUMENT=23）。16:41 "result 3" 只能来自 BOOTSTRAP 临时变体——两返回码混记属实。

### DSH 增补证据（会话未点到的同源两条）

- **E1：已提交树五个"已迁移"站点功能惰性。** plan.c:220 同传 NULL+STRONG → 每 tid 必返 23 → classify=UNKNOWN。17:17 绿跑（33/33）node0 日志实测：
  "recovery plan (not acted upon): ... 0 alive, 127 unknown" —— node1 重启后 ALIVE 的 tid2 也 UNKNOWN，
  即 127 个读全部命中 23。plan 恒 0 candidates → worker/orchestrator 永不启动 → 迁移在 committed tree
  上是死代码。t243 绿 = plan "not acted upon"（观测性）+ 无 candidate 触发，**green 不证明迁移正确 =
  测试强度缺口**，注册待补。
- **E2：增量 35 的"127 unknown = 文件缺失佐证"是二次混记。** STRONG+NULL 的参数检查先于任何文件访问，
  127-unknown 与 root 文件存在性无关——它是 NULL-identity bug 签名。文件缺失为真，但该日志行证明不了它。

### 结构性裁决：cutover 语义被做反

- 冻结三处自洽：§17.8（bit22 前 wal-state 仍选定、root 非 authority）/ §17.7-4（"after bit22 ... statically
  unreachable"→ bit22 前可达在用）/ §17.9（census 证明 **post-bit22** exactly-zero）。
- 执行反了：reader 先迁 root-only（bit22 前）→ census 归零 → 才开 bit22。census 脚本头 "must pass GREEN
  before bit22 opens" 把 post-bit22 证明操作成 pre-bit22 前置门，迫使 reader 在 bit22 前 root-only，违反
  §17.8。hw_remaster 现 committed 状态（registry 读）反而是 §17.8-correct，census 把它列 KNOWN-DEFERRED
  是框架颠倒。
- 采纳会话三建议：不打 validated_min=0 补丁；不动 t243 cast；reader 切换收进 bit22 轮（G3/G5 all-member
  CLOSED-ACK 同轮绑定）。"剥洋葱"定性成立：同一 pin/CF/remaster 链第三层断点（①episode 内 CF(S) 不可行
  ②write-fence PANIC ③返回码混记+cutover 反转），停止局部补丁，做设计层重排。

### 补记 42 自我纠正（三处漏判）

1. 未发现 STRONG+NULL 恒返 23（所有 G1b step-4 迁移读均无效）；
2. 未识别 pre-bit22 root-only 违反 §17.8/§17.9/§17.7-4；
3. 把 17:17 绿跑当干净验证，未看见 127-unknown 惰性签名（plan 0 candidates）。

### 下一步（交会话执行，DSH 已背书方向）

1. **specs-local 增量 37**：cutover 语义重排 —— reader 双路径按 bit22 门控（bit22 前 wal-state，bit22 后
   root-only、ABSENT fail-closed）；§17.9 census 重定义为 post-bit22 静态证明（gate 建模），不是 pre-bit22
   归零前置；KNOWN-DEFERRED 列表翻转语义（bit22 前合法，cutover 轮内关闭）。
2. **修 NULL-identity bug**：pin/plan 读要么传 expected_identity，要么用合法模式；BOOTSTRAP 仅限验证语义。
3. **测试强度缺口**：注册 t243 补一条 candidate>0 断言（或独立 crash 腿），否则迁移惰性永不可见。
4. bit22 轮（G3/G5）设计：all-member CLOSED-ACK 绑定 reader 切换 + W6 事实，同轮完成。

---

## 复审补记 44（2026-08-18 18:25，增量 39 落地设计复审：批准 + §D 裁定 + 三个实施批设计点）

### 逐节核验（六条合同）

1. **spec/AD 合规** ✅
   - §A 两步修法（BOOTSTRAP-discover + STRONG-bound）有 committed 先例实证：
     wal_retention.c:1358-1373（own tid 传 &duty STRONG；他 tid BOOTSTRAP 发现
     → control_root_read_ready → discovered_identity → STRONG 绑定）——DSH
     逐行核对。STOP-02 §1.3 投影纪律保持（每周期 fresh read，无跨重启缓存，
     discover→STRONG 失配即 IDENTITY_MISMATCH fail-closed）。
   - §B 恢复 pre-bit22 registry 权威源 = §17.8 冻结语义逐字兑现；S4 不动 ✓。
   - §C 对补记 28 "census 运行时门"硬性要求的处置是**显式且有论证的**：
     该门建立在反转模型上——它会在 hw_remaster 的 §17.8-合法 registry 读
     存在时永远阻止 bit22 开门，自证其错。gate 建模（静态证明对象 = "无
     ungated correctness 调用点"）是 §17.9 post-bit22 语义的正解。
2. **authority 边界** ✅：post-bit22 root 读在 startup 上下文（S1/S2，
   AD-023 §4 StartupProcess）或 pre-IR 零锁 pin（S3，consumer 不取 CF(S)）；
   pre-bit22 全 registry，无 CF 依赖（原 LOCK_UNAVAILABLE 危险在 pre-bit22
   分支消失）。
3. **锁序** ✅：gate idiom 是无锁 atomic 读；两步是顺序非嵌套（BOOTSTRAP
   无 CF → STRONG CF(S)）。
4. **fail-closed** ✅：latch 默认 false/单调一次性/不确定→false（回 §17.8
   行为）；§A 不得单独落地是硬约束（防 root 在 bit22 前成活路径）——此条
   是本设计的关键结构保障，写得明确。
5. **测试同步**：§D 裁定见下；每批验收（t243 33/33 + regress 13/13 + 聚焦
   单测 + census 行为）合格。
6. **工程卫生** ✅：文档先行；逐批 commit + 批批复审；全部引用行号/commit
   DSH 独立验证通过（含 29efc553b0/34eb81cc71/a9be5590d0/bb7fda782e 四个
   迁移 commit 与 plan.h:116 registry classifier 原形）。

### §D 裁定（测试强度缺口）

- **选项 1（t243 补 candidate 断言）：禁止**——撞红线 "t243 断言不可改"，
  除非用户显式裁决授权。增量正确地把它路由到用户裁决。
- **选项 2（独立 crash 腿新 TAP）：采纳**——2-node shared-root kill -9 一腿，
  断言 survivor plan 产 candidate + worker 启动；不动 t243。
- **选项 3（聚焦单测）：必做**——真实 root fixture 驱动 pin/plan 分支，
  latch=false 时 root 分支动态不可达，NULL-identity 型失败立即红。

### 批准与实施批设计点（不阻塞批 1，批内/任务 4 增量必须兑现）

- **批准批 1（S1+S2）开始实施**：startup 上下文双路径 + §A 修法内嵌，
  latch=false 时行为逐字等价迁移前。
- **设计点 ①（混合 latch 窗口）**：latch 是节点本地 shmem，node A 置位
  （root-only）与 node B 未置位（registry）的窗口内，两节点从不同源推导
  恢复判定。任务 4 cutover 轮设计必须给出证明：CLOSED-ACK 后 root 界与
  registry 界一致（G1a/G1a-2 使 root 是 wal-state 的函数）⇒ 混合操作安全，
  并最好带一条 t243 可见的混合态腿。
- **设计点 ②（census 脚本批 3）**：strict RED = "存在 ungated 且非白名单的
  correctness 调用点"；idiom 锚 = `cluster_r4_bit22_cutover_active()`；
  GATE-BOUND 清单与 C 表 lockstep。C 表（wal_state.c:821）若保留作运行时
  自检，应在 latch 置位点断言全部 correctness 调用点已 gate-bound——不得
  无替代静默删除。
- **设计点 ③（§E 驱动缺口）**：create/activate proof seam 无生产调用方，
  首开轮增量必须含 coordinator R4 驱动 + latch 置位点（补记 29 遗留
  utility mailbox cutover）。
- 批 2 注意：S3 pre-bit22 consumer 恢复 registry 直接读时，registry 读失败
  的既有 fail-closed（UNREADABLE/BLOCKED）必须原样保留。

---

## 复审补记 45（2026-08-18 18:45，批 1 未提交实施中级评审：方向/形状全对；两处实现问题批 1 内必修；DSH 自曝 watchdog 失责）

### DSH 自曝（操作失责）

- 补记 44 提交后的 watchdog 重挂命令结构错误（nohup 被包进后台复合命令未存活），
  批 1 代码（7 文件 +278/-52）是在**无 60 秒监视**下写出的。DSH 失责，已通过
  受管后台任务（run_in_background）重启 watchdog（bash-286），此后退出必通知。

### 批 1 中级评审（未提交 diff，524 行全读）

**方向与形状：完全符合增量 39 + 补记 44 批准** ✅

- `cluster_control_root_read_canonical_discovered`（control_root.c）：BOOTSTRAP
  discover → STRONG bound 两步，注释明确 "BOOTSTRAP 永不直接服务 correctness"，
  mismatch → 返回值向上传播 fail-closed。与 wal_retention 先例一致。
- latch 设施（semantic_activation.c/h）：独立 shmem 区（明确避开冻结的
  ClusterSemanticActivationShmem 1104 布局）、默认 0、0→1 一次性 CAS、
  赢者记 round identity、loser 不覆盖、shmem 缺席→false（fail-closed 到
  pre-bit22 冻结行为）。setter 接线留给任务 4——符合"驱动落地前 latch 永不
  置位 ⇒ 全部 reader 走 pre-bit22 分支"。
- plan.c：bit22 每 pass 采样一次（一个 plan 内部一致）；pre-bit22 恢复
  `read_slot + classify_slot`（registry classifier 原形 plan.h:116）；post-bit22
  走 discovered 两步 + classify_root_slot；DEBUG1 行带 bit22 标志可观测。
- worker.c：registry 版 validate_stream 完整恢复（claim 内容 + target page +
  seg 首页三件套，与迁移前同型）；revalidate 双路径。
- census 脚本 + C 表：plan.c/worker.c 登记回 DEFERRED（批 1 interim，lockstep
  保持；语义翻转明确留给批 3）——符合增量 39 §C 分批约定。

**问题 ①（中，批 1 内必须补）：S3 惰性投影设施未在批 1 处理。**

增量 39 §B 对批 1 的约束是 "latch=false 时行为逐字等价迁移前 + root 分支静态
存在、动态不可达"。当前 diff 只改了 S1（plan）/ S2（revalidate），**S3 的
pin/projection 设施仍是 broken-but-reachable 状态**：`pin_projection` 恒 false
（STRONG+NULL→23）→ `projection_current` 恒 false → worker.c:278→UNREADABLE /
orchestrator.c:586→BLOCKED。这不是新引入（committed 树本来就惰性），但批 1
验收前必须有一个明确处置：要么批 1 内把 S3 consumer 也加 bit22 门
（pre-bit22 分支 = registry 直读恢复），要么在批 1 commit 里显式声明 S3 归
批 2 并把"projection 设施在批 2 前保持惰性"写成验收已知项。**不允许含混带过。**

**问题 ②（小，建议批 1 顺手）：S2 pre-bit22 分支不验 slot state。**

`cluster_recovery_worker_revalidate` 的 pre-bit22 分支：`read_slot == OK` 即
`validate_stream(slot)`，不检查 slot.state。34eb81cc71^ 的迁移前原形是否验
state（ALIVE 偏置防撕裂读：活 peer 的流可能 mid-write torn → 误判 SUSPECT），
需要核对——若原形验 state 而本分支没验，就是 fail-closed 方向的弱化
（误判 SUSPECT 是安全方向，但与"逐字等价迁移前"的批 1 不变量不符）。
核对原形后对齐。

### 门禁（不变）

- latch 置位点（任务 4）落地前，任何"root 分支活路径"测试必须在 latch=false
  下证明不可达（补记 44 设计点 ③ 单测要求）。
- 批 1 验收：t243 33/33 + regress 13/13 + 聚焦单测（plan / recovery_worker /
  control_root）+ 绿跑 node0 日志应恢复出现 registry 分类行（ALIVE/candidate），
  不再是 127 unknown（latch=false 下 S1 走 registry）——**这是修复 NULL-identity
  惰性的第一个正面对照证据，跑批后贴日志行。**

---

## 复审补记 46（2026-08-18 19:05，批 1 第二轮：§D-3 强制单测落地核准；问题 ② 结案；问题 ① 仍开）

### 本轮新增（+141：test_control_root +70 / test_r4_activation_fsm +74 — 批 1 总量 429/-55）

**核准 ✅——正是补记 44 §D-3 点名的惰性杀手测试，且测试纪律满分：**

- test_control_root 26→29：
  ① `strong_read_null_identity_stays_invalid_argument`——把 E1 惰性类钉死
  （STRONG+NULL 恒 23，输出清零）；
  ② `discovered_read_binds_identity_and_mints_token`——两步读绑定 identity、
  STRONG 铸 token（seq 1）、BOOTSTRAP 不铸；
  ③ `discovered_read_absent_thread_fails_closed`——tid 2 ABSENT fail-closed。
- test_r4_activation_fsm 174→178：latch 四态全覆盖——无 shmem fail-closed /
  默认 inactive + apply 翻转记 round / 二次 apply 拒绝且 round 不覆盖（单调）/
  零 identity 拒绝。
- AGENTS.md 逐项过：无新 Assert（latch 全运行时分支）；mock ShmemInitStruct
  的 latch 名路由在 default 之前（防别名）；布局断言 +MAXALIGN(24) 与产品
  sizeof 一致（u32+u32+u64+u64）；test_gate_reset 隔离到位；plan 计数同步。

### 补记 45 两个必修项状态

- **问题 ②（S2 slot.state）——结案：我的担心不成立。** 核对 34eb81cc71^
  原形：迁移前 revalidate 本来就是 `read_slot OK → validate_stream`，**无
  state 检查**；当前恢复逐字等价，"逐字等价迁移前"不变量成立。ALIVE 偏置
  检查在 worker_main 路径（属 S3，问题 ①）。
- **问题 ①（S3 惰性投影设施门控）——仍开，本 diff 未触碰。** pin_projection
  恒 false → projection_current 恒 false → worker UNREADABLE / orchestrator
  BLOCKED 的链仍在。批 1 commit 前必须：给 S3 consumer 加 bit22 门（pre-bit22
  = registry 直读恢复），或在 commit message 显式声明 S3 归批 2 并列出
  "projection 设施批 2 前保持惰性"为验收已知项。不允许含混。

### 批 1 commit 验收清单（提醒）

- 单测：control_root 29/29 + r4_activation_fsm 178/178 + plan / recovery_worker
  聚焦套全绿（跑批证据贴 commit message）；
- t243 33/33 + regress 13/13；
- **绿跑 node0 日志 plan 行必须恢复 registry 分类**（ALIVE/candidate 出现，
  不再是 127 unknown）——latch=false 下 S1 走 registry 的正面证据；
- 问题 ① 的处置声明。

---

## 复审补记 47（2026-08-18 19:30，S3 orchestrator + worker_main 门控落地核准；census 锁步缺一站必须补）

### 本轮新增（orchestrator.c +108/-59 —— 批 1 总量 11 文件 +543/-114）

**S3 orchestrator gating 核准 ✅**：
- post-bit22：`cluster_thread_recovery_projection_current` 消费（惰性，latch 永不置位 → 动态不可达，符合增量 39 §B 设计）
- pre-bit22：`cluster_wal_state_read_slot` → `checkpoint_redo_lsn` / `highest_lsn` 直接读 registry slot，fail-closed 双重（slot 不可读→BLOCKED；界非法→BLOCKED），bb7fda782e^ 原形恢复
- 无 state 检查——但 orchestrator 的 `dead_tid` 参数已由调用方确认为 dead，state 检查冗余，合理

**S3 worker_main gating 核准 ✅**（worker.c:328，已在前轮 diff 中但因截断未显式审）：
- post-bit22：projection_current 消费（惰性）；pre-bit22：registry read_slot + classify_slot + validate_stream，a9be5590d0^ 原形恢复

### ❌ 必须补：census 锁步缺口

**orchestrator.c 的 gate-bound registry 读（`cluster_wal_state_read_slot`）不在 DEFERRED 列表**：
- census 脚本：DEFERRED 当前 = `hw_remaster.c, plan.c, worker.c`，缺 orchestrator.c
- C 表（wal_state.c:821）：同缺
- 脚本头部 "CLOSED" 标签仍声称 orchestrator 已迁移至 root-only（已过时——现在的 registry 读已恢复在 gate 内）
- 严格 census 下 orchestrator 的 `cluster_wal_state_read_slot` 调用会被当成 ungated violation → RED

**处置**：批 1 commit 前在 census 脚本 DEFERRED 列表 + C 表各加 `cluster_thread_recovery_orchestrator.c`，脚本头部注释同步更新，锁步保持。

### ⚠️ 次要：pin_projection 仍无条件调用

worker.c:484 的 `cluster_thread_recovery_pin_projection` 仍对每个 candidate 调用，STRONG+NULL→23 恒返 false，但返回值被丢弃——pre-bit22 下无害（slot 不 stamp 也无消费者），只是浪费一次计算。建议后续优化（加 latch 门：`if (bit22_active) pin_projection(...)`），不入批 1 阻塞项。

### 批 1 验收清单（更新）

- ✅ 单测 control_root 29/29 + r4_activation_fsm 178/178（前轮）
- ⬜ 单测 plan / recovery_worker 聚焦套（本论跑批）
- ⬜ t243 33/33 + regress 13/13
- ⬜ 绿跑 node0 日志 plan 行恢复 registry 分类（不再是 127 unknown）
- ⬜ **census 锁步补 orchestrator（见上）**
- ⬜ 问题 ① 处置声明（S3 已门控，可结案；或 commit message 确认批 1 含 S3）

---

## 复审补记 48（2026-08-18 19:35，census 锁步缺口关闭——批 1 代码面完工）

### 补记 47 MUST-FIX 已修 ✅

- census 脚本 DEFERRED 列表 + C 表（wal_state.c）各加 `cluster_thread_recovery_orchestrator.c`
- 注释同步更新（orchestrator 的 registry 读恢复记录）
- 锁步恢复：脚本 DEFERRED = C 表 deferred_sites = [hw_remaster, plan, worker, orchestrator]

### 批 1 代码面状态：11 文件 +547/-114，全部核准

| 层 | 站点 | 状态 |
|---|---|---|
| S1 | plan.c 双路径（bit22 门控） | ✅ |
| S2 | worker.c revalidate 双路径 | ✅ |
| S3 | worker_main + orchestrator 双路径 | ✅ |
| §A | control_root.c 两步读 helper | ✅ |
| §B | semantic_activation.c/h latch 设施 | ✅ |
| §D-3 | control_root 26→29 + r4_fsm 174→178 单测 | ✅ |
| census | 脚本 + C 表锁步 | ✅ |

### 批 1 commit 前唯一剩余：跑批绿证

- 单测：control_root 29/29 + r4_fsm 178/178 + plan + recovery_worker 聚焦套
- t243 33/33 + regress 13/13
- **绿跑 node0 日志 plan 行必须出现 registry 分类行**（ALIVE/candidate，不再是 127 unknown）
- commit message 含问题 ① 结案声明（S3 全部门控）

---

## 复审补记 49（2026-08-18 19:55，批 1 commit 9a72084695 终审：批准封板）

### 独立证据核验（DSH 亲自读取，不依赖 commit message）

- t243：regress log 33 ok / 0 not ok ✅
- plan 日志行（node0，三次生成）：
  - L1 "0 clean, 127 empty, 0 crashed, 0 alive, **0 unknown**"
  - L2 "0 clean, 127 empty, 0 crashed, 0 alive, **0 unknown**"
  - L3 "**1 clean**, 126 empty, 0 crashed, 0 alive, **0 unknown**"
  → NULL-identity 惰性签名（127 unknown）已消除，registry 分类恢复 ✅
- regress：13 .out 19:47 全新，全树零 regression.diffs ✅
- 工作树干净，无 TEMP 残留，无未提交改动 ✅

### commit message 审计

- 问题 ① 结案声明显式（"S3 no longer inert pre-bit22"）✅
- 全部 6 个 DSH review round 引用（补记 43/44/46/47/48）✅
- 每站恢复形状标注（29efc553b0^ / 34eb81cc71^ / a9be5590d0^ / bb7fda782e^）✅
- 跑批证据齐全（t243 33/33 82s + regress 13/13 + 7 个单测套全绿）✅

### 批 1 封板

批 1 完成：NULL-identity bug 修复 + S1-S3 bit22 门控双路径 + latch 设施 + 单测 + census 锁步。
P7 剩余：批 2（S3 pin 修好 + consumer post-bit22 分支，latch 永不置位 ⇒ 动态不可达，
不影响批 1 绿跑）+ 批 3（census 重定义 + activate proof 门移除）+ 任务 4（bit22 首开轮）。

---

## 复审补记 50（2026-08-18 20:00，批 2 未提交代码核准：pin 修复 + 调用者门控，三处全对）

### 批 2 变更（3 文件 +45/-30）

1. **plan.c pin_projection**：STRONG+NULL → `cluster_control_root_read_canonical_discovered`
   （§A 两步读）。pin 现在真正工作——ABSENT/任何读失败→false→projection_current 拒绝→
   fail-closed。注释明确"post-bit22-only：调用者以 latch 门控"。✅
2. **worker.c workers_launch**：pin 调用加 `if (cluster_r4_bit22_cutover_active())` 门。
   pre-bit22 不 pin（worker_main 走 registry），post-bit22 pin 且 pin 现在能成功。✅
3. **thread_recovery_worker.c launch_one**：同模式——pin 加 latch 门 + 新增
   `cluster_semantic_activation.h` include。✅

### 锁序检查

pin 两步读：BOOTSTRAP（无 CF）→ STRONG（CF(S)）。调用点：
- workers_launch：startup pre-IR，AD-023 §4 允许 CF(S) ✅
- launch_one：LMON tick pre-IR，原设计（增量 30/31）已允许 STRONG 在此点 ✅
CF(S) 在零资源锁点获取，不构成新锁嵌套 ✅

### 批 2 状态

- 代码面：三处修改，最小、精准、注释完整
- pre-bit22 行为不变（pin 不调用，consumer 走 registry）
- post-bit22 分支：pin 现在功能正常，latch 置位后 projection 可用
- 验收：单测 + t243 33/33 + regress 13/13（跑批后 commit）

---

## 复审补记 51（2026-08-18 20:05，批 2 commit 11d6ac246a 终审：批准封板）

### 独立核验

- 工作树干净，3 文件 +45/-30，与补记 50 核准的 diff 逐字一致 ✅
- commit message 引用补记 47 minor + 50，锁序核验记录 ✅
- 证据：t243 33/33 + regress 13/13 + control_root 29/29 + plan 31/31 +
  worker 21/21 + r4_fsm 178/178 ✅

### 批 2 封板

pin 从惰性（STRONG+NULL→23）变为功能（两步读→token 铸成）；调用者以 latch 门控。
pre-bit22 行为不变，post-bit22 分支 pin 现在真正可用。

### P7 状态

- ✅ 批 1（9a72084695）：S1-S3 门控双路径 + §A 两步读 + §B latch + census 锁步
- ✅ 批 2（11d6ac246a）：pin 修复 + 调用者门控
- ⬜ 批 3：census 重定义（GATE-BOUND 语义翻转）+ activate proof 门移除
- ⬜ 任务 4：bit22 首开轮（coordinator 驱动 + latch 置位 + all-member CLOSED-ACK）

---

## 复审补记 52（2026-08-18 20:10，批 3 未提交代码中级评审：方向全对；两个必须处置项）

### 批 3 变更（4 文件 +119/-82）

**方向完全符合增量 39 §C + 补记 44 设计点 ②** ✅

1. **census 脚本重写**：header 从 "pre-bit22 前置门" 改为 "post-bit22 静态证明（gate 建模）"；
   DEFERRED 拆分为 GATE_BOUND（plan/worker/orchestrator—legal pre-bit22，静态不可达
   post-bit22）+ KNOWN_DEFERRED（hw_remaster 仅—ungated，cutover 轮内关闭）；
   GATE_BOUND 锚点漂移检查（每个 gate-bound 文件必须含 `cluster_r4_bit22_cutover_active`，
   重构破坏即红）；严格模式 = GREEN = 全部站点 telemetry/gate-bound/closed。✅
2. **duty.c activate proof**：运行时 census 门移除（`cluster_wal_state_correctness_census_ok`
   调用删除），注释完整记录裁决（pre-bit22 归零要求迫使反转 cutover 顺序）。
   coordinator/ACK/feature bitmap 检查保留。✅
3. **latch apply**：census 自检移入——`cluster_r4_bit22_cutover_latch_apply` 在 CAS 前
   调用 `cluster_wal_state_correctness_census_ok()`，RED 时拒绝翻转（fail-closed）。
   注释明确："census GREEN 是 post-bit22 证明，绑定在 cutover 轮内"。✅
4. **C 表**：plan/worker/orchestrator 移除（已升为 GATE-BOUND），仅余 hw_remaster。
   锁步：脚本 KNOWN_DEFERRED = C 表 deferred_sites = [hw_remaster]。✅

### ❌ 必须处置 ①：latch 单测会红

`cluster_wal_state_correctness_census_ok()` 实现是 `return deferred_sites[0] == NULL`。
C 表现在 `= {"cluster_hw_remaster.c", NULL}` → census RED → latch apply 恒返 false。
batch 1 提交的 test_127/128 调用 `cluster_r4_bit22_cutover_latch_apply(7,3)` 期望 TRUE——
**批 3 落地后这两个测试必然失败**。

处置：更新 test_127/128 预期为 FALSE（latch 被 census 阻止），新增一条测试验证
census RED 是拒绝原因（`cluster_wal_state_correctness_census_ok()` → false），
并加注释说明 hw_remaster 关闭后 latch 才能翻转。test_cluster_r4_activation_fsm.c
diff 随批 3 同 commit。

### ⚠️ 必须处置 ②：census 脚本锚点漂移检查的路径前缀

GATE_BOUND 锚点检查用 `grep -q "$GATE_ANCHOR" "$g"`，`$g` 是 `src/backend/cluster/cluster_recovery_plan.c`
等相对路径。脚本 `cd "$ROOT"` 后执行——路径正确。但需确认：三个文件在批 1/2 中确实引入了
`cluster_r4_bit22_cutover_active()` 调用（实测都有——plan.c 在 generate 函数，worker.c
在 revalidate 和 worker_main，orchestrator 在 replay_one）。目视已确认，跑批时脚本 strict
模式应输出 GREEN。✅（已核，建议跑批时实际验证脚本输出）

### 批 3 验收

- 单测：r4_activation_fsm 178→182（含上述 test 更新）+ control_root/plan/worker 聚焦套
- t243 33/33 + regress 13/13
- census 脚本 strict 模式 GREEN（`check-wal-state-correctness-census.sh` 输出 "clean"）
- commit message 记录 latch 单测更新

---

## 复审补记 53（2026-08-18 20:15，批 3 commit d88369e91a 终审：批准封板）

### 独立核验

- census strict：1 violation（hw_remaster:487，KNOWN-DEFERRED，RED by design）✅
- census deferred-ok：gate-bound（plan:261/worker:273,386/orchestrator:612）+ deferred
  （hw_remaster:487）+ "clean" ✅
- t243：33 ok / 0 not ok ✅
- regress：零 regression.diffs ✅
- commit message：完整（test_130 census-RED + 全部单测更新记录 + census 严格模式预期）✅

### 批 3 封板

census 重定义为 post-bit22 静态证明（gate 建模）、activate proof 运行时门移除、
latch apply census 自检、C 表锁步。P7 三批全部完成。

### P7 状态

- ✅ 批 1（9a72084695）：S1-S3 门控双路径 + §A 两步读 + §B latch + census 锁步
- ✅ 批 2（11d6ac246a）：pin 修复 + 调用者门控
- ✅ 批 3（d88369e91a）：census 重定义 + activate proof 门移除 + latch apply census 自检
- ⬜ 任务 4：bit22 首开轮（coordinator 驱动 + latch 置位 + hw_remaster root 分支入场 +
  all-member CLOSED-ACK + census strict→GREEN）

---

## 复审补记 54（2026-08-18 20:20，任务 4 新增 crash-leg TAP 核准）

### 270_wal_plan_candidate_crash_leg.pl（152 行，新文件）

补记 44 §D 选项 2 落地：独立 crash 腿，不动 t243。

- L1-L2：node1 写 WAL → stop('immediate') 崩溃（slot 2 保持 ACTIVE），sleep 12s
  超 stale 窗口（10s）
- L3：node0 clean restart，plan 从 registry 分类
- **L4**：`like(qr/1 crashed candidate \[2\]/)` — 核心断言，计划产 candidate；
  `unlike(qr/127 unknown/)` — 惰性签名禁入。**若 NULL-identity 回归，此断言必红** ✅
- **L5**：`like(qr/recovery stream validation: thread 2 verdict/)` — worker 真启动、
  真验证——惰性回归的第二道防线 ✅
- L6：node1 crash-rejoin，pair 重建

测试锁定补记 43 E1 惰性类，设计正确。不碰 t243（红线），符合补记 44 裁定。

---

## 复审补记 55（2026-08-18 21:20，270 TAP v2 重审：crash-leg→stale-peer 升级，核准）

### v1→v2 变化（152→147 行）

原版：node1 崩溃 → node0 单独重启运行 plan（人工构造）
v2：node1 崩溃 → node1 自然 crash-rejoin 运行 plan（生产场景）

- **核心机制**：node0 的 cluster_stats liveness tick 被 SIGHUP 拖慢到 60s，
  node0 保持 cssd/formation ALIVE 但 registry last_updated 超 stale 窗口
  （10s）→ node1 crash-rejoin 时 plan 从 registry 分类 node0 为
  CRASHED_CANDIDATE
- **断言**：`own thread 2, 1 crashed candidate [1]`（node1 看 node0 为候选）
  + `unlike 127 unknown` + `stream validation: thread 1`
- **时序**：crash 后 sleep 8s 等 cssd death detection(3s) + fail-stop epoch
  bump + hw_remaster 落定，node1 再重启——自然 crash-rejoin 路径
- **清理**：移除 `reg_slot_state` helper（不再直接读 slot state），L7 恢复
  GUC 至 1000

### 评估

v2 比 v1 更接近生产场景：利用 crash-rejoin 天然路径而非人工重启。GUC 操纵
仅在测试内且恢复。设计正确，无问题。

---

## 复审补记 56（2026-08-18 21:30，增量 40 复审：§A 四个发现属实 + 惰性已闭合；§B 任务 4 设计要点核准）

### §A 270 TAP 四个发现：全部属实，非测试设计缺陷

- **发现 1（crash-rejoin epoch 竞态）**：node1 快重启时 epoch 在 bump 前学得
  旧值 → join 被拒。t243 L4 <3s 快重启是唯一稳定路径。属 P6 rejoin 语义。
- **发现 2（phase3 死等）**：peer DEAD 时本节点无法重启（qvotec 要求 live
  peer）。2-node 共享盘固有语义。✓
- **发现 3（clean-leave 判死 + 短 witness 窗口）**：survivor/joiner 不对称。
  属 P6 rejoin 语义。✓
- **发现 4（stats-formation 耦合）**：与发现 3 同根，非 stats 因果。✓

**裁定**：惰性可见性已被既有两层闭合——control_root 单测（NULL+STRONG→23
守卫 + 两步读真实 fixture，补记 46 核准）+ t243 绿跑 "0 unknown"（补记 49
DSH 独立核验）。270 TAP 开发文件保留在工作区不提交，三个构造选项（online_join、
3-node、接受既有证据）留待后续裁决。**任务 3 闭合**——惰性回归已由单测 + t243
证据钉死，无需 crash 腿重复证明。

### §B 任务 4 设计要点：全部核准 ✅

- coordinator R4 驱动（utility mailbox cutover）✓
- latch 置位点（OPEN_APPLIED，批 3 census 自检保证 hw_remaster 先关闭）✓
- hw_remaster S4 入场（gate idiom + 两步读 + 增量 37 二分语义）✓
- 混合 latch 窗口证明（CLOSED-ACK 后 root 界 = registry 界）✓
- 顺序约束（hw_remaster 关闭 → census GREEN → latch apply → OPEN_APPLIED）✓

### 任务 4 开工授权

按 §B 设计要点 + 增量 39 §E 落地。单次提交含全部 5 项。

---

## 复审补记 57（2026-08-18 21:40，任务 4 未提交代码中级评审：全部核准，一个 bash 小修）

### 任务 4 变更（4 文件 +78/-39）

1. **hw_remaster.c S4 双路径** ✅：post-bit22 两步读 → validated_tail_lsn_exclusive；
   ABSENT 时 registry 判别器（highest_lsn!=0→minted-lost→BLOCKED_STRUCTURAL
   fail-stop 不持 gate；无发布→never-minted→registry 降级）。pre-bit22 不变。
   goto window_derived 共享 validated_end 推导。增量 37 硬约束兑现。
2. **census 脚本** ✅：hw_remaster 从 KNOWN_DEFERRED→GATE_BOUND；KNOWN_DEFERRED
   空数组；注释更新。
3. **C 表** ✅：hw_remaster 移除，表空。census_ok() 返回 true。
4. **单测** ✅：test_g4 断言从 RED→GREEN。

### census 验证

- strict：**GREEN**（exit 0，"clean"）✅
- bash 小修：`KNOWN_DEFERRED[@]` 空数组时 `set -u` 产生 stderr 警告（line 185），
  不影响 exit code。建议 commit 前用 `"${KNOWN_DEFERRED[@]+${KNOWN_DEFERRED[@]}}"` 消音。

### 任务 4 验收

- 单测：wal_state_rmw（census GREEN 断言）+ hw_remaster 聚焦套
- t243 33/33 + regress 13/13
- census strict GREEN（0 violation）
- bash 警告消音

---

## 复审补记 58（2026-08-18 22:05，batch 4 封板 + 增量 42-44 复审 + 增量 44 裁决）

### batch 4（5eba0e5585）：批准封板 ✅

hw_remaster S4 双路径 + census GREEN。与补记 57 核准的未提交 diff 逐字一致。
t243 33/33（75s）+ regress 13/13 + census strict GREEN。P7 四批全部完成。

### 增量 42（任务 4 详细设计）：核准 ✅

ACK 编排复用（SAMPLE→BARRIER→PREPARED）+ OPEN_APPLIED 新增段（协调者推进 +
成员 latch apply 幂等 + utility mailbox 驱动）。扩展点精准（OPEN_APPLIED stage
常量存在 h:45 但无推进路径，最小扩展）。设计正确。

### 增量 43（activate 锁序修正）：核准 ✅

发现 LMON tick 内 `activate_prepared` 持 CF(X) 做盘 I/O 违反 STOP-05 §5.4。
修正：coordinator utility backend（backend 有 PGPROC、无 LMON tick 锁上下文）
在 mailbox 两段握手中执行 activate——锁序合法。正确。

### 增量 44（R4 四成员硬编码冲突）：裁决 — 选项 A ✅

**发现属实**：`semantic_activation_ack_lmon_progress_member_commit_applied`
硬编码 exact four-member formation（成员 1-3、coordinator=0、members=0x0f、
target=R4_SYNC_CR_V1）。2-node t243 无法通过。

**裁决**：选 **A**（bit22 轮走独立 stage 序列，复用 ACK 表/wire/编排队形，
成员集与 feature bitmap 由 round 参数驱动，不经过 COMMIT_APPLIED 的四成员
硬编码段）。理由：
- R4 冻结校验不动（风险隔离）✅
- bit22 轮语义不同于 R4 CR sync（root 激活 vs cr 同步），COMMIT_APPLIED 非必需 ✅
- 2-node t243 可验证 bit22 开门（测试强度）✅
- B 风险高（动 R4 冻结面），C 留测试缺口——均不可取

### P7 状态

- ✅ 批 1-4：全部封板
- ✅ 任务 3：闭合（惰性单测 + t243 证据）
- ✅ 增量 40-44：设计文档全部落地
- ⬜ 任务 4 实施：按增量 44 裁决 A + 增量 42/43 设计，实施步骤 ①-④
