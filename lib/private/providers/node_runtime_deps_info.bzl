"""
Custom provider that mimics the Runfiles, but doesn't incur the expense of creating the runfiles symlink tree.
"""

visibility(["//lib/private"])

NodeRuntimeDepsInfo = provider(
    doc = """
        Stores runtime dependencies of a nodejs_binary or nodejs_test

        These are files that need to be found by the node module resolver at runtime.

        Historically these files were passed using the Runfiles mechanism.
        However runfiles has a big performance penalty of creating a symlink forest
        with FS API calls for every file in node_modules.
        It also causes there to be separate node_modules trees under each binary. This
        prevents user-contributed modules passed as deps[] to a particular action from
        being found by node module resolver, which expects everything in one tree.

        In node, this resolution is done dynamically by assuming a node_modules
        tree will exist on disk, so we assume node actions/binary/test executions will
        do the same.
    """,
    fields = {
        "deps": "depset of runtime dependency labels",
        "pkgs": "list of labels of packages that provide ExternalNpmPackageInfo",
    },
)
