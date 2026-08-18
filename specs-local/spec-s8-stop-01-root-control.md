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
