# specs-local — 工作区本地 spec 增量副本（2026-08-17 建立）

> 研发纪律（user 2026-08-17 指令）：推导过程中形成的、原始 spec 未写的技术方案，
> 必须从 `~/pgrac` 拷贝相关 spec 到 `~/pgrac-dsh/specs-local/`，并**只在本工作区**
> 对 spec 进行优化与内容补全；`~/pgrac` 与 `~/linkdb` 原件只读，绝不修改。
> 本目录已加入 `.git/info/exclude`，绝不 push 公开仓。若需同步回私有设计库，
> 由 user 走其 Writer/talk 流程显式授权后另行同步。
> 公开政策（user 2026-08-18 裁决 A）：本目录随 rf-root-dev/main 推送至
> github.com/sqlrush/pgrac-dsh（公共仓库）；代码与设计文档公开均获 user
> 显式授权（2026-08-17 口头、2026-08-18 书面复核）。原始 spec（~/pgrac）
> 仍只读、不公开于本仓。

## 当前副本清单与增量状态

| 本地副本 | 源文件（只读） | 增量内容 |
|---|---|---|
| `ad-023-rfroot-p04-recovery-authority-serving-split.md` | `~/pgrac/docs/ad-023-rfroot-p04-recovery-authority-serving-split.md` | §10：crash-rejoin self-join 例外合同（六环死锁圈 + 六门窄例外） |
| `spec-rf-root-durable-root-retention-and-fenced-takeover.md` | `~/pgrac/specs/spec-rf-root-durable-root-retention-and-fenced-takeover.md` | §12：D3′ rebuild-first 路径的 formation-witness 绑定增量 |
| `spec-5.16-online-join-grd-pcm-remaster.md` | `~/pgrac/specs/spec-5.16-online-join-grd-pcm-remaster.md` | 附录：self-join 例外与 HF2 actor 边界的一致性说明 |
| `spec-s8-stop-01-root-control.md` | `~/pgrac/specs/spec-s8-stop-01-root-control.md` | 增量 1：contract 1 停机顺序（checkpoint→STOPPED→serving/authority 转换→CLOSED）；增量 2：qvotec 同 poll 写后 fence-token 刷新（4.12b D2 收窄） |

## 绑定锚

- 产品提交：`c4b2357723` "fix(cluster): break the crash-rejoin phase-3 deadlock cycle (RF-ROOT P6)"（2026-08-17 08:57）
- 派生自：AD-023 §9.2（冻结 capability 合同）、RF-ROOT §2.4/§2.5/§5、spec-5.16 Hardening v1.2 HF2
- 增量标记：每份副本的增量章节均以 `工作区本地增量（2026-08-17）` 标注，与原文正文分隔，原文一字未改
