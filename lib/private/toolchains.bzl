"""
Toolchain implementations.
"""

load("//lib/private:providers.bzl", "NodeInfo")

visibility(["//", "//lib"])

# Avoid using non-normalized paths (workspace/../other_workspace/path)
def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _node_toolchain_impl(ctx):
    target_tool = ctx.attr.target_tool

    tool_files = target_tool.files.to_list()
    target_tool_path = _to_manifest_path(ctx, tool_files[0])

    return [
        platform_common.ToolchainInfo(
            nodeinfo = NodeInfo(
                target_tool = target_tool,
                tool_files = tool_files,
            ),
        ),
        # Make the $(NODE_PATH) variable available in places like genrules.
        # See https://docs.bazel.build/versions/master/be/make-variables.html#custom_variables
        platform_common.TemplateVariableInfo({
            "NODE_PATH": target_tool_path,
        }),
    ]

node_toolchain = rule(
    implementation = _node_toolchain_impl,
    attrs = {
        "target_tool": attr.label(
            doc = "A hermetically downloaded nodejs executable target for the target platform.",
            mandatory = True,
            allow_single_file = True,
        ),
    },
    doc = """
        Defines a node toolchain.

        For usage see https://docs.bazel.build/versions/master/toolchains.html#defining-toolchains.
    """,
)
