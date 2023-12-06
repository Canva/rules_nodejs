"""
Install NodeJS & Yarn

This is a set of repository rules for setting up hermetic copies of NodeJS and Yarn.
See https://docs.bazel.build/versions/master/skylark/repository_rules.html
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//lib/private:repositories/nodejs_download/attrs.bzl", "ATTRS", "COMMON_ATTRS")
load("//lib/private:repositories/nodejs_download/data/node_versions.bzl", "NODE_VERSIONS")
load("//lib/private:repositories/nodejs_download/data/yarn_versions.bzl", "YARN_VERSIONS")
load("//lib/private:utils/platform.bzl", "get_platform")
load("//lib/private:utils/strings.bzl", "dedent")

visibility(["//lib/private"])

_YARN_VERSIONS = YARN_VERSIONS

_DOC = """
    To be run in user's WORKSPACE to install rules_nodejs dependencies.

    This rule sets up node, npm, and yarn. The versions of these tools can be specified in one of three ways

    ### Simplest Usage

    Specify no explicit versions. This will download and use the latest NodeJS & Yarn that were available when the
    version of rules_nodejs you're using was released.
    Note that you can skip calling `node_repositories` in your WORKSPACE file - if you later try to `yarn_install` or `npm_install`,
    we'll automatically select this simple usage for you.

    ### Forced version(s)

    You can select the version of NodeJS and/or Yarn to download & use by specifying it when you call node_repositories,
    using a value that matches a known version (see the default values)

    ### Using a custom version

    You can pass in a custom list of NodeJS and/or Yarn repositories and URLs for node_resositories to use.

    #### Custom NodeJS versions

    To specify custom NodeJS versions, use the `node_repositories` attribute

    ```starlark
    node_repositories(
        node_repositories = {
            "10.10.0-darwin_amd64": ("node-v10.10.0-darwin-x64.tar.gz", "node-v10.10.0-darwin-x64", "00b7a8426e076e9bf9d12ba2d571312e833fe962c70afafd10ad3682fdeeaa5e"),
            "10.10.0-linux_amd64": ("node-v10.10.0-linux-x64.tar.xz", "node-v10.10.0-linux-x64", "686d2c7b7698097e67bcd68edc3d6b5d28d81f62436c7cf9e7779d134ec262a9"),
            "10.10.0-windows_amd64": ("node-v10.10.0-win-x64.zip", "node-v10.10.0-win-x64", "70c46e6451798be9d052b700ce5dadccb75cf917f6bf0d6ed54344c856830cfb"),
        },
    )
    ```

    These can be mapped to a custom download URL, using `node_urls`

    ```starlark
    node_repositories(
        node_version = "10.10.0",
        node_repositories = {"10.10.0-darwin_amd64": ("node-v10.10.0-darwin-x64.tar.gz", "node-v10.10.0-darwin-x64", "00b7a8426e076e9bf9d12ba2d571312e833fe962c70afafd10ad3682fdeeaa5e")},
        node_urls = ["https://mycorpproxy/mirror/node/v{version}/{filename}"],
    )
    ```

    A Mac client will try to download node from `https://mycorpproxy/mirror/node/v10.10.0/node-v10.10.0-darwin-x64.tar.gz`
    and expect that file to have sha256sum `00b7a8426e076e9bf9d12ba2d571312e833fe962c70afafd10ad3682fdeeaa5e`

    #### Custom Yarn versions

    To specify custom Yarn versions, use the `yarn_repositories` attribute

    ```starlark
    node_repositories(
        yarn_repositories = {
            "1.12.1": ("yarn-v1.12.1.tar.gz", "yarn-v1.12.1", "09bea8f4ec41e9079fa03093d3b2db7ac5c5331852236d63815f8df42b3ba88d"),
        },
    )
    ```

    Like `node_urls`, the `yarn_urls` attribute can be used to provide a list of custom URLs to use to download yarn

    ```starlark
    node_repositories(
        yarn_repositories = {
            "1.12.1": ("yarn-v1.12.1.tar.gz", "yarn-v1.12.1", "09bea8f4ec41e9079fa03093d3b2db7ac5c5331852236d63815f8df42b3ba88d"),
        },
        yarn_version = "1.12.1",
        yarn_urls = [
            "https://github.com/yarnpkg/yarn/releases/download/v{version}/{filename}",
        ],
    )
    ```

    Will download yarn from https://github.com/yarnpkg/yarn/releases/download/v1.2.1/yarn-v1.12.1.tar.gz
    and expect the file to have sha256sum `09bea8f4ec41e9079fa03093d3b2db7ac5c5331852236d63815f8df42b3ba88d`.

    If you don't use Yarn at all, you can skip downloading it by setting `yarn_urls = []`.

    ### Manual install

    You can optionally pass a `package_json` array to node_repositories. This lets you use Bazel's version of yarn or npm, yet always run the package manager yourself.
    This is an advanced scenario you can use in place of the `npm_install` or `yarn_install` rules, but we don't recommend it, and might remove it in the future.

    ```
    load("@build_bazel_rules_nodejs//:index.bzl", "node_repositories")
    node_repositories(package_json = ["//:package.json", "//subpkg:package.json"])
    ```

    Running `bazel run @nodejs//:yarn_node_repositories` in this repo would create `/node_modules` and `/subpkg/node_modules`.

    Note that the dependency installation scripts will run in each subpackage indicated by the `package_json` attribute.
