/*-------------------------------------------------------------------------
 *
 * test_cluster_side_prepared.c
 *    RF-SIDE D-SIDE-03 focused unit tests: the PREPARED/in-doubt binding
 *    and the RECO-style resolution judgements.
 *
 *    RED mapping (spec §5.1 U-SIDE-06/07 + §2.3 + §4):
 *      - IN_DOUBT requires prepare redo + database-scoped durable
 *        pending + matching TT/undo + exact GID/identity — each fact
 *        one-at-a-time missing -> BLOCKED (never a guessed terminal);
 *      - a pending entry that is only origin-local/cache (the caller
 *        declares pending_durable_ok=false) can never carry weight;
 *      - resolution: terminal + exact pending match + side completion
 *        (COMMIT: TT; ROLLBACK: verified undo) all required; premature
 *        abort and terminal-before-prepare are BLOCKED; locks/resources
 *        release only after matching resolution is durable verified.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "cluster/cluster_side_prepared.h"

#include "unit_test.h"

UT_DEFINE_GLOBALS();

void
ExceptionalCondition(const char *conditionName pg_attribute_unused(),
					 const char *fileName pg_attribute_unused(),
					 int lineNumber pg_attribute_unused())
{
	abort();
}

#include <stdio.h>

static ClusterSidePreparedInput
ut_full_prepare(void)
{
	ClusterSidePreparedInput in;

	memset(&in, 0, sizeof(in));
	in.prepare_redo_ok = true;
	in.pending_durable_ok = true;
	in.tt_undo_match = true;
	in.gid_identity_match = true;
	return in;
}

UT_TEST(test_in_doubt_conjunction)
{
	ClusterSidePreparedInput in = ut_full_prepare();

	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(&in),
				 (int) CLUSTER_SIDE_PREPARED_IN_DOUBT);

	/* U-SIDE-06/07: each fact one-at-a-time missing -> BLOCKED. */
	in.prepare_redo_ok = false;
	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(&in),
				 (int) CLUSTER_SIDE_PREPARED_BLOCKED);
	in = ut_full_prepare();
	in.pending_durable_ok = false; /* origin-local/cache only: no weight */
	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(&in),
				 (int) CLUSTER_SIDE_PREPARED_BLOCKED);
	in = ut_full_prepare();
	in.tt_undo_match = false;
	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(&in),
				 (int) CLUSTER_SIDE_PREPARED_BLOCKED);
	in = ut_full_prepare();
	in.gid_identity_match = false; /* same tx, different GID: conflict */
	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(&in),
				 (int) CLUSTER_SIDE_PREPARED_BLOCKED);
	UT_ASSERT_EQ((int) cluster_side_prepared_verdict(NULL),
				 (int) CLUSTER_SIDE_PREPARED_BLOCKED);
}

UT_TEST(test_resolution_ready_conjunction)
{
	ClusterSidePreparedResolveInput in;

	memset(&in, 0, sizeof(in));
	in.terminal_redo_ok = true;
	in.pending_match = true;
	in.tt_undo_complete = true;
	UT_ASSERT(cluster_side_prepared_resolve_ready(&in));

	/* Terminal without the matching pending (terminal-before-prepare):
	 * BLOCKED (§4). */
	in.pending_match = false;
	UT_ASSERT(!cluster_side_prepared_resolve_ready(&in));
	in.pending_match = true;

	/* Premature abort: undo not complete -> BLOCKED (§2.3 last bullet). */
	in.tt_undo_complete = false;
	UT_ASSERT(!cluster_side_prepared_resolve_ready(&in));
	in.tt_undo_complete = true;

	/* Missing terminal redo -> BLOCKED. */
	in.terminal_redo_ok = false;
	UT_ASSERT(!cluster_side_prepared_resolve_ready(&in));
	UT_ASSERT(!cluster_side_prepared_resolve_ready(NULL));
}

int
main(void)
{
	UT_PLAN(2);

	UT_RUN(test_in_doubt_conjunction);
	UT_RUN(test_resolution_ready_conjunction);

	UT_DONE();
	return ut_failed_count == 0 ? 0 : 1;
}
