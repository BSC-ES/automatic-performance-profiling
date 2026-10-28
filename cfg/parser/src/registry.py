"""Registry of the formats the mapping may name.

Adding a model is one module under :mod:`src.models` plus one entry in
``COMPONENT_FORMATS`` and, when it has a conventional format, one entry in
``MODEL_DEFAULT_FORMAT``.
"""

from .formats import dimemas, lucia, paramedir
from .models import icon, ifs, nemo

# Loaders for data that belongs to one component: (entry, case, component) -> dict
COMPONENT_FORMATS = {
    "nemo-timing": nemo.load,
    "ifs-stat": ifs.load,
    "icon-timing": icon.load_timing,
    "icon-timer-report": icon.load_timer_report,
    "paramedir": paramedir.load,
}

# Loaders for data that belongs to the case as a whole: (entry, case, component) -> {case: dict}
CASE_FORMATS = {
    "lucia": lucia.load,
    "dimemas": dimemas.load,
}

ALL_FORMATS = {**COMPONENT_FORMATS, **CASE_FORMATS}

# Format used when the mapping names the component but not the format
MODEL_DEFAULT_FORMAT = {
    "nemo": "nemo-timing",
    "oifs": "ifs-stat",
    "icon": "icon-timer-report",
}
