# 08 — 悬而未决的问题与待办

> 记录扫描时发现的未决事项。解决后划掉并注明日期。

## P0 级

- [ ] **`RFROOT-P04-A-ROLLOVER-CLOSE-AUTHORITY-SMUGGLE-20260816`**
      （EMERGENCY-HOLD，predicate TALK_AUTHORITY_FORK）——读 talk 中
      `[READ-ALERT P0]` 区段全文，确认当前处置状态。
- [ ] **t243 已知 RED**（node1 canonical ROOT ABSENT，`53R61`）——Writer 处于 STOP；
      P6 唯一下一步（Reader RETURN_MAINLINE 边界）：只在 t243 setup 里调用现有
      production ROOT producer 建立 node1 canonical ROOT；复用已验证 ROOT 格式/authority；
      不新增 bypass/持久格式/产品豁免；不改 workload、judge、顺序、timeout；
      重跑原样 t243，GREEN 后形成 P6 immutable commit，再进 P7。
      设计文档：spec-rf-root-*、spec-s8-stop-05-root-reuse.md、ad-019、ad-023。

## 仓库卫生问题

- [ ] `~/linkdb` 主工作树 detached @ 238fe51d7c + **17 文件未提交修改**，
      归属不明。需先查清来源（哪个会话/分支）再决定保留/归档/丢弃。
      重点文件：`cluster_remote_xact.c`(+127)、`cluster_tt_durable_stat.c`(+98)。
- [ ] `~/pgrac` main 与 origin/main 分叉（领先 12 / 落后 261）——考虑是否同步。
- [ ] `~/pgrac/.p020-*` 三个软链指向已删除的 `/private/tmp/pgrac-p020.1hIcD7`（悬空）。
- [ ] 公共 worktree 里未跟踪的编译产物：`src/bin/pgrac_fenced/pgrac-fenced*`、
      大量 `tmp_s0414_*` TAP 临时目录（可清理，但先确认无诊断价值）。
- [ ] `~/pgrac/scratchpad/` 2.1GB（rig-baseline 1GB、baseline-tree 164MB、
      多个 r2-d11-disabled 各 209MB）——磁盘占用大，可考虑归档。
- [ ] `~/pgrac` 顶层杂项：3.3MB `--01.png`、`未命名*.base/canvas`（Obsidian 残留）、
      `~/` 目录（.dbaa/.opendb）。

## 待核实的信息

- [ ] linkdb 最近提交日期显示 2026-07-15（`4f8d58cdff`），而工作树/文件时间到
      2026-08-16——确认 Stage 8 新提交是否都在公共 worktree 分支上，主树已落后。
- [ ] `git log --since=2026-08-01` 返回 0 的异常（可能与提交日期/时区有关）。
- [ ] `~/pgrac/.codex-candidates/stage8.git`（裸仓？）与公共 worktree 的关系。
- [ ] talk 头部 reader-session 与 `.pgrac-talk-state/reader/state.json` 中
      session_id 不一致（`01a00358-e9c2...` vs `01a00855-6444...`）——可能是
      talk 头部未更新或 reader 换过会话，需确认。

## 未读但可能重要的资料（后续深读候选）

- [ ] talk `[READ-ALERT P0]` 区段全文
- [ ] `docs/ad-023-rfroot-p04-recovery-authority-serving-split.md`（Scheme A 设计）
- [ ] `docs/2026-08-08-stage8-development-plan-and-status.md`、r1-r4 code review
- [ ] `specs/` 中 Stage 8 相关 spec（spec-8.x / S0414 系列）
- [ ] `reports/stage8-4x1x3/`（4x1x3 事故根因报告）
- [ ] `架构设计/` 五篇源码精读文档（ges/grd/lock_acquire/cf_enqueue/lms）
