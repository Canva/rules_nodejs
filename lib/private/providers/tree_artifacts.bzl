"""
This module contains providers for working with TreeArtifacts.

See https://github.com/bazelbuild/bazel-skylib/issues/300
(this feature could be upstreamed to bazel-skylib in the future)

These are also called output directories, created by `ctx.actions.declare_directory`.
"""

visibility(["//lib/private"])

DirectoryFilePathInfo = provider(
    doc = "Joins a label pointing to a TreeArtifact with a path nested within that directory.",
    fields = {
        "directory": "a TreeArtifact (ctx.actions.declare_directory)",
        "path": "path relative to the directory",
    },
)