"""

NODE_EXTRACT_DIR = "bin/nodejs"
YARN_EXTRACT_DIR = "bin/yarnpkg"

GET_SCRIPT_DIR = dedent("""
    # From stackoverflow.com
    SOURCE="${BASH_SOURCE[0]}"
    # Resolve $SOURCE until the file is no longer a symlink
    while [ -h "$SOURCE" ]; do
        DIR="$(cd -P "$(dirname "$SOURCE" )" >/dev/null && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        # if $SOURCE was a relative symlink, we need to resolve it relative to the
        # path where the symlink file was located.
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    SCRIPT_DIR="$(cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd)"
""")

def _download_node(repository_ctx):
    """
    Used to download a NodeJS runtime package.

    Args:
      repository_ctx: The repository rule context
    """
    platform = None
    if not hasattr(repository_ctx.attr, "os"):
        # Exclusively for the `@*_host` repository when using workspace-based dependency management
        platform = get_platform(repository_ctx.os.name, repository_ctx.os.arch)
    else:
        platform = get_platform(repository_ctx.attr.os, repository_ctx.attr.arch)

    node_version = repository_ctx.attr.node_version
    node_repositories = repository_ctx.attr.node_repositories

    # We insert our default value here, not on the attribute's default, so it isn't documented.
    # The size of NODE_VERSIONS constant is huge and not useful to document.
    if not node_repositories.items():
        node_repositories = NODE_VERSIONS
    node_urls = repository_ctx.attr.node_urls

    # Download node & npm
    version_host_os = "%s-%s" % (node_version, platform["id"])
    if not version_host_os in node_repositories:
        fail("Unknown NodeJS version-host %s" % version_host_os)
    filename, strip_prefix, sha256 = node_repositories[version_host_os]

    urls = [url.format(version = node_version, filename = filename) for url in node_urls]
    auth = {}
    for url in urls:
        auth[url] = repository_ctx.attr.node_download_auth

    repository_ctx.download_and_extract(
        auth = auth,
        url = urls,
        output = NODE_EXTRACT_DIR,
        stripPrefix = strip_prefix,
        sha256 = sha256,
    )

    repository_ctx.file(
        "node_info",
        content = dedent("""
            # filename: {filename}
            # strip_prefix: {strip_prefix}
            # sha256: {sha256}
        """).format(
            filename = filename,
            strip_prefix = strip_prefix,
            sha256 = sha256,
        ),
    )

def _download_yarn(repository_ctx):
    """
    Used to download a yarn tool package.

    Args:
      repository_ctx: The repository rule context
    """
    yarn_urls = repository_ctx.attr.yarn_urls

    # If there are no URLs to download yarn, skip the download
    if not len(yarn_urls):
        repository_ctx.file("yarn_info", content = "# no yarn urls")
        return

    yarn_version = repository_ctx.attr.yarn_version
    yarn_repositories = repository_ctx.attr.yarn_repositories

    # We insert our default value here, not on the attribute's default, so it isn't documented.
    # The size of _YARN_VERSIONS constant is huge and not useful to document.
    if not yarn_repositories.items():
        yarn_repositories = _YARN_VERSIONS

    if yarn_version in yarn_repositories:
        filename, strip_prefix, sha256 = yarn_repositories[yarn_version]
    else:
        fail("Unknown Yarn version %s" % yarn_version)

    urls = [url.format(version = yarn_version, filename = filename) for url in yarn_urls]

    auth = {}
    for url in urls:
        auth[url] = repository_ctx.attr.yarn_download_auth

    repository_ctx.download_and_extract(
        auth = auth,
        url = urls,
        output = YARN_EXTRACT_DIR,
        stripPrefix = strip_prefix,
        sha256 = sha256,
    )

    repository_ctx.file(
        "yarn_info",
        content = dedent("""
            # filename: {filename}
            # strip_prefix: {strip_prefix}
            # sha256: {sha256}
        """).format(
            filename = filename,
            strip_prefix = strip_prefix,
            sha256 = sha256,
        ),
    )

def _prepare_node(repository_ctx):
    """
    Sets up BUILD files and shell wrappers for the versions of NodeJS, npm & yarn just set up.

    Windows and other OSes set up the node runtime with different names and paths, which we hide away via
    the BUILD file here.
    In addition, we create a bash script wrapper around NPM that passes a given NPM command to all package.json labels
    passed into here.
    Finally, we create a reusable template bash script around NPM that is used by rules like pkg_npm to access
    NPM.

    Args:
      repository_ctx: The repository rule context
    """

    # Exclusively for the `@*_host` repository when using workspace-based dependency management
    is_windows = "windows" == getattr(repository_ctx.attr, "os", repository_ctx.os.name)

    node_path = NODE_EXTRACT_DIR
    node_package = NODE_EXTRACT_DIR

    yarn_path = YARN_EXTRACT_DIR
    yarn_package = YARN_EXTRACT_DIR

    node_bin = ("%s/bin/node" % node_path) if not is_windows else ("%s/node.exe" % node_path)
    node_bin_label = ("%s/bin/node" % node_package) if not is_windows else ("%s/node.exe" % node_package)

    # Use the npm-cli.js script as the bin for osx & linux so there are no symlink issues with `%s/bin/npm`
    npm_bin = ("%s/lib/node_modules/npm/bin/npm-cli.js" % node_path) if not is_windows else ("%s/npm.cmd" % node_path)
    npm_bin_label = ("%s/lib/node_modules/npm/bin/npm-cli.js" % node_package) if not is_windows else ("%s/npm.cmd" % node_package)
    npm_script = ("%s/lib/node_modules/npm/bin/npm-cli.js" % node_path) if not is_windows else ("%s/node_modules/npm/bin/npm-cli.js" % node_path)

    # Use the npx-cli.js script as the bin for osx & linux so there are no symlink issues with `%s/bin/npx`
    npx_bin = ("%s/lib/node_modules/npm/bin/npx-cli.js" % node_path) if not is_windows else ("%s/npx.cmd" % node_path)
    npx_bin_label = ("%s/lib/node_modules/npm/bin/npx-cli.js" % node_package) if not is_windows else ("%s/npx.cmd" % node_package)

    # Use the yarn.js script as the bin for osx & linux so there are no symlink issues with `%s/bin/npm`
    yarn_bin = ("%s/bin/yarn.js" % yarn_path) if not is_windows else ("%s/bin/yarn.cmd" % yarn_path)
    yarn_bin_label = ("%s/bin/yarn.js" % yarn_package) if not is_windows else ("%s/bin/yarn.cmd" % yarn_package)
    yarn_script = "%s/bin/yarn.js" % yarn_path

    entry_ext = ".cmd" if is_windows else ""
    node_entry = "bin/node%s" % entry_ext
    npm_entry = "bin/npm%s" % entry_ext
    yarn_entry = "bin/yarn%s" % entry_ext

    node_bin_relative = paths.relativize(node_bin, "bin")
    npm_script_relative = paths.relativize(npm_script, "bin")
    yarn_script_relative = paths.relativize(yarn_script, "bin")

    if repository_ctx.attr.preserve_symlinks:
        node_args = "--preserve-symlinks"
    else:
        node_args = ""

    # The entry points for node for osx/linux and windows
    if not is_windows:
        # Sets PATH and runs the application
        repository_ctx.file(
            "bin/node",
            content = dedent("""
                #!/usr/bin/env bash
                # Generated by node_repositories.bzl
                # Immediately exit if any command fails.
                set -e
                {get_script_dir}
                export PATH="$SCRIPT_DIR":$PATH
                exec "$SCRIPT_DIR/{node}" {args} "$@"
            """).format(
                get_script_dir = GET_SCRIPT_DIR,
                node = node_bin_relative,
                args = node_args,
            ),
        )
    else:
        # Sets PATH for node, npm & yarn and run user script
        repository_ctx.file(
            "bin/node.cmd",
            content = dedent("""
                @echo off
                SET SCRIPT_DIR=%~dp0
                SET PATH=%SCRIPT_DIR%;%PATH%
                CALL "%SCRIPT_DIR%\\{node}" {args} %*
            """).format(node = node_bin_relative, args = node_args),
        )

    # The entry points for npm for osx/linux and windows
    # Runs npm using appropriate node entry point
    # --scripts-prepend-node-path is set to false since the correct paths
    # for the Bazel entry points of node, npm & yarn are set in the node
    # entry point
    if not is_windows:
        # Npm entry point
        repository_ctx.file(
            "bin/npm",
            content = dedent("""
                #!/usr/bin/env bash
                # Generated by node_repositories.bzl
                # Immediately exit if any command fails.
                set -e
                {get_script_dir}
                "$SCRIPT_DIR/{node}" "$SCRIPT_DIR/{script}" --scripts-prepend-node-path=false "$@"
            """).format(
                get_script_dir = GET_SCRIPT_DIR,
                node = paths.relativize(node_entry, "bin"),
                script = npm_script_relative,
            ),
            executable = True,
        )
    else:
        # Npm entry point
        repository_ctx.file(
            "bin/npm.cmd",
            content = dedent("""
                @echo off
                SET SCRIPT_DIR=%~dp0
                "%SCRIPT_DIR%\\{node}" "%SCRIPT_DIR%\\{script}" --scripts-prepend-node-path=false %*
            """).format(
                node = paths.relativize(node_entry, "bin"),
                script = npm_script_relative,
            ),
            executable = True,
        )

    # This template file is used by the packager tool and the pkg_npm rule.
    # `yarn publish` is not ready for use under Bazel, see https://github.com/yarnpkg/yarn/issues/610
    repository_ctx.file(
        "run_npm.sh.template",
        content = dedent("""
            "{node}" "{script}" TMPL_args "$@"
        """).format(
            node = repository_ctx.path(node_entry),
            script = repository_ctx.path(npm_script),
        ),
    )

    repository_ctx.file(
        "run_npm.bat.template",
        content = dedent("""
            "{node}" "{script}" TMPL_args %*
        """).format(
            node = repository_ctx.path(node_entry),
            script = repository_ctx.path(npm_script),
        ),
    )

    # The entry points for yarn for osx/linux and windows.
    # Runs yarn using appropriate node entry point.
    # Unset YARN_IGNORE_PATH before calling yarn incase it is set so that
    # .yarnrc yarn-path is followed if set. This is for the case when calling
    # bazel from yarn with `yarn bazel ...` and yarn follows yarn-path in
    # .yarnrc it will set YARN_IGNORE_PATH=1 which will prevent the bazel
    # call into yarn from also following the yarn-path as desired.
    if not is_windows:
        # Yarn entry point
        repository_ctx.file(
            "bin/yarn",
            content = dedent("""
                #!/usr/bin/env bash
                # Generated by node_repositories.bzl
                # Immediately exit if any command fails.
                set -e
                unset YARN_IGNORE_PATH
                {get_script_dir}
                "$SCRIPT_DIR/{node}" "$SCRIPT_DIR/{script}" "$@"
            """).format(
                get_script_dir = GET_SCRIPT_DIR,
                node = paths.relativize(node_entry, "bin"),
                script = yarn_script_relative,
            ),
            executable = True,
        )
    else:
        # Yarn entry point
        repository_ctx.file(
            "bin/yarn.cmd",
            content = dedent("""
                @echo off
                SET SCRIPT_DIR=%~dp0
                SET "YARN_IGNORE_PATH="
                "%SCRIPT_DIR%\\{node}" "%SCRIPT_DIR%\\{script}" %*
            """).format(
                node = paths.relativize(node_entry, "bin"),
                script = yarn_script_relative,
            ),
            executable = True,
        )

    # Base BUILD file for this repository
    repository_ctx.file(
        "BUILD.bazel",
        content = dedent("""
            # Generated by node_repositories.bzl
            package(default_visibility = ["//visibility:public"])
            exports_files([
                "run_npm.sh.template",
                "run_npm.bat.template",
                "{node_bin_export}",
                "{npm_bin_export}",
                "{npx_bin_export}",
                "{yarn_bin_export}",
                "{node_entry}",
                "{npm_entry}",
                "{yarn_entry}",
            ])
            alias(name = "node_bin", actual = "{node_bin_label}")
            alias(name = "npm_bin", actual = "{npm_bin_label}")
            alias(name = "npx_bin", actual = "{npx_bin_label}")
            alias(name = "yarn_bin", actual = "{yarn_bin_label}")
            alias(name = "node", actual = "{node_entry}")
            alias(name = "npm", actual = "{npm_entry}")
            alias(name = "yarn", actual = "{yarn_entry}")
            filegroup(
                name = "node_files",
                srcs = [":node", ":node_bin"],
            )
            filegroup(
                name = "yarn_files",
                srcs = glob(["bin/yarnpkg/**"]) + [":node_files"],
            )
            filegroup(
                name = "npm_files",
                srcs = glob(["bin/nodejs/**"]) + [":node_files"],
            )
        """).format(
            node_bin_export = node_bin,
            npm_bin_export = npm_bin,
            npx_bin_export = npx_bin,
            yarn_bin_export = yarn_bin,
            node_bin_label = node_bin_label,
            npm_bin_label = npm_bin_label,
            npx_bin_label = npx_bin_label,
            yarn_bin_label = yarn_bin_label,
            node_entry = node_entry,
            npm_entry = npm_entry,
            yarn_entry = yarn_entry,
        ),
    )

def _nodejs_download_impl(repository_ctx):
    _download_node(repository_ctx)
    _download_yarn(repository_ctx)
    _prepare_node(repository_ctx)

nodejs_download = repository_rule(
    _nodejs_download_impl,
    doc = _DOC,
    attrs = ATTRS,
)

# Exclusively for the `@*_host` repository when using workspace-based dependency management
nodejs_download_host = repository_rule(
    _nodejs_download_impl,
    doc = _DOC,
    attrs = COMMON_ATTRS,
)
