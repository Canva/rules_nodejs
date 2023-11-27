# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Install npm packages

Rules to install NodeJS dependencies during WORKSPACE evaluation.
This happens before the first build or test runs, allowing you to use Bazel
as the package manager.

See discussion in the README.
"""

load("//:version.bzl", "VERSION")
load("//internal/common:check_bazel_version.bzl", "check_bazel_version")
load("//internal/common:os_name.bzl", "is_windows_os", "os_name")
load("//internal/node:node_labels.bzl", "get_node_label", "get_npm_label", "get_yarn_label")

COMMON_ATTRIBUTES = dict(dict(), **{
    "data": attr.label_list(
        doc = """Data files required by this rule.

If symlink_node_modules is True, this attribute is optional since the package manager
will run in your workspace folder. It is recommended, however, that all files that the
package manager depends on, such as `.rc` files or files used in `postinstall`, are added
symlink_node_modules is True so that the repository rule is rerun when any of these files
change.

If symlink_node_modules is False, the package manager is run in the bazel external
repository so all files that the package manager depends on must be listed.
""",
    ),
    "environment": attr.string_dict(
        doc = """Environment variables to set before calling the package manager.""",
        default = {},
    ),
    "exports_directories_only": attr.bool(
        default = False,
        doc = """Export only top-level package directory artifacts from node_modules.

Turning this on will decrease the time it takes for Bazel to setup runfiles and sandboxing when
there are a large number of npm dependencies as inputs to an action.

This breaks compatibility for labels that reference files within npm packages such as `@npm//:node_modules/prettier/bin-prettier.js`.
To reference files within npm packages, you can use the `directory_file_path` rule and/or `DirectoryFilePathInfo` provider.
Note, some rules still need upgrading to support consuming `DirectoryFilePathInfo` where needed.

NB: This feature requires runfiles be enabled due to an issue in Bazel which we are still investigating.
    On Windows runfiles are off by default and must be enabled with the `--enable_runfiles` flag when
    using this feature.

NB: `ts_library` does not support directory npm deps due to internal dependency on having all input sources files explicitly specified.

NB: `protractor_web_test` and `protractor_web_test_suite` do not support directory npm deps.

For the `nodejs_binary` & `nodejs_test` `entry_point` attribute (which often needs to reference a file within
an npm package) you can set the entry_point to a dict with a single entry, where the key corresponds to the directory
label and the value corresponds to the path within that directory to the entry point.

For example,

```
nodejs_binary(
    name = "prettier",
    data = ["@npm//prettier"],
    entry_point = "@npm//:node_modules/prettier/bin-prettier.js",
)
```

becomes,

```
nodejs_binary(
    name = "prettier",
    data = ["@npm//prettier"],
    entry_point = { "@npm//:node_modules/prettier": "bin-prettier.js" },
)
```

For labels that are passed to `$(rootpath)`, `$(execpath)`, or `$(location)` you can simply break these apart into
the directory label that gets passed to the expander & path part to follows it.

For example,

```
$(rootpath @npm//:node_modules/prettier/bin-prettier.js")
```

becomes,

```
$(rootpath @npm//:node_modules/prettier)/bin-prettier.js
```
""",
    ),
    "generate_local_modules_build_files": attr.bool(
        default = True,
        doc = """Enables the BUILD files auto generation for local modules installed with `file:` (npm) or `link:` (yarn)

When using a monorepo it's common to have modules that we want to use locally and
publish to an external package repository. This can be achieved using a `js_library` rule
with a `package_name` attribute defined inside the local package `BUILD` file. However,
if the project relies on the local package dependency with `file:` (npm) or `link:` (yarn) to be used outside Bazel, this
could introduce a race condition with both `npm_install` or `yarn_install` rules.

In order to overcome it, a link could be created to the package `BUILD` file from the
npm external Bazel repository (so we can use a local BUILD file instead of an auto generated one),
which require us to set `generate_local_modules_build_files = False` and complete a last step which is writing the
expected targets on that same `BUILD` file to be later used both by `npm_install` or `yarn_install`
rules, which are: `<package_name__files>`, `<package_name__nested_node_modules>`,
`<package_name__contents>`, `<package_name__typings>` and the last one just `<package_name>`. If you doubt what those targets
should look like, check the generated `BUILD` file for a given node module.

When true, the rule will follow the default behaviour of auto generating BUILD files for each `node_module` at install time.

