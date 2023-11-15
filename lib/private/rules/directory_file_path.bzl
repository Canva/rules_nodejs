"""
Workaround to allow referencing a file in a directory output.
"""

load("//lib/private:providers.bzl", "DirectoryFilePathInfo")

visibility(["//lib/private"])

def _directory_file_path(ctx):
    if not ctx.file.directory.is_source and not ctx.file.directory.is_directory:
        fail("directory attribute must be a source directory or created with Bazel declare_directory (TreeArtifact)")
    return [DirectoryFilePathInfo(path = ctx.attr.path, directory = ctx.file.directory)]

directory_file_path = rule(
    doc = """
        Provide DirectoryFilePathInfo to reference some file within a directory.

        Otherwise there is no way to give a Bazel label for it.
    """,
    implementation = _directory_file_path,
    attrs = {
        "directory": attr.label(
            doc = "a directory",
            mandatory = True,
            allow_single_file = True,
        ),
        "path": attr.string(
            doc = "a path within that directory",
            mandatory = True,
        ),
    },
)
