#!/bin/bash
#-------------------------------------------------------------------------
#
# check-wal-state-correctness-census.sh
#    CI helper: static census of wal-state registry correctness
#    reader/writer call sites (RF-ROOT P7 G4 / STOP-01 §17.9).
#
#    After bit22 (PGRAC_CONTROL_ROOT_FEATURE_RECOVERY_DUTY_IDENTITY_V1)
#    opens, EVERY wal-state correctness reader/writer must be statically
#    unreachable — the canonical control root carries the checkpoint/tail/
#    FPW bounds (CHECKPOINT_ADVANCE + FPW_STICKY publications), and the
#    registry is telemetry only.  This script is the enforcement gate for
#    the bit22 cutover (G3/G5): it must pass GREEN before the migration
#    round opens bit22.
#
#    The whitelist below is the TELEMETRY-ONLY surface (allowed forever):
#      - W1/W2/W3/W4/W5 writers (cluster_wal_state.c / _rmw unit tests):
#        ACTIVE/STOPPED/telemetry/checkpoint-registry publishes, and the
#        W2 merge_recovered_lsn clear (the retained compatibility bytes).
#      - the xlogrecovery raw_ignored diagnostic LOG (telemetry read).
#      - the R4 migration-image binding (control_root.c:1113 requires
#        merge_recovered_lsn == 0 — the source-zero evidence, not a
#        correctness read).
#
#    KNOWN-DEFERRED (must be closed before bit22 opens; the census stays
#    RED while they exist — the script lists them so the cutover cannot
#    proceed silently):
#      - cluster_hw_remaster.c  validated_min <- registry highest_lsn
#        (episode-worker CF(S) infeasible, hw_remaster evidenced)
#      - cluster_thread_recovery_orchestrator.c window derivation
#        (thread-recovery worker context, same CF(S) constraint)
#      - cluster_recovery_worker.c stream validation
#      - cluster_recovery_plan.c plan generation verdict + SCN ordering
#        (the root has no SCN value field — design decision pending)
#
# IDENTIFICATION
#    scripts/ci/check-wal-state-correctness-census.sh
#
# Author: SqlRush <sqlrush@gmail.com>
#
# Portions Copyright (c) 2026, pgrac contributors
#
# NOTES
#    Strategy: enumerate the production correctness call sites of the
#    wal-state registry read/update APIs and compare against the
#    telemetry whitelist.  `--deferred-ok` prints (not fails) the
#    known-deferred sites; the default (strict) mode is the bit22 gate.
#
#-------------------------------------------------------------------------

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

MODE="${1:-strict}"

# The registry read/update entry points whose call sites this census counts.
APIS='cluster_wal_state_read_slot|cluster_wal_state_update_own'

# Telemetry-only whitelist (file:line-prefix or file).  Every other
# production call site of the APIs above is a census violation.
TELEMETRY_OK=(
	'src/backend/cluster/cluster_wal_state.c'      # the W1-W5 writers themselves
	'src/test/cluster_unit/test_cluster_wal_state'
	'src/test/cluster_unit/test_cluster_wal_state_rmw'
	'src/backend/access/transam/xlogrecovery.c'    # raw_ignored diagnostic LOG only
	'src/backend/access/transam/xlog.c'            # W5a/W5b registry writers + EOR FPW evidence read
	'src/backend/cluster/cluster_control_root.c'   # R4 migration binding (merge_recovered_lsn==0)
	'src/backend/cluster/cluster_stats.c'          # W2/W4 telemetry publishers
	'src/backend/cluster/cluster_recovery_anchor.c' # own-slot ACTIVE/timestamp status read (phase-4 gate)
	'src/backend/cluster/cluster_debug.c'          # observability SRF dump
)

# Known-deferred correctness sites (see header).  Listed explicitly so the
# cutover audit can track them; they must move to the canonical root (or be
# formally retired) before bit22 opens.
DEFERRED=(
	'src/backend/cluster/cluster_hw_remaster.c'
	'src/backend/cluster/cluster_thread_recovery_orchestrator.c'
	'src/backend/cluster/cluster_recovery_worker.c'
	'src/backend/cluster/cluster_recovery_plan.c'
)

violations=0

while IFS=: read -r file line rest; do
	[ -n "$file" ] || continue
	case "$file" in
		src/backend/*|src/test/cluster_unit/*)
			;;
		*)
			continue
			;;
	esac
	ok=0
	for w in "${TELEMETRY_OK[@]}"; do
		case "$file" in
			"$w"*) ok=1 ;;
		esac
		[ "$ok" = 1 ] && break
	done
	if [ "$ok" = 1 ]; then
		continue
	fi
	deferred=0
	for d in "${DEFERRED[@]}"; do
		case "$file" in
			"$d"*) deferred=1 ;;
		esac
		[ "$deferred" = 1 ] && break
	done
	if [ "$deferred" = 1 ]; then
		if [ "$MODE" = "deferred-ok" ]; then
			echo "deferred: $file:$line"
		else
			echo "VIOLATION (deferred, blocks bit22): $file:$line"
			violations=$((violations + 1))
		fi
		continue
	fi
	echo "VIOLATION (unlisted correctness read/write): $file:$line"
	violations=$((violations + 1))
done < <(grep -nE "$APIS" src/backend --include='*.c' -r 2>/dev/null || true)

if [ "$violations" -gt 0 ]; then
	echo "wal-state correctness census: $violations violation(s) — bit22 must NOT open."
	exit 1
fi
echo "wal-state correctness census: clean (all registry call sites are telemetry)."
exit 0