When False, the rule will not auto generate BUILD files for `node_modules` that are installed as symlinks for local modules.
""",
    ),
    "included_files": attr.string_list(
        doc = """List of file extensions to be included in the npm package targets.

NB: This option has no effect when exports_directories_only is True as all files are
automatically included in the exported directory for each npm package.

For example, [".js", ".d.ts", ".proto", ".json", ""].

This option is useful to limit the number of files that are inputs
to actions that depend on npm package targets. See
https://github.com/bazelbuild/bazel/issues/5153.

If set to an empty list then all files are included in the package targets.
If set to a list of extensions, only files with matching extensions are
included in the package targets. An empty string in the list is a special
string that denotes that files with no extensions such as `README` should
be included in the package targets.

This attribute applies to both the coarse `@wksp//:node_modules` target
as well as the fine grained targets such as `@wksp//foo`.
""",
        default = [],
    ),
    "links": attr.string_dict(
        doc = """Targets to link as npm packages.

A mapping of npm package names to bazel targets to linked into node_modules.

If `package_path` is also set, the bazel target will be linked to the node_modules at `package_path`
along with other 3rd party npm packages from this rule.

For example,

```
yarn_install(
    name = "npm",
    package_json = "//web:package.json",
    yarn_lock = "//web:yarn.lock",
    package_path = "web",
    links = {
        "@scope/target": "//some/scoped/target",
        "target": "//some/target",
    },
)
```

creates targets in the @npm external workspace that can be used by other rules which
are linked into `web/node_modules` along side the 3rd party deps since the `project_path` is `web`.

The above links will create the targets,

```
@npm//@scope/target
@npm//target
```

that can be referenced as `data` or `deps` by other rules such as `nodejs_binary` and `ts_project`
and can be required as `@scope/target` and `target` with standard node_modules resolution at runtime,

```
nodejs_binary(
    name = "bin",
    entry_point = "bin.js",
    deps = [
        "@npm//@scope/target",
        "@npm//target"
        "@npm//other/dep"
    ],
)

ts_project(
    name = "test",
    srcs = [...],
    deps = [
        "@npm//@scope/target",
        "@npm//target"
        "@npm//other/dep"
    ],
)
```
""",
    ),
    "manual_build_file_contents": attr.string(
        doc = """Experimental attribute that can be used to override the generated BUILD.bazel file and set its contents manually.

Can be used to work-around a bazel performance issue if the
default `@wksp//:node_modules` target has too many files in it.
See https://github.com/bazelbuild/bazel/issues/5153. If
you are running into performance issues due to a large
node_modules target it is recommended to switch to using
fine grained npm dependencies.
""",
    ),
    "package_json": attr.label(
        mandatory = True,
        allow_single_file = True,
    ),
    "package_path": attr.string(
        default = "",
        doc = """If set, link the 3rd party node_modules dependencies under the package path specified.

