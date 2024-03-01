"""
"""

visibility(["//lib/private"])

def _impl(ctx):
    pass

yarn_install = rule(
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
        "data": attr.label_list(),
        "hoisted_packages": attr.string_list(
            doc = """
                Direct dependencies and hoisted indirect dependencies that will appear in `node_modules`.

                This is a list of package names, not paths. For example, `["react", "react-dom"]`.
                This enables input granularity in conjunction with other rules.
            """,
        ),
        "quiet": attr.bool(
            default = True,
            doc = "Hides output, except in the event of install failure.",
        ),
    },
    doc = "",
)

# node_modules components are pulled out via `directory_path` rules, or at least a forked version that supports dependencies.
