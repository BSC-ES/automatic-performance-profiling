# Configuration file for the Sphinx documentation builder.

import os
import sys
# Add the package directory to sys.path
sys.path.insert(0, os.path.abspath('../../'))


# -- Project information
project = 'Automatic Performance Profiling'
author = 'Roc Salvador Andreazini'
copyright = '2024'
release = '0.1.0'


# -- Master document (index file)
master_doc = 'index'


# -- Extensions and theme
extensions = [
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx_design',
    'sphinx.ext.autosummary',
    'sphinxcontrib.autoprogram',
]
html_theme = 'sphinx_rtd_theme'  # Optional theme


# -- Autoprogram options
autoprogram_options = {
        'ImplementRPEtoSource' : {
            '-i/--input-sources': "path/to/input/sources",
            '-o/--output-sources': "path/to/output/sources"
        }
}


# -- Paths for templates and static files
templates_path = ['_templates']
#html_static_path = ['_static']


# -- Path setup for source files
source_suffix = '.rst'  # File extension for source files


# -- Ignore external libraries
autodoc_mock_imports = ["numpy", "tqdm", "paramiko", "networkx"]

nbsphinx_execute = 'always'
