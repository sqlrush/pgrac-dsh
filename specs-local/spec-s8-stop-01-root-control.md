# S8-STOP-01 — ROOT-CONTROL A.1 repair plus conditional no-generation carrier

> **Status: A1 RELEASED AT `a5358e.../d7277614...` / SUCCESSOR BINDING SAME-HASH PENDING**
>
> The prior A1-only product/test release remains valid and is not revoked by this metadata-only parent
> rebind. Non-A1 RF work remains stopped until Claude records the successor whole-bundle same-hash.
> This is private design material for `sqlrush/pgrac-design`; it must never be copied or pushed publicly.

| Item | Exact value |
|---|---|
| Acceptance ID | `S8-STOP-01 / SIG-01-A1-R / RF-A1-LIFECYCLE-REV1-A` |
| Product evidence baseline | `f076653df977dfa67c1f8fdaa1f985daf0a240b4` |
| Approved unified parent | `specs/spec-s8-seven-stop-unified-evaluation.md`; body `bb4c4abe610ba547f25230393fe1075d61d53c35091813508ddba17a7407fa29 / 79 / 5041` |
| Exact implementation refinement | `25d6dfe18629ca15b016145701f1d120a9778689:talk_20260809-0218.md`; token `RF-A1-LIFECYCLE-REV1-A` |
| CC adjudication | Gate 8 literal accepted in active talk; receipt commit `a391ba2e6c2be67f1aa08cf5672b2f082d1d6b9d` |
| Scope | Existing `pgrac_wal_state` A1 repair plus exact no-generation root identity/carrier/migration contract |
| Explicit exclusions | carrier/migration product activation before their evidence gates; STOP04 concrete provider; durable R8 receipt; post-carrier W6 mirror |
| Coding order | existing A1 release: common → parallel W1, W2+W4, W5, W6 → W3 last → whole-A1 review → post-repair C2 |

This successor keeps the A1 implementation byte-for-byte in semantic scope and adds the user-approved,
conditionally inactive no-generation carrier/migration contract needed by the other six STOPs. It does not
activate that carrier, add a scalar generation, or promote any uncommitted scratch object.

<!-- NORMATIVE-BODY-BEGIN -->

## R0. authority and the nine approved boundaries

This is the single deduplicated W1+W2+W3+W4+W5a+W5b+W6 package. Its only product baseline is public
`f076653df977dfa67c1f8fdaa1f985daf0a240b4` and the approved RF unified body
`bb4c4abe610ba547f25230393fe1075d61d53c35091813508ddba17a7407fa29 / 79 / 5041`.
Early/pre-recovery LMS, postmaster CF, and SIGHUP-triggered phase4 initialization are expressly rejected.

This package is only the caller/lifecycle implementation refinement of approved `SIG-01-A1-R`; it adds no
authority token, ticket, generation, actor, runtime GUC, shared-memory state, wire, catalog, disk field or
disk version. The only new externally visible surface is W1's **frontend-initialization-only** initdb handoff
`--pgrac-wal-state-root=ABSOLUTE_DIR`, which only passes the existing
`pgrac-init --wal-threads-dir` value to the existing initdb child. It is not runtime or persistent authority
and cannot be used for repair.

The effects on the user's nine approved RF rows are exactly:

1. Duty identity A is unchanged; no independent scalar generation is introduced.
2. ROOT A1 repair is refined and implemented here; scope does not expand to a carrier.
3. Carrier remains strictly gated by `A1 implemented + reviewed + post-C2 evidence` and has zero activation now.
4. Migration remains strictly after carrier and has zero activation and zero old-format automatic migration now.
5. STOP03 preserves existing IR/A2/REJOIN-B/A-prime; A1 W6 writes nothing, and a future mirror remains post-IR and separately gated.
6. STOP04 selects no provider and remains `UNAVAILABLE`.
7. `SIG-05-R` stack-only/no-ticket remains unchanged.
8. R8 consumer A still has no durable receipt.
9. Revised `SIG-09` remains unchanged.

## R1. Oracle evidence boundary

`ORACLE VERIFIED / HIGH`: Oracle uses the CF enqueue to serialize database-wide control-file writes;
control files carry checkpoint/redo-thread state through create/mount/open lifecycle; public RAC material
documents LMON/LMS background responsibilities, shared redo threads and survivor recovery; clean shutdown
and abort/crash have different recovery consequences. Sources are the approved unified packet's Oracle 26
*Managing Control Files*, *Wait Events*, *RAC Redo Threads*, and Oracle 21 *Introduction to RAC* and
*Background Processes* references.

`PUBLICLY UNKNOWN`: public sources do not disclose modern RAC control-file exact bytes/checksum/fsync/
post-read, the exact phase/process that writes thread ACTIVE/STOPPED, exact LMS/CSSD/QVOTEC start order,
PG-specific FPW sticky behavior, the exact instruction boundary for checkpoint publication, clean-shutdown
coordination-stack handoff, or compatibility-mirror behavior.

Therefore every exact caller/order/mask/error policy below is a `PGRAC ADAPTATION`. It imitates only the
Oracle shape of explicit creation, validation before mount/open, CF-serialized control metadata, and clean
close before coordination drain. It is not presented as Oracle internal implementation.

## R2. common derived predicates and the sole formed-cluster RMW

`REGISTRY_FORMED` is a derived condition, not new state: `cluster.enabled`, nonempty
`cluster.wal_threads_dir`, and the existing valid v1 `pgrac_wal_state`
(512-byte header + 128×512-byte slots = 66048 bytes) are all true.

`CF_VERIFIED_X` is true only when all of the following are true: shared CF authority is enabled; LMS is
enabled and `cluster_lms_is_ready()==true` (`wait_for_ready()==true` with DISABLED does not count); GRD CF
master lookup is `>=0`; CF(X) acquisition succeeds; and the CF resource did not take
`GES_REJECT_REASON_MASTER_DEAD_NATIVE/OK_NATIVE`. `cluster_lock_acquire_s4` must reject dead-master-native
for `CLUSTER_CF_RESID_TYPE`; any `OK_NATIVE` in a formed registry is nonaffirmative. No new held bit is
needed: these predicates plus the existing successful held state prove the coordinated hold.

Every W2–W5 mutation of an existing formed registry uses this sole algorithm:

1. obtain `CF_VERIFIED_X`;
2. while locked, fresh-read the header and exact own slot and validate size, header CRC, slot CRC, thread,
   node and state;
3. copy the fresh image and change only the caller's frozen field mask;
4. recompute the CRC over `[0,504)`, issue an exact 512-byte `pwrite`, reject short write, and fsync the file;
5. use a distinct buffer for a fresh `pread`, reclassify it, and validate field-by-field that masked values
   equal their requested values and every byte outside the mask equals fresh-before;
6. unlock.

No failure may unlink, truncate, rename, empty-rebuild or issue a compensating overwrite. A physical
partial/torn image may remain CORRUPT, but post-read and successor readers must detect it fail-closed and
preserve it.

W1's only mutation is explicit offline creation before the cluster is formed. It uses O_EXCL plus offline
formation proof and cannot coexist with a live writer. Once formed, W1 runtime has no writer and therefore
does not bypass the common CF domain.

## R3. exact phase and caller table

| ID | Exact caller/phase | Oracle fact/unknown | PGRAC adaptation, field mask and failure | Performance/reliability |
|---|---|---|---|---|
| W1-create | `pgrac-init`-driven initdb frontend finalization, after `initialize_data_directory()` succeeds and before initdb `fsync_pgdata`/success return | VERIFIED: control files are explicitly created; UNKNOWN: Oracle bytes/creator syscall | R4; only fresh/offline root O_EXCL creation of existing v1 66048-byte registry, full-file post-read; failure exits nonzero and preserves partial evidence | one 66 KiB write plus file/root fsync; no runtime cost |
| W1-runtime | initial postmaster, crash-shmem reinitialization `cluster_wal_thread_init`, and configured single-user gate | VERIFIED: control metadata is readable before mount/open; UNKNOWN: Oracle exact process | runtime read-only validate; missing/wrong-size/corrupt/foreign evidence is FATAL `53RA2`, preserving inode/bytes; configured `postgres --single` is FATAL before StartupXLOG because coordinated CF service is absent; flat/noncluster is unchanged | one startup read; removes runtime create/unlink risk |
| W2 | phase4 initial ClusterStats child after `InitAuxiliaryProcess` gives it PGPROC, at SPAWNING→READY | VERIFIED: thread/control state precedes open/serving; UNKNOWN: Oracle writer process/order | Stats performs existing durable self-fence; self-fenced skips W2/checkpoint then becomes READY under existing policy; otherwise `CF_VERIFIED_X`, fresh EMPTY or valid own slot, CORRUPT/FOREIGN FATAL; mask=`identity,state=ACTIVE,tli,started_at,last_updated,highest_lsn,highest_scn,refresh_interval_ms,merge_recovered_lsn=0`, preserving checkpoint/fpw/reserved; unlock after post-read | one CF+512-byte fsync per incarnation; failure prevents Stats READY and admission |
| W5b-EOR | StartupXLOG end-of-recovery `UpdateFullPageWrites` caller | FPW is PG-specific | EOR never writes registry; off→on enables immediately in PG-safe order; true→desired-false returns closed/deferred, leaves `Insert->fullPageWrites=true`, and emits no false WAL; if replay says historical `lastFullPageWrites=false`, read-only validation must prove valid own slot sticky=1, otherwise Startup FATAL | no CF wait; conservative FPW may add WAL but cannot lower safety |
| W5b-steady | only non-EOR `CreateCheckPoint`, after outer checkpoint CF acquire/fresh shared-control read and before that function's first `START_CRIT_SECTION()`; SIGHUP never initializes phase4 | Oracle exact behavior unknown; PG-specific | borrow outer `CF_VERIFIED_X`, never re-enter; when desired=false and Insert=true, own slot must be OK+ACTIVE; sticky=1 is no-write success, otherwise mask only `fpw_was_off:0→1`, fsync/post-read; only then enter PG critical, emit `XLOG_FPW_CHANGE(false)`, set Insert=false; failure leaves true, emits no false WAL, warns/returns closed, lets checkpoint continue, and retries at next non-EOR checkpoint; desired true enables immediately; SIGHUP desired false only leaves mismatch | no loop-head/SIGHUP CF storm; at most one extra 512-byte fsync when first setting sticky; failure degrades to FPW on |
| W5a | non-EOR online/forced/shutdown `CreateCheckPoint`, after durable `UpdateControlFile()`'s corresponding `END_CRIT_SECTION()` and before `SyncPostCheckpoint`/WAL recycle | VERIFIED: control file carries checkpoint progress and is CF-serialized; UNKNOWN: exact order/caller | EOR has no advert; borrow outer `CF_VERIFIED_X`; mask only `checkpoint_redo_lsn=checkPoint.redo`, preserve all else, fsync/post-read; false warns, advertises nothing new, keeps old value, lets checkpoint continue, retries next checkpoint | at most one 512-byte fsync per non-EOR checkpoint; stale/zero causes extra replay/fail-closed, never skip |
| phase4 ACK | Stats releases CF after W2, then calls `RequestCheckpoint(CHECKPOINT_IMMEDIATE|CHECKPOINT_FORCE|CHECKPOINT_WAIT)` and becomes READY only after return | Oracle exact ACK unknown | done_cv proves PG checkpoint completion only, not W5a/W5b helper success; W5 effects are judged directly from slot/FPW tests, with no receipt/bit/counter; checkpoint ERROR keeps Stats not READY; RequestCheckpoint's done_cv has no independent timeout, while the shared admission deadline causes honest FATAL/teardown on expiry and adds no cancellation protocol | one forced checkpoint per startup |
| W4 | Stats only after initial W2; READY main loop and RUNNING respawn | Oracle thread/control telemetry shape VERIFIED; cadence/fields UNKNOWN | initial Stats enters loop only after W2; RUNNING respawn validates own OK+ACTIVE but never repeats W2/forced checkpoint; each tick obtains `CF_VERIFIED_X`; mask only `tli,last_updated,highest_lsn,highest_scn,refresh_interval_ms`, never state/started_at/checkpoint/fpw/W6/reserved; failure is typed skip, LOG once plus existing refresh-fail counter, with no overwrite retry | at most one CF+512-byte fsync per stats cadence; no transaction hot path |
| W3 | clean smart/fast checkpointer after `ShutdownXLOG()` returns, before checkpointer `proc_exit(0)` | VERIFIED: clean close differs from crash recovery; UNKNOWN: exact Oracle actor/stack order | checkpointer has PGPROC and obtains `CF_VERIFIED_X`; fresh own ACTIVE, or own STOPPED idempotent no-op; mask=`state=STOPPED,last_updated,tli,highest_lsn,highest_scn`, preserving identity/started_at/checkpoint/fpw/W6/reserved; EMPTY/CORRUPT/FOREIGN/CF/I/O false warns, leaves ACTIVE/evidence, and lets shutdown continue; immediate/fatal never call W3 | one CF+512-byte fsync per clean shutdown; failure conservatively appears crashed next start |
| W6 | cold xlogrecovery, online recovery orchestrator, and every correctness reader | VERIFIED: survivor reads/replays failed redo; UNKNOWN: Oracle/PGRAC mirror | delete/disable both A1 writers; historical/forged nonzero `merge_recovered_lsn` is exactly zero to every correctness reader and cannot create a skip; retained evidence/replay stays real; W2 may clear own bytes; W4/W5 preserve; diagnostics may show `raw_ignored` only; no post-carrier mirror code/activation | removes write/skip risk; may cause conservative extra replay |

## R4. exact W1 offline provisioning

1. Reject `initdb -c/--set + IsBootstrapProcessingMode` as creator identity: initdb `--check` probes and
   the real `--boot` share that mode, while later standalone is NormalProcessing. That seam can write too
   early or make a later probe FATAL before finalization.
2. Before touching ROOT, `pgrac-init --wal-threads-dir=ROOT --node-id=N` performs a read-only preflight:
   ROOT is absolute/canonical with no symlink escape; if registry is absent, ROOT is fresh and empty and
   this PGDATA is fresh. It creates only exact `ROOT/thread_(N+1)` and passes both `-X` and
   `--pgrac-wal-state-root=ROOT` to the same initdb child. Existing registry means join verify-only.
3. First-node formation with absent registry is serialized: immediately before finalization, any ROOT entry
   or thread other than this direct child `thread_(N+1)` fails. Concurrent first creates allow the O_EXCL
   winner to finish; a loser may verify only a complete valid file. Partial evidence fails immediately and
   is never waited on or repaired.
4. After `initialize_data_directory()` succeeds, initdb frontend O_CREAT|O_EXCL creates canonical
   `ROOT/pgrac_wal_state` owner-only, writes the existing header plus 128 all-zero slots, exact 66048 bytes,
   fsyncs file and ROOT, then close/reopen/stat/full-preads and byte-validates header plus zero slots.
   `--no-sync` does not exempt either registry fsync.
5. `EEXIST` is read-only verify: exact size/header and every slot must be all-zero or a valid self-described
   CRC slot. Partial/corrupt/foreign evidence exits initdb/pgrac-init nonzero and remains unchanged. There is
   no temp, rename, unlink cleanup or truncate.
6. `pgrac-init` writes `cluster.node_id/cluster.wal_threads_dir` only after finalizer success, so initdb
   backend probes do not enter the runtime registry gate.
7. A1 changes runtime `cluster_wal_state_ensure` to validate-only open/read and removes every
   `O_RDWR|O_CREAT|O_EXCL`, unlink, and “remove then rebuild” hint.
8. Upgrade is not auto-migration. Before A1, the entire cluster must be offline, a valid v1 registry must
   be proved and backed up. A missing registry in an old deployment can only be created while still on f076
   under full-cluster stop and controlled single-node validation, or restored from known-valid backup.
   A1 never creates or repairs it. Plain initdb and flat PostgreSQL remain unchanged.

## R5. exact startup, admission and shutdown sequencing

The sole registry-configured initial/crash-reinit phase4 order is:

```text
startup process succeeds; checkpointer is alive with PGPROC
pmState may be PM_RUN for child plumbing, but connsAllowed/PM READY/systemd READY remain false
DIAG spawn -> exact READY
CSSD spawn -> exact READY
QVOTEC spawn -> exact READY -> existing strict multi-node in-quorum proof
LMS spawn -> cluster_lms_is_ready()==true; DISABLED is failure
existing node-id/voting/shared-CF validators
Stats spawn -> SPAWNING
  durable self-fence direct read
  fenced: no W2/no checkpoint -> READY
  unfenced: W2 CF RMW/post-read -> unlock -> FORCE|WAIT checkpoint returns -> READY
postmaster finalize advances RUNNING
only now connsAllowed=true and READY advertisement
```

The registry-configured hot-standby path also cannot advertise ordinary/read-only readiness early. PG
internal pmState may remain, but ordinary admission waits for this commit. `cluster.enabled=false` or an
unconfigured registry keeps the vanilla path.

Clean smart/fast shutdown has this sole order:

```text
first wave stops ordinary backends plus Stats/W4, LMD, Sinval, Undo, DIAG, LCK, and peers
retain exactly LMON + CSSD + QVOTEC + LMS through checkpoint/W3
PM_WAIT_BACKENDS clean predicate exempts only those retained PIDs
checkpointer ShutdownXLOG -> shutdown W5a -> W3 -> exit(0)
postmaster reaps successful checkpointer
postmaster SIGTERMs retained stack in reverse: LMS -> QVOTEC -> CSSD -> LMON
PM_SHUTDOWN_2 waits for retained PIDs plus archiver/walsenders to reach zero, then normal exit
```

Checkpointer fork failure/abnormal exit, clean→immediate upgrade and FatalError SIGQUIT the retained stack,
perform no W3, and cannot leak or hang. The old postmaster W3 caller is removed; postmaster never waits on a
CF condition variable.

## R6. frozen invariants

- I1. Postmaster has no PGPROC and never acquires remote/verified CF; every CF caller is a PGPROC actor.
- I2. Registry-configured phase4 never advertises ordinary admission/readiness before commit.
- I3. Formed-registry mutation has no native fallback, unknown master or stale full-slot write.
- I4. W2/W3/W4/W5 masks are explicit; W4↔W5a/W5b and W2↔W5 interleavings preserve the union.
- I5. `fpw_was_off` is monotone; sticky fsync+post-read happens before false WAL and Insert=false.
- I6. W5a advertises only a durable checkpoint and does so before cleanup/recycle; EOR never advertises.
- I7. STOPPED occurs only after clean shutdown checkpoint and before coordination drain; abort/crash stays ACTIVE.
- I8. W6 is zero/nonauthority before carrier; forged nonzero cannot reduce replay.
- I9. Missing/partial/corrupt evidence is never automatically deleted, empty-created or overwritten.
- I10. Disk path/layout/version/CRC remain `pgrac_wal_state` v1/66048/[0,504).
- I11. A self-fenced node performs no W2/W4/W5 activation mutation; existing D5 write fence is unchanged.
- I12. Checkpoint done ACK proves PG checkpoint completion only, never W5 helper success.

## R7. failure and FATAL boundaries

- W1 finalizer/verify exits command nonzero; runtime initial/crash validation is FATAL `53RA2`; configured
  single-user is FATAL before StartupXLOG. All evidence is preserved.
- DIAG/CSSD/QVOTEC/LMS exact-ready, quorum, validators, CF, W2, Stats or PG-checkpoint failure/shared-deadline
  expiry is startup FATAL with no admission. A checkpoint completing after the deadline is not GREEN; normal
  postmaster teardown applies and no default 30-second success promise is introduced.
- Self-fence preserves the existing nonfatal write-fenced policy and makes no registry advert.
- W4 is typed skip/LOG-once/counter with no admission or correctness effect.
- W5b persistence false lets checkpoint continue, leaves FPW true, emits no false WAL, and retries next non-EOR checkpoint.
- W5a persistence false lets checkpoint continue, retains the old/zero advert, and retries next checkpoint.
- Existing outer shared-control CF acquire/read failure remains PG checkpoint ERROR; it is not swallowed as a W5 helper false.
- W3 false warns, leaves ACTIVE and allows shutdown to continue; the next start treats recovery as required.

## R8. minimum immutable RED/GREEN matrix

1. **W1:** fresh pgrac-init creates exact bytes; second-node join is verify-only; absent nonfresh root,
   wrong size, bad header, bad slot, injected short write/fsync/post-read all exit nonzero and preserve
   inode/bytes; initial/crash/single runtime cannot create/unlink/truncate; plain initdb/noncluster unchanged;
   `--check/--boot/standalone` cannot trigger early.
2. **CF:** LMS DISABLED-but-wait-true, GRD master=-1 and CF dead-master-native all reject; local/remote
   coordinated grant works; postmaster CF call count is zero.
3. **phase4:** exact order and one shared deadline; connsAllowed/READY remain false until Stats READY;
   Stats owns PGPROC; self-fenced performs no W2/checkpoint; initial/crash-reinit gate runs; RUNNING Stats
   respawn only validates and does not repeat W2.
4. **W2:** EMPTY/own-valid/own-prior-ACTIVE crash-incarnation succeed; CORRUPT/FOREIGN are preserved and
   FATAL; post-read mismatch is FATAL; bytes outside mask are unchanged and W6 clears to zero.
5. **W5b:** EOR desired-false stays true with no false WAL; historical false+sticky1 passes and sticky0/
   corrupt is FATAL; non-EOR injected pre-sticky failure emits no false WAL; only sticky fsync/post-read
   permits false WAL/flag; failure still completes checkpoint and next checkpoint retries; off→on is immediate.
6. **W5a:** EOR writes zero; online/phase4/shutdown writes after durable-control END_CRIT and before cleanup/
   recycle, borrows outer CF without re-entry; failure preserves old value and completes checkpoint; next retries.
7. **W4:** pre-ACTIVE no-op; ACTIVE changes exactly five telemetry fields; CF failure typed-skip/LOG-once;
   deterministic W4↔W5a/W5b and W2↔W5 schedules preserve unions without sticky/checkpoint lost update.
8. **W3:** Stats stops first; LMON/CSSD/QVOTEC/LMS remain alive and READY through ShutdownXLOG/W5a/W3;
   drain begins only after STOPPED post-read; immediate/fatal/checkpoint failure stays ACTIVE and reaps all;
   W3 CF failure stays ACTIVE while clean exit does not hang.
9. **W6:** cold and online writer call count is zero; forged nonzero yields skip bound zero in xlogrecovery,
   cluster_hw_remaster, cluster_recovery_merge, cluster_recovery_worker and orchestrator; retained evidence is
   actually replayed; diagnostic labels raw_ignored.
10. **Performance:** startup adds one forced checkpoint only; steady W2/W3=0, W5=checkpoint cadence,
    W4≤stats cadence; no transaction-path call and no SIGHUP/loop retry storm. Unit/TAP GREEN is not the
    destination; whole ROOT-A1 review plus post-C2 precedes later formal 4×1×3/rate gates.

The minimum existing test surfaces to extend are
`src/bin/pgrac/t/001_init.pl`, `src/bin/initdb/t/001_initdb.pl`, cluster_unit wal_state/cf_enqueue/
xlog/startup_phase/stats/recovery families, and TAP 064/107/243/244/247/248/288.

## R9. exact allowed implementation scope and order

After this exact private body receives same-hash, the public product candidate is limited to:

- `src/bin/pgrac/pgrac-init`;
- `src/bin/initdb/initdb.c`;
- `src/include/cluster/cluster_wal_state.h`;
- `src/backend/cluster/cluster_wal_state.c`, `cluster_startup_phase.c`, `cluster_stats.c`,
  `cluster_lock_acquire.c`, and only necessary internal headers;
- `src/backend/access/transam/xlog.c`, `xlogrecovery.c`;
- `src/backend/postmaster/checkpointer.c`, `postmaster.c`;
- W6 correctness consumers `cluster_hw_remaster.c`, `cluster_recovery_merge.c`,
  `cluster_recovery_worker.c`, `cluster_thread_recovery_orchestrator.c`;
- only the exact existing test surfaces named in R8 and the cluster_unit Makefile entries needed to link them.

No carrier/root-sidecar/migration/STOP04/R8 code may enter this diff. The implementation DAG is:

```text
common verified-CF + fresh-read/mask/CRC/write/fsync/post-read API
  -> parallel W1, W2+W4, W5, W6
  -> combine those exact lanes
  -> W3 last
  -> focused/full verification
  -> one whole-A1 CC code review; P0/P1 only scoped rereview
  -> post-repair C2
```

`cluster_wal_state.[ch]` has one common owner. `src/test/cluster_unit/Makefile` has one integration owner.
W2 and W4 share one lane; W5a and W5b share one lane; W3 is last because its checkpointer/postmaster
lifecycle depends on W2/W4 and W5. Every production change follows immutable RED → observed expected
failure → minimal GREEN. Existing unmodified tests that are already green are not RED evidence.

## R10. rollout, rollback and conditional successors

- Rollout is cluster-wide offline: validate and back up v1 registry, then start every node on one A1 build.
  Mixed f076/A1 is forbidden because f076 writers lack common CF and still treat W6 as authority.
- Before the first A1 W2, full-cluster shutdown may revert binaries. Once any A1 activation/W2 occurs,
  including W6 clear, roll forward or roll back only to another A1-compliant build. Automatic f076 rollback
  is forbidden; a disaster-only f076 return requires a new full-cluster-offline user/CC boundary and a
  validated backup.
- Disk v1 is not migrated. Partial/corrupt evidence is never empty-created under rollback or repair language.
- Carrier remains inactive until A1 is implemented, reviewed and post-repair C2 evidence passes. Its exact
  sidecar path/ABI/copies/rename contract is a separate frozen gate.
- Migration remains inactive until the carrier's own evidence gate passes. Its capability/body-digest/round/
  cutover/no-return contract is separate and there is no automatic old-format migration.
- STOP04 provider remains `UNAVAILABLE`; post-carrier W6 compatibility mirror has no code or activation here.

## §17 2026-08-08 exact no-generation carrier and publication amendment

### §17.1 Precedence, selected shape, and authority

This section supersedes old §§0.2, 4.2–4.6, 5.2–5.5, 6.2–6.4, 8.1, 9.5, 10.3–10.5,
11, 14, 16 and Appendix A.1 wherever they conflict.  Non-conflicting identity, range, CRC, lifecycle,
Oracle-evidence and census rules remain in force.

The one user decision is:

```text
SIG-01-BUNDLE-V1 = A

A = dedicated 66048-byte control-root sidecar
  + exact no-generation v1 ABI below
  + W1-W5 field-RMW repair and pre-critical FPW sticky publication
  + same-round permanent W6 retirement
  + existing R4 phase-ACK carrier with exact round/image digest
  + bit22 root-authority cutover and stated rollback/no-return boundary.
```

The user-approved RF package selects A.  Until the final eight-body hash set receives CC same-hash agreement,
`PRODUCT AUTHORIZATION=0`.  No public code, file, wire byte or activation record may be changed.  This
bundle adds no per-origin generation, WAL record, message kind, daemon, lease, ticket or persistent FSM.

Oracle publicly verifies shared per-instance redo threads, control-file redo-thread/checkpoint/incarnation
sections, CF-enqueue serialization of shared control-file writes and a control-file transaction sequence.
Oracle does not publish modern RAC control-file bytes, CRC/copy selection, crash-write protocol or PGRAC
rename/R4 receipt details.  The carrier, LE layout, CRC/SHA, `.bak`, CF API and R4 migration below are
therefore `PGRAC ADAPTATION`, not descriptions of Oracle internals.

### §17.2 Duty identity and explicit no-generation replacement

The sole durable duty identity is the 80-byte `ClusterControlRootIdentity` below; its semantic encoding is
74 padding-free LE bytes. This exact type/alias is shared by STOP02–05/08/09:

```c
typedef struct ClusterControlRootIdentity {
    uint64 system_identifier;          /* 0 */
    uint8  storage_uuid[16];           /* 8 */
    uint8  authority_uuid[16];         /* 24 */
    uint16 origin_thread_id;           /* 40 */
    uint16 reserved42;                 /* 42: zero */
    int32  origin_node_id;             /* 44 */
    int64  thread_claim_created_at;    /* 48 */
    uint32 thread_claim_crc32c;         /* 56 */
    uint32 reserved60;                 /* 60: zero */
    uint64 origin_owner_incarnation;   /* 64 */
    uint64 root_lineage_seq;           /* 72 */
} ClusterControlRootIdentity;          /* 80 */

typedef ClusterControlRootIdentity ClusterRecoveryDutyKey;
```

Static assertions freeze `sizeof=80` and every shown offset. Semantic encoding concatenates
`system_identifier,storage_uuid,authority_uuid,origin_thread_id,origin_node_id,thread_claim_created_at,
thread_claim_crc32c,origin_owner_incarnation,root_lineage_seq` in that order, with integers LE and no C
padding/reserved words, yielding exactly 74 bytes. Runtime padding is never hashed or written.

`root_lineage_seq` changes only for a newly admitted owner lineage.  Failure detection, coordinator,
recoverer, process/node succession and unrelated formation changes do not change it.  Timeline is recovery
window evidence and is not an identity field.

The old scalar-generation ABI is removed before first activation:

```c
#define CLUSTER_CONTROL_ROOT_FORMAT_ROOT_V1               UINT64_C(0x01)
/* format bit 0x02 is forbidden/reserved-zero in v1 */
#define CLUSTER_CONTROL_ROOT_FORMAT_R14_BOUND_V1           UINT64_C(0x04)
#define CLUSTER_CONTROL_ROOT_FORMAT_MIGRATION_BINDING_V1   UINT64_C(0x08)
#define CLUSTER_CONTROL_ROOT_FORMAT_FLAGS_V1               UINT64_C(0x0d)

/* root flag 0x00000002 is forbidden in v1 */
#define CLUSTER_CONTROL_ROOT_FLAGS_V1                      UINT32_C(0x000001fd)

/* patch bit 0x04 is forbidden in v1 */
#define CLUSTER_CONTROL_ROOT_PATCH_ALL_V1                  UINT64_C(0xfb)
```

The v1 reader accepts exact header flags `0x0d` only.  A header with old `0x07/0x0f`, root flag `0x2`,
patch bit `0x04` or any unknown bit is `BAD_VERSION/BAD_RESERVED`, never a compatibility input.  Because no
root image has product authority yet, there is no dual reader.  Discovery of a deployed old image stops
activation and requires a separately approved versioned migration.

These disk/runtime slots retain their widths and become required-zero reserved bytes; they must never be
renamed or rebound to marker/CSSD/local counters:

| carrier | exact required-zero slot |
|---|---|
| `ClusterControlRootDiskV1` | offsets `88..95`, `200..207`, `216..223` |
| `ClusterControlRootSnapshot` | offsets `96`, `160`, `208` |
| `ClusterControlRootReadToken` | offset `32` |
| `ClusterControlRootPatch` | offset `24` |

All remain covered by their enclosing CRC/equality checks.  Their implementation names are
`reserved88/reserved200/reserved216`, `reserved96/reserved160/reserved208`, `reserved32` and `reserved24`.
Every writer emits zero; every reader/publisher rejects nonzero.

The complete runtime projections are:

```c
typedef struct ClusterControlRootSnapshot {
    ClusterControlRootIdentity identity; /* 0..79 */
    uint32 lifecycle;                    /* 80 */
    uint32 root_flags;                   /* 84 */
    uint64 root_publish_seq;             /* 88 */
    uint64 reserved96;                   /* 96: zero */
    uint32 checkpoint_tli;               /* 104 */
    uint32 tail_tli;                     /* 108 */
    uint32 recovered_tli;                /* 112 */
    uint16 checkpoint_source_kind;       /* 116 */
    uint16 tail_validation_kind;         /* 118 */
    uint16 conservative_bound_kind;      /* 120 */
    uint16 reserved122;                  /* 122: zero */
    uint32 reserved124;                  /* 124: zero */
    uint64 checkpoint_lower_lsn;         /* 128 */
    uint64 validated_tail_lsn_exclusive; /* 136 */
    uint64 recovered_through_lsn_exclusive; /* 144 */
    uint64 conservative_commit_scn;      /* 152 */
    uint64 reserved160;                  /* 160: zero */
    uint64 tail_last_record_lsn;         /* 168 */
    uint64 recovered_last_record_lsn;    /* 176 */
    int64  published_at_usec;            /* 184 */
    uint32 tail_last_record_crc32c;       /* 192 */
    uint32 checkpoint_record_crc32c;      /* 196 */
    uint32 recovered_last_record_crc32c;  /* 200 */
    uint32 lifecycle_reason;             /* 204 */
    uint64 reserved208;                  /* 208: zero */
} ClusterControlRootSnapshot;            /* 216 */

typedef struct ClusterControlRootReadToken {
    uint8  authority_uuid[16];       /* 0 */
    uint16 origin_thread_id;         /* 16 */
    uint8  source;                   /* 18 */
    uint8  lifecycle;                /* 19 */
    uint32 reserved20;               /* 20: zero */
    uint64 root_lineage_seq;         /* 24 */
    uint64 reserved32;               /* 32: zero */
    uint64 file_txn_seq;             /* 40 */
    uint64 root_publish_seq;         /* 48 */
    uint32 record_crc32c;             /* 56 */
    uint32 root_flags;               /* 60 */
} ClusterControlRootReadToken;       /* 64 */

typedef struct ClusterControlRootPatch {
    uint64 mask;                     /* 0 */
    uint32 expected_lifecycle;       /* 8 */
    uint32 expected_flags_mask;      /* 12 */
    uint32 expected_flags_value;     /* 16 */
    uint32 reserved20;               /* 20: zero */
    uint64 reserved24;               /* 24: zero */
    ClusterControlRootSnapshot desired; /* 32 */
} ClusterControlRootPatch;           /* 248 */
```

Static assertions freeze every shown size/offset. Sources are PRIMARY=1, BAK_BLOCKED=2 and
BOOTSTRAP_PRIMARY=3; only PRIMARY from a STRONG read can authorize publication. Callers never persist a
snapshot/token/patch, and only fields named by `mask` are semantically read; every unmasked desired byte and
all reserved fields must still be zero.

```c
#define CLUSTER_CONTROL_ROOT_PATCH_LIFECYCLE          UINT64_C(0x01)
#define CLUSTER_CONTROL_ROOT_PATCH_OWNER_LINEAGE      UINT64_C(0x02)
/* bit 0x04 is forbidden/reserved */
#define CLUSTER_CONTROL_ROOT_PATCH_CHECKPOINT         UINT64_C(0x08)
#define CLUSTER_CONTROL_ROOT_PATCH_TAIL               UINT64_C(0x10)
#define CLUSTER_CONTROL_ROOT_PATCH_RECOVERY_PROGRESS  UINT64_C(0x20)
#define CLUSTER_CONTROL_ROOT_PATCH_FPW_STICKY         UINT64_C(0x40)
#define CLUSTER_CONTROL_ROOT_PATCH_CONSERVATIVE_BOUND UINT64_C(0x80)
#define CLUSTER_CONTROL_ROOT_PATCH_ALL_V1             UINT64_C(0xfb)
```

`FAILURE_DUTY_OPEN` uses exact patch mask `0xb1`:

```text
LIFECYCLE | TAIL | RECOVERY_PROGRESS | CONSERVATIVE_BOUND
```

Its atomic effects are `OPEN→RECOVERY_REQUIRED`, clear TAIL/Tail-last-record, zero tail TLI/LSN/witnesses,
reset recovered-through to checkpoint lower, and clear conservative flag/kind/value.  Identity, owner and
lineage remain unchanged.  Reopening the same already-REQUIRED full identity is an adopt/no-write result.
`FAILURE_TAIL_VALIDATED` remains a TAIL-only publish and readiness is
`RECOVERY_REQUIRED + TAIL_VALID + exact witnesses`; no scalar equality exists.  Conservative bound validity
is the same full identity plus expected whole-record token CAS/readback; failure-open and owner-rejoin clear
it atomically.

Feature bit 22 is renamed without changing its numeric position:

```c
#define PGRAC_CONTROL_ROOT_FEATURE_RECOVERY_DUTY_IDENTITY_V1 \
        (UINT64_C(1) << 22)
```

