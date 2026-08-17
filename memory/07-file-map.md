# 07 — 关键文件/目录地图

## ~/pgrac（私有设计仓）关键文件

| 文件/目录 | 用途 |
|---|---|
| `CLAUDE.md`（115KB） | Claude 持久化指令，**权威**：硬约束、Oracle-first 门、协作协议 |
| `AGENTS.md`（11KB） | Codex 必读版指令 + CURRENT OVERRIDE（pgrac-talk 0.2.10） |
| `README.md` | 项目说明 + 文档地图 + 阅读顺序 |
| `CHANGELOG.md`（1MB） | spec 与 linkdb tag 对应关系 |
| `progress.md`（125KB） | Stage 8 起按日进度日志 |
| `findings.md`（115KB） | 发现记录 |
| `task_plan.md` | 任务计划（planning-with-files 风格） |
| `architecture-impact.md`（110KB） | AD-001~AD-012 权威清单 + 工作量评估 |
| `oracle-rac-analysis.md` | Oracle RAC 特性清单 #1-123 |
| `pg-implementation-additions.md` | PG 侧铺路点 P-001+ |
| `modification-checklist.md` | 按阶段 LOC 改造清单 |
| `version-selection.md` | PG 16.13 选型决策 |
| `source-analysis-overview.md` | PG 16.13 源码结构导航 |
| `interconnect-tier-strategy.md` | Interconnect 四层延迟 + RDMA 策略 |
| `shared-storage-strategy.md` | 共享存储对比 + SCSI-3 PR |
| `talk-current` / `talk_*.md` | Writer/Reader 协作日志（259 篇） |
| `docs/` | 162 文件：12 个 `*-design.md` 专项方案、AD-017~023、roadmap、perf-baseline、oracle 置信度 |
| `specs/` | 287 份 spec（0.x→8.x），编码前必产出 |
| `features/` | 113 文件：feature-001~1xx（117 特性）+ OVERVIEW.md |
| `reports/` | 182 文件：spec5-7 审查/性能报告、stage8-4x1x3、s3-p0/t400 dossiers |
| `架构设计/` | cluster_{ges,grd,lock_acquire,cf_enqueue,lms}.c 全文精读架构文档 |
| `skills/pgrac-talk/` | 协作协议本体（SKILL.md + 脚本） |
| `.pgrac-talk-state/` | writer/reader 状态、锁、evidence |
| `_graph/` | Obsidian 知识图谱（MOC：stages/subsystems/roadmap/经验教训/开发纪律） |
| `scratchpad/` | 2.1GB 工作草稿：实现计划、patch、测试 rig |
| `ppt/` `build-harness/` | 每 spec 的 PDF/PPTX + 生成脚本 |
| `codex_migration/` `codex_review/` | Codex 环境迁移与历史评审 |
| `scripts/` | 检查脚本（check_stage8_spec_fingerprint.py 等） |
| `src/` | 拆分前的历史代码副本（245 文件） |

## ~/linkdb（公开代码仓）关键位置

| 路径 | 内容 |
|---|---|
| `README.md` | 公开定位（in the open 叙事 + honest caveat） |
| `src/backend/cluster/` | 集群子系统 ~200 个 .c，117,182 行 |
| `src/include/cluster/` | ~130 个 .h，34,347 行 |
| `src/test/cluster_tap/t/` | 214 个 TAP：001_single_node_smoke → 400_pcm_x_queue_4node_liveness |
| `src/test/cluster_unit/` | 139 个单元测试 .c |
| `src/bin/pgrac_*/` | pgrac-init/pgrac-start 等 CLI 工具 |
| `docs/user-guide/` | install / bootstrap / configuration / verification / wal-threads（公开手册） |
| `docs/reference/` | system-views / wait-events / ges-lock-modes（公开手册） |
| `docs/architecture/` | overview.md |
| `docs/cluster/` | clean-leave / ges-bast-deadlock / ges-grant / grd-entry-lifecycle / node-removal / rdma-transport / shared-storage-backends |
| `docs/perf-gates.md` | 性能门（本次扫描时有未提交修改） |
| `diagrams/` | topology.svg / stack.svg / cache-fusion.svg / mvcc-undo.svg / heartbeat-demo.gif |

## 集群源码子系统速览（src/backend/cluster/）

- 心跳/成员：cssd、membership、qvotec、quorum_decision、voting_disk_io
- 锁：ges、ges_mode、pcm_lock、dl_lock、lck、ir_lock、ko_lock、ts_lock、lmd*（死锁图）
- 资源目录：grd（240KB 最大单文件）、grd_outbound/pending/srf/work_queue
- 缓存融合：cf_authority/enqueue/phase2/stats/storage、gcs_block（182KB）、gcs、hw*
- 进程：lmon、lms、reconfig（120KB）、node_remove、clean_leave、startup_phase
- MVCC：scn、itl、tt_*、undo_*、uba、multixact、subtrans、visibility_*
- 恢复：cr*（恢复池）、thread_recovery_*、block_apply、recovery_merge/plan/worker
- 互联：ic、ic_tier1、ic_router、ic_rdma、ic_mux、ic_envelope、ic_chunk
- 其他：backup（108KB）、fence、write_fence、hang*、inject、debug（136KB）、
  cluster_guc（187KB）、remote_xact、wal_thread、wal_state、epoch、sequence、sinval

## 常用排查命令（供后续会话使用）

```bash
# 当前 talk 与状态
cat ~/pgrac/talk-current
cat ~/pgrac/.pgrac-talk-state/writer/state.json
cat ~/pgrac/.pgrac-talk-state/reader/state.json

# 代码仓状态
cd ~/linkdb && git status -s && git log --oneline -10
cd ~/pgrac/.codex-candidates/stage8-d4b.LHbUJt && git status -s

# 行数统计
find ~/linkdb/src/backend/cluster -name '*.c' | xargs wc -l | tail -1
```
