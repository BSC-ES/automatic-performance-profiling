#!/bin/bash
#####################################################################################################################
# noop.sh
# Brief: Trivial no-op job used as a synchronization/gate point in the workflow.
#
# It only exists so that non-FOR jobs can wait on the whole set of FOR-expanded
# (per-arch) jobs, e.g. PREPROCVAR_READY waits on every PREPROCVAR_<ARCH>.
# This avoids nesting a FOR inside another FOR section, which Autosubmit's
# config loader cannot process reliably.
#####################################################################################################################

exit 0
