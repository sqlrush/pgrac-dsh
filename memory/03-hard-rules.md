# 03 — 硬约束与命名约定

## 硬约束 0：公开代码，不公开设计

- 代码 + 用户手册 → 公开（`sqlrush/pgrac` / `~/linkdb`）。
- 设计推理 / spec / AD / Q&A / 路线图 / CHANGELOG / CLAUDE.md → 私有
  （`sqlrush/pgrac-design` / `~/pgrac`）。
- 口诀：**"怎么用"公开 ✓，"为啥这么设计"私有 ✗**。

## Oracle-first 设计门（强制）

所有架构、协议、状态机、角色划分、故障恢复、资源生命周期、锁序、消息流、回收机制，
**必须以 Oracle RAC 对应做法为默认设计**，不得未经查证自行发明。

动手前必须：
1. 先查 Oracle 官方文档 / 公开技术资料 / 仓库内 Oracle 证据档案。
2. 明确区分「Oracle 已验证事实」「基于公开证据的推断」「PGRAC 自研设计」，
   不得把推断/自研说成 Oracle 实际做法。
3. 在私有 spec/AD 中记录来源、证据、置信度、Oracle 机制 ↔ 拟实现方案的逐项映射。

相关档案：`~/pgrac/docs/oracle-knowledge-confidence.md`（高/中/低置信度档案）、
`oracle-verified-citations.md`、`~/pgrac/oracle-rac-analysis.md`（#1-123 特性清单）。

## 代码命名约定（linkdb 仓）

1. 所有新增 C 符号统一 `pgrac_` 或 `cluster_` 前缀。
2. PG 原生符号不覆盖，保持 ABI 不变。
3. 新头文件路径：`src/include/cluster/...`。
4. PG 原文件改动保留原路径，每处改动注释 `/* PGRAC: ... */`。

## 构建与测试硬要求

- `--disable-cluster` 构建必须与上游 PG 16.13 二进制一致，过 219 回归。
- 启用集群：`configure --enable-cluster --enable-tap-tests`。
- TDD 纪律：RED 先行、最小 GREEN、冻结证据（commit hash、测试计数、RC）。

## 仓库安全边界

- 产品/测试字节只在公共 worktree
  `~/pgrac/.codex-candidates/stage8-d4b.LHbUJt` 修改，不 push。
- talk 与所有设计推理只留在 `~/pgrac`，绝不进公开 `sqlrush/pgrac`。
- Writer 不得把私有内容写入公开仓文件；公开仓 docs/ 只能有"怎么用"。

## 用户裁决优先

- 用户最新范围裁决示例（2026-08-14）：
  `聚焦4节点happy path，不要发散，非happy path的功能一律不做`。
- Reader 不得扩张 happy path 或推翻用户已有明确裁决；范围外工作
  `DEFERRED_NOT_REQUIRED`。
