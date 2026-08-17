# MEMORY-CHANGELOG — 记忆更新日志

| 日期 | 变更 |
|---|---|
| 2026-08-16 | 初始生成：README.md、MEMORY.md、memory/01~09，基于对 ~/pgrac 与 ~/linkdb 的全盘扫描 |
| 2026-08-16 | 工作区建立：~/pgrac-dsh 初始化为 git 仓库（upstream=sqlrush/pgrac，main=d50c76b99c），新建公开仓库 sqlrush/pgrac-dsh 并推送 main + 221 tags；README.md 改名 WORKSPACE.md，记忆文件全部 .git/info/exclude 本地化 |
| 2026-08-16 | user 指令记录：Stage 8 正式验收最新目标 = 相同配置的 4 节点存写场景 TPS 超过 Oracle（替代 4×1×3 正确性+性能+三轮稳定性口径；8-C 30 TPS 判据降为历史文本） |
| 2026-08-16 | user 指令执行：Stage 8 计划调整落地——新建 `~/pgrac/docs/2026-08-16-stage8-plan-adjustment.md` + roadmap 加 8-C.1（G-TPS-R11 中间采样三档判据 + R16/R17 接棒位 + verdict 在 R17 后） |
| 2026-08-16 | ⚠️ 纪律纠正（user 严令）：~/pgrac 与 ~/linkdb 只读绝不修改。已撤销上一条对 ~/pgrac 的写入（roadmap 恢复原状、新增文件删除）；计划调整全文迁回工作区 `memory/10-stage8-plan-adjustment.md`，MEMORY.md 硬约束加第 0 条 |
| 2026-08-17 | spec 增量纪律（user 严令，DSH 实施）：新建 `specs-local/`（git-exclude），拷贝 AD-023 / RF-ROOT / spec-5.16 三份 spec 并在本地副本补全 crash-rejoin self-join 例外合同（绑定提交 c4b2357723 的六环死锁圈 + 六门窄例外），~/pgrac 原件零改动 |
