"""
Defines a repository rule for configuring the node executable.
"""

visibility(["//lib/private"])

def _impl(rctx):
    if rctx.attr.target_tool and rctx.attr.target_tool_path:
        fail("Can only set one of target_tool or target_tool_path but both where set.")

    if rctx.attr.target_tool:
        substitutions = {"%{TOOL_ATTRS}": "    target_tool = \"%s\"\n" % rctx.attr.target_tool}
    else:
        if rctx.attr.target_tool_path:
            default_tool_path = rctx.attr.target_tool_path
        else:
            default_tool_path = rctx.which("node")
            if not default_tool_path:
                fail("No node found on local path. node must available on the PATH or target_tool_path must be provided")
        substitutions = {"%{TOOL_ATTRS}": "    target_tool_path = \"%s\"\n" % default_tool_path}

    rctx.template(
        "BUILD.bazel",
        rctx.attr._build_file_template,
        substitutions,
        False,
    )

nodejs_toolchain_configure = repository_rule(
    implementation = _impl,
    attrs = {
        "target_tool": attr.string(
            doc = "Target for a downloaded nodejs binary for the target os.",
            mandatory = False,
        ),
        "target_tool_path": attr.string(
            doc = "Absolute path to a pre-installed nodejs binary for the target os.",
            mandatory = False,
        ),
        "_build_file_template": attr.label(
            default = "//lib/private:repositories/nodejs_toolchain_configure/BUILD.bazel.tpl",
        ),
    },
    doc = "Creates an external repository with a node_toolchain //:toolchain target properly configured.",
)
