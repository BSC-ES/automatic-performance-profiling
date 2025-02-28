API reference
=============

In this section, we provide a detailed description of the API of the following modules used by the tool to parse the outputs of the different models and create the resources (plots, tables, etc.) that are displayed in the final report:

- Parsers: This module contains the TimingInformation class that is used to parse the outputs of the different models and generate a standarized JSON dictionary.
- Curation: This module contains the functions to generate the plots and tables that are displayed in the final report from the JSON created by the TimingInformation class.

.. toctree::
   :titlesonly:

   code/parsers
   code/curation
   code/reporter
   code/plotter