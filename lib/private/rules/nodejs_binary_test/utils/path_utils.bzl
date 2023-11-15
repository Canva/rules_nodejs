"""
Path utils

Helper functions for path manipulations.
"""

visibility(["//lib/private"])

def strip_external(path):
    return path[len("external/"):] if path.startswith("external/") else path
