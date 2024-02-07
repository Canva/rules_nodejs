"""
"""

visibility(["//lib/private"])

def _impl(rctx):
    pass
    # 1. Resolve `package.json` and `yarn.lock` paths.

    # 2. Process in their original location using API from forked Yarn.

    # 3. Using data from `hoisted` API, generate `BUILD.bazel` file.
    #    Required targets to match existing API follow.
    #    - `:node_modules`, catch-all target that includes all dependencies.
    #      Rule type: `js_library`.
    #    - `:node_modules/{package_name}`, an alias that allows a subset of outputs to be referenced.
    #      Rule type: NA, source files.
    #    - `[{package_scope}/]{package_name}:{package_name}`, normal way packages are referenced
    #      Rule type: `js_library`.
    #    - `[{package_scope}/]{package_name}:{package_name}__contents`, implementation detail.
    #      Rule type: `js_library`.
    #    - `[{package_scope}/]{package_name}:{package_name}__files`, implementation detail.
    #      Rule type: `filegroup`.
    #    - `[{package_scope}/]{package_name}:{package_name}__typings`, implementation detail.
    #      Rule type: `alias`.
    #    - `[{package_scope}/]{package_name}:{package_name}__umd`, implementation detail, unused.
    #      Rule type: `npm_umd_bundle`.
    #    - `[{package_scope}/]{package_name}:{package_name}__umd_directory_file_path`, implementation detail, unused.
    #      Rule type: `directory_file_path`.

yarn_install_via_action = repository_rule(
    implementation = _impl,
    attrs = {
        "package_json": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "yarn_lock": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "host_node_bin": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
    },
    doc = """
        Parses `package.json` and `yarn.lock`, extracting data required for the `yarn_install` rule.

        The result is similar to the `yarn_install` repository rule when operating in directory mode.
    """,
)