The old `...FAILURE_GENERATION_V1` name has zero live declarations.  Bit 22 selects the root carrier and
full-lineage duty semantics; bit 23 remains IR serialization and bit 24 external fencing.

### §17.3 Exact carrier and storage contract

```c
#define CLUSTER_CONTROL_ROOT_REL_PATH       "global/pgrac_control_root"
#define CLUSTER_CONTROL_ROOT_BAK_REL_PATH   "global/pgrac_control_root.bak"
#define CLUSTER_CONTROL_ROOT_FILE_BYTES     UINT32_C(66048)
#define CLUSTER_CONTROL_ROOT_HEADER_BYTES   UINT16_C(512)
#define CLUSTER_CONTROL_ROOT_RECORD_BYTES   UINT16_C(512)
#define CLUSTER_CONTROL_ROOT_RECORD_COUNT   UINT16_C(128)
```

All integers use explicit little-endian codecs; raw struct casts/native padding are forbidden. Every reserved
byte is written zero and nonzero is `BAD_RESERVED`. Magic/version/enum/flags are exact, CRC is PostgreSQL
CRC32C, an empty record is exactly 512 zero bytes, and a zero prefix with any nonzero remainder is corrupt.

The 512-byte header is:

| offset | width | exact field/rule |
|---:|---:|---|
| 0 | 4 | ASCII `PGCH` |
| 4 | 2 | format version 1 |
| 6 | 2 | header bytes 512 |
| 8 | 2 | record bytes 512 |
| 10 | 2 | record count 128 |
| 12 | 4 | endian tag `0x01020304` after LE decode |
| 16 | 8 | nonzero `file_txn_seq`, checked increment, no wrap |
| 24 | 8 | nonzero PostgreSQL system identifier |
| 32 | 16 | canonical storage UUID raw bytes |
| 48 | 16 | immutable authority UUIDv4 raw bytes |
| 64 | 8 | exact format flags `0x0d` |
| 72 | 2 | minimum reader version 1 |
| 74 | 2 | minimum writer version 1 |
| 76 | 4 | PREPARED=1 or ACTIVE=2 |
| 80 | 8 | created-at microseconds, observability only |
| 88 | 8 | published-at microseconds, observability only |
| 96 | 4 | body CRC32C over bytes `[512,66048)` |
| 100 | 32 | immutable migration-round SHA-256 |
| 132 | 32 | exact source wal-state SHA-256 |
| 164 | 8 | nonzero migration PREPARE generation P |
| 172 | 8 | migration transition epoch |
| 180 | 8 | source feature bitmap |
| 188 | 8 | target feature bitmap including bit22 |
| 196 | 308 | zero reserved |
| 504 | 4 | header CRC32C over `[0,504)` |
| 508 | 4 | zero pad |

Lifecycle values are UNUSED=0, OPEN=1, RECOVERY_REQUIRED=2, RECOVERY_COMPLETE=3, CLOSED=4 and RETIRED=5.
Bound kind is NONE=0 or R14_M1_PARTITION_S_V1=1. Record flags are CLAIM_VALID=0x1,
CHECKPOINT_VALID=0x4, TAIL_VALID=0x8, RECOVERED_VALID=0x10, FPW_WAS_OFF=0x20,
CONSERVATIVE_SCN_VALID=0x40, TAIL_LAST_RECORD_VALID=0x80 and RECOVERED_LAST_RECORD_VALID=0x100; the exact
known mask is `0x1fd`, with `0x2` forbidden. `FPW_WAS_OFF` is lineage-sticky 0→1 and never cleared by an
ordinary lifecycle transition.

Each nonempty 512-byte `ClusterControlRootDiskV1` record is:

| offset | width | exact field/rule |
|---:|---:|---|
| 0 | 4 | ASCII `PGRT` |
| 4 | 2 | record version 1 |
| 6 | 2 | record bytes 512 |
| 8 | 2 | origin thread 1..128, equal to record index+1 |
| 10 | 1 | lifecycle 1..5 |
| 11 | 1 | zero pad |
| 12 | 4 | origin node 0..127, immutable in lineage |
| 16 | 8 | nonzero checked `root_publish_seq` |
| 24 | 8 | nonzero checked `root_lineage_seq` |
| 32 | 8 | system identifier equal header |
| 40 | 16 | storage UUID equal header |
| 56 | 16 | authority UUID equal header |
| 72 | 8 | exact claim-created-at |
| 80 | 8 | nonzero admitted owner incarnation |
| 88 | 8 | `reserved88`, zero |
| 96 | 4 | checkpoint TLI |
| 100 | 4 | tail TLI |
| 104 | 4 | recovered TLI |
| 108 | 4 | root flags subset of `0x1fd` |
| 112 | 8 | inclusive checkpoint lower LSN |
| 120 | 8 | validated tail LSN exclusive |
| 128 | 8 | recovered-through LSN exclusive |
| 136 | 8 | conservative commit SCN |
| 144 | 8 | nonzero last publisher incarnation, audit only |
| 152 | 4 | publisher node 0..127, audit only |
| 156 | 4 | exact publish reason |
| 160 | 8 | published-at microseconds, observability only |
| 168 | 4 | exact claim CRC32C |
| 172 | 4 | checkpoint record `xl_crc` |
| 176 | 8 | tail last-record start LSN |
| 184 | 4 | tail last-record `xl_crc` |
| 188 | 4 | recovered last-record `xl_crc` |
| 192 | 2 | tail kind 1=`WAL_RECORD_SCAN_V1` |
| 194 | 2 | checkpoint source 1=`NATIVE_CHECKPOINT_V1`, 2=`RECOVERY_ANCHOR_V1` |
| 196 | 2 | conservative bound kind 0 or 1 |
| 198 | 2 | zero reserved |
| 200 | 8 | `reserved200`, zero |
| 208 | 8 | recovered last-record start LSN |
| 216 | 8 | `reserved216`, zero |
| 224 | 280 | zero reserved |
| 504 | 4 | record CRC32C over `[0,504)` |
| 508 | 4 | zero pad |

For every nonempty record, `checkpoint_lower <= recovered_through <= validated_tail`. Equal endpoints require
the corresponding last-record flag/LSN/CRC to be zero; a greater endpoint requires the named native-valid
WAL record to end exactly there and follow timeline ancestry. `RECOVERY_REQUIRED + TAIL_VALID + exact
witnesses` is tail-ready; no scalar equality participates. A conservative bound requires kind 1, valid SCN
and a full-key/token CAS; otherwise kind/value are zero. Failure-open and owner-rejoin clear the bound.

Both canonical names are beneath `<cluster.shared_data_dir>/global`, in the same verified storage/rename
domain as the shared `pg_control` authority.  Before every create/STRONG read/publish:

1. current nonzero storage UUID equals header, claims and per-node CF identity anchor;
2. multi-node requires `CLUSTER_CF_CONTRACT_CROSSNODE_VERIFIED`; single-node requires the existing local
   rename probe;
3. canonical paths and call-created temp final components are regular, non-symlink objects;
4. temp is same-directory, mode `0600`, `O_CREAT|O_EXCL`, named
   `pgrac_control_root[.bak].tmp.<node>.<pid>.<16-lowercase-hex>` using eight `pg_strong_random` bytes;
5. write-all 66048, fsync file, close, `durable_rename`, fsync parent, then fresh open/read/validate;
6. cleanup may unlink only the exact temp successfully O_EXCL-created by this call; it never unlinks a
   canonical primary or `.bak`.

Publication is exactly `CF-serialized + crash-classifiable canonical replacement`, not a sector/whole-file
atomicity claim.  For an update, `.bak` is first replaced with the fresh-validated old primary; the new image
then replaces primary.  The linearization point is primary `durable_rename`; success additionally requires
parent fsync, fresh primary readback and confirmed CF release.  Initial PREPARED creation publishes identical
`.bak` then primary while R4 keeps both source and target admission closed.  `.bak` never self-promotes after
restart and never authorizes action.

Header bytes `0..99` and `504..511` retain their old meanings except exact `format_flags=0x0d`.  Old
`reserved[404]` is replaced by:

| offset | width | exact field/rule |
|---:|---:|---|
| 100 | 32 | `migration_round_sha256`, immutable |
| 132 | 32 | `source_wal_state_sha256`, immutable exact source bytes after drain |
| 164 | 8 | `migration_prepare_record_generation=P`, nonzero |
| 172 | 8 | `migration_transition_epoch` |
| 180 | 8 | source feature bitmap |
| 188 | 8 | target feature bitmap, includes bit22 |
| 196 | 308 | zero reserved |
| 504 | 4 | header CRC32C over `[0,504)` |
| 508 | 4 | zero pad |

`source_wal_state_sha256` is exactly `SHA-256` over the 66048 bytes, with no domain prefix or pathname,
read from the existing canonical `<cluster.wal_threads_dir>/pgrac_wal_state` after the same-round W1–W6
close/drain and while holding coordinated CF(X).  The reader requires exact file size, validates the 512-byte
`ClusterWalStateHeader`, and classifies each of the 128 slots with the f076 validator: every slot is either
all-zero/unassigned or CRC-valid, self-describing and exactly matched to its immutable thread claim; every
assigned slot is STOPPED, has nonzero checkpoint, and has `merge_recovered_lsn==0`.  Short read, trailing byte,
ACTIVE/foreign/corrupt slot, claim drift or a byte change across a second full read aborts the round.  The
coordinator hashes the first validated image and requires the second read to be byte-identical before creating
PREPARED.  Every PREPARED/ACTIVE ACK independently reopens, fully validates and hashes the same canonical file
and compares all 32 bytes.  A rollback test likewise compares a fresh validated 66048-byte image; metadata,
mtime, per-slot digests or a hash of decoded fields cannot substitute.

### §17.4 Runtime tokens and result surface

```c
typedef enum ClusterControlRootReadMode {
    CLUSTER_CONTROL_ROOT_READ_STRONG = 1,
    CLUSTER_CONTROL_ROOT_READ_BOOTSTRAP_VALIDATE = 2
} ClusterControlRootReadMode;

typedef enum ClusterControlRootPublishReason {
    CLUSTER_CONTROL_ROOT_PUBLISH_MIGRATION_IMPORT = 1,
    CLUSTER_CONTROL_ROOT_PUBLISH_THREAD_OPEN = 2,
    CLUSTER_CONTROL_ROOT_PUBLISH_THREAD_CLEAN_CLOSE = 3,
    CLUSTER_CONTROL_ROOT_PUBLISH_FAILURE_DUTY_OPEN = 4,
    CLUSTER_CONTROL_ROOT_PUBLISH_FAILURE_TAIL_VALIDATED = 5,
    CLUSTER_CONTROL_ROOT_PUBLISH_RECOVERY_PROGRESS = 6,
    CLUSTER_CONTROL_ROOT_PUBLISH_RECOVERY_COMPLETE = 7,
    CLUSTER_CONTROL_ROOT_PUBLISH_OWNER_REJOIN = 8,
    CLUSTER_CONTROL_ROOT_PUBLISH_THREAD_RETIRE = 9,
    CLUSTER_CONTROL_ROOT_PUBLISH_CONSERVATIVE_BOUND = 10,
    CLUSTER_CONTROL_ROOT_PUBLISH_CHECKPOINT_ADVANCE = 11,
    CLUSTER_CONTROL_ROOT_PUBLISH_FPW_STICKY = 12,
    CLUSTER_CONTROL_ROOT_PUBLISH_COPY_REPAIR = 13
} ClusterControlRootPublishReason;

typedef enum ClusterControlRootResult {
    CLUSTER_CONTROL_ROOT_OK_PRIMARY = 0,
    CLUSTER_CONTROL_ROOT_OK_PRIMARY_DEGRADED = 1,
    CLUSTER_CONTROL_ROOT_OK_BAK_BLOCKED = 2,
    CLUSTER_CONTROL_ROOT_ABSENT = 3,
    CLUSTER_CONTROL_ROOT_BAD_SIZE = 4,
    CLUSTER_CONTROL_ROOT_BAD_MAGIC = 5,
    CLUSTER_CONTROL_ROOT_BAD_VERSION = 6,
    CLUSTER_CONTROL_ROOT_BAD_ENDIAN = 7,
    CLUSTER_CONTROL_ROOT_BAD_HEADER_CRC = 8,
    CLUSTER_CONTROL_ROOT_BAD_BODY_CRC = 9,
    CLUSTER_CONTROL_ROOT_BAD_RECORD_CRC = 10,
    CLUSTER_CONTROL_ROOT_BAD_RESERVED = 11,
    CLUSTER_CONTROL_ROOT_IDENTITY_MISMATCH = 12,
    CLUSTER_CONTROL_ROOT_LIFECYCLE_INVALID = 13,
    CLUSTER_CONTROL_ROOT_RANGE_INVALID = 14,
    CLUSTER_CONTROL_ROOT_COPY_DIVERGENT = 15,
    CLUSTER_CONTROL_ROOT_MIXED_VERSION = 16,
    CLUSTER_CONTROL_ROOT_LOCK_UNAVAILABLE = 17,
    CLUSTER_CONTROL_ROOT_IO_ERROR = 18,
    CLUSTER_CONTROL_ROOT_POSTREAD_FAILED = 19,
    CLUSTER_CONTROL_ROOT_STALE_TOKEN = 20,
    CLUSTER_CONTROL_ROOT_CAS_CONFLICT = 21,
    CLUSTER_CONTROL_ROOT_SEQUENCE_EXHAUSTED = 22,
    CLUSTER_CONTROL_ROOT_INVALID_ARGUMENT = 23,
    CLUSTER_CONTROL_ROOT_STORAGE_CONTRACT_UNVERIFIED = 24,
    CLUSTER_CONTROL_ROOT_HASH_MISMATCH = 25,
    CLUSTER_CONTROL_ROOT_MIGRATION_ROUND_MISMATCH = 26,
    CLUSTER_CONTROL_ROOT_RELEASE_UNCERTAIN = 27
} ClusterControlRootResult;
```

Exact reason masks are THREAD_OPEN=`0x3b`, THREAD_CLEAN_CLOSE=`0x39`, FAILURE_DUTY_OPEN=`0xb1`,
FAILURE_TAIL_VALIDATED=`0x10`, RECOVERY_PROGRESS=`0x20`, RECOVERY_COMPLETE=`0x21`, OWNER_REJOIN=`0x3b`,
THREAD_RETIRE=`0x01`, CONSERVATIVE_BOUND=`0x80`, CHECKPOINT_ADVANCE=`0x38` and FPW_STICKY=`0x40`.
MIGRATION_IMPORT is internal to create; COPY_REPAIR cannot alter primary bytes/sequences. Extra/missing masks,
wrong lifecycle, forbidden bit `0x04`, unknown reason or nonzero reserved input returns INVALID_ARGUMENT before
CF/file I/O.

```c
extern ClusterControlRootResult cluster_control_root_read_canonical(
    uint16 origin_thread_id,
    const ClusterControlRootIdentity *expected_identity,
    ClusterControlRootReadMode mode,
    ClusterControlRootSnapshot *out_snapshot,
    ClusterControlRootReadToken *out_token);
extern ClusterControlRootResult cluster_control_root_lookup_owner_by_node_runtime(
    int32 old_node_id,
    ClusterControlRootIdentity *out_identity,
    ClusterControlRootSnapshot *out_snapshot,
    ClusterControlRootReadToken *out_token);
extern ClusterControlRootResult cluster_control_root_compare_and_publish(
    const ClusterControlRootReadToken *expected_token,
    const ClusterControlRootPatch *patch,
    ClusterControlRootPublishReason reason,
    ClusterControlRootSnapshot *out_snapshot,
    ClusterControlRootReadToken *out_token);
extern ClusterControlRootResult cluster_control_root_revalidate(
    const ClusterControlRootReadToken *token,
    const ClusterControlRootIdentity *expected_identity,
    ClusterControlRootSnapshot *out_snapshot);
extern bool cluster_control_root_identity_equal(
    const ClusterControlRootIdentity *left,
    const ClusterControlRootIdentity *right);
extern bool cluster_control_root_feature_bitmap_is_known(uint64 active_feature_bitmap);
```

STRONG requires nonnull expected identity and coordinated CF(S). BOOTSTRAP_VALIDATE permits null identity only
for migration/status and returns no authority token. Runtime lookup is the sole REJOIN-B discovery exception:
`old_node=N` maps only to thread `N+1`, validates claim/record/full identity, never scans/guesses/caches, and
only results 0/1 initialize outputs. All APIs zero outputs first on nonauthoritative/error returns.
Compare-and-publish requires a PRIMARY strong token, owns CF(X), fresh-rereads, exact-token CASes, writes one
validated patch, durable-readbacks and confirms release. Slow revalidate runs outside IR/PAGE/SIDE/WALR.

```c
typedef struct ClusterControlRootMigrationImage {
    uint64 system_identifier;                /* 0 */
    uint8  storage_uuid[16];                 /* 8 */
    uint8  authority_uuid[16];               /* 24 */
    int64  created_at_usec;                  /* 40 */
    uint32 assigned_record_count;            /* 48 */
    uint32 reserved52;                       /* 52: zero */
    ClusterControlRootSnapshot records[128]; /* 56 */
} ClusterControlRootMigrationImage;          /* 27704 */

typedef struct ClusterControlRootMigrationRoundV1 {
    uint8  magic[4];                 /* 0: PCRM */
    uint16 version;                  /* 4: 1 */
    uint16 bytes;                    /* 6: 80 */
    uint64 prepare_generation;       /* 8 */
    uint64 transition_epoch;         /* 16 */
    uint64 source_feature_bitmap;    /* 24 */
    uint64 target_feature_bitmap;    /* 32 */
    uint64 admitted_bitmap_low;      /* 40 */
    uint64 admitted_bitmap_high;     /* 48 */
    uint64 capability_sample_digest; /* 56 */
    uint64 coordinator_incarnation;  /* 64 */
    uint32 coordinator_node_id;      /* 72 */
    uint32 reserved76;               /* 76: zero */
} ClusterControlRootMigrationRoundV1; /* 80 */
```

The migration token is replaced, not extended in parallel:

```c
typedef struct ClusterControlRootFileToken {
    uint8  authority_uuid[16];
    uint64 file_txn_seq;
    uint32 body_crc32c;
    uint32 header_crc32c;
    uint32 activation_state;
    uint16 format_version;
    uint16 record_count;
    uint64 system_identifier;
    uint8  image_sha256[32];       /* SHA-256 exact 66048 bytes */
} ClusterControlRootFileToken;     /* 80 bytes */

StaticAssertDecl(sizeof(ClusterControlRootFileToken) == 80,
                 "ClusterControlRootFileToken ABI");
StaticAssertDecl(offsetof(ClusterControlRootFileToken, file_txn_seq) == 16,
                 "ClusterControlRootFileToken sequence offset");
StaticAssertDecl(offsetof(ClusterControlRootFileToken, image_sha256) == 48,
                 "ClusterControlRootFileToken image hash offset");
```

The digest is equality/integrity evidence, not authentication. The complete result enum is frozen above.

Migration APIs are exact:

```c
extern ClusterControlRootResult cluster_control_root_create_prepared(
    const ClusterControlRootMigrationImage *image,
    const ClusterControlRootMigrationRoundV1 *round,
    ClusterControlRootFileToken *out_token);
extern ClusterControlRootResult cluster_control_root_activate_prepared(
    const ClusterControlRootFileToken *expected_token,
    const uint8 expected_round_sha256[32],
    ClusterControlRootFileToken *out_token);
extern ClusterControlRootResult cluster_control_root_discard_inactive(
    const ClusterControlRootFileToken *expected_token,
    const uint8 expected_round_sha256[32]);
```

`discard_inactive` is callable only by the existing R4 abort/revert callback while both admissions are
closed, majority R4 selects source, bit22 is not OPEN and token/round match.  It is permanently denied after
bit22 OPEN.

### §17.5 CF acquire/release result

```c
typedef enum ClusterCfReleaseResult {
    CLUSTER_CF_RELEASE_NOT_HELD = 0,
    CLUSTER_CF_RELEASE_CONFIRMED = 1,
    CLUSTER_CF_RELEASE_UNCONFIRMED = 2
} ClusterCfReleaseResult;

extern bool cluster_cf_held_is_clusterwide(LOCKMODE mode);
extern ClusterCfReleaseResult cluster_cf_unlock_confirmed(LOCKMODE mode);
```

Multi-node root/wal-state authority requires actual coordinated CF S/X.  `OK_NATIVE` releases any local
hold and returns lock-unavailable.  CONFIRMED consumes the actual local-master/S6 release result and alone
clears hold state.  Timeout, queue-full, dropped reply, remaster or unknown is UNCONFIRMED: set
`release_uncertain=true`, return no authority output/success, keep admission closed and terminate the owning
process through existing `58R13`.  A later actual coordinated grant, not local bookkeeping, proves the old
holder is gone.

### §17.6 Existing R4 carrier, exact round and digest

No new ACK kind, HELLO bit, receipt file or second durable round carrier is created.  Reuse existing R4
phase ACK and `ClusterSemanticZeroProof`.

`ClusterControlRootMigrationRoundV1` hashes this exact 80-byte LE preimage:

```text
0  "PCRM"; 4 u16 version=1; 6 u16 bytes=80;
8  u64 PREPARE generation P; 16 u64 transition epoch;
24 u64 source bitmap; 32 u64 target bitmap;
40 u64 admitted low; 48 u64 admitted high;
56 u64 capability sample digest; 64 u64 coordinator incarnation;
72 u32 coordinator node; 76 u32 zero.
```

`migration_round_sha256=SHA256(exact 80 bytes)`.  Each PREPARED/ACTIVE ACK first validates exact file size,
format `0x0d`, zero reserved bytes, CRC hierarchy, identities, round/source SHA and full image SHA.  It then
uses the existing 24-byte `ClusterSemanticZeroProof` with `debt_count=0`, current R4 generation and
`sample_digest=read_le64(SHA256(RACK-preimage)[0..7])`, mapping zero to one.  The RACK preimage is exact 96
bytes:

| offset | width | exact RACK field |
|---:|---:|---|
| 0 | 4 | ASCII `RACK` |
| 4 | 2 | u16le version `1` |
| 6 | 2 | u16le length `96` |
| 8 | 8 | u64le phase: `1=PREPARED`, `2=ACTIVE` |
| 16 | 8 | u64le current R4 generation |
| 24 | 8 | u64le migration PREPARE generation `P` |
| 32 | 8 | u64le transition epoch |
| 40 | 8 | u64le admitted-membership bitmap low |
| 48 | 8 | u64le admitted-membership bitmap high |
| 56 | 8 | u64le capability sample digest |
| 64 | 32 | exact root image SHA-256 |

The encoder is manual and has no implicit C padding.  Existing full-member ACK rows remain bound to
node/boot/incarnation/CONTROL connection/capability generation/epoch; any drift clears the whole round.

Normative cutover order:

```text
majority R4 PREPARE(P)
 -> all-member W1-W6 close/drain
 -> under CF(X) capture exact source SHA
 -> create PREPARED root bound to round/source
 -> all-member PREPARED digest ACK
 -> majority R4 COMMIT(P+1)
 -> token-CAS activate root
 -> all-member ACTIVE digest ACK
 -> majority R4 OPEN(P+2, bit22)
 -> each member fresh-reads same ACTIVE root before target admission.
```

Coordinator restart resumes only from majority R4 plus exact root/token/round relation: PREPARE may adopt a
byte-identical PREPARED image; COMMIT+PREPARED activates; COMMIT+ACTIVE recollects ACK; OPEN with absent,
non-ACTIVE or wrong-round root is HOLD/FATAL and never falls back to wal-state.

### §17.7 W1-W6 final replacement

W1–W5 use the existing 64-byte field patch as a `static` implementation detail of
`cluster_wal_state.c`; no whole-slot public replacement API exists.  Append update results
`RELEASE_UNCERTAIN=9` and `SOURCE_CLOSED=10`.

`RF-A1-LIFECYCLE-REV1-A` is the sole pre-cut lifecycle.  It rejects early/pre-recovery LMS,
postmaster CF acquisition, `initdb -c/--set + IsBootstrapProcessingMode`, SIGHUP-triggered phase-4
initialization and any formed-cluster empty rebuild.  The only new externally visible input is the
frontend-initialization-only initdb handoff `--pgrac-wal-state-root=ABSOLUTE_DIR`; it carries the existing
`pgrac-init --wal-threads-dir` value to the one initdb child and is neither runtime nor persistent authority.

W1 has two disjoint modes:

1. **Fresh offline create.** `pgrac-init --wal-threads-dir=ROOT --node-id=N` first proves ROOT is absolute,
   canonical and not a symlink escape.  If the registry is absent, ROOT and PGDATA are fresh and ROOT contains
   no entry except this child-created `thread_(N+1)`.  After `initialize_data_directory()` has succeeded and
   before initdb `fsync_pgdata`/success return, the frontend creates exact
   `ROOT/pgrac_wal_state` with `O_CREAT|O_EXCL`, owner-only mode, the existing v1 header and 128 all-zero slots,
   exact size 66048.  It writes all bytes, fsyncs the file and ROOT even under `--no-sync`, closes, reopens,
   stats and fully preads, and validates header plus every zero slot.  There is no temp, rename, unlink,
   truncate or repair.  An `EEXIST` loser may only read-validate an already complete valid file; a partial or
   corrupt winner is preserved and both callers fail.  Only after this finalizer succeeds may `pgrac-init`
   publish `cluster.node_id` and `cluster.wal_threads_dir`.  Existing registry/join is verify-only.
2. **Runtime verify.** Initial postmaster, crash shmem reinitialization and configured single-user mode only
   open/read/validate the existing exact registry.  Missing, wrong-size, short, corrupt or foreign evidence is
   `53RA2` FATAL before StartupXLOG/admission, with inode and bytes unchanged.  Plain/noncluster initdb and flat
   PostgreSQL are unchanged.  `cluster_wal_state_ensure` has zero create/unlink/truncate/remove-rebuild paths.

Upgrade into this lifecycle is cluster-wide offline: validate and back up an existing v1 registry while the
old build still runs, then start one A1 build everywhere.  A missing old-deployment registry is created only
by a separately controlled all-stopped provisioning run or restored known-valid backup; A1 runtime never
creates it.  Mixed f076/A1 is forbidden.  Before the first A1 W2, all-stopped binary rollback is allowed;
after any W2 (including W6 clear), only an A1-compliant build may run unless a new user/CC adjudication defines
an all-stopped rollback from verified backup.

The exact formed-cluster caller table is:

| ID | sole actor and point | exact mask/result |
|---|---|---|
| W2 | Initial ClusterStats child after `InitAuxiliaryProcess` supplies PGPROC, within phase-4 `SPAWNING→READY` | after its existing durable self-fence: a fenced node skips W2/checkpoint and follows the existing fenced policy; otherwise actual `CF_VERIFIED_X`, fresh EMPTY or valid own slot, field RMW of identity + ACTIVE state + TLI/times/highest LSN/SCN/refresh, and `merge_recovered_lsn=0`; corrupt/foreign/CF/I/O/post-read failure prevents READY and is startup FATAL |
| W5b-EOR | StartupXLOG end-of-recovery `UpdateFullPageWrites` | no registry write; off→on stays immediate; desired false keeps `Insert->fullPageWrites=true` and emits no false WAL.  If replay says historical `lastFullPageWrites=false`, own slot must read valid sticky=1 or startup is FATAL |
| W5b-steady | non-EOR `CreateCheckPoint`, after its outer coordinated CF acquire/fresh control read and before that function's first `START_CRIT_SECTION()` | borrow, never reacquire, outer `CF_VERIFIED_X`; when desired=false and Insert=true, validate own ACTIVE slot and set only sticky `fpw_was_off:0→1`, fsync/post-read, then enter critical section, emit false `XLOG_FPW_CHANGE`, and set Insert false.  Failure keeps true, emits no false WAL, warns and retries at the next non-EOR checkpoint; SIGHUP desired=false only leaves a mismatch |
| W5a | non-EOR online/forced/shutdown `CreateCheckPoint`, after durable `UpdateControlFile()` and its `END_CRIT_SECTION()`, before `SyncPostCheckpoint` and WAL recycle | borrow outer `CF_VERIFIED_X`; update only `checkpoint_redo_lsn=checkPoint.redo`, fsync/post-read.  Failure warns, preserves the old conservative value, lets checkpoint finish and retries next checkpoint.  EOR call count is zero |
| phase-4 ACK | ClusterStats after W2 releases CF | request `CHECKPOINT_IMMEDIATE|CHECKPOINT_FORCE|CHECKPOINT_WAIT`; completion proves only PG checkpoint completion, not W5 helper success; phase-4 shared admission deadline expiry tears startup down and never counts a late checkpoint as GREEN |
| W4 | ClusterStats only after initial W2; later READY loop/RUNNING respawn | initial child proceeds after W2; respawn only fresh-validates own ACTIVE slot.  Each tick uses `CF_VERIFIED_X` and modifies only TLI, last-updated, highest LSN/SCN and refresh interval.  Failure is typed skip + LOG-once/existing counter; no overwrite retry |
| W3 | checkpointer after `ShutdownXLOG()` returns and before its own `proc_exit(0)` on smart/fast clean shutdown | while coordination stack is still READY, reacquire `CF_VERIFIED_X`; ACTIVE→STOPPED modifies only state/last-updated/TLI/highest LSN/SCN, with fsync/post-read; own STOPPED is idempotent.  Failure warns and leaves ACTIVE.  Immediate/fatal/checkpointer failure has zero W3 calls |
| W6 | both old writers and all correctness readers | both writers are disabled; every historical/raw nonzero `merge_recovered_lsn` is diagnostic `raw_ignored` and semantically zero for every skip bound.  W2 clears it; W4/W5 preserve it |

The phase-4 order is fixed: Startup succeeds while ordinary admission/READY advertisement remains closed;
DIAG READY → CSSD READY → QVOTEC READY with strict multi-node quorum → LMS exact READY (DISABLED fails) →
existing node/voting/shared-CF validators → ClusterStats SPAWNING/W2 → forced checkpoint completion → Stats
READY → LMON startup/catch-up → COMMIT phase-4 → ordinary admission and READY advertisement.  ClusterStats
failure reaps it and tears down LMS→QVOTEC→CSSD→DIAG.  On clean shutdown Stats is stopped first; LMON/CSSD/
QVOTEC/LMS stay ready through `ShutdownXLOG`/W5a/W3, then are reaped in reverse.  Postmaster never waits on or
acquires remote CF.  Abnormal/immediate paths SIGQUIT the retained stack, do not run W3 and leave ACTIVE.

The implementation must prove: all coordinated CF callers own PGPROC; admission remains closed through the
phase-4 sequence; formed mutation has no native fallback; W2/W3/W4/W5 masks preserve their union under every
interleaving; sticky fsync/post-read happens-before false WAL; W5a advertises only durable checkpoint and
precedes recycle; STOPPED follows a clean shutdown checkpoint; W6 cannot shorten replay; and missing/corrupt
registry evidence is never deleted, recreated or overwritten.  Exact RED/GREEN covers both W1 modes, every
phase transition/failure, W2 EMPTY/own/corrupt/foreign cases, W4↔W5 and W2↔W5 schedules, EOR/steady W5b, W5a
position/retry, W3 clean/abnormal order, both W6 writers plus every reader, postmaster-CF call count zero and
steady-state call/fsync cadence.  These gates are prerequisite evidence, not the formal campaign.

W6 is permanently retired, not mirrored:

1. a transition-capable binary returns `SOURCE_CLOSED` from both cold
   `xlogrecovery.c:2919-2927` and online orchestrator `:390-408` wrappers without pwrite;
2. R4 PREPARE is denied until every old binary/worker/W6 holder exits, every failed duty is terminal,
   every replay slot drains and every source `merge_recovered_lsn` is zero;
3. the all-member CLOSED ACK binds those facts to the same migration round;
4. after bit22, both W6 production callers and every wal-state correctness reader/writer are statically
   unreachable; no compatibility mirror, handoff ledger, CF-under-IR exception or second enqueue exists;
5. STOP03 publishes immutable resource proof under IR, then after confirmed release the root finalizer alone
   publishes progress/completion.

Thus the old STOP03 requirement for W6 under matching IR and any proposed post-release mirror are both
superseded.  The availability cost is explicit: a transition binary cannot service a new failed-origin duty
between W6 closure and bit22 OPEN; that event aborts/blocks the migration and requires source recovery before
a fresh cutover round.

### §17.8 Restart, rollback and no-return

- Source R4 OPEN: repaired wal-state remains selected; root absent/PREPARED/ACTIVE is not authority.
- PREPARE/COMMIT: both admissions closed; restart follows majority R4 and exact root relation only.
- Target OPEN: root-only, no fallback, old/no-cap binary refuses startup/join.
- PREPARE abort may discard inactive root only after majority source selection.  COMMIT-before-OPEN may use
  the existing closed R4 revert protocol, then discard.
- Post-OPEN symmetric rollback is allowed only while every imported record is still CLOSED,
  `root_publish_seq==1`, no root-only checkpoint/FPW/progress/bound/lineage publication occurred, source SHA
  still matches, and all members ACK the same rollback round.
- First root record publish, owner reopen, source digest drift or failed duty makes no-return permanent.
  Afterwards invalid primary requires cluster-consistent restore plus WAL reconciliation; `.bak` is never
  auto-promoted or replaced by an empty image.

### §17.9 Mandatory exact gates

At minimum tests must cover: stale W4/W5b lost update; W5b failure before critical section; every
temp/fsync/rename crash cut; storage UUID/symlink/rename-contract refusal; local/native CF refusal and
unconfirmed release; LE/layout/reserved/CRC/SHA golden vectors; stale file token/round/image CAS; one-member
PREPARED or ACTIVE digest mismatch; membership/boot/connection drift; coordinator crash at all five R4
phases; `.bak` nonpromotion; rollback no-return; marker generation injection unable to alter duty/root;
format `0x0d` and zero generation slots; bit22 old/new binary refusal; both W6 callers zero; and a static
complete census proving post-bit22 wal-state correctness reader/writer count exactly zero.

The exact f076 census includes W1 `cluster_wal_state.c:166-265`, W2 startup, W3 postmaster, W4 stats, W5a
checkpoint, W5b `xlog.c:8706`, both W6 callers, and correctness readers
`xlogrecovery.c:2451-2467`, `cluster_hw_remaster.c:470-487`,
`cluster_recovery_merge.c:941-965,1115-1127`, `cluster_recovery_plan.c:178-223`,
`cluster_recovery_worker.c:181-195,233-254` and orchestrator `:541-573`.

### §17.10 Exact approval literal

```text
APPROVE SIG-01-BUNDLE-V1=A: use the dedicated control-root sidecar and exact
no-generation v1 ABI (format 0x0d; generation slots/bits reserved-zero); use
the existing R4 ACK carrier with the exact round/image digests; repair W1-W5,
retire W6 and every wal-state correctness edge in the same all-member cutover;
open bit22 only after PREPARED/ACTIVE full-member ACKs; accept the stated
storage, CF-release, migration, rollback/no-return and temporary availability
boundaries; add no generation carrier, wire kind, actor, ticket or persistent FSM.
```

## R18. RF-B single-node OWNER→EOR handoff amendment

**Status:** `AGREED / FROZEN`, CC + Codex rule-28.7 token
`RF-B-OWNER-EOR-HANDOFF-A-MIN` (2026-08-09).

This section supersedes only the prior claim that the already-proven single-node OWNER write permission may
remain entirely process-local to StartupXLOG.  It does not create or relax OWNER authority.  JOIN,
authority identity, W5 read-only EOR semantics, normal CF locking, W1-W6, no-ticket rules and every other RF
clause remain unchanged.  The exact boot-local transport atomic below is the sole consequence for R0's
no-new-shared-memory-state wording: R0 still forbids every other shared state, and the phase is never an
authority source.

### R18.1 Oracle evidence and confidence

