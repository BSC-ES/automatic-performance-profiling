#!/bin/bash
#####################################################################################################################
# models/nemo/post.sh
# Brief: NEMO post-processing for the scalability tests.
#        Declared in the FILE list of the nemo post jobs so Autosubmit substitutes its %AS variables%
#        and stages it in the log directory as post_<jobname>. post.sh sources it and calls post_nemo.
#####################################################################################################################

# shellcheck source=/dev/null
. %HPCLOGDIR%/post_nemo_${jobname}
