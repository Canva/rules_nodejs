"""
NodeInfo provider.
"""

visibility(["//lib/private"])

NodeInfo = provider(
    doc = "Information about how to invoke the node executable.",
    fields = {
        "target_tool": "The node executable.",
        "tool_files": """
            Files required in runfiles to make the nodejs executable available.

            May be empty if the target_tool_path points to a locally installed node binary.
        """,
    },
)