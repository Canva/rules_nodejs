"""
LinkablePackageInfo module
"""

visibility(["//lib/private"])

LinkablePackageInfo = provider(
    doc = "The LinkablePackageInfo provider provides information to the linker for linking pkg_npm built packages",
    fields = {
        "files": "Depset of files in this package (must all be contained within path)",
        "package_name": """
            The package name.

            This field is optional. If not set, the target can be made linkable to a package_name with the npm_link rule.
        """,
        "package_path": """
            The directory in the workspace to link to.

            If set, link the 1st party dependencies to the node_modules under the package path specified.
            If unset, the default is to link to the node_modules root of the workspace.
        """,
        "path": """
            The path to link to.

            Path must be relative to execroot/wksp. It can either an output dir path such as,

            `bazel-out/<platform>-<build>/bin/path/to/package` or
            `bazel-out/<platform>-<build>/bin/external/external_wksp>/path/to/package`

            or a source file path such as,

            `path/to/package` or
            `external/<external_wksp>/path/to/package`
        """,
        # TODO(4.0): In a future major release, ts_library will get a package_name attribute to enable the linker
        # and the _tslibrary special case can be removed.
        # This is planned for 4.0: https://github.com/bazelbuild/rules_nodejs/issues/2450.
        "_tslibrary": "For internal use only",
    },
)