In most cases, this should be the directory of the package.json file so that the linker links the node_modules
in the same location they are found in the source tree. In a future release, this will default to the package.json
directory. This is planned for 4.0: https://github.com/bazelbuild/rules_nodejs/issues/2451""",
    ),
    "patch_args": attr.string_list(
        default = ["-p0"],
        doc =
            "The arguments given to the patch tool. Defaults to -p0, " +
            "however -p1 will usually be needed for patches generated by " +
            "git. If multiple -p arguments are specified, the last one will take effect." +
            "If arguments other than -p are specified, Bazel will fall back to use patch " +
            "command line tool instead of the Bazel-native patch implementation. When falling " +
            "back to patch command line tool and patch_tool attribute is not specified, " +
            "`patch` will be used.",
    ),
    "patch_tool": attr.string(
        default = "",
        doc = "The patch(1) utility to use. If this is specified, Bazel will use the specifed " +
              "patch tool instead of the Bazel-native patch implementation.",
    ),
    "post_install_patches": attr.label_list(
        doc = """Patch files to apply after running package manager.

This can be used to make changes to installed packages after the package manager runs.

File paths in patches should be relative to workspace root.

Use with caution when `symlink_node_modules` enabled as the patches will run in your workspace and
will modify files in your workspace.

NB: If `symlink_node_modules` is enabled, the node_modules folder is re-used between executions of the
    repository rule. Patches may be re-applied to files in this case and fail to apply. A marker file
    `node_modules/.bazel-post-install-patches` is left in this mode when patches are applied. When the 
    marker file is detected, patch file failures are treated as WARNINGS. For this reason, it is recommended
    to patch npm packages with an npm tool such as https://www.npmjs.com/package/patch-package when
    `symlink_node_modules` is enabled which handles re-apply patching logic more robustly.""",
    ),
    "pre_install_patches": attr.label_list(
        doc = """Patch files to apply before running package manager.

This can be used to make changes to package.json or other data files passed in before running the
package manager.

File paths in patches should be relative to workspace root.

Not supported with `symlink_node_modules` enabled.""",
    ),
    "quiet": attr.bool(
        default = True,
        doc = "If stdout and stderr should be printed to the terminal.",
    ),
    "strict_visibility": attr.bool(
        default = True,
        doc = """Turn on stricter visibility for generated BUILD.bazel files

When enabled, only dependencies within the given `package.json` file are given public visibility.
All transitive dependencies are given limited visibility, enforcing that all direct dependencies are
listed in the `package.json` file.
""",
    ),
    "symlink_node_modules": attr.bool(
        doc = """Turn symlinking of node_modules on

This requires the use of Bazel 0.26.0 and the experimental
managed_directories feature.

When true, the package manager will run in the package.json folder
and the resulting node_modules folder will be symlinked into the
external repository create by this rule.

When false, the package manager will run in the external repository
created by this rule and any files other than the package.json file and
the lock file that are required for it to run should be listed in the
data attribute.
""",
        default = True,
    ),
    "timeout": attr.int(
        default = 3600,
        doc = """Maximum duration of the package manager execution in seconds.""",
    ),
})

PROXY_ENVVARS = [
    "all_proxy",
    "ALL_PROXY",
    "http_proxy",
    "HTTP_PROXY",
    "https_proxy",
    "HTTPS_PROXY",
    "no_proxy",
    "NO_PROXY",
]

def _apply_pre_install_patches(repository_ctx):
    if len(repository_ctx.attr.pre_install_patches) == 0:
        return
    if repository_ctx.attr.symlink_node_modules:
        fail("pre_install_patches cannot be used with symlink_node_modules enabled")
    _apply_patches(repository_ctx, _WORKSPACE_REROOTED_PATH, repository_ctx.attr.pre_install_patches)

def _apply_post_install_patches(repository_ctx):
    if len(repository_ctx.attr.post_install_patches) == 0:
        return
    if repository_ctx.attr.symlink_node_modules:
        print("\nWARNING: @%s post_install_patches with symlink_node_modules enabled will run in your workspace and potentially modify source files" % repository_ctx.name)
    working_directory = _user_workspace_root(repository_ctx) if repository_ctx.attr.symlink_node_modules else _WORKSPACE_REROOTED_PATH
    marker_file = None
    if repository_ctx.attr.symlink_node_modules:
        marker_file = "%s/node_modules/.bazel-post-install-patches" % repository_ctx.path(repository_ctx.attr.package_json).dirname
    _apply_patches(repository_ctx, working_directory, repository_ctx.attr.post_install_patches, marker_file)

def _apply_patches(repository_ctx, working_directory, patches, marker_file = None):
    bash_exe = repository_ctx.os.environ["BAZEL_SH"] if "BAZEL_SH" in repository_ctx.os.environ else "bash"

    patch_tool = repository_ctx.attr.patch_tool
    if not patch_tool:
        patch_tool = "patch"
    patch_args = repository_ctx.attr.patch_args

    for patch_file in patches:
        if marker_file:
            command = """{patch_tool} {patch_args} < {patch_file}
CODE=$?
if [ $CODE -ne 0 ]; then
    CODE=1
    if [ -f \"{marker_file}\" ]; then
        CODE=2
    fi
fi
echo '1' > \"{marker_file}\"
exit $CODE""".format(
                patch_tool = patch_tool,
                patch_file = repository_ctx.path(patch_file),
                patch_args = " ".join([
                    "'%s'" % arg
                    for arg in patch_args
                ]),
                marker_file = marker_file,
            )
        else:
            command = "{patch_tool} {patch_args} < {patch_file}".format(
                patch_tool = patch_tool,
                patch_file = repository_ctx.path(patch_file),
                patch_args = " ".join([
                    "'%s'" % arg
                    for arg in patch_args
                ]),
            )

        if not repository_ctx.attr.quiet:
            print("@%s appling patch file %s in %s" % (repository_ctx.name, patch_file, working_directory))
            if marker_file:
                print("@%s leaving patches marker file %s" % (repository_ctx.name, marker_file))
        st = repository_ctx.execute(
            [bash_exe, "-c", command],
            quiet = repository_ctx.attr.quiet,
            # Working directory is _ which is where all files are copied to and
            # where the install is run; patches should be relative to workspace root.
            working_directory = working_directory,
        )
        if st.return_code:
            # If return code is 2 (see bash snippet above) that means a marker file was found before applying patches;
            # Treat patch failure as a warning in this case
            if st.return_code == 2:
                print("""\nWARNING: @%s failed to apply patch file %s in %s:\n%s%s
This can happen with symlink_node_modules enabled since your workspace node_modules is re-used between executions of the repository rule.""" % (repository_ctx.name, patch_file, working_directory, st.stderr, st.stdout))
            else:
                fail("Error applying patch %s in %s:\n%s%s" % (str(patch_file), working_directory, st.stderr, st.stdout))

