# 06 — pgrac-talk 协作协议（Writer/Reader 双会话）

> 协议版本当前为 **0.2.10**（2026-08-16 用户批准，覆盖 0.2.6-0.2.8）。
> 权威定义：`~/pgrac/skills/pgrac-talk/`（SKILL.md、references/protocol.md、
> reader-runtime.md、writer-runtime.md）+ `~/pgrac/AGENTS.md` 的 CURRENT OVERRIDE 节。

## 角色与分工

- **Writer**：唯一写产品字节的会话。在公共 worktree
  `~/pgrac/.codex-candidates/stage8-d4b.LHbUJt` 编码，TDD 纪律。
- **Reader**：只读审查会话，绝不修改产品/测试字节。
- 两者通过 `~/pgrac/talk-current`（指针文件）+ 锁目录 `.pgrac-talk-state/locks/`
  协作；状态持久化在 `.pgrac-talk-state/{writer,reader}/state.json`。

## 0.2.10 核心规则

1. Writer 正常连续编码，**不等待 Reader**。普通实现细节、无冲突证据的内部选择、
   测试形状、保持既有行为的 PG adaptation **都不写 talk**。
2. Writer 只在"当前实现可能偏离已验证 Oracle 行为或冻结 Spec"时发一个简短
   `DEVIATION`。Reader 每 60 秒用持久 monitor 轻量检查 talk 与 eligible-code 变化，
   只检查新 diff；代码对齐则沉默。
3. 每个偏离只允许**一轮双边判断**：Writer 发起 → Reader 决定一次；
   Reader 发起 → Writer 决定一次。能回主线记 `RETURN_MAINLINE`，立即纠偏不通知用户。
4. 仅当双方单轮判断确认偏离真实且无法回到 in-scope Oracle/Spec 主线时，记
   `USER_REQUIRED`：Writer 暂停产品修改，**Reader 向用户询问一次**（Writer 不直接问），
   Reader 记录精确 `USER-RESULT` 后恢复。
5. talk 只允许 `DEVIATION`、`DECISION`、`USER-RESULT` 和 900 秒无代码提醒；
   **不得写**进度、RED/GREEN、review finding、设计方案、备选项、建议实现、
   commit 叙述或重复辩论。
6. 同一 eligible-code 指纹 900 秒未变化 → 提醒 Writer 尽快编码；
   1500 秒仍未变化 → Reader 提醒用户介入。没有 1200 秒层级；不自动启动/恢复/
   替换/fence/signal/终止会话。只有 `USER_REQUIRED` 等待中才走用户暂停时钟。
7. Reader 不得扩张 happy path、不得推翻用户已有裁决；范围外 →
   `DEFERRED_NOT_REQUIRED`。
8. 轮次保持存续直到 Stage 8 完成；状态答复、静默 monitor、后台 terminal、
   单次偏离消息都不是结束理由。

## talk 文件格式（当前活跃文件示例）

`talk_20260816-0052.md` 头部包含：predecessor（前一篇）、milestone、
writer-session / reader-session、lease-epoch-at-rotation、queue、
然后是 CURRENT USER / READER AUTHORITY（用户裁决原文 + 签署决策编号）、
CLOSED FINDINGS（作为 authority 携带）、CURRENT WIP / VERIFIED FOCUSED STATE、
REAL MULTI-PROCESS RED CHRONOLOGY、UNRESOLVED ALERTS / DISPUTES、
WRITER NEXT ACTION、SAFETY / REPOSITORY BOUNDARY、CLOSED 收据、
`[READ-ALERT P0]` 区段（EMERGENCY-HOLD）。

## 关键文件

- 指针：`~/pgrac/talk-current`（22 字节，内容 = 当前 talk 文件名）
- 历史：`~/pgrac/talk_*.md`（259 篇，2026-07-28 起）
- 状态：`~/pgrac/.pgrac-talk-state/writer/state.json`（lease_epoch、
  next_action、talk_fingerprint、worktree 路径）
- 证据：`~/pgrac/.pgrac-talk-state/evidence/recovery-*.json`
- 锁：`~/.pgrac-talk-state/locks/{talk,writer-event,reader-event,deviation,monitor,roles}.lock`
- 特殊 talk：`talk-cc-rulings.md`（裁决集）、`talk-lane-A~D.md`（分线）

## 接手注意事项

- 接手前先读 writer/reader state.json 确认租约 epoch 与 next_action。
- 当前 Writer `next_action=STOP`；未获用户恢复指示前，勿自动继续编码
  （t243 RED 的恢复方案按 Reader RETURN_MAINLINE 已有路线）。
- 写 talk 必须遵守"只允许 4 类消息"的纪律，否则污染协作通道。
