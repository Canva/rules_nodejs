"""
Install npm packages

Rules to install NodeJS dependencies during WORKSPACE evaluation.
This happens before the first build or test runs, allowing you to use Bazel
as the package manager.
"""

load("//lib/private:repositories/yarn_install/attrs.bzl", "YARN_INSTALL_ATTRS")
load("//lib/private:utils/strings.bzl", "dedent")

visibility(["//lib/private"])

def _create_build_files(rctx, rule_type, node, lock_file, generate_local_modules_build_files):
    rctx.report_progress("Processing node_modules: installing Bazel packages and generating BUILD files")
    if rctx.attr.manual_build_file_contents:
        rctx.file("manual_build_file_contents", rctx.attr.manual_build_file_contents)

    # validate links
    validated_links = {}
    for k, v in rctx.attr.links.items():
        if v.startswith("//"):
            v = "@%s" % v
        if not v.startswith("@"):
            fail("link target must be label of form '@wksp//path/to:target', '@//path/to:target' or '//path/to:target'")
        validated_links[k] = v
    generate_config_json = struct(
        exports_directories_only = rctx.attr.exports_directories_only,
        generate_local_modules_build_files = generate_local_modules_build_files,
        included_files = rctx.attr.included_files,
        links = validated_links,
        package_json = str(rctx.path(rctx.attr.package_json)),
        package_lock = str(rctx.path(lock_file)),
        package_path = rctx.attr.package_path,
        rule_type = rule_type,
        strict_visibility = rctx.attr.strict_visibility,
        workspace = rctx.attr.name,
        workspace_rerooted_path = _WORKSPACE_REROOTED_PATH,
    ).to_json()
    rctx.file("generate_config.json", generate_config_json)
    result = rctx.execute(
        [node, "index.js"],
        # double the default timeout in case of many packages, see #2231
        timeout = 1200,
        quiet = rctx.attr.quiet,
    )
    if result.return_code:
        fail("generate_build_file.ts failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr))

def _add_scripts(rctx):
    rctx.template(
        "pre_process_package_json.js",
        rctx.path(rctx.attr._pre_process_package_json_script),
        {},
    )

    rctx.template(
        "index.js",
        rctx.path(rctx.attr._generate_build_file_script),
        {},
    )

# The directory in the external repository where we re-root the workspace by copying
# package.json, lock file & data files to and running the package manager in the
# folder of the package.json file.
_WORKSPACE_REROOTED_PATH = "_"

# Returns the path to a file within the re-rooted user workspace
# under _WORKSPACE_REROOTED_PATH in this repo rule's external workspace
def _rerooted_workspace_path(rctx, f):
    segments = [_WORKSPACE_REROOTED_PATH]
    if f.package:
        segments.append(f.package)
    segments.append(f.name)
    return "/".join(segments)

# Returns the path to the package.json directory within the re-rooted user workspace
# under _WORKSPACE_REROOTED_PATH in this repo rule's external workspace
def _rerooted_workspace_package_json_dir(rctx):
    return str(rctx.path(_rerooted_workspace_path(rctx, rctx.attr.package_json)).dirname)

def _copy_file(rctx, f):
    to = _rerooted_workspace_path(rctx, f)

    # ensure the destination directory exists
    to_segments = to.split("/")
    if len(to_segments) > 1:
        dirname = "/".join(to_segments[:-1])
        args = ["mkdir", "-p", dirname] if rctx.os.name != "windows" else ["cmd", "/c", "if not exist {dir} (mkdir {dir})".format(dir = dirname.replace("/", "\\"))]
        result = rctx.execute(
            args,
            quiet = rctx.attr.quiet,
        )
        if result.return_code:
            fail("mkdir -p %s failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (dirname, result.stdout, result.stderr))

    # copy the file; don't use the rctx.template trick with empty substitution as this
    # does not copy over binary files properly
    cp_args = ["cp", "-f", rctx.path(f), to] if rctx.os.name != "windows" else ["xcopy", "/Y", str(rctx.path(f)).replace("/", "\\"), "\\".join(to_segments) + "*"]
    result = rctx.execute(
        cp_args,
        quiet = rctx.attr.quiet,
    )
    if result.return_code:
        fail("cp -f {} {} failed: \nSTDOUT:\n{}\nSTDERR:\n{}".format(rctx.path(f), to, result.stdout, result.stderr))

def _symlink_file(rctx, f):
    rctx.symlink(f, _rerooted_workspace_path(rctx, f))

def _copy_data_dependencies(rctx):
    """Add data dependencies to the repository."""
    total = len(rctx.attr.data)
    for i, f in enumerate(rctx.attr.data):
        rctx.report_progress("Copying data dependencies (%s/%s)" % (i, total))
        # Make copies of the data files instead of symlinking
        # as yarn under linux will have trouble using symlinked
        # files as npm file:// packages
        _copy_file(rctx, f)

def _yarn_install_impl(rctx):
    """Core implementation of yarn_install."""

    node = rctx.path(rctx.attr.host_node_bin)
    yarn = rctx.attr.host_yarn_bin

    is_windows_host = rctx.os.name == "windows"

    yarn_args = []

    # Set frozen lockfile as default install to install the exact version from the yarn.lock
    # file. To perform an yarn install use the vendord yarn binary with:
    # `bazel run @nodejs//:yarn install` or `bazel run @nodejs//:yarn install -- -D <dep-name>`
    if rctx.attr.frozen_lockfile:
        yarn_args.append("--frozen-lockfile")

    if not rctx.attr.use_global_yarn_cache:
        yarn_args.extend(["--cache-folder", str(rctx.path("_yarn_cache"))])
    else:
        # Multiple yarn rules cannot run simultaneously using a shared cache.
        # See https://github.com/yarnpkg/yarn/issues/683
        # The --mutex option ensures only one yarn runs at a time, see
        # https://yarnpkg.com/en/docs/cli#toc-concurrency-and-mutex
        # The shared cache is not necessarily hermetic, but we need to cache downloaded
        # artifacts somewhere, so we rely on yarn to be correct.
        yarn_args.extend(["--mutex", "network"])
    yarn_args.extend(rctx.attr.args)

    # Run the package manager in the package.json folder
    root = str(rctx.path(_rerooted_workspace_package_json_dir(rctx)))

    # The entry points for npm install for osx/linux and windows
    if not is_windows_host:
        # Prefix filenames with _ so they don't conflict with the npm packages.
        # Unset YARN_IGNORE_PATH before calling yarn incase it is set so that
        # .yarnrc yarn-path is followed if set. This is for the case when calling
        # bazel from yarn with `yarn bazel ...` and yarn follows yarn-path in
        # .yarnrc it will set YARN_IGNORE_PATH=1 which will prevent the bazel
        # call into yarn from also following the yarn-path as desired.
        rctx.file(
            "_yarn.sh",
            content = dedent("""
                #!/usr/bin/env bash
                # Immediately exit if any command fails.
                set -e
                unset YARN_IGNORE_PATH
                (cd "{root}"; "{yarn}" {yarn_args})
            """).format(
                root = root,
                yarn = rctx.path(yarn),
                yarn_args = " ".join(yarn_args),
            ),
            executable = True,
        )
    else:
        rctx.file(
            "_yarn.cmd",
            content = dedent("""
                @echo off
                set "YARN_IGNORE_PATH="
                cd /D "{root}" && "{yarn}" {yarn_args}
            """).format(
                root = root,
                yarn = rctx.path(yarn),
                yarn_args = " ".join(yarn_args),
            ),
            executable = True,
        )

    _symlink_file(rctx, rctx.attr.yarn_lock)
    _copy_file(rctx, rctx.attr.package_json)
    _copy_data_dependencies(rctx)
    _add_scripts(rctx)

    result = rctx.execute(
        [node, "pre_process_package_json.js", rctx.path(rctx.attr.package_json), "yarn"],
        quiet = rctx.attr.quiet,
    )
    if result.return_code:
        fail("pre_process_package_json.js failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr))

    env = dict(rctx.attr.environment)
    env_key = "BAZEL_YARN_INSTALL"
    if env_key not in env.keys():
        env[env_key] = "1"
    # TODO Sort out version, or remove env var
    env["BUILD_BAZEL_RULES_NODEJS_VERSION"] = "----"

    rctx.report_progress("Running yarn install on %s" % rctx.attr.package_json)
    result = rctx.execute(
        [rctx.path("_yarn.cmd" if is_windows_host else "_yarn.sh")],
        timeout = rctx.attr.timeout,
        quiet = rctx.attr.quiet,
        environment = env,
    )
    if result.return_code:
        fail("yarn_install failed: %s (%s)" % (result.stdout, result.stderr))

    result = rctx.execute([
        "find",
        rctx.path("node_modules"),
        "-type",
        "f",
        "-name",
        "*.pyc",
        "-delete",
    ])
    if result.return_code:
        fail("deleting .pyc files failed: %s (%s)" % (result.stdout, result.stderr))
    result = rctx.execute([
        "find",
        rctx.path("node_modules"),
        "-type",
        "f",
        "-name",
        "*.node",
        "-exec",
        "strip",
        "-S",
        "{}",
        ";",
    ])
    if result.return_code:
        fail("stripping .node files failed: %s (%s)" % (result.stdout, result.stderr))

    _create_build_files(rctx, "yarn_install", node, rctx.attr.yarn_lock, rctx.attr.generate_local_modules_build_files)

yarn_install = repository_rule(
    implementation = _yarn_install_impl,
    attrs = YARN_INSTALL_ATTRS,
    environ = [
        "BAZEL_SH",
    ],
    doc = """
        Runs yarn install during workspace setup.

        This rule will set the environment variable `BAZEL_YARN_INSTALL` to '1' (unless it
        set to another value in the environment attribute). Scripts may use to this to
        check if yarn is being run by the `yarn_install` repository rule.
    """,
)
