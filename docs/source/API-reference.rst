API reference
=============

.. toctree::
   :titlesonly:
   :hidden:

   code/parsers
   code/curation
   code/reporter
   code/plotter

In this section, we provide a detailed description of the API of the following modules used by the tool to parse the outputs of the different models and create the resources (plots, tables, etc.) that are displayed in the final report:

- `Parsers <code/parsers.html>`_: This module contains the TimingInformation class that is used to parse the outputs of the different models and generate a standarized JSON dictionary.
- `Curation <code/curation.html>`_: This module contains the functions to generate the plots and tables that are displayed in the final report from the JSON created by the TimingInformation class.
- `Reporter <code/reporter.html>`_: This module contains the ReportGenerator class that is used to generate the final report in LaTeX format.   
- `Plotter <code/plotter.html>`_: This module contains a set of functions that are used to generate the plots that are displayed in the final report.

