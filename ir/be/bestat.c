/**
 * This file calls the corresponding statistic functions for
 * some backend statistics.
 * $Id$
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef FIRM_STATISTICS

#include "irnode_t.h"
#include "irprintf.h"
#include "irgwalk.h"
#include "irhooks.h"
#include "dbginfo_t.h"
#include "firmstat_t.h"
#include "irtools.h"

#include "bestat.h"
#include "belive_t.h"
#include "besched.h"

/**
 * Collect reg pressure statistics per block and per class.
 */
static void stat_reg_pressure_block(ir_node *block, void *env) {
	be_irg_t         *birg = env;
	const arch_env_t *aenv = birg->main_env->arch_env;
	int i, n = arch_isa_get_n_reg_class(aenv->isa);

	for (i = 0; i < n; i++) {
		const arch_register_class_t *cls = arch_isa_get_reg_class(aenv->isa, i);
		ir_node  *irn;
		pset     *live_nodes = pset_new_ptr(64);
		int       max_live;

		live_nodes = be_liveness_end_of_block(aenv, cls, block, live_nodes);
		max_live   = pset_count(live_nodes);

		sched_foreach_reverse(block, irn) {
			int cnt;

			live_nodes = be_liveness_transfer(aenv, cls, irn, live_nodes);
			cnt        = pset_count(live_nodes);

			max_live = cnt < max_live ? max_live : cnt;
		}

		stat_be_block_regpressure(birg->irg, block, MIN(max_live, 5), cls->name);
	}
}

void be_do_stat_reg_pressure(be_irg_t *birg) {
	if (stat_is_active()) {
		be_liveness(birg->irg);
		/* Collect register pressure information for each block */
		irg_block_walk_graph(birg->irg, stat_reg_pressure_block, NULL, birg);
	}
}

/**
 * Notify statistic module about amount of ready nodes.
 */
void be_do_stat_sched_ready(ir_node *block, nodeset *ready_set) {
	if (stat_is_active()) {
		stat_be_block_sched_ready(get_irn_irg(block), block, nodeset_count(ready_set));
	}
}

/**
 * Pass information about a perm to the statistic module.
 */
void be_do_stat_perm(const char *class_name, int n_regs, ir_node *perm, ir_node *block, int n, int real_size) {
	if (stat_is_active()) {
		stat_be_block_stat_perm(class_name, n_regs, perm, block, n, real_size);
	}
}

/**
 * Pass information about a cycle or chain in a perm to the statistic module.
 */
void be_do_stat_permcycle(const char *class_name, ir_node *perm, ir_node *block, int is_chain, int n_elems, int n_ops) {
	if (stat_is_active()) {
		stat_be_block_stat_permcycle(class_name, perm, block, is_chain, n_elems, n_ops);
	}
}

#else

void (be_do_stat_reg_pressure)(be_irg_t *birg) {}
void (be_do_stat_sched_ready)(ir_node *block, nodeset *ready_set) {}
void (be_do_stat_perm)(const char *class_name, int n_regs, ir_node *perm, ir_node *block, int n, int real_size) {}

#endif /* FIRM_STATISTICS */