def _create_build_files(repository_ctx, rule_type, node, lock_file, generate_local_modules_build_files):
    repository_ctx.report_progress("Processing node_modules: installing Bazel packages and generating BUILD files")
    if repository_ctx.attr.manual_build_file_contents:
        repository_ctx.file("manual_build_file_contents", repository_ctx.attr.manual_build_file_contents)

    # validate links
    validated_links = {}
    for k, v in repository_ctx.attr.links.items():
        if v.startswith("//"):
            v = "@%s" % v
        if not v.startswith("@"):
            fail("link target must be label of form '@wksp//path/to:target', '@//path/to:target' or '//path/to:target'")
        validated_links[k] = v
    generate_config_json = struct(
        exports_directories_only = repository_ctx.attr.exports_directories_only,
        generate_local_modules_build_files = generate_local_modules_build_files,
        included_files = repository_ctx.attr.included_files,
        links = validated_links,
        package_json = str(repository_ctx.path(repository_ctx.attr.package_json)),
        package_lock = str(repository_ctx.path(lock_file)),
        package_path = repository_ctx.attr.package_path,
        rule_type = rule_type,
        strict_visibility = repository_ctx.attr.strict_visibility,
        workspace = repository_ctx.attr.name,
        workspace_rerooted_path = _WORKSPACE_REROOTED_PATH,
    ).to_json()
    repository_ctx.file("generate_config.json", generate_config_json)
    result = repository_ctx.execute(
        [node, "index.js"],
        # double the default timeout in case of many packages, see #2231
        timeout = 1200,
        quiet = repository_ctx.attr.quiet,
    )
    if result.return_code:
        fail("generate_build_file.ts failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr))

def _add_scripts(repository_ctx):
    repository_ctx.template(
        "pre_process_package_json.js",
        repository_ctx.path(Label("//internal/npm_install:pre_process_package_json.js")),
        {},
    )

    repository_ctx.template(
        "index.js",
        repository_ctx.path(Label("//internal/npm_install:index.js")),
        {},
    )

# The directory in the external repository where we re-root the workspace by copying
# package.json, lock file & data files to and running the package manager in the
# folder of the package.json file.
_WORKSPACE_REROOTED_PATH = "_"

# Returns the root of the user workspace. No built-in way to get
# this but we can derive it from the path of the package.json file
# in the user workspace sources.
def _user_workspace_root(repository_ctx):
    package_json = repository_ctx.attr.package_json
    segments = []
    if package_json.package:
        segments.extend(package_json.package.split("/"))
    segments.extend(package_json.name.split("/"))
    segments.pop()
    user_workspace_root = repository_ctx.path(package_json).dirname
    for i in segments:
        user_workspace_root = user_workspace_root.dirname
    return str(user_workspace_root)

# Returns the path to a file within the re-rooted user workspace
# under _WORKSPACE_REROOTED_PATH in this repo rule's external workspace
def _rerooted_workspace_path(repository_ctx, f):
    segments = [_WORKSPACE_REROOTED_PATH]
    if f.package:
        segments.append(f.package)
    segments.append(f.name)
    return "/".join(segments)

# Returns the path to the package.json directory within the re-rooted user workspace
# under _WORKSPACE_REROOTED_PATH in this repo rule's external workspace
def _rerooted_workspace_package_json_dir(repository_ctx):
    return str(repository_ctx.path(_rerooted_workspace_path(repository_ctx, repository_ctx.attr.package_json)).dirname)

def _is_executable(repository_ctx, path):
    stat_exe = repository_ctx.which("stat")
    if stat_exe == None:
        return False

    # A hack to detect if stat is BSD stat as BSD stat does not support --version flag
    is_bsd_stat = repository_ctx.execute([stat_exe, "--version"]).return_code != 0
    if is_bsd_stat:
        stat_args = ["-f", "%Lp", path]
    else:
        stat_args = ["-c", "%a", path]

    arguments = [stat_exe] + stat_args
    exec_result = repository_ctx.execute(arguments)
    stdout = exec_result.stdout.strip()
    mode = int(stdout, 8)
    return mode & 0o100 != 0

def _copy_file(repository_ctx, f):
    src_path = repository_ctx.path(f)
    dest_path = _rerooted_workspace_path(repository_ctx, f)
    executable = _is_executable(repository_ctx, src_path)

    # Copy the file
    repository_ctx.file(
        dest_path,
        repository_ctx.read(src_path),
        executable = executable,
        legacy_utf8 = False,
    )

def _symlink_file(repository_ctx, f):
    repository_ctx.symlink(f, _rerooted_workspace_path(repository_ctx, f))

def _copy_data_dependencies(repository_ctx):
    """Add data dependencies to the repository."""
    total = len(repository_ctx.attr.data)
    for i, f in enumerate(repository_ctx.attr.data):
        repository_ctx.report_progress("Copying data dependencies (%s/%s)" % (i, total))
        # Make copies of the data files instead of symlinking
        # as yarn under linux will have trouble using symlinked
        # files as npm file:// packages
        _copy_file(repository_ctx, f)

def _add_node_repositories_info_deps(repository_ctx):
    # Add a dep to the node_info & yarn_info files from node_repositories
    # so that if the node or yarn versions change we re-run the repository rule
    repository_ctx.symlink(
        Label("@nodejs_%s//:node_info" % os_name(repository_ctx)),
        repository_ctx.path("_node_info"),
    )
    repository_ctx.symlink(
        Label("@nodejs_%s//:yarn_info" % os_name(repository_ctx)),
        repository_ctx.path("_yarn_info"),
    )

def _symlink_node_modules(repository_ctx):
    package_json_dir = repository_ctx.path(repository_ctx.attr.package_json).dirname
    if repository_ctx.attr.symlink_node_modules:
        repository_ctx.symlink(
            repository_ctx.path(str(package_json_dir) + "/node_modules"),
            repository_ctx.path("node_modules"),
        )
    else:
        repository_ctx.symlink(
            repository_ctx.path(_rerooted_workspace_package_json_dir(repository_ctx) + "/node_modules"),
            repository_ctx.path("node_modules"),
        )

def _check_min_bazel_version(rule, repository_ctx):
    if repository_ctx.attr.symlink_node_modules:
        # When using symlink_node_modules enforce the minimum Bazel version required
        check_bazel_version(
            message = """
        A minimum Bazel version of 0.26.0 is required for the %s @%s repository rule.

        By default, yarn_install and npm_install in build_bazel_rules_nodejs >= 0.30.0
        depends on the managed directory feature added in Bazel 0.26.0. See
        https://github.com/bazelbuild/rules_nodejs/wiki#migrating-to-rules_nodejs-030.

        You can opt out of this feature by setting `symlink_node_modules = False`
        on all of your yarn_install & npm_install rules.
        """ % (rule, repository_ctx.attr.name),
            minimum_bazel_version = "0.26.0",
        )

def _propagate_http_proxy_env(repository_ctx, env):
    """Propagate proxy environment variables if available to repository rule."""
    os_env = repository_ctx.os.environ

    proxy_env = {k: v for k, v in os_env.items() if k in PROXY_ENVVARS}
    return dict(env.items() + proxy_env.items())

def _npm_install_impl(repository_ctx):
    """Core implementation of npm_install."""

    # Mark inputs as dependencies with repository_ctx.path to reduce repo fetch restart costs
    repository_ctx.path(repository_ctx.attr.package_json)
    repository_ctx.path(repository_ctx.attr.package_lock_json)
    for f in repository_ctx.attr.data:
        repository_ctx.path(f)
    node = repository_ctx.path(get_node_label(repository_ctx))
    npm = get_npm_label(repository_ctx)
    repository_ctx.path(Label("//internal/npm_install:pre_process_package_json.js"))
    repository_ctx.path(Label("//internal/npm_install:index.js"))

    _check_min_bazel_version("npm_install", repository_ctx)
    is_windows_host = is_windows_os(repository_ctx)

    # Set the base command (install or ci)
    npm_args = [repository_ctx.attr.npm_command]

    npm_args.extend(repository_ctx.attr.args)

    # Run the package manager in the package.json folder
    if repository_ctx.attr.symlink_node_modules:
        root = str(repository_ctx.path(repository_ctx.attr.package_json).dirname)
    else:
        root = str(repository_ctx.path(_rerooted_workspace_package_json_dir(repository_ctx)))

    # The entry points for npm install for osx/linux and windows
    if not is_windows_host:
        # Prefix filenames with _ so they don't conflict with the npm package `npm`
        repository_ctx.file(
            "_npm.sh",
            content = """#!/usr/bin/env bash
# Immediately exit if any command fails.
set -e
(cd "{root}"; "{npm}" {npm_args})
""".format(
                root = root,
                npm = repository_ctx.path(npm),
                npm_args = " ".join(npm_args),
            ),
            executable = True,
        )
    else:
        repository_ctx.file(
            "_npm.cmd",
            content = """@echo off
cd /D "{root}" && "{npm}" {npm_args}
""".format(
                root = root,
                npm = repository_ctx.path(npm),
                npm_args = " ".join(npm_args),
            ),
            executable = True,
        )

    _symlink_file(repository_ctx, repository_ctx.attr.package_lock_json)
    _copy_file(repository_ctx, repository_ctx.attr.package_json)
    _copy_data_dependencies(repository_ctx)
    _add_scripts(repository_ctx)
    _add_node_repositories_info_deps(repository_ctx)
    _apply_pre_install_patches(repository_ctx)

    result = repository_ctx.execute(
        [node, "pre_process_package_json.js", repository_ctx.path(repository_ctx.attr.package_json), "npm"],
        quiet = repository_ctx.attr.quiet,
    )
    if result.return_code:
        fail("pre_process_package_json.js failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr))

    env = dict(repository_ctx.attr.environment)
    env_key = "BAZEL_NPM_INSTALL"
    if env_key not in env.keys():
        env[env_key] = "1"
    env["BUILD_BAZEL_RULES_NODEJS_VERSION"] = VERSION

    env = _propagate_http_proxy_env(repository_ctx, env)

    # NB: after running npm install, it's essential that we don't cause the repository rule to restart
    # This means we must not reference any additional labels after this point.
    # See https://github.com/bazelbuild/rules_nodejs/issues/2620
    repository_ctx.report_progress("Running npm install on %s" % repository_ctx.attr.package_json)
    result = repository_ctx.execute(
        [repository_ctx.path("_npm.cmd" if is_windows_host else "_npm.sh")],
        timeout = repository_ctx.attr.timeout,
        quiet = repository_ctx.attr.quiet,
        environment = env,
    )

    if result.return_code:
        fail("npm_install failed: %s (%s)" % (result.stdout, result.stderr))

    # removeNPMAbsolutePaths is run on node_modules after npm install as the package.json files
    # generated by npm are non-deterministic. They contain absolute install paths and other private
    # information fields starting with "_". removeNPMAbsolutePaths removes all fields starting with "_".
    fix_absolute_paths_cmd = [
        node,
        repository_ctx.path(repository_ctx.attr._remove_npm_absolute_paths),
        root + "/node_modules",
    ]

    if not repository_ctx.attr.quiet:
        print(fix_absolute_paths_cmd)
    result = repository_ctx.execute(fix_absolute_paths_cmd)

    if result.return_code:
        fail("remove_npm_absolute_paths failed: %s (%s)" % (result.stdout, result.stderr))

    _symlink_node_modules(repository_ctx)
    _apply_post_install_patches(repository_ctx)

    _create_build_files(repository_ctx, "npm_install", node, repository_ctx.attr.package_lock_json, repository_ctx.attr.generate_local_modules_build_files)

npm_install = repository_rule(
    attrs = dict(COMMON_ATTRIBUTES, **{
        "args": attr.string_list(
            doc = """Arguments passed to npm install.

See npm CLI docs https://docs.npmjs.com/cli/install.html for complete list of supported arguments.""",
            default = [],
        ),
        "npm_command": attr.string(
            default = "ci",
            doc = """The npm command to run, to install dependencies.

            See npm docs <https://docs.npmjs.com/cli/v6/commands>

            In particular, for "ci" it says:
            > If dependencies in the package lock do not match those in package.json, npm ci will exit with an error, instead of updating the package lock.
            """,
            values = ["ci", "install"],
        ),
        "package_lock_json": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_remove_npm_absolute_paths": attr.label(default = Label("//third_party/github.com/juanjoDiaz/removeNPMAbsolutePaths:bin/removeNPMAbsolutePaths")),
    }),
    environ = PROXY_ENVVARS,
    doc = """Runs npm install during workspace setup.

This rule will set the environment variable `BAZEL_NPM_INSTALL` to '1' (unless it
set to another value in the environment attribute). Scripts may use to this to
check if yarn is being run by the `npm_install` repository rule.""",
    implementation = _npm_install_impl,
)

def _yarn_install_impl(repository_ctx):
    """Core implementation of yarn_install."""

    # Mark inputs as dependencies with repository_ctx.path to reduce repo fetch restart costs
    repository_ctx.path(repository_ctx.attr.package_json)
    repository_ctx.path(repository_ctx.attr.yarn_lock)
    for f in repository_ctx.attr.data:
        repository_ctx.path(f)
    node = repository_ctx.path(get_node_label(repository_ctx))
    yarn = get_yarn_label(repository_ctx)
    repository_ctx.path(Label("//internal/npm_install:pre_process_package_json.js"))
    repository_ctx.path(Label("//internal/npm_install:index.js"))

    _check_min_bazel_version("yarn_install", repository_ctx)
    is_windows_host = is_windows_os(repository_ctx)

    yarn_args = []

    if repository_ctx.attr.ignore_platform:
        yarn_args.append("--ignore-platform")

    # Set frozen lockfile as default install to install the exact version from the yarn.lock
    # file. To perform an yarn install use the vendord yarn binary with:
    # `bazel run @nodejs//:yarn install` or `bazel run @nodejs//:yarn install -- -D <dep-name>`
    if repository_ctx.attr.frozen_lockfile:
        yarn_args.append("--frozen-lockfile")

    if not repository_ctx.attr.use_global_yarn_cache:
        yarn_args.extend(["--cache-folder", str(repository_ctx.path("_yarn_cache"))])
    else:
        # Multiple yarn rules cannot run simultaneously using a shared cache.
        # See https://github.com/yarnpkg/yarn/issues/683
        # The --mutex option ensures only one yarn runs at a time, see
        # https://yarnpkg.com/en/docs/cli#toc-concurrency-and-mutex
        # The shared cache is not necessarily hermetic, but we need to cache downloaded
        # artifacts somewhere, so we rely on yarn to be correct.
        yarn_args.extend(["--mutex", "network"])
    yarn_args.extend(repository_ctx.attr.args)

    # Run the package manager in the package.json folder
    if repository_ctx.attr.symlink_node_modules:
        root = str(repository_ctx.path(repository_ctx.attr.package_json).dirname)
    else:
        root = str(repository_ctx.path(_rerooted_workspace_package_json_dir(repository_ctx)))

    # The entry points for npm install for osx/linux and windows
    if not is_windows_host:
        # Prefix filenames with _ so they don't conflict with the npm packages.
        # Set YARN_IGNORE_PATH=1 so it doesn't go through wrappers set by `yarn-path` https://classic.yarnpkg.com/lang/en/docs/yarnrc/#toc-yarn-path
        repository_ctx.file(
            "_yarn.sh",
            content = """#!/usr/bin/env bash
# Immediately exit if any command fails.
set -e
export YARN_IGNORE_PATH=1
(cd "{root}"; "{yarn}" {yarn_args})
""".format(
                root = root,
                yarn = repository_ctx.path(yarn),
                yarn_args = " ".join(yarn_args),
            ),
            executable = True,
        )
    else:
        repository_ctx.file(
            "_yarn.cmd",
            content = """@echo off
set "YARN_IGNORE_PATH=1"
cd /D "{root}" && "{yarn}" {yarn_args}
""".format(
                root = root,
                yarn = repository_ctx.path(yarn),
                yarn_args = " ".join(yarn_args),
            ),
            executable = True,
        )

    _symlink_file(repository_ctx, repository_ctx.attr.yarn_lock)
    _copy_file(repository_ctx, repository_ctx.attr.package_json)
    _copy_data_dependencies(repository_ctx)
    _add_scripts(repository_ctx)
    _add_node_repositories_info_deps(repository_ctx)
    _apply_pre_install_patches(repository_ctx)

    result = repository_ctx.execute(
        [node, "pre_process_package_json.js", repository_ctx.path(repository_ctx.attr.package_json), "yarn"],
        quiet = repository_ctx.attr.quiet,
    )
    if result.return_code:
        fail("pre_process_package_json.js failed: \nSTDOUT:\n%s\nSTDERR:\n%s" % (result.stdout, result.stderr))

    env = dict(repository_ctx.attr.environment)
    env_key = "BAZEL_YARN_INSTALL"
    if env_key not in env.keys():
        env[env_key] = "1"
    env["BUILD_BAZEL_RULES_NODEJS_VERSION"] = VERSION

    env = _propagate_http_proxy_env(repository_ctx, env)

    repository_ctx.report_progress("Running yarn install on %s" % repository_ctx.attr.package_json)
    result = repository_ctx.execute(
        [repository_ctx.path("_yarn.cmd" if is_windows_host else "_yarn.sh")],
        timeout = repository_ctx.attr.timeout,
        quiet = repository_ctx.attr.quiet,
        environment = env,
    )
    if result.return_code:
        fail("yarn_install failed: %s (%s)" % (result.stdout, result.stderr))

    _symlink_node_modules(repository_ctx)
    _apply_post_install_patches(repository_ctx)

    repository_ctx.report_progress("Removing non-deterministic *.pyc files")
    result = repository_ctx.execute([
        "find",
        repository_ctx.path("node_modules"),
        "-type",
        "f",
        "-name",
        "*.pyc",
        "-delete",
    ])
    if result.return_code:
        fail("deleting .pyc files failed: %s (%s)" % (result.stdout, result.stderr))

    repository_ctx.report_progress("Stripping non-deterministic debug symbols from *.node files")
    result = repository_ctx.execute([
        "find",
        repository_ctx.path("node_modules"),
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

    _create_build_files(repository_ctx, "yarn_install", node, repository_ctx.attr.yarn_lock, repository_ctx.attr.generate_local_modules_build_files)

yarn_install = repository_rule(
    attrs = dict(COMMON_ATTRIBUTES, **{
        "args": attr.string_list(
            doc = """Arguments passed to yarn install.

See yarn CLI docs https://yarnpkg.com/en/docs/cli/install for complete list of supported arguments.""",
            default = [],
        ),
        "frozen_lockfile": attr.bool(
            default = True,
            doc = """Use the `--frozen-lockfile` flag for yarn.

Don't generate a `yarn.lock` lockfile and fail if an update is needed.

This flag enables an exact install of the version that is specified in the `yarn.lock`
file. This helps to have reproducible builds across builds.

To update a dependency or install a new one run the `yarn install` command with the
vendored yarn binary. `bazel run @nodejs//:yarn install`. You can pass the options like
`bazel run @nodejs//:yarn install -- -D <dep-name>`.
""",
        ),
        "use_global_yarn_cache": attr.bool(
            default = True,
            doc = """Use the global yarn cache on the system.

The cache lets you avoid downloading packages multiple times.
However, it can introduce non-hermeticity, and the yarn cache can
have bugs.

Disabling this attribute causes every run of yarn to have a unique
cache_directory.

If True, this rule will pass `--mutex network` to yarn to ensure that
the global cache can be shared by parallelized yarn_install rules.

If False, this rule will pass `--cache-folder /path/to/external/repository/__yarn_cache`
to yarn so that the local cache is contained within the external repository.
""",
        ),
        "yarn_lock": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "ignore_platform": attr.bool(
            default = False,
            doc = "Use the --ignore-platform flag for yarn install. Skips platform checks when installing packages.",
        ),
    }),
    environ = PROXY_ENVVARS,
    doc = """Runs yarn install during workspace setup.

This rule will set the environment variable `BAZEL_YARN_INSTALL` to '1' (unless it
set to another value in the environment attribute). Scripts may use to this to
check if yarn is being run by the `yarn_install` repository rule.""",
    implementation = _yarn_install_impl,
)