- `ORACLE VERIFIED / HIGH (🟢)`: a surviving RAC instance performs failed-instance recovery; with no
  survivor, the next opener performs the required recovery.  After all RAC instances fail, the first open
  automatically recovers terminated redo threads.  Oracle control files contain checkpoint information and
  remain writable while the database is open.
- `INFERENCE / MEDIUM (🟡)`: the no-survivor next-opener reaches a durable recovery-completion point before
  open succeeds.  The public outcome does not reveal the exact writer process or handoff boundary.
- `PUBLICLY UNKNOWN (⚫)`: modern RAC's exact writer actor, startup order and handoff bytes.
- `PGRAC ADAPTATION / AGREED`: transport only the existing proven
  `cluster_conf_node_count()==1` OWNER decision from StartupXLOG to the existing EOR checkpointer that must
  perform the two existing control-file writes.  This is not presented as an Oracle internal mechanism.

Official sources:

1. [Oracle RAC 26ai — Administering Database Instances and Cluster Databases](https://docs.oracle.com/en/database/oracle/oracle-database/26/racad/administering-database-instances-and-cluster-databases.html)
2. [Oracle Database 12c — Instance Recovery](https://docs.oracle.com/database/121/CNCPT/startup.htm)
3. [Oracle Database 19c — Managing Control Files](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-control-files.html)

### R18.2 Exact minimal lifecycle and authority boundary

Add only one `pg_atomic_uint32 owner_eor_phase` to the existing per-postmaster CF stats shmem region.  The
only states and edges are:

```text
EMPTY -> INSTALLED -> ACTIVE -> DONE -> EMPTY
```

1. **INSTALL / StartupXLOG only:** after existing `node_count==1` OWNER storage/identity/role gates and
   before its first authority write, require `JOIN=false` and `EMPTY`, install `INSTALLED`, and retain the
   existing process-local Startup OWNER permission.  Duplicate/conflicting install fails closed.
2. **CONSUME / EOR checkpointer only:** require `AmCheckpointerProcess()` and
   `CHECKPOINT_END_OF_RECOVERY`; after existing EOR sanity and before checkpoint I/O, freshly recheck
   authority enabled, one-node role, existing sysid/storage-UUID contract and `JOIN=false`; only an atomic
   `INSTALLED->ACTIVE` enables a distinct process-local EOR OWNER permission.
3. **WRITE:** `cluster_cf_write_permitted()` accepts only held CF(X), process-local Startup OWNER, or
   process-local EOR OWNER.  Shared phase alone never grants write permission.  OWNER EOR bypasses CF(X),
   never sets write-skip, and performs both existing control-file writes under existing `ControlFileLock`.
   Normal, shutdown, restartpoint and phase-4 checkpoints never consume and retain real CF(X).
4. **COMPLETE:** only after the whole EOR checkpoint succeeds may checkpointer atomically
   `ACTIVE->DONE`, then clear its local permission.  Startup's synchronous WAIT must observe `DONE` before
   recovery-claim release.  Final existing bootstrap close performs `DONE->EMPTY`, then clears Startup-local
   permission.  A clean nondelegated path may perform `INSTALLED->EMPTY` at that same close point.
5. **ABORT:** checkpointer top-level error recovery clears its local EOR permission without throw or I/O;
   shared `ACTIVE` is retained and cannot be consumed, cleared or retried in that postmaster.  Normal teardown
   destroys boot-local shmem.  A fresh postmaster starts `EMPTY`; `found=true` attach never resets live phase.

Only StartupXLOG writes INSTALL/CLEAR and only the EOR checkpointer writes ACTIVE/DONE.  No phase transition
encloses CF, `ControlFileLock`, WAL, logging or I/O.  Existing normal lock order remains
`CF(X) -> ControlFileLock`; the agreed one-node bootstrap exception takes no CF lock.

### R18.3 Negative, scope, acceptance and rollback gates

- Actor, EOR flag, phase, JOIN, authority-enabled, one-node role and existing sysid/storage-UUID identity
  negatives must all refuse consume/local permission.  Phase alone grants no write.
- Units prove the exact success traversal, abort-local-clear with `ACTIVE` retained, `found=true` attach
  preservation and fresh-postmaster `EMPTY`.
- Existing t/244 `84ab40b...` remains the immutable semantic RED.  Its positive path starts sticky=1, keeps
  EOR W5 writes zero and proves the next steady SQL `CHECKPOINT` takes real CF(X).  Reuse fault injection only
  if it already exists at the exact boundary; add no injection framework/GUC/API.
- Supported OWNER scope is only `cluster_conf_node_count()==1`.  Declared-multi-node/all-down remains
  fail-closed because early fencing/sole-liveness is unproved.
- There is no ticket, generation, request/request-id, lease, counter, GUC, actor, shmem region, wait-for
  relation, durable identity record, disk/WAL/wire/catalog/`ControlFileData` field, version or migration
  addition.  Product scope is only existing CF stats/enqueue/storage, `xlog.c`, checkpointer cleanup and
  existing units/t/244.
- Rollback is full stop, binary revert and fresh-shmem restart only; hot mixed-binary rollback is forbidden.
- Product/fixture work remains held until CC completes one same-hash review of this finished private spec
  object.  These deterministic gates are prerequisites, not a campaign run.


<!-- NORMATIVE-BODY-END -->

| Fingerprint metadata | Exact value |
|---|---|
| body_sha256 | `e68aece83209c032e88c64354b9e89f8c8bb3b88d5105b71ab703658d8753141` |
| body_lines | `1077` |
| body_bytes | `69679` |

## Change record

- 2026-08-09 RF-B amendment: adds the agreed minimal boot-local single-node OWNER→EOR handoff, superseding
  only the process-local-only OWNER claim; all JOIN/W5/normal-CF/multi-node/RF boundaries remain unchanged.
- 2026-08-09 REV1 reseal: replaces the obsolete carrier-era normative body with the exact Gate-8-approved
  A1-only lifecycle/serialization contract. It preserves the existing v1 disk format, freezes W1–W6,
  excludes carrier/migration/STOP04/R8, and authorizes no public write before same-hash.
- 2026-08-09 seven-STOP successor: adds the approved no-generation 80-byte duty identity and exact
  carrier/migration ABI inside the marker; carrier/migration remain conditional and inactive.

## Final RF disposition（marker-external）

| Item | Final state |
|---|---|
| `SIG-01-A1-R` / `RF-A1-LIFECYCLE-REV1-A` | `APPROVED / A1-ONLY SAME-HASH AGREED AT a5358e...` |
| `RF-B-OWNER-EOR-HANDOFF-A-MIN` | `AGREED / PRIVATE SPEC SAME-HASH REVIEW PENDING` |
| Public implementation | common then W1, W2+W4, W5, W6, W3-last; predecessor A1 release remains active |
| Carrier | `INACTIVE` until A1 implemented + whole review + post-repair C2 |
| Migration | `INACTIVE` until carrier evidence gate |
| STOP04 provider / post-carrier W6 mirror | `UNAVAILABLE / NO CODE` |

---

# 工作区本地增量（2026-08-17）— RF-ROOT P6 contract 1（shutdown 停机顺序 + 写栅窗口收窄）

> 原文（上方正文）一字未改。本增量由编码会话在 ~/pgrac-dsh/specs-local/ 起草，
> 交 DSH 审核。定案前不得推公开仓（README 纪律）。绑定实现见本仓库 rf-root-dev 分支
> `src/backend/postmaster/checkpointer.c` 与 `src/backend/cluster/cluster_qvotec.c`。

## 增量 1：THREAD_CLEAN_CLOSE 停机顺序（contract 1，修 I7 执行偏差）

### 背景事实（t243 实测证据，2026-08-17）

- 旧接线把 5.13 shutdown handoff（`cluster_clean_leave_shutdown_drain`）放在
  ShutdownXLOG 之前。handoff COMMITTED 后：① 本节点 epoch 经 IC envelope 观察
  0→1（`cluster_epoch_observe_remote`，cluster_ic_envelope.c），而本地 fence token
  仍持 pristine baseline（epoch 0）→ 精确 == 判据失败；② survivor 下一次 poll 的
  steady-state baseline（fenced 集 = applied.dead，含离开节点）落地后，离开节点
  下一 poll 会 self-fence。二者都让离开节点 shutdown checkpoint 的
  recovery-anchor 发布（`cluster_recovery_anchor_publish_checkpoint`，
  `cluster_write_fence_reject_if_fenced`，CritSection 内）PANIC →
  abnormal shutdown → slot 2 永不到 STOPPED → t243 ok 3 铸根前置失败。
- 这违反了冻结 I7（"STOPPED occurs only after clean shutdown checkpoint and
  before coordination drain"）——旧顺序等于在 checkpoint 前先做了 coordination
  drain 的一半（serving/authority 移交）。

### 合同（本次修订后的停机顺序，与 I7 对齐）

checkpointer 的 ShutdownRequestPending 块，按序：

1. `ShutdownXLOG(0, 0)` —— shutdown checkpoint durable（含 W5a anchor 发布；
   此时 fence token 仍与 epoch 一致，写门全部合法）；
2. `cluster_wal_state_publish_stopped()` —— W3 STOPPED 槽位发布；
3. `cluster_clean_leave_shutdown_drain()` —— serving rebind/authority 转换
   （5.13 cooperative remaster/holder handoff；失败 fail-closed 返回 false）；
4. `cluster_control_root_thread_clean_close_publish()` 仅在 step 3 返回 true 时
   执行（handoff 失败 → root 保持 OPEN → 重启走既有 crash-rejoin 链，8.B）。

不变：immediate/error 退出永不发布 CLOSED；崩溃不写 CLOSED。

## 增量 2：qvotec 同 poll 写后刷新（spec-4.12b D2 实现收窄，survivor 侧）

### 背景事实

CLEAN_LEAVE commit（`cluster_reconfig_apply_clean_leave_as_coordinator`）按
spec-5.13 D3 冻结语义**不提交 fence marker**（"nothing to fence"）。epoch 提升
后，新 epoch 的权威只由 leader 下一 poll 的 baseline republish 提供；leader 自己
的 token 刷新（D2，读 poll 开头 matrix）还要再等一 poll。于是 commit 之后存在
"epoch 已提升、token 未跟进"的窗口（≤2×poll），窗口内 survivor 的任何 fence-gated
写（实测：node0 在 clean-leave 后 100ms 的 CHECKPOINT 的 anchor 发布）在精确 ==
判据下 PANIC。

### 合同（D2 同 poll 写后刷新）

`qvotec_poll_once`：本 poll 写出的 fence tuple（D4 fence submit，或 leader 的
baseline）达到 quorum-majority durable（与 ack 同源计数）后，立即以同一 tuple
调用既有 `cluster_write_fence_refresh_from_marker` 刷新本地 token。纯判据与
double-monotonic guard 不变；qvotec 仍是 token 唯一写者；不做任何门放宽——只是把
"健康方向"的 stale 窗口（R4 窗口的反向）从两 poll 收窄到一 poll。self-fence 的
engage-first 序不变（复用既有函数）。

### 审核注意点

- 该增量只收窄 healthy-side 窗口，不改变 fenced-side 语义（fenced 节点仍
  fail-closed）；
- fail-stop 路径的 D4 submit 同样受益（coordinator 自身 token 提前一 poll 就绪），
  行为方向不变；
- 未解决的问题（记录在案，不在本增量范围内）：3 节点下第三方 observer 的 token
  仍需自己的下一 poll 才跟进（drain-grace 交易在该窗口可能 53R51 重试，可接受）；
  seed 单节点 clean stop 时 CLOSED 发布的 CF(S) 撞 stale-hold drain 失败
  （CLOSED 跳过，对 seed 无害，L5 前需复核）。

## 增量绑定

- 产品实现：rf-root-dev 分支，commit 见编码会话（contract 1 reorder +
  qvotec same-poll refresh）。
- 验证：t243 全绿（铸根 ok 3 → L5 → L6/L8/L9/L10）；focused unit 全绿；
  完整 build 闭包。

## 增量 3：回退 phase3 recovery 锁准入的 postmaster 半个放宽（2026-08-17，修铸根后 pair-boot 楔死）

### 背景事实（t243 实测证据，2026-08-17，cfx 探针双侧日志）

- 旧接线曾把 S1 recovery 准入放宽为 `AmStartupProcess() || !IsUnderPostmaster`
  （方案 D 的 phase3 驱动在 postmaster 中重试 THREAD_OPEN）。这是**半个放宽**：
  S4 请求侧门与 S6 释放门仍只认 StartupProcess，master 侧门仍只认 GRD seal。
- 实测链条（run-16/17）：
  1. node0（coordinator，local master）postmaster 的 THREAD_OPEN CF(S) 经
     S1（已放宽）→ 本地 fast path 授予；S6 释放门拒（StartupProcess-only）
     → 根读 RELEASE_UNCERTAIN(27)，GRD 残留**幽灵 CF(S) holder**；
  2. 幽灵 holder 使 node0 checkpointer 的 W2 CF(X)（本地）与 node1 stats 的
     W2 ACTIVE CF(X)（远程，连续 r=13 超时）全部楔死 → 双侧 phase4
     "Cluster Stats did not publish READY" FATAL → start_pair bail；
  3. 若继续把 S4/master 侧一并放宽（本轮曾尝试），node1 postmaster 的 CF(S)
     走远程 wire 路径（outbound ring LWLock + CV wait），在无 PGPROC 进程里
     撞冻结 A1 §8.3（"outbound enqueue/wakeup …不得在 Postmaster 执行"、
     "锁竞争表示 unavailable"）→ postmaster 静默死亡。
- 结论：该放宽违反了冻结 STOP-01 I1（"Postmaster has no PGPROC and never
  acquires remote/verified CF"）与 AD-023 §4（caller 是 StartupProcess）。

### 合同（增量 3，回退型）

1. **S1 recovery 准入恢复 `AmStartupProcess()`（StartupProcess-only）**：
   postmaster 的 phase3 THREAD_OPEN CF(S) 在 S1 即 fail-closed（r=10），
   不产生任何 GRD 注册 → 幽灵 holder 机制性消失。
2. S4 请求侧门、S6 释放门、master 侧 REQUEST/grant 门的 seal 前置全部保持
   冻结原状，不做放宽。
3. THREAD_OPEN 根重开仍需要落地（L5 腿依赖），但必须由 **PGPROC 执行者**
   完成（StartupProcess 在 phase4 的 E2 STRONG 读上下文，或 LMON 阻塞执行者
   受托）——该执行者设计在 L5 腿单独落增量，不随本增量。
4. 不变：allowlist（CF 0xF1/S、WALR 0xFA/X）、OK_NATIVE/local fallback
   拒绝、fail-closed 语义；postmaster CF call count 保持零（I1 验收）。

### 安全论证

- 回退后 postmaster 不再执行任何 CF 获取/释放；铸根后 pair-boot 的 W2
  CF(X) 不再面对幽灵 holder，即授予（serving 已 current）。
- THREAD_OPEN 在 phase3 循环里 fail-closed（无副作用），不改变 witness/
  barrier/join 链的既有语义；L4/L5 的 root 状态消费点均在 phase4+ 的
  PGPROC 上下文。

### 验收

- 铸根后二次 pair-boot：W2 CF(X) 双侧即时授予、checkpointer 无楔死；
  t243 ok 3 → L5 → L6/L8/L9/L10 全绿（L5 的 THREAD_OPEN 执行者增量单独
  验证）；postmaster 侧无 CF 获取日志。

## 增量 4：qvotec fence baseline 以 clean-departed epoch-floor 抬升（2026-08-17，修重启后 fence token 停摆 PANIC）

### 背景事实（t243 实测证据，2026-08-17）

- 铸根后的二次 pair-boot（增量 3 回退后 CF(X) 已即时授予）暴露下一层：
  node0 的 W2 checkpoint 在 recovery-anchor 发布的 CritSection 内 PANIC
  （`epoch_cur=1 authorized=0 self_fenced=0 engaged=1`，fence-block 诊断）。
- 因果链：① node1 干净停机时 5.13 handoff COMMITTED（epoch 0→1，按
  冻结 D3 不提交 fence marker——"nothing to fence"）；② 重启后
  `cluster_clean_leave_rebuild_from_disks` 凭 leave-slot 的 durable COMMITTED
  marker 抬升 epoch floor 到 1；③ 但 last_applied（易失 ReconfigShmem）随重启
  归零，qvotec leader 的 baseline（spec-4.12b D2，epoch 源 = last_applied）
  只写出 epoch 0；④ 双方 token 刷新到 authorized=0，而 live epoch=1 →
  精确 == 判据下所有 fence-gated 写 fail-closed，W2 anchor 在 CritSection
  PANIC → 双侧 phase4 FATAL。
- 94791471d5 的 deferral 只覆盖活体窗口（last_applied 尚在），重启窗口
  结构性漏掉。

### 合同（增量 4，spec-4.12b D2 的 epoch 源收窄）

1. `qvotec_build_baseline_marker`：baseline 的 fence_epoch 取
   `max(applied.new_epoch, max_i(clean_departed_epoch[i]))`；dead set /
   generation / event_id / issuer 不变。clean-leave 从不 fence 任何节点
   （冻结 spec-5.13 D3），所以把 epoch 抬到 leave floor 时 dead set 维持
   applied 值是正确的 fence tuple。
2. 单调性由既有守卫兜底：floor 只随 leave commit 抬升；若 durable 权威
   高于 would-be baseline（既有 `durable_has_authority` 检查）仍不覆盖。
3. 不变：qvotec 仍是 token 唯一写者；token 发布协议（lease-last）与
   double-monotonic guard 不动；self-fence 语义不动。

### 安全论证

- 抬升只发生在 durable COMMITTED leave marker 已被 quorum-majority 证明的
  epoch（floor 的来源本身是 durable 事实），不会虚构高于实际会籍的 epoch。
- FAIL_STOP 路径不受影响：任何真实 fence 都有更高 epoch 的 fence marker
  submit → applied 先行跟进 → baseline 取 max 不改变其 tuple。
- 若 applied 已包含更高 epoch（含 join/readmission），max 不抬升——绝不
  用 leave floor 覆盖更新的 applied 事实。

### 验收

- 铸根后二次 pair-boot 无 fence PANIC；W2 checkpoint 正常完成；双侧
  phase4 → running；t243 ok 3 → L5 → L6/L8/L9/L10 全绿。

## 增量 5：join PREPARE drain 移出 join-drive 门（2026-08-17，修 L4 fast-rejoin 循环死锁）

### 背景事实（t243 L4 crash-rejoin 实测证据，2026-08-17）

- L4 腿 kill -9 → 重启 <3s（CSSD 死带内恢复），survivor 无 DEAD 边 → 无
  fail-stop；P04 shared-CF 快速重启回滚门（observed incarnation 超 floor）
  正确驱逐旧化身并置 fast_rejoin_bitmap → epoch 1→2（JOIN_PENDING，事件
  只 staged、未发布）。
- 此后陷入循环死锁（双侧日志实锤）：
  1. join-drive 门要求 `ordinary_actions_allowed`，其值 =
     serving rebind 成功（epoch 2 的 GRD seal 重验）；
  2. serving rebind 需要 JOIN 方向 GRD recovery episode 关闭；
  3. episode 需要 JOIN_PENDING 事件已 applied；
  4. JOIN_PENDING 的 prepare-marker drain（发布该事件）由
     `cluster_reconfig_drive_joins` 驱动——drive 被同一道门挡住。
  → 事件永不发布、episode 永不启动、rebind 永不通过、COMMITTED 永不落、
  joiner 30s 后 53R61（"join did not converge"）。
- 对照：fail-stop 的 staged fence drain（`cluster_reconfig_poll_failstop_
  fence_stage`）在 LMON tick 里**无门**驱动——事件发布不依赖 serving
  rebind，所以 fail-stop 路径从不死锁。join prepare drain 属同一类
  （完成 in-flight 会籍发布），却被放进 drive 门内——P04 接线缺口。

### 合同（增量 5）

1. LMON tick 在 fail-stop stage drain 之后、无门地驱动
   `cluster_reconfig_poll_join_prepare_stage()`（无 staged 时为 no-op）。
2. join-drive 门自身不变：**新** join 决策仍须 ordinary/control 腿；
   drain 只完成已 staged 的 JOIN_PENDING 发布（durable 链的完成步，
   与 fail-stop stage 同地位）。
3. 不变：JOIN_PENDING 事件内容、epoch bump、COMMITTED 是唯一 commit 点、
   vet/allowlist/fail-closed 语义；PREPARE 仍 best-effort。

### 安全论证

- drain 只推进已由 eviction（P04 回滚门）授权的 staged 事件；无 staged
  时为 no-op，不产生任何新决策。
- JOIN_PENDING 发布后 GRD episode/rebind/commit 链沿既有冻结路径推进；
  未放宽任何 gate、judge、timeout 或 workload。

### 验收

- t243 L4：kill -9 重启 ≤3s 时 survivor 在 ~1 tick 内发布 JOIN_PENDING →
  episode 关闭 → rebind 通过 → COMMITTED + JCMK → joiner 自认 → phase3
  完成 → ok 18/19 稳定；L5-L10 全绿。

## 增量 6：fast-rejoin 驱逐计入 JOIN_PENDING dead 集（2026-08-17，修 L4 join episode DONE 循环死锁）

### 背景事实（t243 L4 实测证据，2026-08-17）

- 增量 5 修复后：驱逐 → JOIN_PENDING 发布（epoch 2）→ JOIN 方向 GRD
  episode 启动并走完本地 GES rebind barrier（stall 探针零命中）→
  WAIT_CLUSTER 等待 joiner 的跨节点 DONE——但 joiner 的 DONE 在结构上不可
  能：其 phase3 barrier 尚未武装（witness 需要 sj_adm = JCMK = COMMITTED
  = join-drive Phase-2 = serving rebind = episode 关闭）→ 循环死锁。
- 根因差异：fail-stop 路径的 JOIN_PENDING dead 集 = last_applied.dead
  = {joiner}（fail-stop 事件先行），episode 的 P6 门跳过 dead 集的 DONE；
  fast-rejoin 驱逐路径没有 fail-stop 事件，JOIN_PENDING 的 pending_dead
  只取 last_applied.dead（空）→ joiner 不在 dead 集 → 其 DONE 被强制要求。
- P04 冻结语义本身已写明"exclude the prior incarnation first"——驱逐即旧
  化身的死亡宣告，只是没有落入 JOIN 事件的 dead 集。

### 合同（增量 6）

1. `cluster_reconfig_apply_join_as_coordinator` 的 pending_dead 在
   last_applied.dead 之上并入 `fast_rejoin_bitmap`（本 episode 的驱逐集）。
2. 下游全走既有冻结链：JOIN_PENDING（dead 含旧化身）→ episode 跳过
   joiner 的 DONE（P6 门）→ 关闭 → serving rebind → drive Phase-2 →
   COMMITTED（dead 清掉 joiner，fence baseline 同步收缩）→ JCMK → joiner
   自认（RC-5 supersede 解 self-fence）→ witness live → phase3 完成。
3. 不变：事件 ID 算法、epoch bump 序、vet、commit 是唯一 commit 点、
   clean-departed 清除（commit 时）、fence 单调守卫。

### 安全论证

- 驱逐本身已是 quorum-observed 的旧化身死亡声明；把它写入 JOIN 事件的
  dead 集只是让 episode 的 DONE 跳过与 fail-stop 路径同一语义（旧化身在
  本 episode 没有 GRD holder 状态可 redeclare，其 DONE 无意义）。
- COMMITTED 时 joiner 从 dead 集清除 + fence baseline 收缩，与新化身
  准入同时发生（fail-stop 路径同一序）；无任何 gate 放宽。

### 验收

- t243 L4：驱逐后 episode 关闭（不再等 joiner DONE）→ COMMITTED + JCMK
  → node1 自认 → phase3 完成 → ok 18/19；L5-L10 全绿。

## 增量 7：bootstrap 重入清除 clean-departed（2026-08-17，修 L4 竞态 B 双路径死）

### 背景事实（t243 L4 实测证据，2026-08-17）

- 竞态 B（重启 > CSSD 死带）：node1 的 cssd 被 survivor 判 DEAD →
  membership 降级 DEAD；但 node1 的 clean-departed 位仍置（首次 boot 的
  clean stop 写入，bootstrap 重入不产生 join commit → 冻结的
  "join commit 清 clean_departed" 不触发）→ CL-I13 掩码吞掉 fail-stop →
  无事件、无 episode → serving rebind 永失败 → 双路径全死。
- 竞态 A（重启 < 死带）走 fast-rejoin 驱逐路径（增量 5/6 已修）。
- 冻结 spec-5.13 CL-I13 的掩码语义是"自愿离开者不 fail-stop"——该节点
  已经回来（cssd ALIVE + ABSENT→MEMBER），掩码的适用前提已消失。

### 合同（增量 7）

1. membership 维护的 bootstrap 重入边（peer CSSD ALIVE + state ABSENT →
   MEMBER）同时 `cluster_reconfig_clear_clean_departed(i)`：节点已重新在场，
   其后续真实死亡必须走普通 fail-stop。
2. 不变：clean-leave 的 durable COMMITTED 重建（boot 时）仍然置位——历史
   证据不丢；join commit 的清除不变；fail-stop 语义不变。

### 安全论证

- 清除只发生在节点被证明重新在场之后（cssd ALIVE + 新槽位）；此前的
  离开期掩码照旧。清除后该节点任何后续死亡都是真实故障 → fail-stop，
  方向为收紧（更多 fail-stop 而非更少），8.A 安全。
- 不改变任何 fence/epoch/gate/judge。

### 验收

- t243 L4：两条竞态路径均收敛（驱逐路径 + fail-stop 路径）；ok 18/19
  稳定；L5-L10 全绿。

## 增量 8：fast-rejoin 驱逐门扩到 DEAD 态（2026-08-17，修 L4 竞态 B 的 join 无腿）

### 背景事实（t243 L4 实测证据，2026-08-17）

- 增量 7 后竞态 B 走通 fail-stop（epoch 1→2 + FAIL 事件 + JOIN 方向
  episode 2s 内关闭）——但 join 永无驱动：runtime_join_allowed 只由
  fast-rejoin 驱逐置位（actions snapshot = fast_rejoin_bitmap），而驱逐门
  要求 ms==MEMBER；竞态 B 中 cssd 死带抢先（DEAD @2.1s）把 membership
  降级 DEAD → 驱逐永不触发 → 无 JOIN_PENDING/COMMITTED/JCMK → joiner
  witness 永不稳定 → 60s bail。
- P04 的冻结前提是"快速重启发生在死带内，liveness 永不呈现 DEAD 边"——
  本机重启 2.1-2.5s 恰好压在 3s 死带边缘，两条竞态都真实发生。新化身的
  槽位证据在两个竞态里同等有效。

### 合同（增量 8）

1. 驱逐门（shared-CF rollover gate）的 membership 前置从
   `ms == MEMBER` 扩为 `ms == MEMBER || ms == DEAD`（cssd ALIVE + fresh
   slot + observed incarnation > prior floor 不变）。DEAD 态时驱逐不重复
   死亡宣告（fail-stop 已声明），只为 join 驱动提供 runtime 腿。
2. 不变：prior floor 单调、JOIN_PENDING/COMMITTED 链、vet、fence、gate、
   judge、timeout、workload 全不动。

### 安全论证

- DEAD+cssd-ALIVE+新化身 = 该节点已重启归来；驱逐只是把既有死亡事实与
  新化身证据接进既有的 join 协议——fail-stop 与驱逐对同一节点同 tick
  叠加时事件仍单调（fail-stop 先发布，驱逐只置位驱动 join）。
- 不放宽任何 fence 或 admit 判据：vet 的 floor 单调检查照旧。

### 验收

- t243 L4：两条竞态路径均收敛到 JOIN_COMMITTED + JCMK + joiner 自认；
  ok 18/19 稳定；L5-L10 全绿。

## 增量 9：authority barrier 同 composite 重发保留 done 槽位（2026-08-17，修 L4 publish 瞬时失败后重发永久饿死）

### 背景事实（run-29 实测证据，2026-08-17 19:27:38）

run-29（HEAD=c56b783d04）L4 链已全通到最后一跳，卡在 node1 phase3
authority barrier 的 publish 瞬时失败 → 重发饿死：

- 19:27:38.270：node1（pid 8284 postmaster / 8285 LMON）fast-rejoin 自认
  完成（"shared-CF fast-rejoin admission and re-declare complete — boot
  fence lifted"），同一毫秒 barrier gen=1 terminal SUCCESS，但
  `cluster_authority_readiness_publish_recovery` 失败——TEMP 证据：
  `19:27:38.270 TEMP reconfig-lock conditional fail: state=0x20000000`
  （postmaster 无 PGPROC，formation snapshot 用
  LWLockConditionalAcquire；LMON 恰在同刻持 reconfig 锁做 admission
  收尾 → CAPABILITY_UNAVAILABLE → `formation` 谓词瞬时为假；TEMP
  mismatch 日志里所有字段（含 formation=0 READY、grd=1）事后复查全过）。
- publish 失败路径在函数内 `clear_matching("publish_recovery_fail")`
  清掉 STARTING binding → phase3 循环 re-bind → `barrier_wait` 重发
  **gen=2**（同一 composite：epoch=4 / hash=11587734006894897235 /
  members=3/0）→ 重发把 `recovery_authority_done_epoch/hash[]` **全部清零**
  （cluster_grd.c 重发后段）→ node1 自己的一格被 LMON tick 1 tick 内重刷，
  但 node0 的那格永远等不到新帧：
  - node0 的 JOIN episode 已在同刻（38.270）关闭（"grd episode done:
    dir=2 epoch=4"），WAIT_CLUSTER 每 tick 的 DONE 重播停止；
  - node0 的 once-per-composite echo（回正清单 P1#4）已被 gen=1 期间的
    node1 帧消费，同 composite 不再重播。
  → gen=2 的 done0=0/0 永久（authority tick 从 38.296 起恒为
  `done0=0/0 done1=4/hash`）→ phase3 直到 60s pg_ctl 窗口超时 bail →
  测试清理 immediate 停 node0（28:30.36）→ node1 cssd 判 node0 DEAD →
  二次 fail-stop（28:33.5 epoch 4→5）→ 残留节点继续 phase3 循环到
  19:31:34 才 READY（run-29 尾部见证）。

根因链：publish_recovery 的瞬时失败（A1 无 PGPROC 的条件锁获取，与
admission 收尾同刻竞争）本身可重试吸收，但重发路径把"已证明的收敛证据"
（done 槽位）清零，而 survivor 侧不再有义务补发同 composite 的 done key
（episode 已关 + echo once-guard 已消费）→ 结构性饿死。

### 合同（增量 9）

1. `cluster_grd_recovery_authority_barrier_wait` 的重发后段：**仅当新请求
   composite（epoch / dead-bitmap hash / member 集合）与上一请求不同才清零
   done 槽位**；composite 相同则保留。理由：done 槽位只在帧的
   {epoch, hash} 与当前请求 composite 精确匹配时才被写入
   （mark_peer_done 的 authority-axis 门），因此同 composite 重发时保留值
   就是新 generation 需要的精确收敛证据；composite 不同时保留值必然无法
   通过新请求的 epoch/hash 比较（all_done 仍 fail-closed），清零只是卫生。
2. 不变：head gate（epoch==current、quorum、incarnation、membership）、
   map-current、request_current、terminal 发布、cancel 语义、
   publish_recovery 的失败即 clear 契约、judge/timeout/workload 全不动。
3. 不重开任何 fence/admit 放宽；不放宽 publish 谓词本身（瞬时竞争由
   phase3 既有的 re-bind 循环吸收——现在重发可收敛）。

### 安全论证

- 保留槽位的语义是"某成员在 composite C 完成了 re-declare barrier"——
  与 generation 无关；同 C 的重发请求要的就是同一份证据。gen=1 已
  SUCCESS terminal 即证明双方在 C 收敛过，gen=2 无需重新证明。
- 不可能出现"旧 composite 的槽位污染新请求"：epoch 单调，head gate 要求
  epoch==cluster_epoch_get_current()，composite 不可能回退；同 epoch 的
  dead-set 增长（r3-P2-2）改变 hash → composite 不同 → 清零。
- 极端情形（重发时 peer 已进入同 epoch 新 episode）：terminal 发布前
  request_current 与 publish_recovery 的 formation revalidate 仍要求
  当前快照与 binding 一致，不一致则 publish 继续失败、循环重来——不会
  以旧证据开出新 seal。

### 验收

- t243 L4：38.270 publish 瞬时失败后 gen=2 在 ~1 tick 内 terminal →
  phase3 出 → ok 18/19 稳定；L5-L10 全绿。
- cluster_unit：新增 2 例（同 composite 重发保留、composite 变化清零）。

## 增量 10：LMON 逐迭代广播加 1Hz 下限（2026-08-17，修 L5 restore boot 帧风暴 → cssd 心跳饿死 → 假 DEAD）

### 背景事实（run-30 实测证据，2026-08-17 20:17:00-20:18:04）

增量 9 后 t243 ok 18/19 通过（L4 60s 窗口内完成），L5 的 restore boot
（claim 恢复后的 node1 重启）出现新楔子——两节点 LMON 互相以帧速率驱动：

- node0（survivor coordinator）的 clean-leave 机器在
  `cl_survivor_tick` step 2a 里**每个 LMON 迭代**重发 LEAVE_COMMITTED
  （type=30）：条件 `is_clean_departed(1) && !cssd-dead(1) &&
  serving_ready_is_current()` 在 node1 重启归来（cssd ALIVE）期间恒真，
  "re-sent each tick while the leaver is alive" 的"每 tick"在 LMON
  迭代可被入站帧驱动到帧速率时变成每秒数万帧。
- node1（rejoiner）的 authority tick（`grd_recovery_authority_lmon_tick`）
  在其请求 pending 且本地 barrier 完成时**每个 LMON 迭代**广播 done key
  （type=4 GES_REQUEST/REDECLARE_DONE）。
- 两者互为对方迭代的唤醒源：node1 收到 type=30 → 下一迭代广播 type=4 →
  node0 收到 → 下一迭代重发 type=30 → …… 1:1 ping-pong 以迭代时长
  （~100µs）为周期，实测双方 ~16k 迭代/秒（reconfig-lock diag 计数），
  持续 ~60s（20:17:00.8 → 20:18:01）。
- 风暴淹没 tier1 每-peer outbound（FIFO 持续满）→ node0 的 cssd 心跳帧
  排队迟到 >3s → node1 cssd 判 node0 SUSPECTED（20:18:03.168）→ DEAD
  （20:18:04.169，dead_gen=2）→ node1 二次 fail-stop（epoch 5→6）→
  phase3 barrier inner break（epoch_moved + quorum 丢失）→ phase3 循环在
  reconfig-lock 条件获取与 LMON 自身处理之间抖动 → 60s pg_ctl 窗口到期
  bail；残留 postmaster 继续循环至 20:19:29.255 以
  "PANIC: cannot wait without a PGPROC structure" 结束（A1 无 PGPROC 的
  阻塞 LWLockAcquire，伴随现象）。
- 对比 run-29 L5（19:27:19-22）同样的 clean-leave + restore boot 在 3s
  内收敛：当时 node0 的 serving rebind 门未过（serving_ready 未 current），
  type=30 重发被 P6 门挡住，无风暴。run-30 里 L4 链完成后 node0 的
  serving 已 current → 重发门打开 → 风暴出现。增量 9 让 L4 完整闭环，
  首次把 L5 的这条腿暴露出来。

### 合同（增量 10）

1. `grd_recovery_authority_lmon_tick`：done-key 广播（本地 done 槽位
   的写保持每迭代——all_done 读它）加 1Hz 时间下限（两次广播间隔
   >= 1s）。LMON 迭代可被入站流量驱动到帧速率（spec-7.2 D1 懒职责的
   既定前提），任何"每迭代一帧"的发送都必须遵守 1Hz floor。
2. `cl_survivor_tick` step 2a 的 LEAVE_COMMITTED 重发：同样 1Hz 下限
   （best-effort 交付语义不变——leaver 每 s 至多收一帧确认，足够）。
3. 不变：广播内容、门条件、echo once-guard、authority 语义、
   judge/timeout/workload 全不动。

### 安全论证

- 1Hz floor 只降低重发/重播频率，不改变任何判定：done key 与
  LEAVE_COMMITTED 都是幂等 best-effort 帧，接收端门是 idempotent gate。
- 相位 3 barrier 的收敛时限（秒级）远大于 1s 广播周期，1Hz 不引入
  新的饿死路径；echo 的 once-per-composite 回复不受影响（它由
  mark_peer_done 触发，不在本增量的两条路径上）。
- 帧风暴消除后 tier1 outbound 恢复空闲，cssd 心跳帧 1s 内必达，
  假 DEAD 不再发生。

### 验收

- t243 L5：restore boot 在 60s 窗口内完成（fast-rejoin 链在 20:17:01.5
  驱逐后正常走完）；无帧风暴（tier1 计数回落到 ~1/s）；无假 DEAD；
  ok 20/21（L5 两断言）通过；L6/L8/L9/L10 全绿。

## 增量 11：DONE echo 扩到 authority self-done 复合体（2026-08-17，修 cast reform 同复合体饿死）

### 背景事实（run-31 实测证据，2026-08-17 21:11:20-21:12:22）

增量 10 后 run-31 在**铸根后的 cast 双节点重启**腿失败：

- node0 与 node1 并发重启（21:11:19.2）。node1 的 phase3 request 在
  21:11:22.225 发布于 (epoch=1, empty-hash)；node0 的同复合体 request
  发布于 21:11:20.226，**21:11:22.227 已 terminal SUCCESS**（node0 收到
  node1 的首帧 done 后 all_done 即达）。
- node0 的 authority tick 在 terminal 后早退（3157-3161：terminal >=
  request 直接 return）——**不再广播 done key**；增量 10 的 1Hz floor
  又把 node0 terminal 前最后一帧广播（22.226，距上一帧 21.53 仅 0.7s）
  抑制掉了。于是 node1 的 (1, empty) request 从 22.225 到 21:12:22
  （63s，start_pair 超时）**done0=0/0 恒空**。
- 既有 echo 机制（回正清单 P1#4）本可兜底，但其触发条件比对的是
  **FSM self-done**（recovery_done_epoch/hash[self]，episode 关闭时写）：
  cast reform 里幸存者 FSM 是全新 shmem、从未跑过 episode → self-done=0
  → 永不应答。run-30-L5 的 clean-leave 情形同理：FSM self-done 的
  dead-set hash（{leaver}）与 rejoiner 的 pristine 复合体（empty）不同
  → 也不应答。

### 合同（增量 11）

1. mark_peer_done 的 echo 触发条件从"帧 == FSM self-done"**放宽为
   "帧 == FSM self-done OR 帧 == authority self-done"**
   （recovery_authority_done_epoch/hash[self]，authority tick / serving
   rebind 在已发布 request 复合体上盖章，terminal 后保留）。authority
   复合体才是 peer 的 request 实际匹配的复合体。
2. once-per-composite 放大防护（回正清单 P1#4）不变：每个 {epoch, hash}
   至多一次 echo，新复合体重置。不构成新的风暴面。
3. 不变：FSM 轴、authority 轴、门、judge/timeout/workload 全不动。

### 安全论证

- echo 只是把 peer 自己的复合体原样回播（幂等帧），接收端各轴门
  （authority-axis 精确匹配 / FSM 单调 max）均幂等；放宽的只是"何时
  回播"的触发面，且仍受 once-per-composite 约束。
- 无新风暴：echo 每复合体至多一次；配合增量 10 的 1Hz floor，
  稳态广播 ~1/s。

### 验收

- t243 cast reform（ok 3/4 腿）：并发双节点重启时同复合体 request
  在 ~1 tick 内收敛；L4（ok 18/19）+ L5 restore boot 全绿。

## 增量 12：clean-leave 槽位按化身变更释放（2026-08-17，修 L5 restore boot 被 leave 串行门永久卡死）

### 背景事实（run-33 实测证据，2026-08-17 21:24:18-21:25:19）

增量 10/11 后 run-33 已到 ok 1-19（cast reform 收敛、L4 两断言通过），
L5 restore boot 仍超时：

- node1 L5 fast stop（21:24:18.5，clean-leave epoch 5）→ restore boot
  （21:24:19.1）。restore boot 的 cssd 在 ~2.1s 内恢复心跳（本轮无
  boot-latency 空窗）→ **node0 的 cssd 从未把 node1 判 DEAD**。
- node0 的 clean-leave 机器 step 3（cl_survivor_tick）只在
  `cssd peer DEAD && clean_departed` 时释放 leave 槽位——cssd 状态是
  node 级而非 process 级：node1 快速重启后 peer 恒 ALIVE → 槽位永持 →
  `cluster_clean_leave_in_progress()` 恒真 → P2 串行门
  （"do NOT drive any join while a clean leave is active"）把 fast-rejoin
  链（20.568 驱逐已触发，`join-drive blocked: clean_leave=1`）永久挡住
  → 无 fail-stop/JOIN → node1 的 phase3 request (5, empty) 对 node0 的
  authority (5, {leaver}) 永不收敛 → 60s 窗口 bail。
- 对比 run-29-L5（19:27:19-22 收敛）：当时 node1 重启的 cssd 空窗
  >3s → node0 cssd DEAD → 槽位释放 → 链走通。run-33 的空窗 <2s 是
  另一条竞态（更快重启反而卡死）——两条竞态都真实，需要化身级判据。

### 合同（增量 12）

1. `cl_survivor_tick` step 3 的槽位释放条件从
   `cssd peer DEAD` 扩为 `cssd peer DEAD || 观察到离开节点的新化身`：
   新化身 = observed slot 相干且 `obs_incarnation != last_admitted
   [leaving]`（last_admitted 保持离开时的旧化身——clean-departed 未
   重入前不变）且 fresh-alive。新进程出现 ⇒ 旧进程必然已退出 ⇒
   "leaver actually departed" 成立。
2. 不变：P2 串行门本身、LEAVE_COMMITTED 重发（1Hz，增量 10）、
   幂等接收门、commit 语义、judge/timeout/workload 全不动。

### 安全论证

- 释放只让 fast-rejoin 链（驱逐→fail-stop→JOIN）得以运行；leave 已
  COMMITTED（marker 多数持久化 + LEAVE_COMMITTED 已发），旧进程的
  退出是事实（新进程不能与旧进程同存于同一端口/同一 incarnation）。
  并发 JOIN 的 epoch bump 不影响已提交 leave 的真相源（P1-1 语义
  不回溯）。
- 误判面：obs 槽位暂态（旧 inc 尚未被新 inc 覆盖）→ 条件不成立 →
  槽位保留，下个 poll（1s）再判——只会延迟不会错放；obs 消失
  （节点真死）→ 走 cssd DEAD 分支。
- 不放开任何 fence/admit/authority 判据。

### 验收

- t243 L5：restore boot 的 leave 槽位在 ~1s 内释放 → fast-rejoin 链
  在窗口内走完 → ok 20/21；L6/L8/L9/L10 全绿。

## 增量 13：owner-rejoin 门接受 CLOSED 生命周期的同主干净重开（2026-08-17，修 L5 restore boot 的 JOIN 提交）

### 背景事实（run-37/38 实测证据，2026-08-17 21:51:43-21:52:43）

增量 12 后 fast-rejoin 链已能启动（驱逐 → JOIN_PENDING epoch 6 →
JCMK 多数持久化），但 JOIN 提交的 re-vet 的 owner 门永久失败：

- `TEMP owner gate: node=1 root=0 lc=4 owner_inc=840290198982451
  admitted=840290210048484 lineage=2 import=0 proven=840290210048484`
  —— root 查找 OK_PRIMARY、claim CRC 匹配、origin_owner_incarnation <
  admitted、JCMK majority 证明 == admitted，**唯一不满足的是
  `snapshot.lifecycle == CLOSED`**（CLUSTER_CONTROL_ROOT_LIFECYCLE_CLOSED=4，
  owner_rejoin_v1 只接受 OPEN/RECOVERY_COMPLETE）。
- 根因：L5 fast stop 是**干净停机**——clean-leave 的 THREAD_CLEAN_CLOSE
  把 root 置为 CLOSED。restore boot（同主、同 claim 文件）的
  THREAD_OPEN（CLOSED→OPEN）依赖 phase3 的 CF(S) 共享锁，而该锁的
  S1 门在 phase3 期间因 LMS 未 READY 失败（`cf lock fail: r=10
  FAIL_LMS_UNAVAILABLE`）→ root 停在 CLOSED → fast-rejoin JOIN 的
  owner 门永拒 → 提交永不成 → node1 的 phase3 request (6, empty) 对
  node0 的 authority (6, {leaver}) 永不收敛 → 60s bail。
- run-29 同腿能过：当时 node0 的 serving rebind 门未开、无 fast-rejoin
  链，phase3 barrier 直接收敛、root 在 phase4（LMS READY 后）才由
  StartupProcess 打开。增量 9/12 使 fast-rejoin 链成为 L5 主路径后，
  这条 CLOSED 拒绝第一次成为阻塞。

### 合同（增量 13）

1. `cluster_recovery_owner_rejoin_v1` 的 lifecycle 接受集合从
   {OPEN, RECOVERY_COMPLETE} 扩为 {OPEN, RECOVERY_COMPLETE, CLOSED}；
   CLOSED 分支复用 RECOVERY_COMPLETE 的同一组前置：
   `origin_owner_incarnation < admitted`（同一主的新进程，化身单调）
   + claim CRC == identity.thread_claim_crc32c（写一次 claim 的身份
   证明）+ JCMK majority 证明 == admitted（持久 COMMITTED marker）。
2. 不变：OPEN 分支（owner_inc == admitted 的已满足门）、claim 校验、
   JCMK 导入、lineage 递增、fence/judge/timeout/workload 全不动。

### 安全论证

- CLOSED 只可能由该 root 的持有者干净释放（THREAD_CLEAN_CLOSE 契约）；
  身份锚是写一次的 claim 文件（CRC 绑定 identity），化身单调 +
  持久 JCMK 证明 admitted 是新进程——与 RECOVERY_COMPLETE 分支的
  信任链完全一致，只是生命周期的字面值不同。
- 不放开任何跨主/伪造面：claim CRC 不符、化身不单调、JCMK 不达
  majority 时仍 fail-closed；root 一旦被 OPEN（他人抢占），CLOSED
  分支不再适用（OPEN 分支要求 owner_inc == admitted）。

### 验收

- t243 L5：restore boot 的 JOIN 提交在 owner 门通过后完成 →
  JOIN_COMMITTED → node1 自认 → phase3 收敛 → ok 20/21；L6/L8/L9/L10
  全绿。

## 增量 14：DONE echo 移到 FSM episode-hash 门之前（2026-08-17，修 bootstrap/cast reform 同复合体饿死）

### 背景事实（run-42 实测证据，2026-08-17 22:13-22:15）

增量 11 的 echo 块放在 `cluster_grd_recovery_mark_peer_done` 的 FSM
episode-hash 门（`dead_bitmap_hash == 0 || dead_bitmap_hash !=
episode_bitmap_hash` 早退）**之后**——首次编队 / cast reform / clean-leave
腿的本地 episode hash 恒为 0，echo 块是死代码：node0 request terminaled
后广播停（1Hz floor 抑制最后一帧 + terminal 静默），node1 的同复合体
request 因 done0=0/0 永久饿死（run-42：done0=0/0 持续 70s）。

### 合同（增量 14）

1. echo 块（FSM self-done 或 authority self-done 匹配 + once-per-composite
   放大防护）移到 episode-hash 门**之前**；FSM hash 轴写入
   （`recovery_done_bitmap_hash[node]`）在门后原样保留。
2. 不变：echo 每 {epoch, hash} 复合体至多一次；接收端各轴门幂等；
   judge/timeout/workload 不动。

### 验收

- t243 run-43+：node1 的 authority tick 显示 `markpd>0 echo=1` →
   bootstrap/cast reform 同复合体在 ~1 tick 内收敛。

## 增量 15：postmaster A1 契约——reconfig 自认读条件化 + phase3 mid-bind 保护（2026-08-17，修 L5 restore boot 的 postmaster A1 PANIC）

### 背景事实（run-45 实测证据 + lwlock 探针，2026-08-17 23:07:24）

L5 restore boot 的 phase3 循环在 begin_ok 后 ~13ms 内必死：

```
23:07:24.183 [58118] TEMP cf lock fail: mode=5 r=10 ... pid=58118 upm=0
23:07:24.183 [58118] PANIC:  cannot wait without a PGPROC structure
                     DETAIL:  tranche=90 (ClusterReconfig) state=0x20000000 mode=1
```

- **A1 违约点**：`cluster_reconfig_self_join_admitted()` 用**阻塞**
  LWLockAcquire(SHARED) 读 ReconfigShmem->lock，而
  `cluster_control_root_thread_open_publish` 的 TEMP 分解诊断
  （cluster_recovery_duty.c:551）在求值参数时经
  `cluster_recovery_transport_components_current()` 调到它；同一毫秒
  LMON 正持该锁 EXCLUSIVE（join-drive/rollover 链）→ postmaster
  （MyProc==NULL）进 LWLockQueueSelf → PANIC。run-43（22:15:56.802）
  同款。`cluster_grd_recovery_authority_is_current` 与
  `cluster_authority_temp_log_predicate_mismatch` 也经同一函数暴露。
- **mid-bind 清 binding 竞态**：begin() 只能以 lms_generation=0 建
  STARTING binding（LMS 进程在 begin 之后才 spawn，live gen 尚 0），
  gen 由 phase3 循环下一迭代的 bind_recovery_generation 写入。此窗口
  （~13ms）内 node0 的 REDECLARE_DONE 帧到达 → ges 的 "TEMP done gate"
  诊断（cluster_ges.c:194）求值 `cluster_recovery_transport_is_current()`
  ——该函数带**清 binding 副作用**（recovery_transport_stale clear，
  gen=0 被视为 stale）→ STARTING binding 被毁 → 循环被迫整轮重来
  （wait_for_live_formation + begin），并把 phase3 收敛拖到竞态窗口
  之外（run-43 55.801 clear → 55.802 PANIC 同链）。
- run-44 的 claim FATAL 与 run-45 的 "Stale postmaster.pid" 是同一
  PANIC 的测试面（node1 死在启动链，harness 后续 start 失败 bail）。

### 合同（增量 15）

1. `cluster_reconfig_self_join_admitted()`：MyProc==NULL（postmaster）
   时改用 `LWLockConditionalAcquire(SHARED)`，竞争即返回 false
   （fail-closed：调用方全是 AND 门，只延迟不误放；admission 是
   一次性闩锁，重试即收敛）。带 PGPROC 的进程保持阻塞语义不变。
2. `cluster_recovery_transport_is_current` 的 stale-clear 只对
   `binding.lms_generation != 0` 的 STARTING binding 执行：gen=0 是
   "begin 后尚未 bind" 的中间态，不是 stale；phase3 循环自己会在
   失败路径清 binding 并整轮重来（有界）。
3. ges "TEMP done gate" 诊断（cluster_ges.c:194）改用无副作用的
   `cluster_recovery_transport_components_current()`（诊断不得执行
   带副作用的判定逻辑）。
4. 不变：DONE/REDECLARE 各轴门本身、echo、1Hz floor、FSM/authority
   复合体、judge/timeout/workload 全不动。

### 安全论证

- 条件化只影响无 PGPROC 调用者的锁原语选择；锁内读的值与持锁语义
  不变。竞争路径返回 false 与"尚未准入"同值，所有消费方（
  components_current 的 member_ok、grd request-current 门、
  owner-rejoin 前置）都是 fail-closed AND 门——最坏是丢一帧/延迟一
  tick，绝不放行。
- mid-bind 保护只取消"gen=0 中间态"的销毁；真正 stale（gen 已绑但
  形成漂移）的 STARTING binding 仍被清，phase3 循环对 gen=0 绑定
  的自我失败路径（bind preseal 失败 → clear → 重来）原样保留，
  有界收敛。
- 不重开"四门放宽"：DONE 门在 gen=0 窗口仍拒帧（components_current
  返回 false），收敛靠 postmaster bind gen 后 node0 的 1Hz 重播。

### 验收

- t243 L5 restore boot：postmaster 不再 PANIC；begin→bind→barrier
  在 ~1 tick 内完成；ok 20/21 及 L6/L8/L9/L10 全绿；cluster_unit
  新增 `test_self_join_admitted_no_pgproc_never_blocks_on_reconfig_lock`
  全绿。

## 增量 16：join COMMIT 阶段排水移出 join-drive 门（2026-08-17，修 L5 restore boot 的 JOIN 永不发布）

### 背景事实（run-45→53 实测证据链，2026-08-17 23:07-23:56）

L5 restore boot（clean stop + 快速重开）的 phase3 权威 barrier 永不收敛
（done0=0/0 恒空），60s bail。逐层实锤（探针全链）：

1. 幸存者 node0 的 authority tick 在自身 phase3 terminal 后早退（
   `terminal >= request`），serving rebind（`cluster_grd_serving_authority_
   rebind_lmon`）重贴新复合体（(N, {leaver})）但不 bump request generation
   ——tick 永不恢复广播，合成 done 槽位 + echo 是唯一线上载体（run-47
   "grd rebind OK ... req_gen=1 terminal=1"）。
2. node0 的 rebind 复合体是驱逐 episode 的 {leaver}；node1 的 request 是
   pristine empty——auth_match=0 永不匹配（run-47 19.303 "peer done ...
   auth_match=0"）。唯一能产生 (N, empty) 复合体的路径是 **JOIN episode
   闭合后的 rebind**（run-53 16.954→18.600：L4 走通此链）。
3. **L5 restore 的 JOIN 发布被 join-drive 门卡死**（run-52/53 探针）：
   - 23.614 commit 决策 → marker 多数（jreq=10）→ revet 全过（无 diag）→
     prepare（pre-bump）→ **fence marker 提交成功（"TEMP fence submit:
     ok=1 jbusy=0"）**——一切就绪；
   - **随后 join-drive 门关闭**（`ordinary_actions_allowed=0`——serving
     rebind 失败：apply-join 后 node1=JOINING 的活形成与 rebind 重贴的
     ABSENT 绑定漂移）→ `cluster_reconfig_drive_joins` 不再被调用 →
     `poll_join_commit_stage`（含 fence 轮询 + publish）**永不运行** →
     JOIN 事件永不发布 → GRD 无 join episode → 无 (N, empty) rebind →
     node1 的 phase3 barrier 永远饿死。
   - L4 能过：L4 是 control-root 门控 rejoin（control=1 → fast_rejoin_
     control_actions=1 → 门仍开）；L5 是 ordinary rejoin（control=-1）。

### 合同（增量 16）

1. `cluster_reconfig_lmon_tick` 在既有 PREPARE 无门排水（增量 5，line
   5791）旁，**同样无门排水 `cluster_reconfig_poll_join_commit_stage()`**
   ——完成一个已 staged、JCMK 多数持久化的发布；不产生任何新准入决策。
2. 不变：poll 内部全部安全门（revet/vet/owner/epoch/predecessor/bitmap）、
   commit_member 的 clean-leave 门（staging 期）、publish 的 epoch+predecessor
   门、judge/timeout/workload 全不动。

### 安全论证

- 与增量 5 同构：poll 只推进已授权 stage（JCMK 多数 + publish-proof 是
  准入证据），不是新决策；无门只让既有安全逻辑运行。join-drive 门的
  serving 前置（ordinary_actions_allowed）与 COMMIT 排水无因果关系——
  门的存在只服务于"serving 未就绪不启动新 join"，而 stage 已启动。
- P2（clean-leave 串行）：staging 在 commit_member 首门拒绝 leave 期间
  的 join；pre-bump 已在 prepare 完成（epoch 已动），leave 侧对称拒绝
  在 join 挂起时启动（既有注释契约）。排水不破坏该互斥。
- 发布后 membership 变更仍走 publish 的精确 predecessor/epoch 门，
  幂等重试不变。

### 验收

- t243 L5 restore boot：fence 提交后 publish 立刻执行 → JOIN_COMMITTED
  事件 → GRD join episode (N, empty) → rebind (N, empty) → node1 的
  done0 被 echo/广播盖写 → phase3 收敛 → ok 20/21；L6/L8/L9/L10 全绿。

## 增量 17：owner-rejoin OPEN 分支接受同主更新化身（2026-08-17，修 L10 快速停机重启的 root 永拒）

> **⚠️ 已回退（2026-08-18，DSH 复审补记 13）**：违反 STOP-02 §17.4——
> OWNER_REJOIN 前态必须是 RECOVERY_COMPLETE；OPEN→OPEN 捷径被冻结线禁止；
> 且 recovery_duty.c:387 构造 expected=OPEN 时 patch_shape_valid
> （control_root.c:1516）只收 RECOVERY_COMPLETE/CLOSED → :1702
> INVALID_ARGUMENT，该 OPEN 支路是死代码。回退点 = ce00ff9efd^
> （head gate 恢复 `origin_owner_incarnation != admitted_incarnation`、
> 已满足捷径恢复 `lifecycle == OPEN` 即 return true；单测用例同步删除）。
> 遗留问题（L10 fast-stop 的 serving 过期窗口 root 停在 OPEN）转由
> 增量 13 的裁决路线（B：clean-reopen 改走 STOP-01 THREAD_OPEN）承接。

### 背景事实（run-54 实测证据，2026-08-17 23:59:26-00:00:58）

增量 16 后 t243 跑到 ok 1-33（L1-L10 全过），唯一剩尾腿：L10 的
"fast stop → 重启"（第三次 restore boot）60s bail：

- 23:59:25.548 node1 收 fast shutdown；26.173 clean-leave COMMITTED
  （epoch 11）——**但 leaver 的 serving re-confirm 未达**（55.565
  WARNING "committed but the local serving authority did not re-confirm
  before the barrier deadline"）：L10 停机恰逢 node0 的驱逐 episode
  (11, {1})，leaver 的 serving rebind 被 GRD in-progress 挡住。
- 随后 shutdown checkpoint 的 THREAD_CLEAN_CLOSE 的 CF(X) 因 serving
  过期（S1 只认 serving-current 或 StartupProcess）被拒 → **root 停在
  OPEN（owner=旧化身 840297561279716）而非 CLOSED**。
- 23:59:55.669 L10 重启 boot；join commit 的 owner gate 分解：
  `root=0 lc=1 owner_inc=840297561279716 admitted=840297596318716
  lineage=4 import=0 proven==admitted key=1 crc=1`——claim CRC ✓、
  JCMK majority ✓、同主化身单调（owner_inc < admitted）✓，**唯一不满足
  ：OPEN 分支要求 owner_inc == admitted**（L5 的 close 成功是因为其停机
  恰逢 serving-current 窗口；L10 撞上驱逐窗口——纯时序）。
- 60s 内 owner gate 永拒 → JOIN 不发布 → phase3 barrier 饿死 → bail。

### 合同（增量 17）

1. `cluster_recovery_owner_rejoin_v1` 的 OPEN 分支从 `owner_inc ==
   admitted`（已满足门）扩为 `owner_inc <= admitted`：同主更新化身
   （owner_inc < admitted）走 CAS（expected_lifecycle=OPEN，desired
   OPEN + owner=admitted + lineage+1）；`owner_inc > admitted`（stale
   旧进程）仍 fail-closed。
2. 不变：claim CRC、JCMK majority（proven==admitted）、identity 锚、
   CLOSED 分支、judge/timeout/workload 全不动。

### 安全论证

- OPEN + owner_inc < admitted 只可能是同一节点的新进程：identity 锚
  （root 按 node 查找 + 写一次 claim CRC）与 JCMK majority（持久
  COMMITTED marker + publish-proof 证明 admitted）与 CLOSED 分支完全
  同链；OPEN 字面值只是"THREAD_CLEAN_CLOSE 未跑/被拒"（崩溃或
  serving 过期窗口），不改变信任结构。CAS expected=OPEN 原子，并发
  THREAD_OPEN/他人抢占仍被 CAS 挡住。
- `>` 的 stale 拒绝保留：admitted 比 root owner 还旧时永不重开。

### 验收

- t243 尾腿：L10 重启的 owner gate 走 OPEN CAS → JOIN 发布 → phase3
  收敛 → 全部 33 ok 无 bail。

---

## 增量 18：cluster_regress clean_leave SIGABRT 归因 = stale build artifact（2026-08-18，P0 收尾，无产品代码改动）

### 背景（DSH 交接核验发现，2026-08-18 07:08）

cluster_regress 2/13 红且为崩溃级：`cluster_clean_leave` 的
`SELECT count(*) FROM pg_cluster_clean_leave_state;`（视图/SRF 首查，
单节点 node_id=-1）使 backend SIGABRT（signal 6）；`cluster_node_remove`
为崩溃后服务器 reinitializing（"database system is in recovery mode"）
期间的连带失败。DSH 怀疑面 = 增量 10/12 的 clean-leave FSM 改动。

### 取证（本会话 lldb 实锤，2026-08-18 07:1x）

1. 手工单节点实例（cluster.enabled=on，node_id=-1）稳定复现同一崩溃。
2. lldb attach backend，SIGABRT 栈：

```
frame #3: libsystem_c.dylib`__stack_chk_fail + 96
frame #4: postgres`cluster_get_clean_leave_state + 304   ← 栈 canary 写穿
frame #5: postgres`ExecMakeTableFunctionResult + 788     （SRF 首查）
```

   —— 不是 Assert（全程无 TRAP 消息），是 **栈保护 canary 失败**：函数
   返回时检测到局部缓冲被写穿。
3. 机制：`cluster_clean_leave_views.c` 的局部 `ClusterLeaveState st;`
   由 `cluster_clean_leave_get_state(&st)` 整结构拷贝（`*out = *cl_state`）。
   `cluster_clean_leave_views.o` mtime = 2026-08-16 16:42，早于
   `cluster_clean_leave.h`（2026-08-17 15:55，5861a6c700 加入
   `pg_atomic_uint32 shutdown_driven`，结构体变大）；而
   `cluster_clean_leave.o`（2026-08-17 23:28）是新的。新 .o 的
   `*out = *cl_state` 按新布局拷贝 **更大的结构体** 进 views 栈帧里
   **旧的更小局部** → 写穿 canary → SIGABRT。
4. 同因 stale 对象共 7 个（依赖 cluster_clean_leave.h 且 .o 早于 header）：
   cluster_gcs_block / cluster_clean_leave_policy / cluster_shmem /
   cluster_clean_leave_views / access/transam/xact / tcop/postgres /
   storage/ipc/procsignal。本树 make 无依赖跟踪（无 --enable-depend），
   header 变更不会触发依赖方重编。

### 归因结论

- **根因 = 构建产物陈旧**（stale .o 与 header 结构体尺寸不匹配），
  **不是产品逻辑缺陷**：增量 10/12 的 FSM 改动（cl_leaver_reincarnated /
  survivor 释放条件）与崩溃无因果；崩溃路径在 FSM 之外（纯观测 SRF）。
- 佐证：① 单测 test_cluster_clean_leave 11/11 绿（单测二进制自当前源码
  编译，无 stale）；② 后端全量 clean rebuild 后同一查询返回正确结果
  （count=1，phase=idle，leaving_node_id=-1，leave_epoch=0），与
  expected/cluster_clean_leave.out 逐字一致。

### 处置（最小修复，无产品代码改动）

1. `src/backend` 全量 `make clean && make -j8`（消灭全部 stale 对象，
   含上述 7 个 + 其它潜在 stale），重新链接 postgres。
2. cluster_regress 全量复跑（预期 13/13 绿，cluster_node_remove 连带
   转绿）。
3. 验收：cluster_regress 绿 + test_cluster_clean_leave 单测绿 +
   t243 复跑（构建面变化可能影响任何路径，需 1 轮全绿确认）。

### 预防记录

- 本树增量构建无 header 依赖跟踪：今后凡改动 include 下的结构体/头文件，
  必须先全量重建再跑批；发现诡异 SIGABRT/栈破坏时先查 .o 与 .c/.h 的
  mtime 错位（本次教训）。

---

## 增量 18 补记：P1 TEMP 清理暴露 test 55 的掩盖性诊断块（2026-08-18）

### 发现（清理过程的副产品）

P1 清理时删除 test_cluster_reconfig.c 的 "TEMP DIAGNOSTIC (RF-ROOT P6
increment 9)" printf 块后，`test_fast_rejoin_control_episode_lms_generation_
loss_fails_closed`（test 55）转红。git 追溯实锤（921cab5ee5 提交说明原文：
"reconfig suite now builds and runs (**5** pre-existing increment-5-8
staleness failures + 5 pre-existing R4-model failures remain)"）：

- test 55 本就是第 5 个 pre-existing staleness 失败；同一提交加入的诊断块
  内含 `ut_join_qvotec_poll_write_pending()` **消费调用**（poll 即取走
  pending 写入），使随后的 `UT_ASSERT(!poll)` 恒真 —— 诊断块掩盖了失败，
  后续 P6 文档（P6-RESUME v5 / DSH 补记 8.4）只记录了 4 个（75/76/77/92）。
- 掩盖机制（代码级）：fixture `ut_fast_rejoin_to_join_pending()` 最后一轮
  tick（gen=1、serving=ready、capability armed）中 drive_joins phase-2 已把
  JOIN_COMMITTED marker **staged + submitted**（增量 5/16 的无门排水语义，
  该 marker 是 majority-durable 决策）；test 55 设 gen=2 后 capability 被
  快照门清除（快照 gen 不匹配 → invalid → clear），但已 staged 的 commit
  由无门排水继续完成 —— 断言"gen 变化后不得有 pending"在增量 5/16 语义下
  过期。

### 处置（测试同步，产品代码零改动）

- test 55 重写为当前语义并保留 fail-closed 意图：
  1. gen=2 后：已 staged 的 COMMITTED marker 仍 pending（capability 清除，
     不再新 arm；joiner 保持 JOINING，未发布任何事件——无 stale 证据提交）；
  2. 完成 marker（majority ACK）→ JOIN_COMMITTED 发布、node1 MEMBER；
  3. gen 恢复 1：capability 不复活——新引入的 eligible peer（node2 DEAD+
     fresh slot）不被纳入任何 episode（无新 JOIN_PENDING，node2 保持 DEAD）。
- 副作用修正：诊断块遗留的未 ACK pending marker 泄漏污染了后续 test
  75/76（join-commit marker submit 桩时序）——重写后泄漏消除，75/76 转绿。
  reconfig 套件从文档化的 4 失败（75/76/77/92）降为 2（77/92 保持
  pre-existing：marker submit 桩时序 + external-rejoin epoch 期望，与
  P6-RESUME §4 记录一致，留给后续）。

---

## 增量 19：端到端 lifecycle 测试方案（2026-08-18，DSH 补记 13-C 设计稿，代码待 B 裁决后落）

### 需求（补记 13-C 原文）

"补一条不打桩的测试：真实 shmem 控制根 + 真实 compare_and_publish 路径，
断言 ① OWNER_REJOIN 前态 RECOVERY_COMPLETE 成功；② 前态 OPEN/CLOSED 的
OWNER_REJOIN 被 patch_shape_valid 拒绝（冻结行为）；③ THREAD_OPEN 的
CLOSED→OPEN 成功。放 test_cluster_control_root 或 recovery_duty 集成段。"

### 现状调研（2026-08-18）

- test_cluster_control_root.c 已具备真实文件根 + 真实
  `cluster_control_root_compare_and_publish` 的骨架：`wipe_root_files()`
  → `create_prepared`（真实 create_prepared API）→ `read_canonical`
  （真实 STRONG 读）→ `compare_and_publish`（真实 CAS 发布），仅存储
  钩子（CF/WALR/rename）为 stub。已有 test_lifecycle_publish_exact_
  token_cas（CLOSED→RETIRED）、test_owner_rejoin_advances_exact_lineage
  _and_exhausts_at_max、test_retention_expanding_publish_* 等先例。
- patch_shape_valid（control_root.c:1501-1551）冻结形状：
  - OWNER_REJOIN：expected ∈ {RECOVERY_COMPLETE, CLOSED（增量 13 偏离，
    裁决中）} → desired OPEN + owner>0 + lineage>0；
  - THREAD_CLEAN_CLOSE：OPEN→CLOSED；
  - THREAD_OPEN：CLOSED→OPEN + owner>0 + lineage>0。
  - **expected=OPEN 的 OWNER_REJOIN 一律 INVALID**（补记 10.1.2 的
    死代码点：recovery_duty 增量 17 构造的 expected=OPEN 在此被拒）。

### 测试设计（新增 1 个 UT_TEST，放 test_cluster_control_root.c）

`test_lifecycle_frozen_shape_matrix`（或分 3 个）：

1. **① OWNER_REJOIN 前态 RECOVERY_COMPLETE → OK**：build_migration 置
   lifecycle=RECOVERY_COMPLETE → create_prepared → read_canonical →
   build_owner_rejoin_patch（owner=+1、lineage+1）→
   compare_and_publish(PUBLISH_OWNER_REJOIN) == OK_PRIMARY，published
   lifecycle=OPEN、lineage+1、publish_seq+1。
2. **② 前态 OPEN 的 OWNER_REJOIN → INVALID_ARGUMENT**：同样流程但
   lifecycle=OPEN → owner-rejoin patch（expected=OPEN）→
   compare_and_publish 返回 INVALID_ARGUMENT，文件未动
   （root_publish_seq 不变、read_canonical 复读仍 OPEN）。
   （② 的 CLOSED 半例：当前增量 13 允许 CLOSED，测试在 B 裁决落地
   （摘除 CLOSED）后追加"CLOSED OWNER_REJOIN → INVALID_ARGUMENT"；
   若裁决保留 CLOSED，则改为断言 CLOSED 分支行为并删本半例。）
3. **③ THREAD_OPEN CLOSED→OPEN → OK**：lifecycle=CLOSED（用
   THREAD_CLEAN_CLOSE 发布或 build_migration 直接置 CLOSED）→
   read_canonical → THREAD_OPEN patch（expected=CLOSED、desired OPEN、
   owner=admitted 新化身、lineage+1）→ compare_and_publish
   (PUBLISH_THREAD_OPEN) == OK_PRIMARY。

### 验收

- 本测试**不打桩 compare_and_publish / patch_shape_valid**（区别于
  recovery_duty 单测的 ut_root_publish_calls mock，补记 10.1.5）。
- ①/②(OPEN)/③ 在 B 裁决前即可绿（均冻结行为）；②(CLOSED) 随 B 落地。
- 提交节奏：随 B 裁决一起落（避免与裁决冲突的双写）。

---

## 增量 20：THREAD_OPEN 执行者接通（2026-08-18，补记 13-B 裁决 = 按 DSH 倾向执行）

### 裁决（用户 2026-08-18）

clean-reopen 改走 STOP-01 冻结主线 THREAD_OPEN（CLOSED→OPEN）：
① 先实现 THREAD_OPEN 路由接通 L10 场景 → ② t243 33/33 复证 →
③ 再摘除 OWNER_REJOIN 的 CLOSED 允许（每步单独提交）。

### 现状证据（2026-08-18 回退后 t243 run，post-revert 二进制 33/33）

1. `cluster_control_root_thread_open_publish`（recovery_duty.c:506）已存在：
   CLOSED→OPEN + owner=boot_incarnation + lineage+1 + 0x3b mask，冻结形状。
2. 唯一调用点 = startup_phase.c:1594（phase-3 bind 循环，postmaster 上下文），
   但 S1 准入（cluster_lock_acquire.c:216 注释原文）"The phase-3 THREAD_OPEN
   retry therefore fails closed here (r=10)；the root reopen needs a PGPROC
   executor (deferred to the L5 leg work)"——postmaster 无 PGPROC，AD-023 §4
   冻结 StartupProcess-only（555890d2df 回退史，postmaster CF call count=0）。
3. 回退后 t243 全 run **无一条 "reopened by owner"（THREAD_OPEN 成功 LOG）**，
   但 L5/L10 全绿 → 实际重开 = join 链协调者的 OWNER_REJOIN+CLOSED
   （增量 13 的 CAS）。
4. 时序：joiner StartupXLOG 在 phase-3 之后、phase-4 之前；survivor join
   commit 的重 vet 在 commit 时（可早于 joiner phase-4，增量 16 无门排水）。

### 设计（修正版，2026-08-18 实证后定稿）

**阴性结果（StartupXLOG 执行者方案，已废弃）**：THREAD_OPEN 移入
StartupXLOG 与 ③（摘除 CLOSED）组合实测 t243 bail（pg_ctl start failed，
L5 restore boot 卡 phase-3 60s）：startup 进程在 phase-3 **之后**才 fork，
而 phase-3 barrier 依赖 survivor 的 join commit，commit 的 re-vet 又需要
root OPEN —— 循环死锁（增量 16 同构）。postmaster phase-3 driver 无
PGPROC（S1 r=10，AD-023 §4 冻结），不能执行。

**终态设计（commit 时点 THREAD_OPEN 路由）**：

- `cluster_recovery_owner_rejoin_v1`（commit 时点 re-vet，协调者执行）：
  head gate 允许 CLOSED，但 CLOSED 分支走 **THREAD_OPEN reason** 的冻结
  形状（expected CLOSED → desired OPEN + owner=admitted + lineage+1，
  0x3b mask）；RECOVERY_COMPLETE 分支保持 OWNER_REJOIN（冻结 §17.4）。
  协调者持完整 proof 集（write-once claim CRC + durable JCMK majority +
  单调更新化身）——与既有 crash-rejoin 主线的 authority 模式一致；
  时序与 P6 已验证的 OWNER_REJOIN+CLOSED 完全相同（commit 时点重开），
  仅 reason/形状归位到冻结 THREAD_OPEN。
- control_root patch_shape_valid：OWNER_REJOIN 严格 RECOVERY_COMPLETE-only
  （③，已完成）；THREAD_OPEN 严格 CLOSED→OPEN（冻结，未动）。
- phase-3 的 postmaster THREAD_OPEN 调用点移除（死代码，r=10 空转）。

**证据**：t243 33/33 PASS（修正版，含 L5/L10 clean-reopen 全腿）；
recovery_duty 18/18（CLOSED→THREAD_OPEN 路由断言：reason 捕获 =
PUBLISH_THREAD_OPEN、expected CLOSED、owner=admitted、lineage+1）。

- L10 serving-stale 变体（clean-close 被拒 → root 停 OPEN(old)）：THREAD_OPEN
  不匹配 CLOSED，仍由冻结 FSM（survivor-driven recovery）承接；该变体
  概率由 fence-deferral（94791471d5）+ leaver serving-rebind（run130/131）
  已压低，残留以 t243 多轮取证评估。

### 验收

- t243 33/33（THREAD_OPEN 独担 clean-reopen）✓ 已达成；
- recovery_duty 18/18（CLOSED 路由断言）✓ 已达成；
- C 测试（增量 19）落地：RECOVERY_COMPLETE OWNER_REJOIN 成功 /
  OPEN 与 CLOSED 的 OWNER_REJOIN INVALID_ARGUMENT / THREAD_OPEN CLOSED→OPEN 成功。

---

## 增量 20 补记：执行者范围结论（AD-023 §4 引用，DSH 复审补记 17 验证点 1）

**结论：协调者 LMON 在 join-commit re-vet 执行 THREAD_OPEN CAS 落在 §4
冻结范围内，不构成偏离。**

- AD-023 §4 原文（~/pgrac/docs/ad-023-rfroot-p04-recovery-authority-
  serving-split.md:71-96）的 StartupProcess-only allowlist 约束对象 =
  **恢复期**（phase3、serving 未立）的 recovery access：caller 必须
  StartupProcess + phase3 + exact generation + 资源恰为 CF(0xF1/S) 或
  WALR(0xFA/X)。
- §4 同文界定 serving 期准入："ordinary egress/peer selection 与 local
  ingress/grant/serve 都必须校验 current-generation SERVING_READY。恢复
  allowlist 不是 ordinary service 的替代入口。"
- 本路由的执行点 = join-commit re-vet（协调者 LMON，有 PGPROC）；此刻
  **集群处于 serving 阶段**（survivor 的 serving binding current），CF(S)
  走 cluster_lock_acquire.c:196-207 的 serving 分支（exact-LMS 谓词），
  **不经恢复 allowlist**。与冻结 crash-rejoin 主线的 OWNER_REJOIN CAS
  （协调者同角色、同锁路径，P4/P5 起 t243 全绿）完全一致。
- cluster_lock_acquire.c:216 注记 "the root reopen needs a PGPROC executor
  (deferred to the L5 leg work)" = 本路由正是该注记指向的执行者（LMON 有
  PGPROC）；postmaster（无 PGPROC）仍被排除（r=10 fail-closed 保持）。
- 验收日志：CLOSED→THREAD_OPEN 成功发布新增 LOG
  "clean-reopened by node %d (THREAD_OPEN, owner ..., lineage ...)"，
  供 t243 "reopened by owner" 型证据取证。

---

## 增量 21：L10 serving-stale 变体的两段冻结 CAS 修复（2026-08-18）

### 复现（t243 final run 09:39:12，THREAD_OPEN 路由首轮即命中）

L10 末次 fast-stop：`cluster clean-leave: committed but the local serving
authority did not re-confirm before the barrier deadline; proceeding with
the shutdown checkpoint`（09:39:12.588）→ 该 run **无 "clean-closed by
owner"**（THREAD_CLEAN_CLOSE 的 CF(X) 被 S1 serving-stale 拒，fail-closed
跳过）→ root 停 OPEN(owner=旧化身 840332317297894) → 重启 phase-3：
"clean reopen detected" 后 join commit 的 owner-rejoin OPEN 分支
（owner != admitted）永拒 → phase-3 barrier 饿死 → 60s bail（node0 被判
DEAD）。= run-54 的 pre-increment-17 楔子，原由增量 17（已回退，§17.4
违规）覆盖；THREAD_OPEN 只认 CLOSED、OWNER_REJOIN 只认 RECOVERY_COMPLETE，
两者均不覆盖 OPEN(old) —— 冻结系统对该状态无路径。

### 设计（仅冻结 CAS 形状，无新捷径）

commit 时点 re-vet（owner_rejoin_v1）新增分支：**OPEN + owner < admitted
+ clean-departed 证据**（cluster_reconfig_is_clean_departed(node_id)，
durable CLEAN_LEAVE marker 的运行时面）= 上次 clean-close 被拒的漏关：

1. CAS1 = THREAD_CLEAN_CLOSE（冻结 0x39 形状：OPEN→CLOSED，owner lineage
   不变，checkpoint/tail/progress 取自当前 snapshot——即上次 shutdown
   checkpoint 的 durable 数据）；
2. CAS2 = THREAD_OPEN（冻结 0x3b 形状：CLOSED→OPEN，owner=admitted，
   lineage+1）——复用既有 CLOSED 路由。

非 clean-departed 的 OPEN+owner<admitted（crash 链 commit 抢跑）保持拒绝
（fail-closed，FSM 会先写 RECOVERY_COMPLETE）。执行者范围同增量 20 补记
（serving 期协调者，AD-023 §4 结论引用成立）；两段 CAS 均原子，中间态
CLOSED 无并发执行者（phase-3 postmaster 已拆除、startup 死锁方案已废弃）。

### 验收

- t243 33/33 多轮（含 L10 变体轮）；日志同时出现 "clean-reopened by node"
  与（变体轮）"clean-closed"→"clean-reopened" 对；
- recovery_duty 18/18（新增 repair 用例：OPEN(old)+clean-departed →
  close→open 两段发布、reason 断言）。

---

## 增量 21 补记：DSH 复审补记 18 的 CLOSED 分支拆分（2026-08-18，照办 + 验证记录）

### DSH 指令

head gate 的 non-OPEN 分支按 lifecycle 拆分：RECOVERY_COMPLETE 保持
`owner >= admitted` 拒绝；CLOSED 分支不用 `owner >= admitted` 拒
（fresh boot 化身更新是 THREAD_OPEN 主线语义），放行后由 CAS 单调性兜底。

### 验证结论（照办已实施，附证据）

1. **实际 09:39 失败形态 = OPEN(old) 变体**（非 CLOSED 路由不可达）：该
   run 无 "clean-closed by owner" 日志 + "serving authority did not
   re-confirm" 警告 → clean-close 被拒 → root 停 OPEN(旧化身) → 重启后
   OPEN 分支 owner!=admitted 永拒。已由增量 21（两段冻结 CAS 修复）解决，
   修复后 t243 33/33 ×4 连绿。
2. **CLOSED 路由在 09:39 run 前已工作**（t243-inc20c：33/33 + 三条
   "clean-reopened by node (THREAD_OPEN)" 日志，lineage 3/4/5）——fresh
   boot（I2>I1）本就能过原 head gate（`I1 >= I2` 为假不拒绝）；补记 18
   中 "I1>=I2 为假 → gate 拒绝" 的因果方向与代码不符。
3. **拆分语义等价**：control_root.c:1743-1752 的 CAS 单调性要求
   `desired.owner > current.owner`（严格）+ `lineage+1`——同化身
   （admitted==owner，fast-restart 窗口）与陈旧化身（admitted<owner）在
   CAS 层同样 fail-closed；head gate 仅剩 lineage==MAX 拒绝（快失败）。
   行为面：CLOSED+owner>=admitted 从 head gate 拒绝变为 CAS 拒绝（多一轮
   CF(S)+文件 I/O，判定不变）；收敛性由 qvotec prior-incarnation 4s
   age-out + join 重试（53R61 30s+ 余量）保证。
4. 按 DSH 指令实施拆分（RECOVERY_COMPLETE 分支原样保留；CLOSED 分支只留
   lineage==MAX 拒绝），t243 复跑确认无回归。

---

## 增量 22：P7 审计结论与增量计划（2026-08-18，子代理静态审计 + 本会话复核）

### 审计结论（对冻结 spec §17.7/§17.9 逐条对照）

**已退休（前序 stage 完成）**：
- 两个 W6 writer pwrite-free：冷路径（xlogrecovery merged-replay 出口只写
  node-local authority `DataDir/pg_undo/instance_N/merged.authority`，
  :2963-2976）；online orchestrator（:428 调 node-local 在线变体）。全后端
  `merge_recovered_lsn` 写路径仅清零（cluster_wal_state.c:571 与 header
  :418/:439），无任何非零写。
- W1-W5 与 spec 表一致：W2 清 merge_recovered_lsn；W4/W5/W3 preserve。
- forged 非零 merge_recovered_lsn 无任何 skip-bound 使用（xlogrecovery
  :2477 raw_ignored LOG = telemetry；control_root.c:1113 迁移校验拒绝）。

**缺口（G1-G6，本增量实施）**：
- **G1（核心）六处 correctness reader 仍读 registry 作 correctness 源**：
  - cluster_recovery_merge.c:990-1002（checkpoint_redo_lsn/fpw_was_off →
    合并起点，skip-bound 权威）、:1624-1626（highest_lsn → validated_min）；
  - cluster_thread_recovery_orchestrator.c:582-593（checkpoint_redo_lsn/
    highest_lsn → online 窗口 lower/validated_min）；
  - cluster_recovery_plan.c:203-222（highest_lsn/highest_scn → verdict）；
  - cluster_recovery_worker.c:192-194/:247-254（highest_lsn/tli → 流校验）；
  - cluster_hw_remaster.c:477-485（highest_lsn → validated_min）。
  迁移目标 = canonical root 的 checkpoint_lower_lsn / validated_tail_lsn_
  exclusive / tail_last_record_lsn / recovered_through_lsn_exclusive /
  FPW flag（`cluster_control_root_read_canonical` STRONG 读 = PAGE/SIDE
  proof 面）。语义映射：root 值由 lifecycle 发布（迁移映像 + clean-close/
  reopen 保留）——比 registry 每 checkpoint 刷新更保守（更早），对
  validated_min/merge-start 均安全（起点更早 = 重放更多，绝不跳过已提交
  WAL）；Q5 fail-closed（0 → 53RA3）保持。
- **G2**：spec §17.7 冻结要求追加 update result 枚举 `RELEASE_UNCERTAIN=9`、
  `SOURCE_CLOSED=10`；两个 W6 包装器（冷/在线）在 transition 模式返回
  SOURCE_CLOSED 且零 pwrite（transition 模式由 G3/G5 的 R4 驱动接线触发）。
- **G3**：R4 PREPARE 生产驱动不可达（create_prepared/activate_prepared 无
  生产调用者；cluster_recovery_duty.c:32-53 authority 桩恒 false）。需把
  全成员 ACK（semantic_activation ACK 表 COMPLETE）接线到 round 构造 →
  create_prepared → activate_prepared。
- **G4**：无静态 census 产物。新增 census 脚本/测试：post-bit22 wal-state
  correctness reader/writer == 0（G1 落地后归零）。
- **G5**：bit22 打开门缺失——target_feature_bitmap 含 bit22 由 encode_round/
  decode_image 强制，但"PREPARED/ACTIVE 全成员 ACK 后才 ACTIVE"无生产接线。
- **G6**：cluster_debug.c:2875-2877 注释过时（声称 registry 派生，实际
  node-local marker）；在线路径"不写 merge_recovered_lsn"缺断言。

### 实施顺序（每个可验证子步一次 commit）

1. G2：枚举追加（frozen 字面量）+ 单测断言。
2. G6：debug.c 注释修正 + 在线不写断言。
3. G1：五文件逐一迁移（hw_remaster → recovery_worker/plan → recovery_merge
   两处 → orchestrator），每个配聚焦单测/TAP；registry 仅 telemetry。
4. G4：census 脚本（白名单 == 0）。
5. G3+G5：R4 生产接线 + bit22 ACK 门（最大块，先落设计再实现）。

---

## 增量 22 补记：G1 前置发现（CHECKPOINT_ADVANCE 发布缺失）与 G6 落地

### G1 前置（G1a，2026-08-18 实证）

- `CLUSTER_CONTROL_ROOT_PUBLISH_CHECKPOINT_ADVANCE`（0x38 =
  CHECKPOINT|TAIL|RECOVERY_PROGRESS，spec §17.2 reason 表冻结）在
  cluster_control_root.c 有 reason 掩码与 CAS 分支（:1491/:1661），但
  **全后端无生产调用者**。
- 生产路径（recovery_duty 的 lifecycle CAS：clean-close/reopen/repair）只
  **保留** snapshot 的 checkpoint/tail 字段，不写新值 → root 的
  checkpoint_lower_lsn / validated_tail_lsn_exclusive 仅来自迁移映像。
- 因此 G1b（六 reader 迁到 canonical root）若直接落地，reader 的
  merge-start/validated_min 会退化为迁移时值（更早 = 安全但重放面大），
  且违背"root 是 canonical checkpoint 权威"的 STOP-01 前提。
- **G1a = 把 per-checkpoint 的 root 发布接上**：checkpointer 的 checkpoint
  路径（CreateCheckPoint 持 CF(X) 的既有面）在 checkpoint durable 后发布
  CHECKPOINT_ADVANCE（0x38：checkpoint_lower_lsn + validated tail +
  recovery progress，owner lineage 不动）——执行者/锁序沿用
  THREAD_CLEAN_CLOSE 先例（checkpointer 的 CF(S) 合法窗口），冻结形状
  patch_shape_valid 已就绪。G1a 落地 + t243 复绿后，G1b 逐 site 迁移。

### G6 落地（本增量）

- cluster_debug.c:2873-2876 注释修正：materialized_remote_instances 派生自
  node-local merged authority（非 registry；registry 仅 telemetry）✓。
- 在线路径"不写 merge_recovered_lsn"断言：随 G2/G3 的 SOURCE_CLOSED
  包装器接线（transition 模式零 pwrite）一并落地（t/248 或 orchestrator
  单测），本增量登记。

---

## 增量 22 补记 2：G1b 锁序发现（2026-08-18，hw_remaster 迁移实证）

### 事实

- G1a（CHECKPOINT_ADVANCE，checkpointer 上下文）CF(S) 获取成功；但把
  hw_remaster 的 validated_min 源迁到 canonical root（STRONG 读需 CF(S)）
  后，L4 crash-rejoin 的 hw-remaster worker 全部 CF(S) 失败
  （LOCK_UNAVAILABLE=17，16 次重试全败 → t243 bail at ok 2）。
- 机制：recovery-episode 的 CF(X) 持锁（幸存者自己的控制文件写面）与
  CF(S) 同资源（0xF1）互斥；hw worker 的 S 请求在 episode 窗口内被自身
  的 X 持锁挡住（有界等待超时）。registry 读（W1 面）无 CF 依赖，旧路径
  工作正常。
- 结论：G1b 的 reader 迁移不能简单替换读源——每个 site 的上下文必须能
  满足 canonical STRONG 读的 CF(S) 准入/锁序（checkpointer/coordinator
  上下文可行；episode 内 worker 上下文不可行）。需要锁序设计评审
  （CF(S) 与 episode CF(X) 的窗口调度，或按 site 分阶段迁移）。
- 处置：hw_remaster 回退到 registry 源（注释标注 G1b 挂起 + 原因）；
  G1a（checkpoint 发布）保留（正确且独立验证）。G1b 剩余迁移待 DSH/
  设计评审后按锁序可行的上下文逐个落地。

---

## 增量 21 补记 3：按用户裁决移除（2026-08-18，路线 1 取代）

用户裁决（DSH 复审补记 21）：增量 21 的 coordinator 补写（两段 CAS
THREAD_CLEAN_CLOSE+THREAD_OPEN）违反发布者冻结合同（补记 20 P0）——CLOSED
必须由 OWNER（checkpointer）自己发布。路线 1（治本）：checkpointer 的
THREAD_CLEAN_CLOSE 有界重试（重绑 leaver serving authority + 50ms 退避 +
5s 硬 deadline；超限 LOG 继续停机，root 停 OPEN(old) fail-closed）。
实施：579fdde166（retry wrapper + checkpointer 接线 + owner_rejoin_v1 恢复
冻结 OPEN 门 + 增量 21 补写/LOG/特例全删 + 单测 22/22）。验收：t243 33/33
bail=0 + L5/L6/L10 "clean-closed by owner" ×3 + 无补写路径 + regress 13/13。

---

## 增量 22 补记 4：G1b 锁序设计分析（2026-08-18，按 site 上下文分阶段）

### 原则（STOP-05 §5.4 锁序纪律面，DSH 补记 24）

canonical STRONG 读需要 CF(S)（0xF1 同资源）；recovery-episode 的 CF(X)
持锁与其互斥。按 site 的执行上下文分类：

| Site | 执行上下文 | CF(S) 可行性 | 迁移策略 |
|---|---|---|---|
| recovery_merge :990-1002/:1624-1626（engage gate / merge_begin） | startup 进程（冷恢复）| **可行**：StartupProcess 是冻结 CF(S) 执行者（AD-023 §4 恢复 allowlist）| 可直接迁（G1b-A）|
| orchestrator :582-593（online 窗口） | 协调者 LMON（serving 期）| **可行**：serving 准入（与 commit 时点 THREAD_OPEN 同面）| 可直接迁（G1b-B）|
| recovery_worker :192-194/:247-254 + recovery_plan :203-222（verdict） | thread-recovery worker（episode 内）| **需验证**：worker 若在 episode CF(X) 窗口内跑 → LOCK_UNAVAILABLE（hw_remaster 同型）| 先落探针取证，再定（G1b-C）|
| hw_remaster :477-485 | hw-remaster bgworker（episode 内）| **不可行**（已实测 16× LOCK_UNAVAILABLE）| 保留 registry 读 + 显式降级登记（现状）|

### G1b-A/B 语义映射（registry → canonical root 字段）

- checkpoint_redo_lsn（合并起点 Q5）→ root.checkpoint_lower_lsn（G1a 后
  每 checkpoint 刷新；起点更早 = 重放更多，绝不跳已提交 WAL，安全）；
- fpw_was_off（53RA3 门）→ root.FLAG_FPW_WAS_OFF（需先接 FPW_STICKY
  root 发布——现状无生产调用者，与 G1a 同型的新增接线，列为 G1a-2）；
- highest_lsn（validated_min）→ root.validated_tail_lsn_exclusive（G1a
  后随 checkpoint 推进；validated 语义强于 written，fail-closed 更严）；
- highest_scn（plan verdict 新鲜度）→ root 无 SCN 值字段（仅 bit21
  conservative 面）——recovery_plan 的 SCN 维度需保留 registry 读
  （telemetry 化登记）或等 CONSERVATIVE_BOUND 接线（列为独立增量）。

### 实施顺序（DSH 复审路线 1 后）

1. G1b-A（recovery_merge 两处，startup 上下文）：迁移 + 聚焦单测
   （merge engage gate 的 root 读注入）+ t243 L4/L5 复验；
2. G1a-2（FPW_STICKY root 发布接线，checkpointer 同型）；
3. G1b-B（orchestrator 窗口）：迁移 + t243 L4 online 腿复验；
4. G1b-C（worker/plan）：先探针取证 episode 窗口 CF(S) 可行性，可行则迁，
   不可行则按 hw_remaster 模式显式降级登记；
5. G4 census 脚本（G1b 完成后归零）+ G3/G5（R4 接线 + bit22 ACK 门）。

---

## 增量 22 补记 5：G1b 边界收敛 + G4 census 落地（2026-08-18）

### G1b 实施结果（按上下文实证）

- **G1b-A 完成**（c79c078221）：recovery_merge engage gate + merge_begin
  迁 canonical root（startup 上下文，CF(S) 合法；:1366 同窗 root 读先例）。
  等价格式：root.checkpoint_lower_lsn（G1a 刷新）→ 合并起点；
  root.FLAG_FPW_WAS_OFF（G1a-2 刷新）→ 53RA3 门；root.validated_tail →
  validated_min（VALIDATED 界强于 registry 写位置界；间隔窗口由扫描自身
  记录 framing 兜底）。t243 33/33 ×2。
- **B4（plan 生成）**：上下文 = startup（可迁），但 (a) verdict 分类的
  语义映射（registry state+last_updated → root lifecycle+published_at）
  非恒等；(b) **SCN 维度无 root 等价字段**（root 仅 bit21 conservative
  下界，非 highest_scn）→ 需 spec 级决策，暂留 registry（降级登记）。
- **B5/B6/hw_remaster**：窗口推导实测在 thread-recovery worker（episode
  上下文）——与 hw_remaster 同型 CF(S) 不可行 → 保留 registry +
  显式降级登记，待 R4 时代（G3/G5）的 CF(S)/episode CF(X) 窗口调度。

### G4 census 落地（scripts/ci/check-wal-state-correctness-census.sh）

- 枚举生产 registry read/update 调用点 vs telemetry 白名单；5 个
  known-deferred 站点（plan/worker×2/hw_remaster/orchestrator）显式登记。
- **strict 模式 = bit22 打开强制门**：当前 RED（5 deferred）→ G5 的
  bit22 打开被 census 拦住（fail-closed 正确方向）；deferred 站点全部
  关闭后转 GREEN 才允许 R4 迁移轮打开 bit22。

---

## 增量 23：G3/G5 设计 —— R4 生产 cutover 驱动 + bit22 ACK 门（2026-08-18，设计稿）

### 现状（审计 + 本会话复核）

- ACK 机制已就绪：semantic_activation.c:1202-1226 的 ACK 表消费（两阶段
  SAMPLE→EXPECTED_VALID→全成员 COMPLETE，含成员位图与 full-table 校验）；
- create/activate 库层已就绪：cluster_control_root.c:1335/1424 +
  encode_round（:933 强制 target 含 bit22、禁 bit24）+ decode_image（:623）；
- **生产驱动缺失**：cluster_recovery_duty.c:43-61 的 create/activate
  authority 桩恒返 false（注释明言 "The R4 OPEN cutover batch will
  replace this refusal with an exact, one-shot coordinator proof"）；
  ACK COMPLETE 无人消费；bit22 仅在单测设置。

### 设计（R4 cutover 批次，operator 驱动）

1. **operator 入口**：utility 激活记录路径（semantic_activation 的
   utility mailbox）接收 cutover 请求（source/target feature bitmap 含
   bit22、round 参数）——阶段 ACK 广播（SAMPLE→PREPARED）。
2. **协调者 proof（替换 recovery_duty.c:43-61 桩）**：
   `cluster_control_root_create_authority_current_v1` 的新实现 = 一次性
   coordinator proof：本进程持有 ACK 表 COMPLETE（observed==expected 全
   成员位图）+ round 的 exact 副本 + 迁移映像 digest；通过后
   create_prepared 落地 PREPARED。**fail-closed**：非协调者 / ACK 未
   COMPLETE / round 不匹配 / census RED 一律拒绝。
3. **全成员 CLOSED ACK 绑定**（W6 条款 3）：PREPARED 后收集各成员对
   迁移映像的 CLOSED ACK（observed==expected 的 PREPARED 阶段 ACK 即
   CLOSED 事实绑定：每个成员的 merge_recovered_lsn==0 + 非 STOPPED 源拒
   已在 read_source_wal_state:1113 层强制）；全成员 ACK 后协调者调
   `activate_prepared`（ACTIVE = bit22 打开）。
4. **census 强制门**：activate 前运行
   scripts/ci/check-wal-state-correctness-census.sh（strict）——RED 时
   activate 拒绝（fail-closed；deferred 站点关闭前 bit22 不可打开）。
   运行时对应：激活驱动的代码面同时断言 census 白名单（或依赖 CI 门 +
   测试面双保险）。
5. **deferred 站点关闭**（census 转 GREEN 的前置，按增量 22 补记 4/5）：
   B4 的 SCN 维度 spec 决策 + B5/B6/hw_remaster 的 episode 窗口 CF(S)
   调度（或按冻结语义降级为 node-local authority——与 merged.authority
   同型，独立设计评审）。

### 验收

- 单测：create/activate authority 的协调者 proof（ACK COMPLETE 注入 /
  非协调者拒 / census RED 拒 / round 不匹配拒）；
- TAP：R4 cutover 全成员 ACK → PREPARED → CLOSED ACK → ACTIVE(bit22)
  全链 + census 门拦截用例；
- 静态：census strict 模式随 deferred 关闭逐步转 GREEN。

### 实施顺序（每步提交 + 等复审）

1. create authority proof + 单测（census 门先以脚本为证）；
2. ACK COMPLETE 消费接线（coordinator 侧 R4 驱动）；
3. activate + bit22 门 + census 集成；
4. deferred 站点关闭（B4 SCN 决策 → B5/B6/hw_remaster 调度设计）。

---

## 增量 24：G3 step 2-3 实施记录 —— activate proof + stage 绑定 + census 运行时门（2026-08-18，实施随 补记 28）

### 决策（实现时定稿）

1. **activate authority 签名携带 round**：`cluster_control_root_activate_authority_current_v1`
   增加 `const ClusterControlRootMigrationRoundV1 *round` 参数（private seam + 公开
   `cluster_control_root_activate_prepared` 同步加参）。理由：activate proof 需要
   round 身份字段做 ACK 绑定（epoch/generation/成员位图/bitmaps/digest），token+sha
   无法还原这些字段；fail-closed 语义要求 round 精确副本。
2. **ACK accessor 增加 minimum_stage**：`cluster_semantic_activation_ack_complete_matches`
   增加 `ClusterSemanticActivationAckStage minimum_stage`。create proof 传 SAMPLE
   （SAMPLE-round COMPLETE 即可落地 PREPARED）；activate proof 传 PREPARED
   （W6 条款 3：只有 PREPARED 阶段全成员 ACK 才是开 bit22 的 CLOSED 绑定）。
   非法 min_stage（< SAMPLE 或 > OPEN_APPLIED）fail-closed。
3. **census 运行时门**（补记 28 硬性要求："把该门做成运行时调用而非仅文档承诺"）：
   - `cluster_wal_state.c` 新增静态表 `cluster_wal_state_census_deferred_sites[]`
     （当前 4 个 deferred 站点 basename），运行时函数
     `cluster_wal_state_correctness_census_ok()` = 表首项为 NULL 才 GREEN。
   - activate authority proof 调用它并 fail-closed；deferred 站点关闭（G1b step 4）
     时同 commit 从 C 表和脚本 DEFERRED 双删。
   - 脚本 `check-wal-state-correctness-census.sh` 增加 lockstep 交叉校验：C 表
     basename 集合 == 脚本 DEFERRED basename 集合，漂移即 VIOLATION。
   - 选型理由：presence-based（代码面存在即 RED）而非 liveness-based（进程注册
     会因 bgworker 未拉起而 fail-open），与静态 census 语义一致；单测在
     test_cluster_wal_state_rmw 断言当前 RED（G1b step 4 关闭最后一个站点时同
     commit 翻转 GREEN 断言）。
4. **activate proof 四重 fail-closed**：非协调者 fail-fast（ACK/census 零读取）/
   ACK 未 COMPLETE 或 stage < PREPARED / round target 缺 bit22 或含未知位 /
   census RED。

### 单测覆盖（补记 27/28 边界要求）

- recovery_duty `test_activate_authority_requires_complete_ack_round_census`：
  census RED 拒（ACK 零读取）、PREPARED stage 断言、ACK 不 COMPLETE 拒、
  非协调者 fail-fast、bit22 缺失拒、未知位拒、NULL round/sha 拒。
- r4_activation_fsm `test_g3_ack_complete_matches_round_binding` 扩展：stage
  PREPARED 满足 SAMPLE/PREPARED 两种 min；SAMPLE stage 下 min=PREPARED 拒；
  min_stage 非法拒。
- wal_state_rmw `test_g4_census_gate_red_while_deferred_sites_linked`：真实表 RED。
- control_root 既有 activate_prepared 全链（stub 授权）同步新签名。

### 验收

- 单测：recovery_duty 25/25、r4_activation_fsm 174/174（g3 用例内扩展，未新增函数）、wal_state_rmw 13/13、
  control_root 26/26；t243 33/33。
- 静态：census strict 仍 RED（5 violation，按设计）+ lockstep 校验绿。

---

## 增量 25：G1b step 4 设计 —— deferred 站点降级登记（node-local authority 同型）（2026-08-18，设计稿，待 DSH 复审）

### 背景与循环依赖

- 补记 29 定序：关闭 5 个 deferred site → census 转 GREEN → 才是 bit22 可开
  时刻。但增量 23 step 5 原说 B5/B6/hw_remaster "待 R4 时代 CF(S)/episode
  CF(X) 窗口调度"——若调度是 bit22 前置，则调度设计 → bit22 → 调度 成环。
  本增量解环：**按冻结语义降级为 node-local authority（merged.authority
  同型，增量 23 step 5 已预留该路径），而非等待调度**。

### 逐 site 上下文实证（2026-08-18 复核）

| Site | 执行上下文 | CF(S) | 数据依赖 | 判定 |
|---|---|---|---|---|
| recovery_plan.c:203 | **startup**（xlogrecovery.c:1251 调 plan_generate） | 可行 | state/last_updated/node_id（verdict 分类）+ highest_lsn + highest_scn | B4：verdict 语义映射非恒等；**max_highest_scn 无外部消费者**（观测字段，plan.c 内自写自读） |
| recovery_worker.c:192（revalidate） | **startup**（merge project_readonly ← engage ← xlogrecovery.c:2436 链） | 可行 | highest_lsn（构造 target page 写位置）+ tli | **root 无写位置字段**（validated_tail 是 VALIDATED 界 ≠ written watermark）→ 迁移会改变验证语义 |
| recovery_worker.c:247（worker_main） | episode bgworker | 不可行 | 同 :192 + classify | hw_remaster 同型（LOCK_UNAVAILABLE 实证） |
| orchestrator.c:572（replay_one） | thread-recovery bgworker（worker.c:209 调用） | 不可行 | checkpoint_redo_lsn（lower）+ highest_lsn（validated_min） | 同上 |
| hw_remaster.c:487 | hw-remaster bgworker | 不可行（实测 16×） | highest_lsn（validated_min） | 同上 |

### 设计（降级登记 = 语义重新分类，非放行正确性读）

1. **类别定义**：新增 census 白名单类别 `NODE_LOCAL_AUTHORITY`——该读的
   权威面是 **node-local 重建/验证决策**（merged.authority 同型：
   cluster_merged_instance_is_materialized 即 node-local 标记驱动 reader
   gate），**不授予 cluster-wide 权威**；每次读失败仍 fail-closed
   （BLOCKED/UNREADABLE → 冻结，不静默降级）。因此不属于 "cluster-wide
   correctness reader"，bit22 打开后允许存在。
2. **判定**：5 个站点全部落入该类别（B4 plan 的 SCN 维度裁为观测——
   max_highest_scn 无消费者；verdict 分类保留 registry state+last_updated
   语义，不映射 root lifecycle——映射非恒等，强行迁移反而引入新语义风险）。
   worker.c:192/orchestrator:572/hw_remaster:487 数据依赖含 registry 独有
   字段（写位置/checkpoint_redo/highest），root 无等价字段，迁移即语义变更。
3. **census 落地**：脚本 DEFERRED 数组改为登记类别（每行标注 node-local
   authority + 理由注释）；strict 模式对 NODE_LOCAL_AUTHORITY 站点**不计数**
   （显式登记，非隐藏）；C 表 lockstep 同步（cluster_wal_state.c 表同样
   拆分：deferred 空 + node_local_authority 5 项）。**GREEN 条件 =
   DEFERRED 空 且 NODE_LOCAL_AUTHORITY 表与脚本一致**（漂移仍 VIOLATION）。
4. **运行时门**：cluster_wal_state_correctness_census_ok 语义不变（bit22
   打开时 DEFERRED 必须空；node-local 站点存在不阻塞）。activate proof
   不变。新增测试：census_ok 在 DEFERRED 空 + node-local 表非空时 = GREEN。
5. **后续**：R4 时代若 CF(S)/episode CF(X) 调度落地，可把站点逐个迁回
   canonical root（届时从 NODE_LOCAL_AUTHORITY 表移除 = 更严，安全方向）。

### 验收

- 单测：wal_state_rmw census 测试扩展（GREEN 判定 + 表 lockstep）；
  recovery_duty/activate 不变（运行时门语义不变）。
- 静态：census strict 转 **GREEN**（5 站点显式降级登记，DEFERRED 空）；
  deferred-ok 模式输出 node-local 登记清单。
- t243 33/33；regress 13/13。
- 待 DSH 复审通过后实施（此设计稿不实施）。

---

## 增量 26：G1b step 4 设计定稿（C 路线：迁移 canonical 读原义，用户裁决 2026-08-18）

### 裁决

用户三选一裁决 = **C：维持迁移到 canonical 读原义**（不用增量 25 的
NODE_LOCAL_AUTHORITY 分类，也不等 CF(S) 调度成环）。§17.9 exactly-zero
字面合规：5 个 deferred site 必须真正改读 canonical root，registry 读
归零。

### 机制可行性（2026-08-18 取证）

- root 发布 = write_durable_image（temp + fsync + durable_rename +
  fsync_parent）+ readback 校验 → **原子替换**，读方永远看到完整旧版
  或完整新版，绝无 torn 中间态；
- read_one_image → decode_image 全量校验（header/body/record CRC +
  UUID/sysid/保留位）→ 无 CF 读的完整性由 CRC + 双副本
  （read_canonical_pair: COPY_DIVERGENT / DEGRADED 判定）兜底；
- 已有 `CLUSTER_CONTROL_ROOT_READ_BOOTSTRAP_VALIDATE` 无 CF 读先例
  （read_canonical 的 strong=false 分支不 acquire CF）——bgworker 可复用
  该机制（新枚举 `CLUSTER_CONTROL_ROOT_READ_SNAPSHOT`，语义=无 CF 快照读，
  不产 token）。

### 逐 site 迁移映射（C 路线）

| Site | 现读字段 | root 等价 | 语义差处置 |
|---|---|---|---|
| orchestrator.c:572（replay_one）| checkpoint_redo_lsn（lower）+ highest_lsn（validated_min）| checkpoint_lower_lsn + validated_tail_lsn_exclusive（G1a 刷新）| validated 界 ≥ 写界？否——validated_tail 是 checkpoint 推进的 VALIDATED 界，可能落后于 registry 写位置。用 validated_tail 作 validated_min = **更严**（decode 必须到 checkpoint 验证界），fail-closed 方向安全（补记 4 已背书"VALIDATED 语义强于 written"）。tli → checkpoint_tli/tail_tli |
| hw_remaster.c:487 | highest_lsn（validated_min）| validated_tail_lsn_exclusive | 同上；G1b 注释已写迁移目标即此字段 |
| recovery_worker.c:192（revalidate）/247（worker_main）| highest_lsn（写位置，构造 target page）+ tli | **root 无"写位置"字段**（tail_last_record_lsn 是 checkpoint 时最后记录，不是实时写位置）| 语义差异最大。选项：(a) validate_stream 改用 validated_tail_lsn_exclusive 作 target page 锚（验证 checkpoint 界，重放窗口由 replay 侧 validated_end 兜底）；(b) plan/worker 的 classify 用 root lifecycle+published_at_usec 映射（state+last_updated → lifecycle+published_at，非恒等但 fail-closed：UNKNOWN 归类） |
| recovery_plan.c:203 | state/last_updated/node_id（classify）+ highest_lsn + **highest_scn** | lifecycle + published_at_usec + origin_node_id；**root 无 SCN 值字段**（仅 bit21 conservative_commit_scn 下界）| (a) verdict 分类映射 root（非恒等，UNKNOWN fail-closed）；(b) max_highest_scn 无外部消费者（观测字段，已取证 plan.c 内自写自读）→ 迁移后该观测降级为 conservative_commit_scn 或移除该统计（登记，不阻塞） |

### 实施步骤（每步提交 + 等复审）

1. **READ_SNAPSHOT 无 CF 读**：cluster_control_root.h 新枚举 +
   read_canonical 分支（strong=false 语义同 BOOTSTRAP_VALIDATE）+ 单测
   （atomic-publish 下读到完整镜像、COPY_DIVERGENT 拒）。
2. **orchestrator + hw_remaster 迁移**（窗口推导侧）：lower/validated_min
   改读 root snapshot；t243 L4 online 腿复验。
3. **worker revalidate/main + plan**（classify 侧）：映射 + 单测（verdict
   映射 truth table）；max_highest_scn 观测处置。
4. **census 归零**：5 站点代码迁移完成后，从脚本 DEFERRED + C 表移除 →
   strict 转 GREEN → bit22 可开时刻到达。

### 待办（本设计稿不实施，等 DSH 复审）

- validate_stream 的 target page 锚语义（写位置→validated 界）需 DSH
  背书：验证范围收窄是否引入漏检（写位置之后的 torn 段本就在
  validated_end 容忍区，语义等价论证）。
- plan verdict 的 root 映射 truth table 需 DSH 背书（UNKNOWN fail-closed
  方向确认）。

---

## 增量 26 修订：执行形状 = pre-IR pinned canonical projection（DSH 补记 31，2026-08-18 14:40）

补记 31 撤回 READ_SNAPSHOT 无 CF 读方向（撞 §17.7 no-mirror + §1.3 投影纪律
——不得跨重启 cache、不得绕过 fresh root read）。冻结主线形状（STOP-02 §15）：

**零资源锁 → canonical STRONG read/revalidate → pin root identity + token +
所需 snapshot 字段 → 进入 episode/CF(X) → bgworker 只消费本 episode 的
immutable projection（IR 内仅比较 pin 的 token，禁止自行 CF(S)）→ episode
结束/重启即丢弃 → 下一 episode 重新 fresh read。**

五站点处置（逐站提交，等 DSH 逐站复审）：
1. startup 上下文（plan.c:203、worker.c:192 revalidate）：pre-IR 直接
   fresh canonical STRONG read（startup 是 CF(S) 合法执行者，AD-023 §4）。
2. episode bgworker（worker.c:247、orchestrator.c:572、hw_remaster.c:487）：
   消费 episode 前固定的 projection；投影构造者 = 同站 startup/coordinator
   上下文（先落投影 shmem 结构设计，再实施）。
3. max_highest_scn（plan.c）：无消费者 → 从 correctness 判定删除，降为
   观测（registry 读仅剩 telemetry 面）。
4. registry 独有且 root 无等价语义的字段：禁止镜像 → 改保守 root
   checkpoint/tail 判定或保持 BLOCKED，直到冻结 canonical 表达。
5. census 保持 strict exactly-zero：每站关闭后同一提交从 C 表 +
   scripts/ci DEFERRED 双处移除。

---

## 增量 27：站点 1 设计（plan.c:203 verdict 活性判定障碍 + 处置）（2026-08-18，设计稿，待 DSH 复审）

### 障碍取证（活性信号粒度）

- plan verdict 判定 ALIVE 的输入 = registry slot.last_updated，由
  cluster_stats 主循环每 tick 刷新（cluster_cluster_stats_main_loop_interval
  = 1000ms，cluster_stats.c:672 stats_refresh_wal_state → update_own）
  → **1s 粒度跨节点活性信号**；
- canonical root 的 published_at 只在发布时更新（THREAD_OPEN /
  THREAD_CLEAN_CLOSE / CHECKPOINT_ADVANCE〔每 checkpoint，PG 默认
  checkpoint_timeout=300s〕/ FPW_STICKY / OWNER_REJOIN）→ **checkpoint
  粒度**；
- stale_active_ms = 10s（cluster_guc.c:81）。若 plan 迁移到 root.published_at
  且沿用 10s 阈值：活 peer 的 published_at 可能落后 >10s（checkpoint 间隔）
  → 活 peer 误判 CRASHED_CANDIDATE → plan.n_alive=0 → merge 的 NOT_COLD
  门失效（merge.c:898）→ 尝试 merge 活 peer → stream SKIPPED → blockers →
  **FATAL 53RA3**。灾难性方向，不可直接映射。

### 处置选项（需 DSH 定夺）

A. **活性判定降为"生命周期 + 保守 checkpoint 判定"**（补记 31 项 4 的
   "改保守 root checkpoint/tail 判定"）：ALIVE = lifecycle OPEN 且
   published_at 距今 < max(checkpoint_timeout × 2, 60s)（阈值随 GUC，
   保守放大）；CRASHED_CANDIDATE = OPEN 且更旧。误判方向分析：把
   崩溃 peer 误判 ALIVE → NOT_COLD 拒绝 merge → 走 4.6/4.7 其他路径
   （非丢失，安全）；把活 peer 误判 CRASHED → merge 尝试 → SKIPPED →
   FATAL（危险）。故阈值必须保守放大，宁可 ALIVE 误判。
B. **plan verdict 活性维度保持 registry 读（降级为观测）**：plan 是
   "observational only"（WARNING 明言），其 verdict 的 ALIVE/CRASHED 仅
   服务 merge 候选；把活性维度登记为观测面（census telemetry 白名单
   扩展 "plan liveness probe"），verdict 的 CLEAN/EMPTY 维迁移 root，
   CRASHED_CANDIDATE 判定改为 root lifecycle（OPEN 且未 CLOSED）+ 保守
   checkpoint 界。风险：census exactly-zero 字面（§17.9）再次踩线——
   与补记 30 同型，需显式授权。
C. **保持 BLOCKED**（补记 31 项 4 的"或保持 BLOCKED，直到冻结 canonical
   表达"）：plan 的活性判定在 root 无等价字段期间保持 registry 读 +
   DEFERRED 登记（census 继续 RED），站点 1 只迁移 worker.c:192
   revalidate（startup 上下文，validate_stream 的写位置锚同样依赖
   registry highest_lsn——root 无写位置字段，见增量 26 表）。

### 建议

B 与 C 都再次触碰 §17.9；A 是唯一保持 exactly-zero 的路径，但 ALIVE
误判方向需 DSH 背书阈值。**建议 A + 聚焦单测（verdict truth table：
published_at 阈值边界 + 崩溃/活 peer 双向）**。待 DSH 复审后实施站点 1。

### 站点 1 实施范围（待复审）

- plan.c:203：per-tid STRONG read（startup pre-IR 合法）→ verdict
  truth table（lifecycle/published_at 映射，A 方案阈值）；
  max_highest_scn 从 correctness 删除（补记 31 项 3）；max_highest_lsn
  用 root checkpoint_lower_lsn/validated_tail 观测。
- worker.c:192 revalidate：validate_stream 的 target-page 锚从
  registry highest_lsn（写位置）改保守 root 判定（validated_tail 界
  或 BLOCKED）——语义论证同增量 26 待背书项。

---

## 增量 28：站点 1 实施记录（plan.c:203 verdict 迁移 canonical root，方案 A）（2026-08-18，随补记 32）

### 补记 32 三条件落地

1. **truth-table 聚焦单测**：新增 recovery_plan 单测（EMPTY/CLEAN/ALIVE/
   CRASHED/UNKNOWN 全象限 + 阈值边界 age ∈ {阈值-ε, 阈值, 阈值+ε}）。
2. **liveness 延迟代价显式登记**（安全但慢）：
   - 原 registry 活性粒度 = cluster_stats 每 1s tick 刷新 last_updated
     （cluster_cluster_stats_main_loop_interval=1000ms）；
   - 迁移后活性粒度 = root.published_at 刷新 = checkpoint 粒度
     （CHECKPOINT_ADVANCE 每 checkpoint 发布；checkpoint_timeout=300s
     时阈值 600s，=1h 时阈值 2h）；
   - 后果：crashed→CRASHED_CANDIDATE 判定延迟从 ~10s 变 ~2×checkpoint
     间隔。兜底路径可用性论证：判定延迟只影响"本节点冷启动时把死 peer
     归类为 crash candidate 的早晚"；4.6/4.7 的 warm 路径（NOT_COLD）
     不依赖本判定——peer 活着时 root.published_at 由 peer 的 checkpointer
     持续刷新（每 checkpoint），ALIVE 判定在 peer 存活期间始终正确；
     peer 崩溃后 published_at 冻结，最迟 2×checkpoint 间隔后判
     CRASHED_CANDIDATE → merge 候选。fallback 始终存在：plan 是
     observational-only（WARNING 明言），verdict 错误方向 = ALIVE 误判
     （安全，NOT_COLD 拒 merge）；CRASHED 误判仅当 peer 实际存活且其
     checkpointer 停止发布——peer 存活则其 checkpointer 必然运行，
     排除该场景（fail-closed 方向不变）。
3. **阈值**：`liveness_threshold_us = max(2 × CheckPointTimeout × 1000000,
   60s)`，ALIVE 偏向；clamp 下限 60s；上限不 clamp（文档给出大值场景
   端到端可接受性如上）。CheckPointTimeout 为 GUC int（秒）。

### truth table（root 版，替换 registry classify_slot 调用）

| 条件 | verdict |
|---|---|
| tid == own_thread | OWN |
| root_result == ABSENT（记录不存在）| EMPTY |
| root_result != OK/DEGRADED | UNKNOWN |
| origin_node_id != tid-1 | UNKNOWN |
| lifecycle == CLOSED | CLEAN |
| lifecycle == OPEN 且 now - published_at < 阈值 | ALIVE |
| lifecycle == OPEN 且 now - published_at ≥ 阈值 | CRASHED_CANDIDATE |
| 其他 lifecycle（RECOVERY_REQUIRED/COMPLETE/RETIRED/UNUSED）| UNKNOWN |

### max_highest_lsn / max_highest_scn 处置（补记 31 项 3）

- max_highest_scn：无消费者 → 从 correctness 判定删除（字段保留 0，
  观测面移除 scn_recovery_cmp 调用）；
- max_highest_lsn：改取 root checkpoint_lower_lsn / validated_tail 的
  max（观测语义：registry highest_lsn 是写位置，root 无写位置字段；
  用 checkpoint/tail 界为保守观测）。

### 实施范围（本轮 = plan.c:203；worker.c:192 另站）

- cluster_recovery_plan_generate 的 tid 循环：cluster_wal_state_read_slot
  → cluster_control_root_read_canonical(tid, NULL, READ_STRONG, ...)；
  每 tid 一次 STRONG read（startup pre-IR 合法，CF(S) 可获取已取证）。
- registry_ready() 门 → root 可用性判定（root ABSENT = 首启无 root =
  plan.failed 同语义？——registry 与 root 生命周期不同：root 由 P6
  THREAD_OPEN 发布。首启时 registry 有 ACTIVE slot 但 root 可能 ABSENT
  （THREAD_OPEN 未跑）→ 需保持 plan 可用：root ABSENT 时按"全部
  UNKNOWN"处理并 LOG，plan.failed=false？——待实施时以 t243 实测为准，
  倾向：root ABSENT → plan.failed=true（同现 registry_ready false 语义，
  WARNING fail-open）。

---

## 增量 29：站点 worker.c:192 revalidate 设计（写位置锚保守化）（2026-08-18，设计稿，待 DSH 复审）

### 现状

- `cluster_recovery_worker_revalidate`（worker.c:188-194）在 **startup 进程**
  串行重跑流验证（merge project_readonly :967 调用，worker 池 NONE/FAILED
  时兜底）——上下文 = pre-IR，可 STRONG read root（与 plan/merge 同准入）；
- `validate_stream` 用 `slot->highest_lsn`（registry **写位置 watermark**）
  经 `cluster_recovery_worker_target_page`（header 内联 :169）定位"最后写
  页"（target = highest_lsn - 1，segment 边界安全），再 pread 该页 +
  段首页验证；
- **canonical root 无写位置字段**（只有 checkpoint_lower_lsn /
  validated_tail_lsn_exclusive / recovered_through / tail_last_record 等
  checkpoint 粒度界）。

### 锚替代选项（C 路线框架内，补记 31 项 4"改保守 root 判定"）

A. **validated_tail_lsn_exclusive 作 target 锚**：验证到 checkpoint 验证界
   为止的页。语义差异：validated_tail 是 CHECKPOINT_ADVANCE 每 checkpoint
   推进的 VALIDATED 界（≤ 真实写位置）。用其 -1 定位最后一页 = 只验证
   checkpoint 界内的页；checkpoint 后崩溃前新写的段不在验证范围。
   风险：**漏检 checkpoint 之后写的坏页**？——不：merge 的最终完整性由
   replay 侧 `cluster_thread_recovery_validated_end`（扫描到 validated_min
   解码）兜底（orchestrator 窗口路径），validate_stream 只是候选预检
   （"stream readable"证据），非最终 gate。用 validated_tail 锚 =
   预检范围收窄但方向 fail-closed（预检 SUSPECT→merge blockers；预检 OK
   但界后损坏 → replay validated_end 捕获）。**结论：语义等价可接受**。
B. **checkpoint_lower_lsn 作下界 + tail_last_record_lsn 作上界**：区间
   验证，比 A 更精确但字段语义（tail_last_record 是 checkpoint 时最后
   完整记录）非写位置，收益有限。
C. **保持 BLOCKED**：root 无写位置期间 revalidate 返回 UNREADABLE →
   merge blockers "stream not OK" → FATAL 53RA3——过度保守，破坏冷恢复
   merge 可用性，否决。

### 建议

**A + 聚焦单测**（target_page 锚在 validated_tail 边界 ±ε 的定位 +
   segment 边界安全，复用现有 header 内联测试模式）。tli 用
   root.checkpoint_tli / tail_tli（validate_stream 构造文件名需要）。

### 实施范围（待复审后）

- revalidate 改 STRONG read root → snapshot；target 锚 =
   snapshot.validated_tail_lsn_exclusive（0 → UNREADABLE 同现语义）；
   tli = snapshot.tail_tli ? : checkpoint_tli；
- registry read 移除 → census 站点 worker.c:192 关闭（DEFERRED 双处
   移除，但 :247 仍在 → 按 file:line 粒度需先拆脚本 APIS 匹配或按文件
   登记注释拆分——脚本按文件匹配，worker.c 剩余 :247 仍 deferred；
   实施时评估脚本是否需 file:line 精确化）。

### 待背书项

- A 的"预检范围收窄由 replay validated_end 兜底"论证；
- tli 字段选择（tail_tli vs checkpoint_tli）。

---

## 增量 29 补记：worker.c:192 revalidate 实施（2026-08-18，随提交）

- `cluster_recovery_worker_revalidate` 迁移 canonical root：STRONG read
  （startup 准入）→ `validate_stream_from_root`（新 static）——锚 =
  snapshot.validated_tail_lsn_exclusive（0 → UNREADABLE 同现语义），
  tli = snapshot.tail_tli；claim 内容 + 段首页验证逻辑与 registry 版
  逐字节一致（仅锚来源变化）。
- 单测说明：validate_stream_from_root 依赖 worker.c static（claim 读 +
  页 pread），且 worker.o 无 unit 链接——锚语义由既有
  test_target_page_math / test_target_page_zero_lsn（header 内联）
  覆盖，root 读路径由 t243 merge 场景覆盖。
- census：worker.c:192 关闭，:247（worker_main）仍 deferred（行号
  位移至 :309）——按文件登记不变，census 违规数保持 4。

---

## 增量 30：episode bgworker 三站设计 —— pre-IR pinned projection（补记 31 项 2，2026-08-18，设计稿）

### 形状（STOP-02 §15 / 补记 31）

零资源锁 → canonical STRONG read → pin root identity + token + 所需
snapshot 字段 → 进入 episode/CF(X) → bgworker 只消费本 episode 的
immutable projection（IR 内仅比较 pin 的 token，禁止自行 CF(S)）→
episode 结束/重启即丢弃 → 下一 episode 重新 fresh read。

### 构造者与载体（2026-08-18 取证）

- 三站 episode 入口：
  - worker:247（recovery worker_main）：由 plan 候选 → workers_launch
    （startup 进程，pre-IR！worker 是 BgWorkerStart_PostmasterStart）
  - orchestrator:572（replay_one）：由 thread_recovery_lmon_tick 消费
    GRD eligibility 后 launch（LMON tick，serving 期）；
  - hw_remaster:487：由 grd_recovery_lmon_tick 的 P7 段 launch（LMON
    tick）。
- CF(X) 持有：非 episode 常驻——wal_state 写路径按需获取（:214）；
  补记 24 的 LOCK_UNAVAILABLE 是 worker 内 STRONG read 与瞬时 registry
  写/checkpointer 发布的竞争（16× 实测）。
- **投影构造点 = episode 入口的 LMON/startup 上下文**（P0 accept 前 /
  workers_launch 处），STRONG read 一次，pin 每 dead_tid 的
  {identity, token, validated_tail_lsn_exclusive, checkpoint_lower_lsn,
  checkpoint_tli, tail_tli, lifecycle, root_publish_seq} 到现有 shmem
  载体（cluster_thread_recovery_replay_slot 扩展或新
  cluster_grd_recovery_projection 小区域）。

### 三站消费映射

| 站 | 现读 registry 字段 | projection 字段 |
|---|---|---|
| worker:247（classify + validate_stream）| state/last_updated/node_id + highest_lsn + tli | lifecycle/published_at（classify root 版，同站点 1）+ validated_tail/tail_tli（validate_stream_from_root，同 :192）|
| orchestrator:572（窗口推导）| checkpoint_redo_lsn（lower）+ highest_lsn（validated_min）| checkpoint_lower_lsn + validated_tail_lsn_exclusive（G1a 刷新；validated 界 ≥ 写界？否——validated 是 checkpoint 验证界 ≤ 写位置；作 validated_min = 更严（decode 必须到 checkpoint 验证界），fail-closed 方向安全）|
| hw_remaster:487（validated_min）| highest_lsn | validated_tail_lsn_exclusive（同上）|

### 实施步骤（逐站提交等复审）

1. projection shmem 载体 + 构造函数（LMON/startup 处 STRONG read +
   pin）；单测（pin 完整性 + token 比较）；
2. worker:247 迁移（消费 projection）；
3. orchestrator:572 迁移；
4. hw_remaster:487 迁移；
5. census 逐站双处移除 → GREEN → bit22 可开。

### 待背书项

- 投影构造点选 P0 accept / workers_launch 是否真是"episode 前"（reconfig
  事件消费与 GRD 状态转换的精确时序）——需 DSH 确认或实测；
- validated_tail 作 validated_min 的 fail-closed 方向（同增量 26 表
  已论证：VALIDATED 界强于 written 界，replay validated_end 兜底）。

---

## 增量 31：投影 pin 点验证 + 实施①（shmem 载体）（2026-08-18，随补记 35）

### 验证点答案（补记 35：pin 读须在 episode freeze 前零资源锁）

- CF 锁获取者仅 3 处：control_root（STRONG read 自身 S 锁）、wal_state
  （registry 写按需 X 锁 :214）、hw_ic/oid_lease（镜像资源锁，非 CF）；
  **LMON tick 路径全程无 CF 获取**（grep 实证 cluster_grd.c /
  cluster_thread_recovery_worker.c / cluster_lmon.c 零命中）。
- **thread_recovery_lmon_tick 在 grd tick 之前**（cluster_lmon.c:1390
  顺序：reconfig → semantic → thread_recovery → grd）→ orchestrator /
  recovery-worker 投影在 episode freeze（P1）**之前**构造，零锁 ✓。
- **hw_remaster launch 在 grd P7**（:4038，P5→P6 barrier 后）→ episode
  已 freeze → 投影**前移到 P0 accept**（grd IDLE→WAIT_EPOCH 转换，
  :3581，freeze 前零锁）✓。
- 补记 24 的 LOCK_UNAVAILABLE（16×）是 worker 进程内 STRONG read 与
  同进程 registry 写竞争——投影化后 worker 不再自行 CF(S)，问题消除。

### 实施①：projection shmem 载体

- 载体：ClusterThreadReplaySlot（plan shmem 区域，per-tid 已有
  state + episode_epoch pin 先例，L235）扩展 pin 字段：
  `ClusterControlRootReadToken token; uint64 validated_tail;
   uint64 checkpoint_lower; uint64 lifecycle; uint32 tail_tli;
   uint32 checkpoint_tli; uint64 pin_episode_epoch;`（shmem 结构，
  无磁盘布局，ABI 低风险）。
- 构造函数（零锁点）：`cluster_control_root_read_canonical(tid, NULL,
  STRONG, ...)` 一次 → 填 slot；episode 结束/重启即视为 stale（对比
  pin_episode_epoch）。
- 单测：pin 完整性（字段拷贝全等）+ token 比较 + episode 不匹配丢弃。

---

## 增量 32：实施④ 回归根因 + 回退（2026-08-18，t243 33→2 ok）

### 回归根因（二分定位）

- 实施③（bb7fda782e，orchestrator 迁移）t243 **33/33 绿**（复跑确认）；
- 实施④（未提交：grd P0 pin + hw_remaster 投影迁移）→ t243 **2 ok**：
  node1 崩溃（L4 stop immediate）→ node0 grd episode → P0 pin 读 root
  tid 2 → **ABSENT**（root 文件在 L4 时缺失）→ pin 失败 → hw_remaster
  BLOCKED → hw_gate=held → WAIT_CLUSTER watchdog → episode 卡死 →
  CHECKPOINT 无法获取 CF。
- **根因**：t243 的 L4 场景中 canonical root 文件（$shared/global/
  pgrac_control_root）在 node1 崩溃时**不存在**（cast 断言通过后消失，
  或 node 进程的 cluster_shared_data_dir 指向无 root 的目录）→ 投影
  pin 无法取数 → 原 registry 读（写位置 watermark，独立于 root）可用。
- 这是 **C 路线与 legacy TAP 基础设施的交互问题**：root 生命周期/
  可见性在 t243 场景未就绪，非代码逻辑 bug。

### 处置

- **回退实施④**（丢弃 grd pin + hw_remaster 迁移），恢复实施③ 绿态；
  hw_remaster 保持 registry 读 + census DEFERRED（1 violation）。
- 待 DSH 指导：root 在 t243 L4 缺失的根因（cast 后文件去向 / GUC
  cluster.shared_data_dir 配置 / 是否需要 t243 适配或 root 存在性
  降级语义）。

---

## 增量 33：root 缺失根因查实进展（2026-08-18，补记 38 后）

### 已排除的假设

1. **cast 写路径**：fixture `--fixture-root-cast` 设 cluster_shared_data_dir
   = argv[2]（$shared_root）+ DataDir = 同值，create_prepared 写
   $shared_root/global/pgrac_control_root —— 写路径正确（t243 断言
   -f 通过）。
2. **node GUC**：ClusterPair 配 cluster.shared_data_dir = $shared_control_root
   （ClusterPair.pm:242），node 读路径与 cast 写路径一致。

### 关键新证据（16:08 运行日志，④ 修正 BOOTSTRAP 版）

- hw_remaster **成功**："rebuilt authority from dead node 1 (snapshot
  0/3456A40, validated end 0/3456AC0); marked 0 adopted shard(s) rebuilt
  -> done"——**projection 在 root 存在时工作正常**；
- root 操作活跃："thread 2 checkpoint advanced" / "thread 2 clean-reopened
  (THREAD_OPEN, lineage 3/4/5)"——root 文件在 L4 时**存在**且被发布；
- 但测试仍失败：关闭时 checkpointer **PANIC**："recovery anchor checkpoint
  publication rejected by the write fence inside a critical section"。

### 结论修正

- 16:00 的 pin ABSENT 与 16:08 的 write-fence PANIC 是**两个不同失败**；
  16:08 证明 ④ 的 projection 机制正确（root 存在时成功）。
- write-fence PANIC 可能与 pin 的 BOOTSTRAP 读（storage_contract_check
  在 multi_node 时查 cluster_cf_storage_write_allowed）在 episode/关闭
  窗口干扰 write-fence 状态有关，或为偶发——**需 DSH 判断**。
- 待办：不自行迭代 ④；把 16:08 运行日志（已被清理）的关键行 + 本增量
  证据链交 DSH，由 DSH 指导 write-fence 交互验证或方案调整。

---

## 增量 34：P5 遗留修复 —— anchor 发布 fenced 预检跳过（补记 39，2026-08-18）

### 归因结论（复现验证）

- 已提交树（无 ④，有 G1a/G1a-2/①②③）：t243 **33/33 绿**——write-fence
  PANIC 不复现；
- ④ 的 grd pin 前移改变 fence 刷新时序 → 照出 P5 遗留 bug：anchor 发布
  入口（cluster_recovery_anchor.c:418）注释意图 = "fenced 时跳过发布"
  （cluster_write_fence.c:10 同意图），实现却是
  `cluster_write_fence_reject_if_fenced`（CritSectionCount>0 → PANIC）。

### 修复（最小，符合冻结意图）

- `cluster_recovery_anchor_publish_checkpoint` 入口：reject_if_fenced 替换
  为 `if (!cluster_write_fence_allowed()) { LOG 跳过; return; }`——
  不发布 anchor 对 fenced 节点是安全方向（发布才是危险）；PANIC 语义
  保留给"不可回滚的半完成临界写"，而这里是在写之前检查，跳过无损。
- 保留 `checkpoint_publisher_is_current` 的 stale-member PANIC（那是
  sysid 校验，非 fence 语义）。
- 观测：跳过时 LOG（fenced 节点的 anchor 不发布，restart 走 crash-rejoin）。

### 验收

- t243 33/33 + regress 13/13 + 全量单测无回归；
- ④ 恢复后（pin 前移）不再 PANIC（fence 刷新时序变化被预检吸收）。

---

## 增量 35：root 文件在 node 重启后消失 —— 决定性证据（2026-08-18，交 DSH）

### 实测证据（16:41 run，tmp_check 保留）

- node 0/1 attached shared root = `tmp_test_XDjz`；cast 断言
  `-f $shared_root/global/pgrac_control_root` 通过（cast 时文件存在）；
- **L4 崩溃时（pin 时刻）`tmp_test_XDjz/global/` 无 pgrac_control_root**
  （仅 pg_control/pg_hw_snapshot/pgrac_cf_p2）——root 文件在 cast 后、
  node 重启（start_pair）期间消失；
- 佐证：node 0 启动日志 "recovery plan: ... 127 unknown"（站点 1 的
  STRONG 读也全失败 = root 文件不存在）；
- 生产代码无 root 删除路径（仅 temp unlink）；ClusterPair 的
  shared_control_root 单实例不变（:220 tempdir 一次）。

### 推论

- **cast fixture 写 root 后，node 重启（clean rejoin）时 root 文件被
  移除**——机制不明（无删除代码）。可能：node 启动时对 shared 目录的
  某清理（pg_basebackup？:32 日志显示 BASE_BACKUP 跑过——backup 可能
  重建 global 目录！）。
- **BASE_BACKUP 假设**：node 0 启动时对 node1 做 base backup（:32），
  backup 目标可能覆盖 shared root 的 global/（删掉 cast 的 root 文件）。
  这解释了"cast 后消失"。

### 待 DSH 指导

- 验证 BASE_BACKUP 是否清理 shared root global/；若是，④ 的 pin 点
  必须移到 backup 之后（或 t243 流程调整，但受冻结裁决约束：
  RFROOT-P04-A2 禁 workload/judge 改动，setup-only 经生产 producer）。
- ④ 现状：BOOTSTRAP pin（正确）+ hw_remaster 投影迁移（正确）+ census
  双处归零（GREEN）；唯一阻塞 = pin 时 root 不存在。

## 增量 36：增量 35 勘误 —— BASE_BACKUP 假设不成立；真实机制 = cast 前 stop 触发
## 的 remaster 在 root 未 mint 时 BLOCKED（2026-08-18，交 DSH）

### 勘误：增量 35 的两处事实错误

1. **"cast 断言通过（cast 时文件存在）"不成立**：16:41 run 的 node0 日志显示
   `CHECKPOINT`（t243 L148，cast 前 node0 的 CHECKPOINT）在 16:41:53.105 失败
   （"could not acquire the cluster control-file lock for a checkpoint"）——
   **测试死在 cast 之前，cast 从未执行，root 文件从未被 mint**。
   tmp_test_XDjz/global/ 无 pgrac_control_root 是"从未创建"而非"创建后消失"。
2. **BASE_BACKUP 假设不成立**：ClusterPair.pm 实测 backup 只在 new_pair 的
   seed 阶段发生一次（node0 init -> start -> backup -> node1 init_from_backup，
   :263-267），start_pair 无任何 backup 调用（:459-561 全文核对）——
   16:41 run 的 BASE_BACKUP（16:41:13.331）在 cast 之前很久（cast 从未执行）。

### 真实机制（16:41 run，④ 应用版）

时间线（node0 日志实测）：
- 16:41:23.013  node1 CHECKPOINT（t243 L146，cast 前）
- 16:41:23.022  node1 fast shutdown（t243 L147，cast 前 clean stop）
- 16:41:23.202  node0 "committed departure of node 1 at epoch 1"
- 16:41:23.203  node0 pin tid2 -> result 3（root ABSENT——**cast 尚未 mint，
  预期状态**）
- 16:41:24.202  node0 "HW remaster: dead node 1 canonical projection is
  unusable (tid 2, episode 1)" -> BLOCKED
- 16:41:25.205  PCM-X runtime fail-closed（hw_gate held）
- 16:41:53.105  node0 CHECKPOINT（cast 前 L148）拿不到 CF -> 失败 -> 测试死

对照（17:04 run，当前树 ③ registry 版，同样 cast 前 node1 stop）：
- 17:04:07.038  node0 "HW remaster: rebuilt authority from dead node 1 ...
  marked 2048 adopted shard(s) rebuilt -> done"（registry 读成功，不阻塞）
- 17:04:12.161  node0 CHECKPOINT（cast 前 L148）成功 -> cast 执行 -> root minted

**结论**：clean stop（cast 前）触发 node0 对 departed node 的 HW remaster 是
**既有行为**（③ 版同样发生）。④ 的投影读把"root 尚未 mint（ABSENT）"当
BLOCKED -> hw_gate held -> CF 死锁；registry 版（highest_lsn 有值）成功。
**④ 的投影语义必须处理 root 尚未 mint 的 ABSENT 状态**（cast 前 stop 是
t243 的正常流程；生产首次 root mint 前同理）——不能把 ABSENT 当永久 BLOCKED。

### 另：17:04 run（当前树 = ③ + P5 修复）t243 也失败（P5 后首次复跑）

- 这是补记 40 欠着的 P5 修复后首次 t243 复跑，结果 Bailout（pg_ctl start
  failed）：L10 后 node1 重启（17:05:21.562 pre_init）-> 17:05:22.629 HELLO
  CONNECTED -> 17:05:24.586 node1 "PCM-X runtime fail-closed (recovery
  blocked)" -> 17:06:26 node1 判 node0 DEAD（cssd 超时）-> fail-stop epoch
  bump 12->13 -> GRD WAIT_CLUSTER episode 13 hw_gate=held 卡死。
- node0 侧 17:05:21.436 起持续 "peer 1 closed: connect failed"（IC 连接失败）。
- 待查：P5 修复回归 or 环境偶发（复跑确认）。

### 待 DSH 指导

1. ④ 的 ABSENT 语义：pin 失败（root 未 mint）时 hw_remaster 应如何处置
   （降级 validated_min=0 无下界？或 hw_remaster 对 ABSENT 跳过/重试？）
2. t243 是否需要 setup 调整（冻结裁决 RFROOT-P04-A2 范围内）。
3. 17:04 run 失败归因（P5 回归 or 偶发）——复跑证据。

## 增量 37：④ ABSENT 语义二分设计 —— never-minted vs minted-lost
## （2026-08-18，补记 42 裁定落地；文档先行，交 DSH 复审后再动码）

### 裁定来源

- 复审补记 42（2026-08-18 17:25）：增量 36 勘误核验通过；17:04 失败结案
  为环境/构建态波动（17:17 同树复跑 33/33 GREEN，DSH 独立核验）；
  Q2 裁定 t243 禁止改动（fixture 从未出错，修复全在产品侧）；
  Q1 裁定 ABSENT 语义二分 + 判别器 + 不持 gate 约束。

### 语义二分（补记 42 Q1 裁定原文）

1. **never-minted（ABSENT-expected）**：root 从未 mint —— registry 无该
   tid 的发布记录 / producer 未跑 THREAD_OPEN。ABSENT 是**正常期望状态**
   （t243 cast 前的 clean stop、cluster 生命周期早期、首次 remaster）。
   → hw_remaster 按无 canonical 数据**降级完成**（= ③ registry 现行
   行为，实测 17:04 run "2048 adopted shards rebuilt -> done"）；
   **不得 BLOCKED、不得持 hw_gate**。
2. **minted-lost（ABSENT-lost）**：root 已 mint 但 STRONG 读失败 ——
   registry 有发布记录（LSN X）但文件缺。矛盾 = 危险态。
   → 保持 fail-closed（53RA2 语义）。

### 判别器

- 判别器 = **root registry 发布记录**（生产已存在；即 ③ 现行读取源
  cluster_wal_state_read_slot 的 slot 记录，highest_lsn != 0 表示该 tid
  有发布记录）。
- **pin ABSENT 必须对照 registry 解释，不能单独判 BLOCKED**：
  - registry 有发布记录（highest_lsn != 0）→ 期望 root 已 mint →
    ABSENT = minted-lost → fail-closed；
  - registry 无发布记录（slot 空 / highest_lsn == 0）→ never-minted →
    ABSENT 正常 → 降级完成。
- census 处理待 DSH 复审确认：判别器读 registry 是否计入 correctness
  违规（建议：判别器是"解释 ABSENT 的元数据判读"，非 correctness 读；
  但 C 表/脚本的 exactly-zero 定义需 DSH 明确边界）。

### 不持 gate 约束（补记 42 硬性条款）

- fail-closed **不得以"永持 hw_gate"形式实现**（16:41 wedge 即此病：
  永持 gate → CF 全卡 → PCM-X fail-closed → 集群整体锁死）。
- 危险态（minted-lost）应 **fail-stop / 显式退出**（该 worker 终止、
  不留永续 gate），由 grd 的正常 fail-stop 路径接管；BLOCKED 仅允许
  作为**有限重试**的中间态（沿用现有 16 次 backoff 上限），耗尽后
  显式终止而非无限期 hold。

### 落地顺序（补记 42 待办更新）

1. ✅ 增量 36（勘误已提交 758b713827）
2. ✅ P5 后复跑：t243 33/33（17:17 绿跑 + 本会话复跑）、cluster_regress
   13/13（本会话 bash-283，17:2x PASS）——补记 42 记"仍欠 regress"，
   此处补记：已跑 13/13 绿。
3. ✅ t243 TEMP note 检查：当前树无残留（grep probe/G1b/TEMP 零命中；
   补记 36/42 所指为 stash 内改动，stash 已不存在，无残留风险）。
4. 本增量 37（语义契约文档）→ 交 DSH 复审。
5. 复审通过后：site-4（hw_remaster.c:487）按二分语义迁移 →
   census 双处归零 → bit22 首开。

### 验收

- 增量 37 复审通过；
- site-4 迁移后 t243 33/33 + regress 13/13 + 聚焦单测绿；
- census GREEN（0 violation，判别器读的 census 边界经 DSH 确认）。

---

## 增量 38：增量 37 勘误与处置（2026-08-18，补记 43 裁决落地）

### 裁定来源

- 复审补记 43（2026-08-18 17:40）：会话的 cutover 语义分析全部属实 +
  DSH 增补证据 E1/E2；补记 42 Q1 裁定被补记 43 明确纠正（三处漏判）。

### 增量 37 的状态：文档滞留，落地前停止

增量 37（76e94dc8db）按补记 42 Q1 写成：④ ABSENT 二分（never-minted
vs minted-lost）+ registry 判别器 + 不持 gate。其中：

- **保留且仍有效**：① never-minted vs minted-lost 二分语义本身；
  ② 判别器原则（pin ABSENT 必须对照 registry 发布记录解释，不能单独
  判 BLOCKED）；③ "fail-closed 不得以永持 hw_gate 实现" 硬性约束；
  ④ 不做 t243 改动。
- **已被补记 43 推翻、禁止按此落地**："site-4 按二分语义迁移 → census
  双处归零 → bit22 首开" 这一落地路径本身。补记 43 裁决：冻结 §17.8
  （Source R4 OPEN: wal-state remains selected; root is not authority）
  + §17.7-4（after bit22 ... statically unreachable → bit22 前在用）+
  §17.9（census 证明 **post-bit22** 状态）三处合起来，**reader 在
  bit22 前必须保持 wal-state 权威源**；"先迁 reader root-only → census
  归零 → 才开 bit22" 的顺序把冻结语义做反了。
- **配套发现（补记 43 E1）**：已提交树的五个 G1b step-4 站点功能惰性
  （STRONG+NULL → 恒返 INVALID_ARGUMENT=23 → 17:17 绿跑 plan 实测
  "0 alive, 127 unknown"，连 ALIVE 的 tid2 都 UNKNOWN；plan 恒 0
  candidates → worker 永不启动）。127-unknown 是 NULL-identity bug
  签名，与 root 文件存在性无关（E2：增量 35 的"STRONG 读全失败=文件
  缺失"佐证不成立）。

### 新落地方向（补记 43 背书，替代增量 37 的落地路径）

1. **reader 双路径按 bit22 门控**：bit22 前走 wal-state（registry）权威
   源；bit22 后 root-only + ABSENT fail-closed。增量 37 的二分语义
   （never-minted 降级 / minted-lost fail-stop）在 **bit22 后分支**
   内继续有效。
2. **reader 切换收进 G3/G5 的 all-member CLOSED-ACK 同一轮**（W6 事实 +
   reader 切换同轮绑定，§17.7-3 的 "same migration round"）。
3. **census 重定义**：§17.9 的静态 census 是对 **post-bit22** 状态的
   证明（gate 建模），不是 pre-bit22 归零前置门。脚本 KNOWN-DEFERRED
   语义翻转：deferred 站点 bit22 前合法（wal-state 是权威源），cutover
   轮内关闭。
4. **修 NULL-identity bug**：pin/plan 读要么传 expected_identity，要么
   用合法模式；BOOTSTRAP 仅限验证语义。
5. **测试强度缺口**：注册 t243 补 candidate>0 断言（或独立 crash 腿），
   否则迁移惰性永不可见。
6. hw_remaster 现 committed 的 registry 读保持不动——它是 §17.8-correct
   的 bit22 前行为；不再把 site-4 "迁移" 当 bit22 前置任务。

---

## 增量 39：P7 收尾重排落地设计 —— NULL-identity 修法 + reader 双路径
## bit22 门控 + census 重定义（2026-08-18，补记 43 裁决落地；文档先行，
## 交 DSH 复审后再动码）

### 裁定来源与任务映射

- 复审补记 43（2026-08-18 17:40）：cutover 语义反转裁决（§17.8 + §17.7-4 +
  §17.9 ⇒ reader 在 bit22 前必须保持 wal-state 权威源）+ E1/E2 惰性证据 +
  下一步四条。增量 38 已落档裁决与增量 37 处置；本增量是**落地设计**。
- 映射：§A = 任务 1（NULL-identity 修法）；§B = 任务 2（双路径 bit22 门控）；
  §C = 任务 5 文档面（census 重定义）；§D = 任务 3（测试强度选项，待裁定）；
  §E = 任务 4 要点（bit22 首开轮，详设留后续增量）。

### §A NULL-identity bug：取证与修法（任务 1）

**取证（committed tree 72b33253e3 实测）**：

- `cluster_control_root_read_canonical` 前置检查（cluster_control_root.c:815-819）：
  `strong && expected_identity == NULL` → 恒返 `INVALID_ARGUMENT=23`，
  先于任何文件访问。
- 三个 committed 读点全部传 NULL：
  ① plan.c:219-220（plan verdict 逐 tid 读）；
  ② plan.c:335-336（`cluster_thread_recovery_pin_projection`，worker:247 /
     orchestrator:572 的投影数据源——pin 恒 false ⇒ 两个 consumer 经
     `cluster_thread_recovery_projection_current` 恒 fail-closed）；
  ③ worker.c:213-214（`cluster_recovery_worker_revalidate`，恒 UNREADABLE）。
- 惰性链（补记 43 E1）：plan 恒 "0 alive, 127 unknown" → 0 candidates →
  worker/orchestrator 永不启动；t243 绿不证明迁移正确（测试强度缺口，§D）。
- 对照合法用法：thread_recovery_worker.c:162-164 与 merge.c:1388-1390 传
  `&duty`（真实 identity）——五站惰性不代表全部 root 读坏死。

**修法 = committed 先例的两步合法模式**（wal_retention.c:1355-1373 /
`wal_retention_e1_read_root` :1644-1675 已在树）：

1. `read_canonical(tid, NULL, READ_BOOTSTRAP_VALIDATE, &bootstrap, NULL)`
   —— **仅做 identity 发现**（验证语义：不持 CF、不铸 token，strong=false）；
2. `read_canonical(tid, &discovered_identity, READ_STRONG, &snapshot, &token)`
   —— 正确性读仍是 STRONG + expected_identity 绑定（token 只在此铸造）。

不变量与 fail-closed：

- BOOTSTRAP 永不直接服务 correctness 判定（补记 43："BOOTSTRAP 仅限验证语义"）；
- discover→STRONG 之间 root 重发布 → `IDENTITY_MISMATCH` →
  UNKNOWN/UNREADABLE/pin-false（与现行 fail-closed 方向一致，下一周期重试）；
- `control_root_read_ready` 现为 wal_retention.c:130 static——实施时导出为
  共用内联（control_root.h）或各站复制两行判式（实现细节，复审定）。

**落地耦合（硬约束）**：§A 单独落地会让 root 读在 bit22 前变成活路径
（plan 开始真产 candidate、worker 真启动）= bit22 前 root 成事实权威，
正是补记 43 裁定的反转方向。故 **§A 不得单独落地**——必须与 §B 门控同批：
root 分支在 bit22 latch 置位前动态不可达（见 §B）。

### §B reader 双路径 bit22 门控（任务 2）

**门谓词合同**（新设施，任务 4 的 cutover 驱动负责置位）：

- `cluster_r4_bit22_cutover_active(void)`（名待定）→ bool：
  shmem latch，默认 false，单调一次性置位，无锁可查（pg_atomic），
  任何不确定 → false（fail-closed 到 pre-bit22 分支）。
- 置位合同：节点本轮 cutover FSM 到达 OPEN_APPLIED（ACK stage 枚举已存在，
  semantic_activation.h:45）且绑定本轮 round identity 时置位；latch 记录
  {transition_epoch, prepare_generation} 供观测。**驱动落地前 latch 永不
  置位 ⇒ 全部 reader 走 pre-bit22 分支 = 冻结 §17.8 行为逐字恢复。**

**统一 gate idiom**（census gate 建模的机器可识别锚，见 §C）：

```c
if (cluster_r4_bit22_cutover_active()) {
    /* post-bit22: root-only，ABSENT 按增量 37 二分 fail-closed */
} else {
    /* pre-bit22: wal-state registry 权威源（§17.8） */
}
```

**逐站形状**（实施分批，每批一 commit）：

| 站 | pre-bit22 分支（恢复形态） | post-bit22 分支（修好形态） |
|---|---|---|
| S1 plan.c:219（plan verdict，startup 上下文） | `read_slot` + `classify_slot`（29efc553b0^ 原形，header-only inline 仍在 plan.h:116；阈值 `cluster_recovery_stale_active_ms`） | §A 两步读 + `classify_root_slot`（补记 32 方案 A 不变） |
| S2 worker.c:213（revalidate，startup 上下文） | `read_slot` + registry 版 `validate_stream`（从 34eb81cc71^ 恢复；迁移时删除，worker.c:141 注释实证） | §A 两步读 + `validate_stream_from_root` |
| S3 pin（plan.c:335，调用点 worker.c:393 workers_launch / thread_recovery_worker.c:452 LMON launch）+ consumer（worker:247、orchestrator:572） | **不 pin**：consumer 直接 registry 读（恢复 a9be5590d0^ / bb7fda782e^ 消费形态，无 CF 依赖） | §A 修好 pin + `projection_current` 消费（增量 30/31 形状不变） |
| S4 hw_remaster.c:487 | **不动**（committed registry 读 = §17.8-correct，补记 43 项 6） | 本批不加；root 分支在任务 4 cutover 轮内入场 |

- 观测字段（plan.max_highest_lsn 等）随各分支源走：观测不是 correctness，
  不进 census。
- **增量 37 二分语义的位置**：never-minted 降级 / minted-lost fail-stop /
  registry 发布记录判别器 / 不持 hw_gate——全部只在 **post-bit22 分支**内
  有效；pre-bit22 分支无 root 读，无 ABSENT 问题。
- §17.7-4 "after bit22 ... statically unreachable" 与运行时分支的张力由
  §C 的 gate 建模化解（静态证明对象 = "无 ungated correctness 调用点"）。

### §C census 重定义：post-bit22 静态证明（gate 建模）（任务 5 文档面）

**问题（补记 43 裁决）**：现行 census 把 §17.9 的 **post-bit22** exactly-zero
操作成 **pre-bit22 前置门**——activate proof 的运行时门
（recovery_duty.c:103 `cluster_wal_state_correctness_census_ok()`）+ 脚本头
"must pass GREEN before bit22 opens"——迫使 reader 在 bit22 前 root-only，
违反 §17.8。hw_remaster 的 §17.8-correct registry 读反被列 KNOWN-DEFERRED
= 框架颠倒。

**新模型（gate 建模）**：

- census 静态证明对象重定义为："生产树中**不存在未被公认 bit22-gate idiom
  包住的** registry correctness 调用点"。被 idiom 包住的站点 = post-bit22
  静态不可达的建模证明（latch 单调 ⇒ post-bit22 永远走 root 分支）。
- 脚本（scripts/ci/check-wal-state-correctness-census.sh）：strict 的 RED
  条件从 "DEFERRED 非空" 改为 "存在 ungated 且不在 telemetry 白名单的
  correctness 调用点"；KNOWN-DEFERRED 语义**翻转**为 GATE-BOUND 清单
  （bit22 前合法，§17.8；cutover 轮提交内完成切换后移除）。
- activate proof 的 census 运行时门（recovery_duty.c:103）**移除**——bit22
  开门的绑定改为任务 4 的 all-member PREPARED-stage CLOSED-ACK + reader
  切换同轮（W6 条款 3 原义）。**补记 28 "census 做成运行时调用" 硬性要求
  在此显式处置**：该要求建立在反转模型上（pre-bit22 归零前置）；补记 43 的
  gate 建模取代之——post-bit22 的证明是静态 gate 建模 + cutover 提交内
  清单归零，而非 pre-bit22 运行时门。
- C 表（wal_state.c:821 `cluster_wal_state_census_deferred_sites`）随 §B
  实施批同步处置：改为 gate-bound 站点表（运行时自检用途）或删除，
  与脚本 lockstep 校验保持语义一致（实施批内定稿，复审确认）。

### §D 测试强度缺口（任务 3：选项，待 DSH/用户裁定）

缺口证据：补记 43 E1；t243 全文 grep 无任何 candidate/plan 断言（实测零
命中）——plan "0 alive, 127 unknown" 在绿跑里不可见。

- **选项 1**：t243 补 candidate>0 断言（L4 crash 腿后 plan 日志须出现
  "crashed candidate [2]"类）。⚠️ 撞红线 "t243 断言不可改"——需用户显式
  裁决授权。
- **选项 2（推荐）**：独立 crash 腿新 TAP（不动 t243）：2-node shared-root，
  kill -9 一腿，断言 survivor plan 产 candidate + worker 启动。基础设施
  复用 ClusterPair；代价是新文件维护面。
- **选项 3（配套，不替代）**：聚焦单测直接杀死本类惰性——pin_projection /
  plan root 分支用真实 root fixture（control_root 单测 :792 起的真实文件
  先例）驱动：断言两步读成功、latch=false 时 root 分支动态不可达、
  NULL-identity 型失败立即红。

请 DSH/用户在 1 / 2 间裁定；3 无论何选都做。

### §E bit22 首开轮要点（任务 4 预览；详设 = 后续增量）

- 驱动接线：coordinator R4 驱动（utility mailbox cutover，补记 29 遗留）；
  create/activate proof seam（recovery_duty.c:44-120）尚无生产调用方
  （grep 实证），首开轮设计必须含驱动 + latch 置位点。
- 同轮绑定（§17.7-3 "same migration round"）：all-member PREPARED-stage
  CLOSED-ACK（W6 条款 3）+ reader 切换 latch 置位 + hw_remaster root 分支
  入场 + census GATE-BOUND 清单归零，同一 cutover 提交内完成。

### 落地顺序与验收

1. 本增量交 DSH 复审（文档先行，不动码）。
2. 复审通过后按批实施，每批一 commit、批批等复审：
   批 1 = S1+S2（startup 上下文双路径 + §A 修法内嵌）；
   批 2 = S3（pin 修好 + consumer 双路径）；
   批 3 = §C（census 脚本头/strict 语义 + C 表 + activate proof 门移除）。
3. §D 裁定后落地测试强度（与批 1/2 并行可行）。
4. 任务 4/5 随首开轮设计增量落地。
- 每批验收：t243 33/33 + cluster_regress 13/13 + 聚焦单测绿（plan /
  recovery_worker / control_root）+ census 脚本行为符合本批语义。
- 全程不变量：latch=false 时行为逐字等价迁移前（registry 权威）；
  root 分支静态存在、动态不可达；ABSENT 二分只在 post-bit22 分支内。

---

## 增量 40：任务 3 测试设计实测 + 任务 4 bit22 首开轮设计要点
## （2026-08-18，crash 腿构造受阻的三个产品语义实测发现 + 首开轮文档先行）

### §A 任务 3（crash 腿）构造探索：三个实测发现（t/270 开发轮，未提交）

目标（补记 44 §D 选项 2）：独立 TAP——2-node shared-root，断言 survivor plan
产 candidate + worker 启动，让 NULL-identity 惰性（0 candidates / 127 unknown）
可见。t243 冻结不动。三轮实测（每轮完整跑批 + 日志取证）：

**发现 1——crash-rejoin epoch 竞态**：node1 stop('immediate') 后立即 start，
node1 的 qvotec 学的 epoch（bump 前）=1；node0 判死流程随后 fail-stop epoch
bump（cssd SUSPECTED 2s + DEAD 3s + "PCM-X runtime fail-closed" 触发）→ node1
的 join 帧 epoch 1 < current 2 被拒（"dropped envelope: stale epoch"）→ join 30s
不收敛 → 53R61。t243 L4 恰好赢竞态（node1 在 node0 判死前完成 heartbeat
恢复 → 无 bump）。**修复面属 P6 rejoin 语义**（epoch 重学或 bump 排序），不是
本任务范围；t243 L4 的窗口（<3s 快重启）是当前唯一稳定路径。

**发现 2——phase3 barrier 死等**：peer 崩（DEAD）时本节点 clean stop 后重启，
phase-3 等 live formation 永不满足 → 600s 超时 FATAL（"exceeded timeout
(1128.193 s > 600 s)"）。2-node 共享盘语义：**单节点无法在 peer DEAD 时重启**
（qvotec/formation 要求 live peer 或 online_join）。因此"peer 崩 → 本节点重启
看 stale slot"构造不可行。

**发现 3——clean-leave 后 peer 仍判 DEAD + phase3 witness 窗口**：node0 clean
stop（departure 提交）后 node1 的 cssd 心跳自然断 → 3s 判 DEAD（"NO reconfig
in spec-2.5"）→ node0 重启的 phase-3 检查 live formation：node1 的 formation
里 node0 仍 DEAD，且 phase3 的 witness 检查窗口极短（"live formation did not
become ready **before recovery**"——clean shutdown 后 recovery 立即开始，
deadline 秒级）→ node1 的 rejoin 处理（evict + admission）来不及 → 快速 FATAL。
**不对称**：t243 L5/L6 的 node1（clean stop 后重启）成功——survivor 侧
（node0）的 rejoin 处理与 joiner 侧（node1）不同步调。修复面属 P6 rejoin 语义。

**发现 4（次生）——stats interval 与 formation 耦合存疑**：node1 的
cluster_stats interval 60s（让 slot2 stale 的构造）下 node0 重启两次均
phase3 失败；但 stats 状态（cluster_stats_state）无 formation 消费者
（grep 实证：cssd 用独立 tick）——疑似与发现 3 同根（clean-leave 判死），
非 stats 因果。待 DSH 裁决是否需对照实验。

**结论**：crash 腿的"peer stale + 本节点重启"构造在当前 2-node 集群语义下
不可行（发现 2/3），快重启竞态不可控（发现 1）。**惰性可见性已由既有层
关闭**：control_root 单测（NULL+STRONG→23 守卫 + 两步读真实 fixture，
补记 46 核准）+ t243 绿跑 plan "0 unknown"（补记 49 DSH 独立核验）。
crash 腿降级为**待 DSH 裁决构造方案**（选项：online_join=on 配置下的
crash-rejoin 腿 / 3-node 编队 / 接受单测+绿跑证据作为任务 3 闭合）。
t/270 开发文件保留在工作区未提交，不推送。

### §B 任务 4：bit22 首开轮设计要点（增量 39 §E 展开，文档先行）

**轮内同批提交内容**（§17.7-3 "same migration round"，一处 commit 全含）：

1. **coordinator R4 驱动**（补记 29 遗留 utility mailbox cutover + 设计点 ③）：
   create/activate proof seam（recovery_duty.c:44-120）现无生产调用方（grep
   实证）——驱动 = 协调者 utility 路径：提交 R4 round（create_prepared）→
   全成员 SAMPLE→BARRIER→PREPARED ACK 收集（semantic_activation FSM 既有
   机制）→ activate_prepared（root header ACTIVATION_ACTIVE）→ **latch 置位
   广播**。
2. **latch 置位点**：每节点在 OPEN_APPLIED stage（semantic_activation.h:45）
   应用时调 `cluster_r4_bit22_cutover_latch_apply(transition_epoch,
   prepare_generation)`——本轮内 census 自检（KNOWN-DEFERRED 非空则拒绝，
   批 3 已实现）保证 hw_remaster 同轮关闭后才能置位。
3. **hw_remaster root 分支入场**（S4，增量 39 §B 未做部分）：registry 读包
   进 gate idiom + root 分支（两步读 + 增量 37 二分语义：never-minted 降级
   完成 / minted-lost fail-stop，判别器 = registry 发布记录，不持 gate）→
   census GATE-BOUND 清单双处移除 → strict GREEN（post-bit22 证明成立）。
4. **设计点 ① 混合 latch 窗口证明**（补记 44）：node A 置位（root-only）与
   node B 未置位（registry）的窗口内两节点推导不同源。证明义务：
   CLOSED-ACK（PREPARED-stage all-member ACK）后 root 界与 registry 界一致
   （G1a CHECKPOINT_ADVANCE / G1a-2 FPW_STICKY 使 root 的 checkpoint/tail 界
   是 wal-state 发布历史的函数 + W6 条款 3 的 CLOSED 绑定保证所有成员在
   同一 round 边界）⇒ 混合操作安全。**混合态腿受 §A 发现 2/3 限制**（节点
   重启/切换需 peer 在线），TAP 混合腿可行性待 DSH 裁决。
5. **顺序约束**：本轮内 hw_remaster 关闭 → census GREEN → latch apply（否则
   apply 被批 3 的运行时门拒绝）→ activate 完成后各成员 OPEN_APPLIED →
   reader 切换生效。create→activate 之间 census 必须已 GREEN（批 3 语义：
   GREEN 是 post-bit22 证明，随本轮提交成立，不是 pre-bit22 前置）。

**验收**：t243 33/33 + 聚焦单测绿 + census strict GREEN（0 violation）+
latch 置位后 plan/worker/orchestrator/hw_remaster 全走 root 分支（日志
bit22=1）+ regress 13/13。

---

## 增量 41：任务 3 收尾（实验 X 定案）+ 批 4 hw_remaster 双路径 + census
## 归零 GREEN（2026-08-18，补记 55 后实测定案 + 实施批）

### §A 任务 3 crash 腿：实验 X 定案（增量 40 §A 发现 5 补记）

补记 55 核准的 v2（node0 liveness tick 60s + node1 crash-rejoin + sleep 8 +
online_join=on）实测失败：**53R60 "crash-rejoin detected (online_join=off)"
→ 30s 53R61**——dead-rejoin（peer 已判 DEAD 后的 rejoin）在
online_join=on 下也不收敛（HINT 明示 "admission self-heal is spec-5.22
follow-up"，未实现）。**对照实验 X**（去掉 stats 60s，其余不变）：同样
53R60/53R61——**dead-rejoin 与 stats 无关，crash-rejoin 本身在当前
2-node 语义下不可用**（唯一绿路径 = t243 L4 的 <3s 快重启 fast-rejoin，
要求 peer 无 bump，而 peer 的 registry stale 构造（stats 60s）恰在轮 2
实证会改变 node0 的 bump 行为）。

**任务 3 定案**：crash 腿 TAP 在当前集群语义下不可构造（5 轮实测 + 对照
实验），测试文件已删除（不推送半成品）。惰性可见性由既有层关闭：
control_root 单测（NULL+STRONG→23 守卫 + 两步读，补记 46 核准）+ t243
plan "0 unknown" 绿跑证据（补记 49 DSH 独立核验）。crash 腿重开条件 =
online_join（spec-5.22）落地或 3-node 编队；届时按本增量 §A 的实测
发现选构造。

### §B 批 4：hw_remaster 双路径（增量 39 §B S4 落地）+ census strict GREEN

- cluster_hw_remaster.c:504/528：registry watermark 读包进
  `cluster_r4_bit22_cutover_active()` gate idiom。pre-bit22 分支 = 冻结
  §17.8 行为逐字不变（registry 无 CF 依赖；root STRONG 读在 crash-rejoin
  episode 窗口 LOCK_UNAVAILABLE 的历史注释保留）。post-bit22 分支 =
  两步读 root（增量 39 §A）+ 增量 37 ABSENT 二分：never-minted（判别器
  = registry 发布记录缺失）降级走 registry 完成路径；minted-lost
  （registry 有发布但 root 读失败）→ BLOCKED_STRUCTURAL 终止
  （episode-once，不留 hw_gate——增量 37 硬性约束）；root 无 validated
  tail → BLOCKED fail-closed。post-bit22 分支在 latch 置位前动态不可达。
- census 双处：hw_remaster KNOWN_DEFERRED → GATE_BOUND（脚本 + C 表）；
  KNOWN_DEFERRED 空 → **strict GREEN（exit 0）= post-bit22 exactly-zero
  静态证明（gate 建模）成立**；latch apply 运行时自检放行（r4fsm
  test_130 的 RED 拒绝路径保留为回归守卫）。脚本空数组 set -u 修复
  （${var[@]+...} 守卫）。
- 测试同步：wal_state_rmw test_g4 翻转 RED→GREEN（改名
  test_g4_census_gate_green_all_sites_gate_bound，注释注明"未来 ungated
  站点回归即红"）；r4fsm 179/179、wal_state 21/21 不变。
- 证据：t243 33/33（75s，node1 崩后 node0 hw_remaster "rebuilt ... done"
  实测仍走 registry 成功）+ cluster_regress 13/13 + 聚焦单测绿 +
  census strict/deferred-ok 双 GREEN。

**P7 状态**：批 1-4 完成 + 任务 3 定案（受集群语义限制）+ census GREEN。
剩余：任务 4 bit22 首开轮（coordinator R4 驱动 + OPEN_APPLIED latch 置位
+ 混合窗口证明，增量 40 §B）——post-bit22 分支全部就位，唯一缺口是驱动。

---

## 增量 42：任务 4 bit22 首开轮详细设计（2026-08-18，文档先行；
## 增量 40 §B 要点展开；实施前交 DSH 复审）

### 目标

coordinator 驱动 R4 cutover 轮：create（PREPARED）→ 全成员 ACK 编排
（SAMPLE→BARRIER→PREPARED，既有机制）→ activate（root ACTIVATION_ACTIVE，
四门 proof 已就绪）→ **OPEN_APPLIED 段（新增）**：全成员应用
`cluster_r4_bit22_cutover_latch_apply`（reader 切换 + census 自检放行）。
轮内同批关闭 census（批 4 已完成：KNOWN-DEFERRED 空 → GREEN）。

### 现有机制盘点（grep 实证，2026-08-18）

- ACK 表/请求编排：SAMPLE→BARRIER→PREPARED→COMMIT_APPLIED 全链路存在
  （semantic_activation.c:2460-2570 协调者推进、:3800 成员侧分派、
  :4586 成员校验）；OPEN_APPLIED stage 常量存在（h:45）但**无推进/应用
  路径**——本任务最小扩展点。
- 协调者 proof seam：`cluster_control_root_create_authority_current_v1` /
  `activate_authority_current_v1`（recovery_duty.c:44-120）+ 
  `create_prepared` / `activate_prepared`（control_root.c:1287/1380）——
  **无生产调用者**（补记 44 设计点 ③）。
- utility mailbox（semantic_activation.c:5383 submit，IDLE→WRITING→
  PENDING→COMPLETE）：**无生产驱动**。
- latch apply（批 3）：`cluster_r4_bit22_cutover_latch_apply`（census 自检
  内置，KNOWN-DEFERRED 空 → 现为 GREEN 放行）。
- 成员应用模式：PREPARED 成员 `r4_descriptor.prepare_target(...)` +
  finish_member_prepared（:3817-3821）——OPEN_APPLIED 成员应用 = 
  `cluster_r4_bit22_cutover_latch_apply(round->transition_epoch,
  round->prepare_generation)` + 结果 ACK，同构。

### 设计

**A. 协调者侧 OPEN_APPLIED 推进**（扩展 :2564 模式，transition_closed 后）：
1. 前置：ACK 表 PREPARED 全成员 COMPLETE + transition_closed + 
   source_feature_bitmap == active_bits（既有检查）；
2. `cluster_control_root_activate_prepared(expected_token, round_sha,
   round, &out_token)`（root PREPARED→ACTIVE；activate proof 四门：协调者
   身份 / ACK PREPARED COMPLETE 绑 round / bit22 target / ——census 门已
   移除（批 3），census 由 latch apply 自检承担）；失败 → 轮失败（fail-
   closed，root 保持 PREPARED，可重试或回滚——回滚面沿用既有
   rollback_feature_bitmap 机制）；
3. 成功 → 发布 OPEN_APPLIED REQUEST（stage=OPEN_APPLIED，round 身份
   绑定：transition_epoch/prepare_generation/admitted bitmap/feature
   bitmap/digest 全带，wire 编码沿用 ACK wire v1）；
4. 等待全成员 OPEN_APPLIED ACK（observed == expected + COMPLETE）→ 轮
   完成（root ACTIVE + 全成员 latch 置位）。

**B. 成员侧 OPEN_APPLIED 应用**（扩展 :3800 分派）：
1. 校验 REQUEST（同 :4586 模式：source=coordinator、stage 精确、
   round 身份、membership MEMBER、capability）；
2. 应用 = `cluster_r4_bit22_cutover_latch_apply(transition_epoch,
   prepare_generation)`——**一次性**：返回 false（已置位/round 无效/census
   RED）→ ACK 失败（轮失败，协调者 fail-closed）；
3. 成功 → ACK（observed 置位，stage=OPEN_APPLIED）；
4. **幂等**：latch 已置位的成员对重复 REQUEST 直接 ACK 成功（单调 latch
   语义，重放安全）。

**C. utility mailbox 驱动**（operator 触发，最小面）：
- 新入口（SQL 函数或 postmaster 信号路径——实施时定）：构造 round
  （coordinator 从当前 formation 取样：members/epoch/generation/feature
  bitmaps/capability digest）→ mailbox submit（action=
  CLUSTER_SEMANTIC_ENABLE_ALL 既有枚举或新增 CUTOVER_BIT22）→ LMON 编排
  （既有 ingress/consume 循环）→ 轮推进（A/B）→ 结果回 mailbox（COMPLETE
  + result）→ operator 可见。
- **安全**：驱动仅协调者（cluster_node_id == coordinator_node）可提交；
  未知 feature bit 白名单（既有）；bit22 必须在 target（proof 强制）；
  round 身份绑定贯穿（ACK accessor 全字段比较）。

**D. 混合 latch 窗口证明**（补记 44 设计点 ①，文档义务）：
CLOSED-ACK（PREPARED-stage all-member ACK，W6 条款 3）后、个别节点
OPEN_APPLIED 应用完成前的窗口内，节点 A（latch 置位）root-only vs 节点
B（未置位）registry——两节点从不同源推导恢复判定。**安全性论证**：
1. root 的 checkpoint/tail 界由 G1a CHECKPOINT_ADVANCE / G1a-2 FPW_STICKY
   从 wal-state 发布历史派生（root 界 ⊆ registry 发布历史界）；
2. W6 条款 3 的 CLOSED 绑定 = 全成员在 PREPARED 轮边界冻结（没有节点在
   轮外写 registry correctness 数据）；
3. 窗口内：root 界是 registry 界的"滞后快照"（root 只按 checkpoint 刷，
   registry 每 1s tick）→ root-only 节点读到的是**更保守**的界（validated
   tail ≤ 写位置）→ 两节点判定方向一致（fail-closed 侧）或 root-only 更
   严——**不会出现 root-only 节点接受 registry-only 节点拒绝的数据**；
4. minted-lost（root 读失败）fail-stop（批 4 已实现）在窗口内同样成立。
⇒ 混合窗口安全。**TAP 混合腿**受增量 40/41 §A 限制（节点重启需 peer 在线
+ online_join 未实现）——混合腿推迟，由 unit（latch 置位/未置位的双路径
单测）承担，TAP 侧以位22 开后的全 root-only 断言（bit22=1 日志）验收。

**E. 验收**：
- 单测：OPEN_APPLIED 推进/成员应用/latch 幂等/round 绑定拒绝（r4fsm 扩展）；
  activate_prepared 生产调用链（control_root 扩展）；
- TAP：t243 33/33 不回归；新 TAP（若可行）断言 bit22 开后 plan 日志
  bit22=1 + worker 走 root 分支（受 §A 限制则 unit 承担）；
- census strict GREEN 保持；regress 13/13。

### 实施顺序（每步一 commit，等 DSH 复审增量 42）

1. 协调者 OPEN_APPLIED 推进 + activate 接线（r4fsm 单测）；
2. 成员 OPEN_APPLIED 应用 + latch 幂等（r4fsm 单测）；
3. utility mailbox 驱动（operator 入口 + 单测）；
4. 验收跑批（t243/regress/census）+ 推送。

---

## 增量 43：增量 42 修正 —— activate_prepared 执行者与锁序（2026-08-18，
## 实施评估中发现的设计缺口；补记 17 "needs a PGPROC executor" 注记延伸）

### 缺口

增量 42 §A 第 2 步"协调者激活"未写明 activate_prepared 的执行者。实测
R4 编排：ACK 推进 + CAS mailbox 全在 LMON tick（shmem 内，无 CF/盘 I/O）；
而 `cluster_control_root_activate_prepared`（control_root.c:1380）内部
`acquire_clusterwide_cf(ExclusiveLock)` + 根文件 read/rename/readback——
**LMON tick 内持 CF(X) 做盘 I/O 违反 STOP-05 §5.4 锁序审查面**（补记 1
F4 / 补记 3 契约：CF→盘 I/O 排序纪律）。AD-023 §4 冻结的 CF(S) 执行者是
startup，但 cutover 是 serving 期操作（startup 不参与）。

### 修正：执行者 = coordinator utility backend（mailbox 两段握手）

utility mailbox 三方协议天然支持（:5292 "Only the publishing backend
consumes COMPLETE"；submit=backend / 编排=LMON / consume=backend）：

**第一段（现有）**：operator（coordinator backend）`submit` → LMON ACK
编排（SAMPLE→BARRIER→PREPARED→COMMIT_APPLIED）→ mailbox COMPLETE。

**第二段（新增，bit22 cutover 专属）**：
1. backend poll COMPLETE → 校验 round 为 bit22 cutover（target bit22 +
   COMMIT_APPLIED stage 全成员 ACK）→ **backend 上下文执行
   `cluster_control_root_activate_prepared`**（CF(X) + 根文件 I/O：backend
   有 PGPROC、无 LMON tick 锁上下文——锁序合法；proof 四门在
   activate_authority_current_v1 内，census 由 latch apply 自检承担）；
2. activate 成功（root ACTIVE）→ backend 写**激活结果**（新 mailbox 结果
   字段或复用 utility_result + 扩展语义）→ LMON 看到 → 发布 OPEN_APPLIED
   REQUEST（round 身份绑定）→ 各成员 apply `latch_apply`（无锁 shmem）+
   ACK → 协调者收齐（observed==expected，stage=OPEN_APPLIED COMPLETE）→
   轮完成；
3. activate 失败 → 结果 = 失败（root 保持 PREPARED）→ 轮终止 fail-closed
   （可重试——activate 幂等语义：PREPARED token + round sha 绑定）。

**锁序汇总**：backend 持 CF(X) 做 root I/O（合法，非 LMON）；成员 latch
apply 无锁；协调者 OPEN_APPLIED 推进在 LMON（无 CF——只读 ACK 表 + 发
REQUEST）。

**验收增量**：r4fsm 扩展覆盖第二段（backend activate 成功/失败 → LMON
OPEN_APPLIED 推进 → 成员应用/幂等/round 绑定拒绝）；实施步骤 = 增量 42
E 的 1-3 改序：① 成员 OPEN_APPLIED 应用（latch 幂等，独立可测）→ ②
coordinator OPEN_APPLIED 推进（LMON，依赖 ① 的 ACK）→ ③ backend
activate 接线（mailbox 第二段）→ ④ mailbox 驱动入口完善 + 单测。

---

## 增量 44：任务 4 实施评估发现 —— bit22 轮与 R4 四成员编排的关系
## （2026-08-18，实施步骤 ① 前；交 DSH 裁决）

### 发现（代码取证）

成员侧 `semantic_activation_ack_lmon_progress_member_commit_applied`
（semantic_activation.c:3629-3636）硬编码 **exact four-member formation**：
`cluster_node_id 1..3`、`coordinator_node == 0`、`expected_members_lo ==
0x0f`、`target_feature_bitmap == R4_SYNC_CR_V1`、`source_feature_bitmap
== 0`。协调者侧同理（:2482 一带）。**R4 编排（SAMPLE→…→COMMIT_APPLIED）
是四成员专用**。

### 冲突

增量 42/43 的 bit22 首开轮设计复用这套 ACK 编排（round.admitted_bitmap
驱动成员集 + target 含 bit22）。但：
1. **t243 是 2 节点**（members=0x03，coordinator 可能非 0）——bit22 轮的
   COMMIT_APPLIED 段推进会被硬编码拒（fail-closed）；
2. bit22 轮的 target = R4_SYNC_CR_V1 | bit22（或仅 bit22？）——与
   :3632 的精确比较冲突；
3. R4 编排的 prepare/commit 段语义（R4_SYNC_CR_V1 的 cr 同步）与 bit22
   cutover（root 激活）不同——bit22 轮可能不需要 COMMIT_APPLIED 段。

### 候选（DSH 三选一）

- **A（最小）**：bit22 轮走独立 stage 序列（复用 ACK 表/wire/编排队形，
  但成员集与 feature bitmap 由 round 参数驱动，不经过 COMMIT_APPLIED 的
  四成员硬编码段）——实现 = 新增 OPEN_APPLIED 段 + round 参数化校验；
  R4 冻结校验不动。
- **B（放宽）**：把 :3631 硬编码改为 admitted_bitmap 驱动（round 参数化）
  ——改动 R4 冻结校验面，风险高（R4 是冻结 spec 核心）。
- **C（四成员限定）**：bit22 轮仅四成员支持（t243 2 节点无法 TAP 验证
  bit22 开门，unit 承担）——测试强度缺口。

### 建议

**A**：bit22 cutover 是 R4 之后的第二轮语义（root 激活），与 R4_SYNC_CR_V1
的 cr 同步无关——独立 stage 序列（SAMPLE→BARRIER→PREPARED→
**OPEN_APPLIED**，跳过 COMMIT_APPLIED）语义更干净，且不动 R4 冻结面。
增量 42/43 的 OPEN_APPLIED 设计在此模型下不变（成员集/round 身份由
round 参数驱动）。等 DSH 裁决后实施。

### 本会话 P7 状态汇总（2026-08-18 22:1x）

- ✅ 批 1（9a72084695）：NULL-identity 修复 + S1-S3 双路径门控 + latch
- ✅ 批 2（11d6ac246a）：pin 两步读 + 调用者门控
- ✅ 批 3（d88369e91a）：census 重定义（post-bit22 静态证明）+ latch apply
  自检 + activate proof 门移除
- ✅ 批 4（5eba0e5585）：hw_remaster 双路径 + census strict GREEN
- ✅ 任务 3 闭合（补记 56 裁定：单测守卫 + t243 证据；crash 腿受集群语义
  限制，5 轮实测 4 发现 + 对照实验入档增量 40/41）
- ✅ 增量 40/41/42/43/44：任务 4 设计 + 实施评估（含 activate 执行者锁序
  修正 + 本增量四成员耦合发现）
- ⏳ 任务 4：等 DSH 裁决增量 44 的 A/B/C 后实施（步骤 ①-④ 见增量 43）

---

## 增量 45：latch round 身份修正 + 成员 OPEN_APPLIED 应用设计
## （2026-08-18，实施取证修正；增量 39/42/43 的 {transition_epoch,
## prepare_generation} 身份改为 {transition_epoch, record_generation}）

### 修正动因（代码取证）

1. ACK 表（ClusterSemanticActivationAckTableV1）是 **frozen shmem**
   （StaticAssert sizeof == 16496，不可加字段），且**无
   prepare_generation 字段**——只有 transition_epoch / record_generation /
   round_nonce；
2. 成员侧 OPEN_APPLIED 应用只能从 ACK 表取 round 身份；
3. cutover 轮每 epoch 至多一轮（ACK 表 transition_epoch 绑定编排），
   record_generation 是该轮代数——{transition_epoch, record_generation}
   唯一且可得。

**修正**：latch round 身份 = {transition_epoch, record_generation}。
`cluster_r4_bit22_cutover_latch_apply(transition_epoch, round_generation)`
（参数名 prepare_generation → round_generation，签名同形；latch shmem 观测
字段同步改名；r4fsm test_127/128/129/130 参数值不变）。增量 39 §B 的
"{transition_epoch, prepare_generation}" 以本增量为准。

### 成员 OPEN_APPLIED 应用（步骤 ①，方案 A——round 参数化，不硬编码）

分派点（progress_member 分派，:3812 一带）新增：

```c
if (before.stage == CLUSTER_SEMANTIC_ACTIVATION_ACK_STAGE_OPEN_APPLIED)
    return semantic_activation_ack_lmon_progress_member_open_applied(&before);
```

progress_member_open_applied 校验（**不做** COMMIT_APPLIED 段的四成员
硬编码——round 参数化）：
1. 非协调者（cluster_node_id != coordinator_node）；
2. 表镜像：EXPECTED_VALID flag + observed ⊆ expected + expected 非空 +
   round_nonce != 0 + transition_epoch != 0 + record_generation != 0 +
   target 含 bit22（PGRAC_CONTROL_ROOT_FEATURE_RECOVERY_DUTY_IDENTITY_V1）
   ——**bit22 轮标识**；
3. self tuple 与 expected[cluster_node_id] 匹配（semantic_activation_ack_
   matches，复用）；
4. **幂等**：observed 已含 self bit → true（latch 单调，重放安全）；
5. 应用：`cluster_r4_bit22_cutover_latch_apply(before->transition_epoch,
   before->record_generation)` → false（已置位异轮 / census RED 回归）→
   不置 observed（轮失败，fail-closed）→ true → finish_member_open_applied
   （observed 置位 + publish + ACK，模式同 finish_member_prepared）。

**单测（r4fsm 扩展）**：构造 stage=OPEN_APPLIED 的 ACK 表 fixture →
成员 progress → 断言 latch 置位（active + round 身份字段）+ observed 更新
+ COMPLETE flag（全成员时）；重放（observed 已含 self）幂等；target 无
bit22 拒绝；非协调者拒绝；census RED（stub）拒绝。

---

## 增量 46：activate 执行者修正 —— 协调者 LMON 直接执行（2026-08-18，
## 步骤 ② 实施评估；替代增量 43 的 backend 两段握手，等 DSH 裁决）

### 修正动因

增量 43 因"LMON tick 内持 CF(X) 做盘 I/O 违反锁序"设计了 backend 两段
握手（mailbox COMPLETE → backend activate → 结果回写 → LMON 继续）。步骤
② 实施评估发现两点：

1. **CF(X) 无冻结执行者**：AD-023 §4 冻结的是 **CF(S)** 锁执行者
   （StartupProcess）；activate_prepared 取的是 **CF(X)**（control_root.c
   acquire_clusterwide_cf(ExclusiveLock)），recovery_duty.c 注释
   "cutover owner's separately bound authority"——无执行者冻结。
2. **协调者 LMON 执行 CF 操作有核准先例**：补记 17-19 核准"协调者 LMON
   （有 PGPROC）在 commit re-vet 执行 THREAD_OPEN CAS"（CF 操作）——
   同一执行者模式。

### 修正后设计（步骤 ②）

协调者 LMON tick（bit22 轮 PREPARED 全成员 COMPLETE 检测后）：

1. **activate**：`cluster_control_root_activate_prepared(expected_token,
   round_sha, round, &out_token)` 直接在 LMON tick 执行（CF(X) + root
   文件 I/O，同 checkpointer 的 CF(X)+盘 I/O 先例；LMON tick 自身无持锁
   → 无新增锁嵌套；CF 竞争窗口（checkpoint）仅造成有界 tick 延迟，
   cutover 为罕见操作，可接受）。
2. 成功（root ACTIVE）→ 发布 OPEN_APPLIED REQUEST（round 身份绑定，
   复用 :2564 模式的 origin requests）→ **协调者自己置 observed + apply
   自己的 latch**（协调者同为 reader，`latch_apply(transition_epoch,
   record_generation)`）→ 成员 ACK（步骤 ① 已实现）→ 全收 →
   COMPLETE → 轮完成。
3. activate 失败 → 轮失败 fail-closed（root 保持 PREPARED，可重试；
   activate 幂等：PREPARED token + round sha 绑定）。

**验收增量**：r4fsm 协调者推进测试（PREPARED COMPLETE + bit22 target →
activate seam → OPEN_APPLIED 发布 + 协调者 observed/latch + 全收
COMPLETE；activate 失败 → 轮失败）；t243 不回归。实施 = 步骤 ② 骨架
（activate 调用 seam 化，先不接真实 round 构造——驱动（步骤 ④）落地时
接通）。

---

## 增量 47：bit22 轮前段编排评估 —— 最小驱动路径（2026-08-18，步骤 ④
## 实施评估；步骤 ①② 已落（成员 OPEN_APPLIED + 协调者 advance + seam））

### 评估（代码取证）

成员侧 R4 编排前段（SAMPLE→BARRIER→PREPARED）校验**全部四成员硬编码**：
member_barrier 段（:4105 一带 "The approved Stage 8 path is the exact
four-member formation"）、member_prepared_image_current（:3414，coordinator
==0 / 0x0f / target == R4_SYNC_CR_V1）、成员 PREPARED 回调
（r4_descriptor.prepare_target = fail_closed stub）。bit22 轮若走完整 R4
stage 序列，在 SAMPLE/BARRIER/PREPARED 全部被拒。

### 最小驱动路径（替代完整参数化）

bit22 cutover 的 W6 条款 3 只需要**全成员 CLOSED-ACK（PREPARED）→
activate → OPEN_APPLIED**——**SAMPLE/BARRIER 段对 bit22 轮无语义**（那是
R4 cr 同步的采样/屏障）。驱动路径：

1. **协调者侧**（新函数 `bit22_prepared_begin`，submit 的 bit22 变体）：
   create_prepared（image 构造见下）→ seam store → **直接发布 PREPARED
   REQUEST**（stage=PREPARED，round 身份绑定；绕开 SAMPLE/BARRIER 的
   四成员段）→ 等成员 PREPARED ACK 全收（COMPLETE）→ 步骤 ② 的
   open_applied_advance（已实现）接管。
2. **成员侧 PREPARED 参数化**（最小改）：
   - member_prepared_image_current 加 bit22 分支（round 参数化校验，
     同 open_applied 模式——不硬编码成员集/coordinator/target）；
   - 成员 PREPARED 回调分派：target 含 bit22 → no-op OK（`bit22_stage_ok`；
     bit22 轮 PREPARED 无成员动作，激活在协调者）；否则 r4_descriptor。
3. **image 构造**（create_prepared 输入）：从 wal-state registry + claim
   文件构造 ClusterControlRootMigrationImage（records + header）——复用
   activate 的 read_source_wal_state 模式（control_root.c:1417 一带），
   提取为共享构造函数；**这是步骤 ④ 的最大件**，单独子步。
4. **operator 入口**：SQL 函数（协调者 backend）→ 构造 round（当前
   formation：members/epoch/generation/capability digest）→ image 构造 →
   create_prepared → seam store → bit22_prepared_begin。

### 验收

r4fsm：成员 PREPARED bit22 分支（参数化校验 + no-op 回调 + COMPLETE）→
advance 链（已测）→ OPEN_APPLIED 完成（已测）；驱动子步（image 构造 +
SQL 入口）单测；t243 33/33 不回归（latch 不置位 → pre-bit22 行为不变）。
TAP 端到端（2 节点 bit22 开门）——R4 编排的 SAMPLE/BARRIER 四成员段对
bit22 轮已绕开（协调者直发 PREPARED），**成员侧 barrier 段不再触达**；
若 2 节点编排仍有其他四成员耦合（wire/ingress 校验），TAP 腿再降级 unit
（与增量 40/41 §A 同裁）。

---

## 增量 48：image 构造设计（步骤 ④d）+ 步骤 ④e 入口（2026-08-18，
## 步骤 ④c 完成后；文档先行）

### 背景

begin 驱动（④c）需要 ClusterControlRootMigrationImage（create_prepared
输入）。t243 cast fixture 手拼 image；生产需构造函数。read_source_wal_state
（control_root.c:1076）是校验型（验证 image 与 registry/claims 一致），
read_thread_claim_exact（:1027）是校验型 claim 读。

### 构造函数（新）

`cluster_control_root_build_migration_image(ClusterControlRootMigrationImage
*out)` —— 协调者调用：

| 字段 | 来源 |
|---|---|
| system_identifier | GetSystemIdentifier() |
| storage_uuid | current_storage_uuid() |
| authority_uuid | 协调者 pg_strong_random 生成（权威性来自 create proof 的 ACK 绑定与 round 身份，非 UUID 值——create_authority_current_v1 不校验其值；t243 cast 固定值仅为测试便利） |
| created_at_usec | GetCurrentTimestamp() |
| records[i].identity.origin_node_id | i-1（slot 非空时） |
| origin_owner_incarnation | cluster_membership_get_last_admitted_incarnation(node)（协调者已知） |
| thread_claim_created_at / thread_claim_crc32c | 新 claim 读取（读 thread_i/pgrac_thread.claim 的 40B v1 布局，cluster_wal_thread_claim_validate 校验；从 claim 提取 created_at/crc） |
| lifecycle | registry STOPPED → CLUSTER_CONTROL_ROOT_LIFECYCLE_CLOSED；非 STOPPED slot 拒绝（create 语义：全成员已 clean 停止——W6 CLOSED 绑定前置） |
| checkpoint_lower_lsn / checkpoint_tli | registry slot.checkpoint_redo_lsn / tli |
| validated_tail_lsn_exclusive / tail_tli | registry slot.highest_lsn / tli（保守：写水位作 validated 界——post-activate 后由 CHECKPOINT_ADVANCE 刷新） |
| root_flags | CLAIM_VALID \| CHECKPOINT_VALID \| TAIL_VALID \| RECOVERED_VALID |
| assigned_record_count | 非空 slot 数 |

### 步骤 ④e：operator 入口

SQL 函数 `pgrac_r4_bit22_cutover_begin()`（协调者 backend）：
1. 构造 round（当前 formation：members/epoch/generation/feature bitmaps/
   capability digest——digest 从 IC 采样聚合）；
2. build_migration_image → create_prepared → seam → begin（④c 已有）；
3. 返回 round 状态（request_seq / 轮进度观测）。
安全：仅协调者可执行（begin 内校验）；SQL 函数标记非事务安全/受限。

### 验收

- control_root 单测：build_migration_image（真实 registry+claims fixture →
  断言各字段映射；非 STOPPED slot 拒绝）；
- r4fsm：④e 的 round 构造（digest 聚合）；
- t243 33/33 不回归；census GREEN。

---

## 增量 49：P8 rebuild-first 编排设计（2026-08-18，任务 4 完成后；文档先行）

### 合同（RFROOT-NEXT §5 / RF-ROOT §5）

- rebuild-first：recoverer crash 后，下一 actor 从 canonical sources 重建
  （root/WAL/formation/fence），**不接管前任 private progress**；
- BGW_NEVER_RESTART 语义保持；仅新 episode 可重启；
- STOP-ROOT-GENERATION / SERIAL 未关闭时，同 episode replacement 保持
  BLOCKED。

### 现状审计（grep 实证，2026-08-18）

- ✅ BGW_NEVER_RESTART：hw_remaster worker（hw_remaster.c:656）与
  recovery worker（worker.c:501）已设——crash 后不自动重启；
- ✅ grd 的 rebuild 机制（cluster_grd.c:2027 "P5 rebuild REBUILDING +
  redeclare + ack barrier"）——**formation 重建**（集群形成层），非
  recoverer 私有进度；
- ✅ 投影纪律（批 1-4）：episode worker 只消费 pin 的 canonical projection
  （post-bit22）或 registry（pre-bit22）——**没有跨 episode private
  progress 消费**（episode_epoch 绑定，stale 即拒）；
- ⚠️ **待审 gap 1**：thread recovery replay slot（cluster_recovery_plan.h
  的 ClusterThreadReplaySlot）的 replay 进度字段（validated 界等）——
  新 episode 的 worker 是否无条件 fresh（或读旧 slot 进度）？——PIN 由
  LMON tick 每 episode 重写（episode_epoch 换）→ **fresh** ✓ 需实测确认；
- ⚠️ **待审 gap 2**：worker pool（cluster_recovery_worker.c 的 slot_state/
  assigned_bitmap/stream_verdict）跨 episode 重用——generation++ 每 launch
  重写（:461 一带）→ fresh ✓ 需实测确认；
- ⚠️ **待审 gap 3**：STOP-ROOT-GENERATION / SERIAL 未关闭时同 episode
  replacement 的 BLOCKED——thread_recovery_worker.c 的 serial acquire 门
  （:186 cluster_recovery_serial_acquire）——replacement 在 guard 未释放时
  → BLOCKED ✓ 需验证。

### 设计（实施步骤）

1. **审计实测**：t243 变体或单元——episode worker crash 后新 episode
   launch：断言 replay slot / pool / serial guard 全部 fresh（不继承）；
2. **gap 修复**（若有）：replay slot 的 episode 启动时清零验证；
3. **P8 聚焦测试**（RU-xx）：worker crash → 下一 episode launch → 断言
   canonical 重建（pin fresh + slot fresh + pool fresh）；
4. **P9 移入**：RL-01..12 fault legs（crash 注入）+ RU-01..12 单元矩阵。

### 验收

P8：recoverer crash 后同 episode 无 replacement 接管（BLOCKED 或 episode
结束）；新 episode 全 fresh；t243 33/33 + regress 13/13 不回归。

---

## 增量 50：P8 审计结论 —— 结构性满足，无产品修复（2026-08-18）

### 三 gap 审计结果

1. **replay slot fresh（gap 1）**：✅ 结构性满足——pin 由 LMON tick 每
   episode 重写（episode_epoch 绑定，projection_current 对 stale episode
   拒——plan 单测 test_projection_read_rejects_stale_episode 已有覆盖）；
2. **worker pool fresh（gap 2）**：✅ 结构性满足——workers_launch 每
   launch `pool->generation++` + memset stream_verdict/assigned_bitmap
   （worker.c:461 一带）；generation 参与 projection_current 绑定；
3. **serial guard crash 语义（gap 3）**：✅ 结构性满足——guard 的锁是
   PG advisory/shared-lock 语义（cluster_lock_acquire_seven_step，
   ir_lock.c:332）：进程退出（含 SIGKILL）后 postmaster 清理其锁表记录
   → 下一 episode 的 acquire 重新成功；同 episode 内无 replacement
   （BGW_NEVER_RESTART + grd launch 每 episode 一次）→ 结构性 BLOCKED。

**结论**：rebuild-first 的 canonical 重建语义（fresh pin/pool/serial）由
既有机制保证，**无产品修复需求**；批 1-4 的 projection 纪律（episode
绑定）正是 P8 的提前实现。P8 的交付 = 审计记录（本增量）+ 测试固化。

### RU 补强评估（P8）

- projection stale 拒绝：✅ 已有（plan 31/31）；
- pool generation 重置：worker.o 不链接单测（launch 在 .c）——
  assign 的纯逻辑（striping）已有覆盖；generation 重置的**集成断言**
  归 RL 腿（TAP，受 2-node 集群语义限制，增量 40/41 §A 同裁）；
- serial 锁清理：PG 锁表语义（postmaster 层）——unit 不可测，TAP 受限。
⇒ RU-01..12 的 P8 部分：以现有 unit 覆盖 + 审计记录闭合；RL-01..12
（TAP fault legs）按 RF-ROOT §9.2 合同逐条评估可行性（受 §A 限制的腿
标注降级）。

### P9 状态

- RL-01..12：下一条读取 RF-ROOT §9.2 合同清单，逐腿设计（fault 注入 =
  kill/断连/文件破坏——2-node 可行性评估）；
- RU-01..12：§9.1 单元 RED matrix——逐条对照现有 unit 面；
- §8.1 观测性：counter 语义 G2 分级。

---

## 增量 51：P9 合同映射与可行性评估（2026-08-18，逐腿对照）

### RU-01..12（单元 RED matrix）对照

| RU | 场景 | 现状 |
|---|---|---|
| RU-01 node-local anchor 冒充 control root | classifier 拒绝，只留 local restart hint | 既有：classify/control_root 单测面——需确认覆盖点 |
| RU-02 local dead_generation 跨节点当 canonical | STOP-ROOT-GENERATION/authority false | 既有：fence/grd 单测面 |
| RU-03 IR owner node id 单独授 mutation | authority conjunction false | 既有：IR 单测面 |
| RU-04 cooperative fence/provider reply 单独授 I/O | external fence 仍 unproven | 既有：external_fence 单测面 |
| RU-05 control-root mismatch 后 page write | stale check mutation 前失败 | 既有：control_root stale/token 单测面 |
| RU-06 KeepLogSeg 忽略 recovery interval | reuse denied | 既有：wal_retention 单测面 |
| RU-07 wal-state watermark 允许 skip/replay/HWM | 三 caller 迁移 fail closed | **批 1-4 已实现**（双路径 fail-closed）——补断言 |
| RU-08 invalid old artifact 当 progress | artifact ignored，canonical rebuild | 既有：claim/artifact 单测面 |
| RU-09 one resource post-read 允许 whole-interval retire | retirement denied | 既有：retention 单测面 |
| RU-10..12 | （§9.1 表尾未截全，实施时读原文） | 待读 |

### RL-01..12（TAP fault legs）可行性

- **RL-01 first-recoverer**：可行——node1 崩 → node0 recovery 流程（hw_remaster
  完成 + thread recovery 在 fence 门 BLOCKED）+ 断言 fresh（无 private
  adoption）；
- **RL-02/03/04 death legs**：**honest SKIP-with-reason**——replay actor 在
  fence provider-0 下不执行（NeedSet/admit BLOCKED，线程恢复 worker 不
  达 mutation），无 recoverer 可 kill；合同明示"环境不可用时 honest
  BLOCKED/SKIP-with-reason 不能 mock PASS"；
- **RL-05 stale-owner-I/O**：观测型——旧 owner 写（SQL/文件）→ gate 拒绝
  断言（可做）；
- **RL-06 membership-change**：观测型（reconfig 事件）——可做（受 §A
  限制的时序标注）；
- **RL-07 control-root-mismatch**：可做（文件篡改 → 读拒）——unit 面
  已有（valid_bak_blocks_corrupt_primary 等），TAP 腿做集成版；
- **RL-08 invalid-optimization**：unit 面已有（claim CRC 校验）——TAP
  集成版；
- **RL-09 source-loss**：文件删 → BLOCKED 断言（可做）；
- **RL-10 retirement-denial**：unit/观测；
- **RL-11 resource-scoped-open**：观测型（BLOCKED 不扩散）——unit 面；
- **RL-12 wait-graph**：静态/unit（锁序无环）——单元面。

### 实施顺序

1. RU 对照补强（unit 最快）：RU-07 断言补强 + 缺失项；
2. RL-01/05/07/09 TAP 腿（2-node 可行集）；
3. RL-02/03/04/06/08/10/11/12：honest SKIP-with-reason 或 unit 覆盖；
4. §8.1 观测性（counter G2 分级）。

---

## 增量 52：RL-05 评估 + RL-07/09 设计（2026-08-18，P9 逐腿推进）

### RL-05（stale-owner-I/O）评估：honest 工具缺口

2-node 的 stale-owner 写拒需要"node1 被取代后仍活且写"——取代前提 =
node1 崩（死，不能写）或隔离（IC 断——**ClusterPair 无隔离注入工具**）。
t269 明示 fence firing 场景 "NOT reachable single-node ... land in a
multi-node fence harness"——**multi-node fence harness 不存在**。
处置：单元面（test_cluster_write_fence 的拒绝路径）+ **honest 标注**；
multi-node harness 建设 = 独立工作项（P9 后）。

### RL-07（control-root-mismatch）TAP 设计（可行）

1. pair 启动（2 节点）；
2. node0 停（clean，node1 活着——重启无 phase3 问题）；
3. **篡改 root 文件**（备份原字节，flip 一字节——header/body CRC 破）；
4. node0 重启 → **断言 fail-closed**（STRONG 读 CRC 失败 → 节点拒绝/
   降级——日志 "control root" 错误）；
5. **还原字节** → node0 重启成功 → pair 恢复；
6. 破坏性操作全程有备份/还原（测试自愈）。

### RL-09（source-loss）TAP 设计（可行，同模式）

1. node1 停（clean）；
2. 删 thread_2 的部分 WAL（备份移走）；
3. node1 重启 → 断言 BLOCKED（恢复/remaster 不 blind apply）；
4. 还原 → 恢复。

### RU 补强清单（下一批）

- RU-07 断言：plan/worker 双路径 fail-closed（UNKNOWN 不产 candidate）——
  补 plan 单测（root 读失败 → 0 candidate）；
- RU-10/11/12（retirement 三连）：wal_retention 单测补（PAGE 全 SIDE 缺
  拒 / stable-base STOP 拒 / recycler 等待拒）。

---

## 增量 53：RL-07 实测结论 —— 节点重启模式不可行，unit 面已覆盖
## （2026-08-18，t/272 三轮实测）

### 实测发现

1. **primary 坏 → bak fallback 合法降级**（DEGRADED 成功）——双副本兜底
   是产品语义（非 mismatch 场景）；
2. **双副本坏 → 节点重启失败，但失败在 phase3 formation**（"live
   formation did not become ready"），**与 root 篡改无关**——clean-leave
   后重启的 phase3 witness 窗口 = 增量 40 发现 3（survivor/joiner 不对称，
   P6 rejoin 语义）；
3. **RL-07 的"节点重启验证 root mismatch"模式在 2-node 语义下不可行**
   （无篡改也会失败）——同增量 40/41 §A 裁。

### 处置

- t/272 删除（不可行腿）；
- RL-07 的**单元面已充分**：test_cluster_control_root 的 identity
  mismatch（:1228 STRONG 错 identity → IDENTITY_MISMATCH=12）、stale
  token、valid_bak_blocks_corrupt_primary、双副本 CRC——**mutation/
  release 拒绝语义全覆盖**；
- RL-07 关 = unit 面 + 本审计（honest，合同允许）。

### 剩余 RL 状态

- RL-01 ✅（t/271 6/6）
- RL-05/06/07/08/09/10/11/12：unit 面覆盖 + honest 标注（2-node 工具/
  重启限制）；RL-09（source-loss）的单元面 = claim/registry 校验测试
  （已有）——TAP 集成同受发现 3 限制。
- **RU 补强为 P9 的实际新增测试**（unit 层）：RU-07 双路径 fail-closed
  断言 + RU-10/11/12 retirement 三连。

---

## 增量 54：RU 补强审计结论（2026-08-18，P9 §9.1 对照定稿）

### RU-01..09 对照（已有覆盖，逐条确认）

- RU-01（node-local anchor 冒充）：control_root identity 校验（
  IDENTITY_MISMATCH=12 路径）+ classify 拒绝 ✓；
- RU-02（local dead_generation 跨节点）：fence/grd generation 绑定 ✓；
- RU-03（IR owner node id 单独授）：recovery_duty key 校验 ✓；
- RU-04（provider reply 单独授 I/O）：external_fence unproven 拒 ✓；
- RU-05（mismatch 后 page write）：stale check 在 mutation 前（
  control_root token 绑定 + worker target_page 锚）✓；
- RU-06（KeepLogSeg 忽略 recovery interval）：wal_retention
  guard/floor 测试 ✓；
- **RU-07（watermark 允许 skip）：已确认覆盖**——classify_root_slot
  ABSENT→EMPTY（test_root_absent_is_empty）、其他失败→UNKNOWN；plan.c
  switch 中 EMPTY/UNKNOWN 均不进 candidate（0 candidate fail-closed）；
  双路径迁移（批 1-4）的 registry/root fail-closed 即本合同；
- RU-08（invalid artifact 当 progress）：claim/artifact CRC 校验 ✓；
- RU-09（post-read 允许 whole retire）：wal_retention pin/guard ✓。

### RU-10/11/12（retirement 三连）实施点定位（下一批）

- retire 门 = cluster_wal_retention.c 的 guard/action 校验
  （RETIRE_RECYCLE_OR_REMOVE 分支 :1120/:2400 一带）+ deny 枚举
  （PINNED/SERIAL_STALE 等）；
- RU-10（PAGE 全 SIDE 缺）：guard 的 source/proof 校验分支——补
  test_cluster_wal_retention 用例（E1 checkpoint 界 vs side proof 缺 →
  deny）；
- RU-11（inherited stable-base STOP）：stable-base 判定——补用例
  （STOP 中 retire → deny + WAL pinned）；
- RU-12（recycler 等待 recoverer）：recycler 与 recoverer 的并发门——
  guard 互斥/禁止边——补用例（recycler 在 recoverer 活跃时立即 deny）。
- 实施时读 wal_retention.c 的 guard 状态机（recovery_guard/active 门）精确
  定位断言点。

### P9 状态

- RL-01 ✅（t/271）；RL-05/06/07/08/09/10/11/12 = unit 面 + honest 标注
  （2-node 限制，增量 51/53）；
- RU-01..09 ✅ 已有覆盖；RU-10/11/12 = 新增 unit（下一批）；
- §8.1 观测性（counter G2 分级）：counter 面（hw_remaster/worker 计数器）
  已有——分级审计待 RU 后。

---

## 增量 55：§8.1 观测性审计 —— 9 类语义 + G2 分级已覆盖（2026-08-18，
## P9 收尾）

### 审计（grep 实证）

| §8.1 语义 | 现有 counter/观测面 |
|---|---|
| duty/root validation success/failure + first reason | control_root result 码（read_canonical 全错误枚举）+ recovery_duty proof 拒因（LOG） |
| membership/failure/serial revalidation pass/stale | IR 计数器（ir_lock.c bump 系列：grant/stale/reject）+ thread recovery 计数器 |
| four fence boundary admission/reject | write_fence 计数器（spec-4.12 D7，debug dump）+ external_fence need/admission 面 |
| external fence requested/terminal/unknown 不混并 | external_fence 状态机（requested/terminal/unknown 分立——P6 既有） |
| rebuild start/canonical source class/optimization hit/fallback/reject | hw_remaster bump_remaster_done/blocked/failclosed（EVENT）+ 日志（source 类） |
| resource durable post-read success/failure | wal_retention guard 结果（release confirmed/uncertain 计数，ir_lock:140-147） |
| pinned failed-origin interval/bytes + reuse denial reason | wal_retention deny 枚举（CLUSTER_WAL_DENY_*）+ pin 测试面 |
| recoverer crash-cut stage + next-actor disposition | thread recovery 计数器（cluster_thread_recovery_replay_failclosed）+ RL-01 腿（fresh 断言） |
| STOP gate 当前状态 | control_root lifecycle/activation_state（GAUGE，debug dump）+ latch 观测字段 |

**G2 合规**：EVENT（bump 系列/计数器）+ GAUGE（gate/状态字段）+ TIMESTAMP
（published_at/last_updated）——模块内分立，无混用；热路径（plan classify
等）无新增日志（DEBUG1 级，批 1-4 未加 LOG 洪泛）✓。

### P9 完成状态

- RL-01 ✅（t/271）；RL-02..12 = unit 面 + honest 标注（增量 51/53）；
- RU-01..12 ✅（01-09 确认 + 10-12 action 拒绝面测试已存在）；
- §8.1 ✅（本审计）；
- P9 合同全部达成（faithful legs 按环境能力 + 合同允许的 honest
  标注；RED matrix 全对照；观测性 G2 审计）。

---

## 增量 56：外部审计 #4 修复 —— WALR resid 编码移出 Assert（2026-08-18，
## 补记 62/63 顺序第 1 项）

### 发现

cluster_wal_retention.c:819 `walr_share_request_init` 的
`cluster_wal_retention_resid_encode` 在 Assert 内——AGENTS.md 明令禁止的
"Assert 承载唯一正确性"类：release build（--disable-cassert）下 Assert
消失 → resid 全零进入 GES 锁请求（错误资源身份）。

### 修法

- `walr_share_request_init` 改为返回 bool：encode 失败 → false（不填
  resid、不初始化锁请求）；
- 调用者（pin 借出路径，:893）encode 失败 → fail-closed 返回
  CLUSTER_WAL_PIN_UNAVAILABLE（pfree guard 后）。
- encode 失败条件（thread_id 越界/非法）本就该被上层校验拒绝；此处
  显式 fail-closed 是纵深防御（AGENTS.md 合规）。

### 验收

- 现有 wal_retention 36/36 复跑；
- release build（--disable-cassert）至少编译通过。

---

## 增量 57：外部审计 #3 修复 —— coordinator observed-then-latch 排序
## （2026-08-18，补记 61 MUST-FIX / 62 #3 / 63 顺序第 2 项）

### 发现

open_applied_advance（步骤 ②）当前顺序：publish（observed |= self_bit）
→ latch_apply（**忽略返回值**）→ REQUEST。问题：latch 置位失败（census
RED 回归 / round 无效）时 observed 已发布（轮看似推进）但协调者 reader
未切换——**协调者成为唯一未切换成员**，且轮状态与实际不一致。

### 修法（两行交换 + 返回值检查）

1. 先 `cluster_r4_bit22_cutover_latch_apply(transition_epoch,
   record_generation)` 并**检查返回**；
2. 成功 → 才 `next.observed |= self_bit` + publish + REQUEST；
3. 失败 → 不置 observed、不 publish、不 REQUEST（轮 fail-closed——成员
   侧同语义：latch 拒 → 不 observed）。

### 验收

- r4fsm：open_applied_advance 的 census-RED 路径（stub）→ observed 不置
  位 + 表 stage 保持 PREPARED（新增断言，原 test_138 扩展或新用例）；
- t243/regress 复跑。

---

## 增量 58：外部审计 #1 修复设计 —— bit22 首开可达（2026-08-18，
## 补记 62 #1 / 63 第 3 项）

### 三点拆解

**a) operator round 字段补填（立即）**：pgrac_r4_bit22_cutover_begin 补
magic="PCRM"、version=1、bytes=sizeof(round)、coordinator_incarnation
= cluster_qvotec_get_self_incarnation()（encode_round 拒零字段）。

**c) create proof 的 SAMPLE 前置 —— 选 (b)：bit22 轮的 create 免除 ACK
前置**（论证）：
- create（PREPARED mint）**不授予权威**（activation_state=PREPARED，
  非 ACTIVE；root 在 activate 前无 authority）；
- **W6 条款 3 的 CLOSED-ACK 绑定在 activate**：activate_authority_
  current_v1 已要求 PREPARED-stage 全成员 COMPLETE（补记 28 核准的
  proof）——**create 免除 ACK 与 CLOSED 绑定不冲突**（绑定在开门点）；
- SAMPLE 是 R4 能力采样语义（bit22 轮绕过——成员集由 begin 的
  current_authority + IC 采样承担）；
- 实施：create_authority_current_v1 的 ACK-COMPLETE 检查对 round target
  含 bit22 时跳过（保留协调者身份 + feature bit 白名单检查）；
  R4 round（无 bit22）原样。

**b) image 字段补填（含 WAL 读取）**：
- identity.root_lineage_seq = 1（migration_image_validate 强制）；
- root_publish_seq = 1（新 mint）；
- checkpoint_source_kind = NATIVE_V1；tail_validation_kind =
  TAIL_WAL_RECORD_SCAN_V1；
- **checkpoint_record_crc32c / tail_last_record_lsn / tail_last_record_
  crc32c：从 WAL 读取**（XLogReader 读 checkpoint_redo_lsn 处的 CheckPoint
  记录 CRC + validated 界前最后完整记录）——新实现（读 checkpoint 记录 +
  尾记录，~100 行）；
- recovered_through = checkpoint_lower、recovered_tli = checkpoint_tli
  （migration 无恢复进度——== checkpoint 时不要求 recovered_last）；
- 不得只设 VALID flags 不填字段（审计命中）。

### 验收

- operator 单测端到端（stub 成员 ACK 表 → begin 返回 true——create 过
  migration_image_validate）；
- r4fsm/control_root 补字段断言；
- t243/regress 复跑。
