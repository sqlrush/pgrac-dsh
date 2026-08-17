# 01 — 项目背景与目标

## 项目是什么

**pgrac**：基于 PostgreSQL 16.13，目标实现 Oracle RAC 等价能力。

- **shared-disk 集群数据库**（多节点共享存储 + 多活），对标 Oracle RAC，
  **不是** shared-nothing 分片（区别于 Citus/Greenplum 路线）。
- 核心特性目标：Cache Fusion（跨节点块传输）、GES 全局锁、SCN 全局时钟、
  集群崩溃恢复、Active Data Guard、FAN/TAF、RDMA interconnect。
- PostgreSQL 原生只有 shared-nothing 复制 HA，从未有过 shared-disk 多活集群。

## 定位与宣传

- 公开 README 的定位："I'm reimplementing Oracle RAC on PostgreSQL — in the open."
- 项目站点：pgrac.dev（架构深度文、特性目录、与 Oracle RAC 对比）
- 诚实标注：多活代码路径已运行（TCP interconnect + 1Hz LMON 心跳、
  SCN/ITL/undo 块格式、多节点 pgrac.conf bootstrap、Cache Fusion 3-way 块传输、
  跨节点 MVCC、全局 SCN 时钟），但跨节点行为级测试覆盖仍在建设中。
- Sanity anchor：`--disable-cluster` 构建与上游 PG 16.13 二进制一致，
  过全部 219 项回归测试。

## 主导者与许可

- 主导：Yingjie Wang <sqlrush@gmail.com>
- 集群代码为原创，PostgreSQL License（BSD 风格），与上游兼容。

## 版本选型

- PostgreSQL 16.13（选型决策见 `~/pgrac/version-selection.md`）
- 上游源码以 subtree-split 保留完整 history 进入代码仓。

## 项目周期定位

- 这不是短期项目：生产代码估算 ~340K 行、测试 ~620K 行、总工程量 ~767 人月。
- 最小可演示版本 12-18 个月；全部 117 特性 5-15 年。
- 是"一项长期事业"，文档体系为支撑长期迭代设计（spec/feature/AD/talk 多层归档）。
