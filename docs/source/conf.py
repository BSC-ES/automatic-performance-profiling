# Configuration file for the Sphinx documentation builder.

import os
import sys
# Add the package directory to sys.path
sys.path.insert(0, os.path.abspath('../../'))


# -- Project information
project = 'Auto Profiling'
author = 'Roc Salvador Andreazini'
copyright = '2024'
release = '1.0.0'


# -- Master document (index file)
master_doc = 'index'


# -- Extensions and theme
extensions = [
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx_design',
    'sphinx.ext.autosummary',
    'sphinxcontrib.autoprogram',
    'sphinx.ext.autosectionlabel',
]

html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "icon_links": [
        {
            # Label for this link
            "name": "GitLab",
            # URL where the link will redirect
            "url": "https://earth.bsc.es/gitlab/ces/hpc-for-es-team/automatic_performance_profiling",  # required
            # Icon class (if "type": "fontawesome"), or path to local image (if "type": "local")
            "icon": "fa-brands fa-square-gitlab",
            # The type of image to be used (see below for details)
            "type": "fontawesome",
        }
   ]
}

# -- Paths for templates and static files
templates_path = ['_templates']
#html_static_path = ['_static']

# -- Path setup for source files
source_suffix = '.rst'  # File extension for source files

# -- Ignore external libraries
autodoc_mock_imports = ["numpy", "tqdm", "paramiko", "networkx"]

nbsphinx_execute = 'always'
