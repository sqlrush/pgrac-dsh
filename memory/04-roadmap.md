# 04 — 路线图与工程量

## 6 大主线 Stage + 2 个专项

| Stage | 内容 | 周期估算 |
|---|---|---|
| 0 | 基础设施期：脚手架、CI/CD、测试框架（**已完成**，spec-0.30 acceptance） | 3-10 个月 |
| 1 | 单节点伪集群：PG 在共享存储上跑起来 | 10-13 个月 |
| 2 | 双节点 Cache Fusion MVP：跨节点传块、能锁 | 12-18 个月 |
| 3 | Undo + MVCC：AD-006 落地（最复杂） | 9-15 个月 |
| 4 | WAL + Recovery：集群崩溃恢复、fencing | 6-12 个月 |
| 5 | 完整 GES + 死锁：锁体系完整化 | 6-9 个月 |
| 6 | 生产化加固：RDMA / ADG / Backup / 监控 | 12-24 个月 |
| 7 | 性能攻坚：4 节点 pgrac 超越 4 节点 Oracle RAC | 目标驱动 |
| **8** | **Oracle 对齐重构专项 R1-R17（当前，阻塞项）** | 2026-08 重定义 |

Stage 8 于 2026-08-02 重定义、08-03 扩展；R15 冻结验收合同，最终 verdict 在 R17 后。
旧「后 GA 可选架构优化」定义已 SUPERSEDED。

## Stage 8 正式验收目标与执行策略（user 2026-08-16 指令，工作区本地口径）

- 最终目标：相同配置 4 节点存写场景 TPS 超过 Oracle（三轮零错 + 三轮中位数 > 冻结值 1116.25）；
  8-C 的 30 TPS 判据降为历史合同文本。
- 执行策略：R11 后加 `G-TPS-R11` 中间采样（单轮零错 + TPS 三档判据），R16/R17 明确为接棒位，
  最终 verdict 一律在 R17 后；R17 后仍红 → 需 user 重开 A-campaign 根因调查。
- 完整正文：`memory/10-stage8-plan-adjustment.md`（工作区本地；~/pgrac 只读不改）。

## 发布决策（关键节点）

- **Stage 5 完成 → v0.5.0-beta（首次正式公开 release）**（约 ~2033）
- Stage 6 完成 → v1.0.0 GA（约 ~2034-2035）
- 理由：Stage 5 才具备"RAC 核心功能"的最早可信切点；过早发布会因
  缺 crash recovery/fencing 翻车（RethinkDB 教训）。

## 诚实工程量（README 公示）

- Oracle 特性总数：117 有效（4 废弃 + 2 不实现）
- 生产代码 ~340K 行；测试 ~620K 行；总 ~767 人月
- 最小可演示版本 12-18 个月；全部特性 5-15 年

## 性能目标（阶段性 bar）

- Stage 0-1（单节点）：≥ PG 16 原生 0.95×（集群开销 ≤5%）
- Stage 2-3（双节点）：≥ Oracle RAC 同档 1.5×
- Stage 4-5（多节点+恢复+全锁）：≥ Oracle RAC 同档 2.5×
- Stage 6（RDMA+ADG）：≥ Oracle RAC 同档 3-4×（前提：AD-012 例外 9 双维度
  visibility 路径分流，本地 OLTP hot path 零集群开销）

## 进度跟踪入口

- 北极星：`~/pgrac/docs/development-roadmap.md`
- 进度日志：`~/pgrac/progress.md`（Stage 8 起按日记录）
- 任务计划：`~/pgrac/task_plan.md`
- 路线图 MOC：`~/pgrac/_graph/moc/roadmap.md`、`_graph/moc/stages/`
