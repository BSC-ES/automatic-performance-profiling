"""Parse the raw outputs of the performance tests into one JSON per test.

The package is driven by a declarative input mapping (see :mod:`src.mapping`)
that says which file belongs to which case, component and format, so no file name is
ever inspected to decide what it contains.
"""

__version__ = "1.0.0"
