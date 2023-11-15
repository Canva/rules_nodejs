"""
Attributes for `nodejs_download` repository rule.
"""

visibility(["//lib/private"])

ATTRS = {
    "node_download_auth": attr.string_dict(
        default = {},
        doc = """
            Auth to use for all url requests
            Example: `{"type": "basic", "login": "<UserName>", "password": "<Password>" }`
        """,
    ),
    "node_repositories": attr.string_list_dict(
        doc = """
            Custom list of node repositories to use

            A dictionary mapping NodeJS versions to sets of hosts and their corresponding (filename, strip_prefix, sha256) tuples.
            You should list a node binary for every platform users have, likely Mac, Windows, and Linux.

            By default, if this attribute has no items, we'll use a list of all public NodeJS releases.
        """,
    ),
    "node_urls": attr.string_list(
        default = [
            "https://nodejs.org/dist/v{version}/{filename}",
        ],
        doc = """
            Custom list of URLs to use to download NodeJS

            Each entry is a template for downloading a node distribution.

            The `{version}` parameter is substituted with the `node_version` attribute,
            and `{filename}` with the matching entry from the `node_repositories` attribute.
        """,
    ),
    "node_version": attr.string(
        mandatory = True,
        doc = "The specific version of NodeJS to install or, if vendored_node is specified, the vendored version of node",
    ),
    "package_json": attr.label_list(
        doc = """
            (ADVANCED, not recommended)
            A list of labels, which indicate the package.json files that will be installed
            when you manually run the package manager, e.g. with
            `bazel run @nodejs//:yarn_node_repositories` or `bazel run @nodejs//:npm_node_repositories install`.
            If you use bazel-managed dependencies, you should omit this attribute.
        """,
    ),
    "preserve_symlinks": attr.bool(
        default = True,
        doc = """
            Turn on --node_options=--preserve-symlinks for nodejs_binary and nodejs_test rules.

            When this option is turned on, node will preserve the symlinked path for resolves instead of the default
            behavior of resolving to the real path. This means that all required files must be in be included in your
            runfiles as it prevents the default behavior of potentially resolving outside of the runfiles. For example,
            all required files need to be included in your node_modules filegroup. This option is desirable as it gives
            a stronger guarantee of hermeticity which is required for remote execution.
        """,
    ),
    "vendored_node": attr.label(
        allow_single_file = True,
        doc = """
            The local path to a pre-installed NodeJS runtime.

            If set then also set node_version to the version that of node that is vendored.
        """,
    ),
    "vendored_yarn": attr.label(
        allow_single_file = True,
        doc = "The local path to a pre-installed yarn tool",
    ),
    "yarn_download_auth": attr.string_dict(
        default = {},
        doc = """
            Auth to use for all url requests
            Example: `{"type": "basic", "login": "<UserName>", "password": "<Password>" }`
        """,
    ),
    "yarn_repositories": attr.string_list_dict(
        doc = """
            Custom list of yarn repositories to use.

            Dictionary mapping Yarn versions to their corresponding (filename, strip_prefix, sha256) tuples.

            By default, if this attribute has no items, we'll use a list of all public NodeJS releases.
        """,
    ),
    "yarn_urls": attr.string_list(
        default = [
            "https://github.com/yarnpkg/yarn/releases/download/v{version}/{filename}",
        ],
        doc = """
            Custom list of URLs to use to download Yarn

            Each entry is a template, similar to the `node_urls` attribute, using `yarn_version` and `yarn_repositories` in the substitutions.

            If this list is empty, we won't download yarn at all.
        """,
    ),
    "yarn_version": attr.string(
        doc = "The specific version of Yarn to install",
        mandatory = True,
    ),
    "os": attr.string(
        mandatory = True,
    ),
    "arch": attr.string(
        mandatory = True,
    ),
}