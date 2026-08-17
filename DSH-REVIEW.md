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
