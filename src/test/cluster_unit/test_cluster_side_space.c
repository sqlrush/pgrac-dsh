/*-------------------------------------------------------------------------
 *
 * test_cluster_side_space.c
 *    RF-SIDE D-SIDE-05 focused unit tests: the canonical space metadata
 *    gates under STOP-RF-SIDE-SPACE-ABI.
 *
 *    RED mapping (spec §5.1 U-SIDE-11/12/18 + §2.5):
 *      - the mutation gate is ALWAYS closed for every space kind, and
 *        the API exposes no config/GUC/test override (U-SIDE-18: the
 *        STOP cannot be overridden);
 *      - the metadata page-version gates delegate to the RF-PAGE §3.2
 *        decision: result-skip only on a trusted exact result,
 *        expected-before apply only on an exact match, everything else
 *        BLOCKED (U-SIDE-12 negative tests);
 *      - canonical HWM semantic tests stay RED (U-SIDE-11): no apply
 *        path may open while the ABI is unapproved.
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "cluster/cluster_side_space.h"

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

static ClusterPageIdentity ut_id;
static ClusterPageVersion ut_v[3];

static void
ut_setup_globals(void)
{
	int			i;

	memset(&ut_id, 0, sizeof(ut_id));
	ut_id.rlocator.spcOid = 1;
	ut_id.rlocator.dbOid = 2;
	ut_id.rlocator.relNumber = 3;
	ut_id.forknum = MAIN_FORKNUM;
	ut_id.blocknum = 7;			/* a canonical HWM/extent/bitmap page */

	for (i = 0; i < 3; i++) {
		memset(&ut_v[i], 0, sizeof(ut_v[i]));
		ut_v[i].identity = ut_id;
		ut_v[i].incarnation = 7;
		ut_v[i].token = (uint64) (100 + i);
	}
}

UT_TEST(test_mutation_gate_always_closed)
{
	/* U-SIDE-18: STOP-RF-SIDE-SPACE-ABI cannot be overridden — the gate
	 * is unconditionally closed for every kind, and there is no
	 * parameter in the API that could open it. */
	UT_ASSERT(!cluster_side_space_metadata_mutation_allowed(
				  CLUSTER_SIDE_SPACE_HWM));
	UT_ASSERT(!cluster_side_space_metadata_mutation_allowed(
				  CLUSTER_SIDE_SPACE_EXTENT));
	UT_ASSERT(!cluster_side_space_metadata_mutation_allowed(
				  CLUSTER_SIDE_SPACE_BITMAP));
	UT_ASSERT(!cluster_side_space_metadata_mutation_allowed(
				  (ClusterSideSpaceKind) 99));
}

UT_TEST(test_metadata_page_verdict_gates)
{
	ClusterSideSpaceKind kinds[] = {
		CLUSTER_SIDE_SPACE_HWM,
		CLUSTER_SIDE_SPACE_EXTENT,
		CLUSTER_SIDE_SPACE_BITMAP
	};
	int			i;

	for (i = 0; i < (int) lengthof(kinds); i++) {
		ClusterSideSpaceKind kind = kinds[i];

		/* U-SIDE-12: expected-before exact match -> one APPLY. */
		UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
						 kind, &ut_v[0], &ut_v[0], &ut_v[1], NULL),
					 (int) CLUSTER_PAGE_APPLY_APPLY);
		/* Trusted exact result -> SKIP. */
		UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
						 kind, &ut_v[0], &ut_v[2], &ut_v[1], &ut_v[1]),
					 (int) CLUSTER_PAGE_APPLY_SKIP);
		/* Mismatch / numeric-higher never applies nor skips. */
		UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
						 kind, &ut_v[0], &ut_v[2], &ut_v[1], NULL),
					 (int) CLUSTER_PAGE_APPLY_BLOCKED);
		UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
						 kind, &ut_v[0], &ut_v[2], &ut_v[1], &ut_v[2]),
					 (int) CLUSTER_PAGE_APPLY_BLOCKED);
		/* Invalid inputs fail closed. */
		UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
						 kind, NULL, &ut_v[0], &ut_v[1], NULL),
					 (int) CLUSTER_PAGE_APPLY_BLOCKED);
	}
	/* Bad kind fails closed. */
	UT_ASSERT_EQ((int) cluster_side_space_metadata_page_verdict(
					 (ClusterSideSpaceKind) 99, &ut_v[0], &ut_v[0], &ut_v[1],
					 NULL),
				 (int) CLUSTER_PAGE_APPLY_BLOCKED);
}

int
main(void)
{
	UT_PLAN(2);

	ut_setup_globals();

	UT_RUN(test_mutation_gate_always_closed);
	UT_RUN(test_metadata_page_verdict_gates);

	UT_DONE();
	return ut_failed_count == 0 ? 0 : 1;
}
