# MEMORY.md — pgrac 项目核心记忆（快速热身）

> 会话接手 pgrac 任务时先读本文件。详细版见 `memory/*.md`。
> 生成于 2026-08-16；最后更新见 `MEMORY-CHANGELOG.md`。

## 一句话

**pgrac = 在 PostgreSQL 16.13 上重实现 Oracle RAC**（shared-disk 多活集群：
Cache Fusion / GES / SCN / 集群恢复 / Active Data Guard）。
不是 shared-nothing 分片。主导者：Yingjie Wang（sqlrush@gmail.com）。

## 两仓分工（最重要的一张表）

| 角色 | 本地目录 | GitHub 仓库 | 可见性 |
|---|---|---|---|
| 公开代码 + 用户手册 | `~/linkdb` | `sqlrush/pgrac` | PUBLIC |
| 私有设计 / 推理 | `~/pgrac` | `sqlrush/pgrac-design` | PRIVATE |

口诀：**"怎么用"公开 ✓，"为啥这么设计"私有 ✗**

⚠️ GitHub `sqlrush/pgrac` 是【公开代码库】——设计/spec/AD/Q&A/路线图等**绝不能 push 过去**。

## 当前状态（2026-08-16 快照）

- **Stage 8**：Oracle 对齐重构专项 R1-R17（阻塞项，当前主战场）
- **Stage 8 正式验收最新目标（user 2026-08-16 指令）**：不是"4×1×3 正确性+性能+三轮稳定性"口径，
  而是**相同配置的 4 节点存写场景 TPS 性能超过 Oracle**（roadmap 8-C 的 30 TPS 判据为历史合同文本，
  最终验收目标以本条 user 指令为准）
- **Stage 8 计划调整（user 2026-08-16 指令，全文在本工作区 `memory/10-stage8-plan-adjustment.md`）**：
  ① R11 后加中间采样点 G-TPS-R11（固定四节点 clients 配置单轮零错 + TPS 读数，
  三档判据：正确性红→8-G.2 归因修复重采 / TPS<1116.25→R16/R17 接棒 / TPS≥1116.25→正式三轮回环）；
  ② R16/R17 接棒位明确（采样红或回环 TPS 红即接棒，最终 verdict 在 R17 后；R17 后仍红→需 user 重开
  A-campaign 根因调查）
- 里程碑：`ST8-M01-P4-S0414`；position：`04 RF-ROOT P6 S05-5 P04 A2 PUBLIC-MERGED`
- **t243 回正清单已核实并交编码会话**（2026-08-16 20:55 第一轮 + 22:45 第二轮，
  见 `RFROOT-PLAN.md` 尾部两个"🔴 回正清单"节）：删 joiner 合成 survivor 事件 /
  修 incarnation-epoch 拼接 / durable I/O 移出 reconfig 锁 / DONE 回声去重 /
  停机 CF(X) 第二持锁者排查 / 接现有停机生产者 / 清理 TEMP 诊断
- Writer 租约 epoch 32，`next_action=STOP`；t243 已知 RED（canonical node1 ROOT 缺失）
- Reader 最近决策：`RFROOT-P04-A1-T243-SHAREDCF-WITNESS-CONFLICT-20260816`
- **P0 EMERGENCY-HOLD**：`RFROOT-P04-A-ROLLOVER-CLOSE-AUTHORITY-SMUGGLE-20260816`
  （predicate: TALK_AUTHORITY_FORK）
- `~/linkdb` 主工作树：detached HEAD @ `238fe51d7c` + **17 文件未提交修改**
- 公共 worktree：`~/pgrac/.codex-candidates/stage8-d4b.LHbUJt`（branch `agent/stage8-r3-r4d10-integration`）

## 硬约束速记

0. **~/pgrac 与 ~/linkdb 只读，绝不修改**（user 2026-08-16 严令）：所有需要调整的文件
   一律拷贝/重建到本工作区 `~/pgrac-dsh`（memory/ 或工作区文件）再改；读取分析不限。
0b. **spec 增量纪律（user 2026-08-17 严令，由 DSH 实施）**：推导过程中形成原始 spec 未写的
   技术方案时，从 ~/pgrac 拷贝相关 spec 到 `~/pgrac-dsh/specs-local/`，并**只在本工作区**
   对 spec 做优化/内容补全（增量章节标注"工作区本地增量+日期"，原文一字不改）；
   specs-local 已 git-exclude，绝不 push；并入私有库由 user 裁决后经 talk 同步。
1. 设计文档绝不上公开仓；产品字节只进公共 worktree，不 push。
2. 代码命名：新符号 `pgrac_` / `cluster_` 前缀；改 PG 原文件标 `/* PGRAC: ... */`；
   新头文件放 `src/include/cluster/`。
3. 所有设计对齐 Oracle RAC（Oracle-first 门）：先查 Oracle 证据，区分
   「Oracle 已验证事实 / 公开证据推断 / PGRAC 自研」。
4. 协作走 **pgrac-talk 0.2.10** 协议（Writer/Reader 双会话），见 `memory/06-talk-protocol.md`。
5. `--disable-cluster` 构建必须与上游 PG 16.13 二进制一致、过 219 回归。

## 关键入口

- 当前 talk：`~/pgrac/talk-current` → `talk_20260816-0052.md`
- 权威指令：`~/pgrac/CLAUDE.md`（Claude 必读）/ `~/pgrac/AGENTS.md`（Codex 必读）
- 北极星路线图：`~/pgrac/docs/development-roadmap.md`
- 状态机：`~/pgrac/.pgrac-talk-state/writer/state.json`、`reader/state.json`
- 集群代码：`~/linkdb/src/backend/cluster/`（~117K 行 C）
- 测试：`~/linkdb/src/test/cluster_tap/t/`（214 个）、`cluster_unit/`（139 个）

## 我的工作区（2026-08-16 建立）

- **DSH 新角色（user 2026-08-17 指令）：审核编码会话（flash 模型）的代码，
  发现问题立即投递到 `~/pgrac-dsh/DSH-REVIEW.md`（专用审核通道，与编码会话自维护的
  RFROOT-PLAN.md 分离避免双写冲突）；审核合同六条见 DSH-REVIEW.md 头部。**

- 本地：`~/pgrac-dsh` = git 仓库（main = 上游代码完整副本，59,657 提交）
- 我的 GitHub 仓库：**https://github.com/sqlrush/pgrac-dsh**（公开）
- remote：`origin` = pgrac-dsh（我的仓），`upstream` = sqlrush/pgrac（项目公开主仓）
- 代码工作在 `~/pgrac-dsh` + pgrac-dsh 仓库开展；**不碰** ~/linkdb 与公共 worktree
- **~/pgrac、~/linkdb 只读**（user 2026-08-16 纪律）；计划/文档调整放本工作区 memory/，绝不写回两仓
- 记忆文件（MEMORY.md、memory/、WORKSPACE.md）仅本地，`.git/info/exclude` 排除，绝不 push
- 回馈上游：只走 PR/补丁，经用户确认

## 接手时的建议顺序

1. 读本文件 → 2. `memory/05-current-state.md` → 3. 对照 talk 最新状态 →
   4. 读 `~/pgrac/CLAUDE.md` 相关段落 → 5. 确认租约/锁状态后再动手。
