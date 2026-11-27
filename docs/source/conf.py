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

html_theme = "pydata_sphinx_theme"

# Same theme as the other BSC-ES tool docs (Autosubmit), with the APP section layout.
html_theme_options = {
    "header_links_before_dropdown": 4,
    "show_nav_level": 3,
    "navigation_depth": 3,
    "show_toc_level": 3,
    "use_edit_page_button": True,
    "icon_links": [
        {
            "name": "GitHub",
            "url": "https://github.com/BSC-ES/automatic-performance-profiling",
            "icon": "fa-brands fa-square-github",
            "type": "fontawesome",
        },
    ],
    "navbar_start": ["navbar-logo"],
    "navbar_center": ["navbar-nav"],
    "navbar_end": ["navbar-icon-links"],
    "navbar_persistent": ["search-button", "theme-switcher"],
    "footer_start": ["copyright", "sphinx-version"],
    "footer_end": ["theme-version"],
    "logo": {
        "image_light": "_static/Logo.svg",
        "image_dark": "_static/Logo-dark.svg",
    },
}

html_context = {
    "github_user": "BSC-ES",
    "github_repo": "automatic-performance-profiling",
    "github_version": "master",
    "doc_path": "docs/source/",
}

html_logo = "_static/Logo.svg"
html_sidebars = {"**": ["sidebar-nav-bs"]}

# -- Paths for templates and static files
templates_path = ['_templates']
html_static_path = ['_static']
html_css_files = ['custom.css']

# -- Path setup for source files
source_suffix = '.rst'  # File extension for source files

# -- Ignore external libraries
autodoc_mock_imports = ["tqdm", "paramiko", "networkx"]

nbsphinx_execute = 'always'
