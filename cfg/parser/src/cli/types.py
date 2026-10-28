"""Argument types shared by the commands."""

import argparse
from os.path import isfile


def existing_file(value: str) -> str:
    """Return ``value`` when it is an existing file.

    Args:
        value (str): Path given on the command line.

    Returns:
        str: The path, unchanged.

    Raises:
        argparse.ArgumentTypeError: If the path is not an existing file.
    """
    if not isfile(value):
        raise argparse.ArgumentTypeError(f"path is not a file: '{value}'")
    return value
