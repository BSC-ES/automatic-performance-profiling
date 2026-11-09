# Configuration file for the Sphinx documentation builder.

import os
import sys

source_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(source_dir, "..", ".."))
parser_dir = os.path.join(project_root, "cfg", "parser")
sys.path.insert(0, parser_dir)
sys.path.insert(0, project_root)

if not os.path.isdir(os.path.join(parser_dir, "src")):
    sys.stderr.write(f"[docs] warning: {parser_dir}/src not found, the src.* API pages will be empty\n")


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
    'sphinx.ext.autodoc',
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
autodoc_mock_imports = ["tqdm", "paramiko", "networkx"]

nbsphinx_execute = 'always'
