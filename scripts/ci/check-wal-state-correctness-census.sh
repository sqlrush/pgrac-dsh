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
#    CLOSED (2026-08-18, increment 28 / 补记 32): cluster_recovery_plan.c
#    migrated to the canonical control root (verdict + liveness, scheme A);
#    its registry read is gone.
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
# G1b step 4 site 1 (2026-08-18, increment 28): cluster_recovery_plan.c was
# migrated to the canonical control root (verdict + liveness, 补记 32 scheme
# A) and removed from this list — its registry read is gone.
DEFERRED=(
	'src/backend/cluster/cluster_recovery_worker.c'
	'src/backend/cluster/cluster_hw_remaster.c'
	'src/backend/cluster/cluster_thread_recovery_orchestrator.c'
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

# Lockstep check: the runtime mirror table in cluster_wal_state.c
# (cluster_wal_state_correctness_census_ok) must list EXACTLY the same
# deferred sites as this script's DEFERRED list.  Closing a deferred site
# removes it from both in the same commit; a mismatch means the runtime gate
# and the static census disagree about whether bit22 may open.
CENSUS_TABLE='src/backend/cluster/cluster_wal_state.c'
if [ -f "$CENSUS_TABLE" ]; then
	table_sites=$(sed -n '/cluster_wal_state_census_deferred_sites\[\]/,/^};/p' "$CENSUS_TABLE" \
		| grep -oE '"[a-z_./]+\.c"' | tr -d '"' || true)
	# The script's DEFERRED entries carry src/... paths; the runtime table
	# uses basenames — compare normalized basenames.
	script_sites=$(printf '%s\n' "${DEFERRED[@]}" | sed 's#^.*/##' | grep -v '^$' || true)
	table_diff=$(comm -3 <(printf '%s\n' $table_sites | sort) \
		<(printf '%s\n' "$script_sites" | sort))
	if [ -n "$table_diff" ]; then
		echo "VIOLATION (lockstep drift between the runtime census table and the script DEFERRED list):"
		printf '%s\n' "$table_diff" | sed 's/^/  /'
		echo "bit22 must NOT open."
		exit 1
	fi
fi

echo "wal-state correctness census: clean (all registry call sites are telemetry)."
exit 0
