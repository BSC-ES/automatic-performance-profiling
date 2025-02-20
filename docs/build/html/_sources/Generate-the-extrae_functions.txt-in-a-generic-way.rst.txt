
To generate the function list usually we were using the `gthrottling <https://earth.bsc.es/wiki/doku.php?id=computing:howto:functions_throttling>`_ process. Written by Miguel Castrillo and some other guy which is no longer in BSC, it used ``gprof`` to extract a list of function suitable to be used with extrae when tracing functions.

This was a quite long process and sometimes was giving problems (to me). Plus involved the usage of one more tool: so Oriol Tintó suggested that maybe a new workflow could be designed, which was involving just extrae and some bash.

So I developed a bash script, that takes as input the executable you want to profile, and a list of function you would prefer not to trace (they can be communication functions, external libraries, or function that you already know that are of no interest)
The list has the following aspect:

.. code-block::

   iom
   calendar
   iso_c_binding
   lbclnk
   lib_fortran
   lib_mpp

It is just the name of the function, as they appear in the code. It is needed so that we can grep them out when doing an ``nm`` on the executable.

The workflow is the following:


* Generate a trace with just the sampling and the callers enabled (this is the `extrae.xml <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/snippets/68>`_\ )
* With paramedir generate a histogram of function time duration (the configuration used is `sampling_user_function.cfg <https://earth.bsc.es/gitlab/ces/nemo_performance_profile/snippets/67>`_\ )
* Parse the histogram and take function names and  function average duration
* Save info to a file in decreasing order of average time: on every line the function name will be followed by the function duration.
* Output first $n_function lines removing the function not to trace

The number of output function is **hardcoded** inside the script

.. code-block:: bash

   n_functions=80

You can change this behavior adding an input parameter.
