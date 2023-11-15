"""
Executing programs

These rules run the node executable with the given sources.

They support module mapping: any targets in the transitive dependencies with
a `module_name` attribute can be `require`d by that name.
"""

load("//lib/private:aspects.bzl", "MODULE_MAPPINGS_ASPECT_RESULTS_NAME")
load("//lib/private:providers.bzl", "DirectoryFilePathInfo", "ExternalNpmPackageInfo", "JSModuleInfo", "JSNamedModuleInfo", "NodeRuntimeDepsInfo")
load("//lib/private:rules/nodejs_binary_test/attrs.bzl", "BINARY_ATTRS", "TEST_ATTRS")
load("//lib/private:rules/nodejs_binary_test/utils/expand_into_runfiles.bzl", "expand_location_into_runfiles")
load("//lib/private:rules/nodejs_binary_test/utils/preserve_legacy_templated_args.bzl", "preserve_legacy_templated_args")
load("//lib/private:rules/nodejs_binary_test/utils/windows_utils.bzl", "create_windows_native_launcher_script", "is_windows")
load("//lib/private:rules/nodejs_binary_test/utils/write_node_modules_manifest.bzl", "write_node_modules_manifest")
load("//lib/private:utils/strings.bzl", "dedent")

visibility(["//lib/private"])

def _compute_node_modules_roots(ctx):
    """Computes the node_modules root (if any) from data attribute."""
    node_modules_roots = {}

    # Add in roots from third-party deps
    for d in ctx.attr.data:
        if ExternalNpmPackageInfo in d:
            path = d[ExternalNpmPackageInfo].path
            workspace = d[ExternalNpmPackageInfo].workspace
            if path in node_modules_roots:
                other_workspace = node_modules_roots[path]
                if other_workspace != workspace:
                    fail("All npm dependencies at the path '%s' must come from a single workspace. Found '%s' and '%s'." % (path, other_workspace, workspace))
            node_modules_roots[path] = workspace

    # Add in roots for multi-linked first party deps
    for dep in ctx.attr.data:
        for k, v in getattr(dep, MODULE_MAPPINGS_ASPECT_RESULTS_NAME, {}).items():
            map_key_split = k.split(":")
            package_name = map_key_split[0]
            package_path = map_key_split[1] if len(map_key_split) > 1 else ""
            if package_path not in node_modules_roots:
                node_modules_roots[package_path] = ""
    return node_modules_roots

def _write_require_patch_script(ctx, node_modules_root):
    # Generates the JavaScript snippet of module roots mappings, with each entry
    # in the form:
    #   {module_name: /^mod_name\b/, module_root: 'path/to/mod_name'}
    module_mappings = []
    for d in ctx.attr.data:
        if hasattr(d, "runfiles_module_mappings"):
            for [mn, mr] in d.runfiles_module_mappings.items():
                escaped = mn.replace("/", "\\/").replace(".", "\\.")
                mapping = {
                    "module_name": "/^%s\\b/" % escaped,
                    "module_root": mr
                }
                module_mappings.append(mapping)

    ctx.actions.expand_template(
        template = ctx.file._require_patch_template,
        output = ctx.outputs.require_patch_script,
        substitutions = {
            "TEMPLATED_bin_dir": ctx.bin_dir.path,
            "TEMPLATED_gen_dir": ctx.genfiles_dir.path,
            "/*TEMPLATED_module_roots*/": json.encode(module_mappings),
            "TEMPLATED_node_modules_root": node_modules_root,
            "TEMPLATED_target": str(ctx.label),
            "TEMPLATED_user_workspace_name": ctx.workspace_name,
        },
        is_executable = True,
    )

def _ts_to_js(entry_point_path):
    """If the entry point specified is a typescript file then set it to .js.

    Workaround for #1974
    ts_library doesn't give labels for its .js outputs so users are forced to give .ts labels

    Args:
        entry_point_path: a file path
    """
    if entry_point_path.endswith(".ts"):
        return entry_point_path[:-3] + ".js"
    elif entry_point_path.endswith(".tsx"):
        return entry_point_path[:-4] + ".js"
    return entry_point_path

def _get_entry_point_file(ctx):
    if len(ctx.attr.entry_point.files.to_list()) > 1:
        fail("labels in entry_point must contain exactly one file")
    if len(ctx.files.entry_point) == 1:
        return ctx.files.entry_point[0]
    if DirectoryFilePathInfo in ctx.attr.entry_point:
        return ctx.attr.entry_point[DirectoryFilePathInfo].directory
    fail("entry_point must either be a file, or provide DirectoryFilePathInfo")

def _write_loader_script(ctx):
    substitutions = {}
    substitutions["TEMPLATED_entry_point_path"] = _ts_to_js(_to_manifest_path(ctx, _get_entry_point_file(ctx)))
    if DirectoryFilePathInfo in ctx.attr.entry_point:
        fail("Not supported")

    ctx.actions.expand_template(
        template = ctx.file._loader_template,
        output = ctx.outputs.loader_script,
        substitutions = substitutions,
        is_executable = True,
    )

# Avoid using non-normalized paths (workspace/../other_workspace/path)
def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _to_execroot_path(ctx, file):
    parts = file.path.split("/")
    if parts[0] == "external":
        if parts[2] == "node_modules":
            # external/npm/node_modules -> node_modules/foo
            # the linker will make sure we can resolve node_modules from npm
            return "/".join(parts[2:])

    return file.path

def _join(*elements):
    return "/".join([f for f in elements if f])

def _nodejs_binary_impl(ctx):
    node_modules_manifest = write_node_modules_manifest(ctx, link_workspace_root = ctx.attr.link_workspace_root)
    node_modules_depsets = []

    # Also include files from npm fine grained deps as inputs.
    # These deps are identified by the ExternalNpmPackageInfo provider.
    for d in ctx.attr.data:
        if ExternalNpmPackageInfo in d:
            node_modules_depsets.append(d[ExternalNpmPackageInfo].sources)

    node_modules = depset(transitive = node_modules_depsets)

    # Using an array of depsets will allow us to avoid flattening files and sources
    # inside this loop. This should reduce the performances hits,
    # since we don't need to call .to_list()
    # Also avoid deap transitive depset()s by creating single array of
    # transitive depset()s
    sources_depsets = []

    for d in ctx.attr.data:
        if JSModuleInfo in d:
            sources_depsets.append(d[JSModuleInfo].sources)

        # Deprecated should be removed with version 3.x.x at least have a transition phase
        # for dependencies to provide the output under the JSModuleInfo instead.
        if JSNamedModuleInfo in d:
            sources_depsets.append(d[JSNamedModuleInfo].sources)
        if hasattr(d, "files"):
            sources_depsets.append(d.files)
    sources = depset(transitive = sources_depsets)

    node_modules_roots = _compute_node_modules_roots(ctx)

    if "" in node_modules_roots:
        node_modules_root = node_modules_roots[""] + "/node_modules"
    else:
        # there are no fine grained deps but we still need a node_modules_root even if it is a non-existant one
        node_modules_root = "build_bazel_rules_nodejs/node_modules"
    _write_require_patch_script(ctx, node_modules_root)

    _write_loader_script(ctx)

    # Provide the target name as an environment variable avaiable to all actions for the
    # runfiles helpers to use.
    env_vars = "export BAZEL_TARGET=%s\n" % ctx.label
    env_vars += """export NM_SYMLINKS="$(mktemp -d)/nm-symlinks.json"\n"""

    # Add all env vars from the ctx attr
    for [key, value] in ctx.attr.env.items():
        env_vars += "export %s=%s\n" % (key, expand_location_into_runfiles(ctx, value, ctx.attr.data))

    # While we can derive the workspace from the pwd when running locally
    # because it is in the execroot path `execroot/my_wksp`, on RBE the
    # `execroot/my_wksp` path is reduced a path such as `/w/f/b` so
    # the workspace name is obfuscated from the path. So we provide the workspace
    # name here as an environment variable avaiable to all actions for the
    # runfiles helpers to use.
    env_vars += "export BAZEL_WORKSPACE=%s\n" % ctx.workspace_name

    bazel_node_module_roots = ""
    for path, root in node_modules_roots.items():
        if bazel_node_module_roots:
            bazel_node_module_roots = bazel_node_module_roots + ","
        bazel_node_module_roots = bazel_node_module_roots + "%s:%s" % (path, root)

    # if BAZEL_NODE_MODULES_ROOTS has not already been set by
    # run_node, then set it to the computed value
    env_vars += dedent("""
        if [[ -z "${BAZEL_NODE_MODULES_ROOTS:-}" ]]; then
            export BAZEL_NODE_MODULES_ROOTS=%s
        fi
    """) % bazel_node_module_roots

    for k in ctx.attr.configuration_env_vars + ctx.attr.default_env_vars:
        # Check ctx.var first & if env var not in there then check
        # ctx.configuration.default_shell_env. The former will contain values from --define=FOO=BAR
        # and latter will contain values from --action_env=FOO=BAR (but not from --action_env=FOO).
        if k in ctx.var.keys():
            env_vars += "export %s=\"%s\"\n" % (k, ctx.var[k])
        elif k in ctx.configuration.default_shell_env.keys():
            env_vars += "export %s=\"%s\"\n" % (k, ctx.configuration.default_shell_env[k])

    expected_exit_code = 0
    if hasattr(ctx.attr, "expected_exit_code"):
        expected_exit_code = ctx.attr.expected_exit_code

    # Add both the node executable for the user's local machine which is in ctx.files._node and comes
    # from @nodejs//:node_bin and the node executable from the selected node --platform which comes from
    # ctx.toolchains["@build_bazel_rules_nodejs//toolchains/node:toolchain_type"].nodeinfo.
    # In most cases these are the same files but for RBE and when explitely setting --platform for cross-compilation
    # any given nodejs_binary should be able to run on both the user's local machine and on the RBE or selected
    # platform.
    #
    # Rules such as nodejs_image should use only ctx.toolchains["@build_bazel_rules_nodejs//toolchains/node:toolchain_type"].nodeinfo
    # when building the image as that will reflect the selected --platform.
    node_toolchain = ctx.toolchains[Label("@build_bazel_rules_nodejs//lib:nodejs_toolchain_type")]
    node_tool_files = []
    node_tool_files.extend(node_toolchain.nodeinfo.tool_files)

    node_tool_files.append(ctx.file._link_modules_script)
    node_tool_files.append(ctx.file._runfile_helpers_bundle)
    node_tool_files.append(ctx.file._runfile_helpers_main)
    node_tool_files.append(ctx.file._node_patches_script)
    node_tool_files.append(ctx.file._lcov_merger_script)
    node_tool_files.append(node_modules_manifest)

    runfiles = []
    runfiles.extend(node_tool_files)
    runfiles.extend(ctx.files._bash_runfile_helper)
    runfiles.append(ctx.outputs.loader_script)
    runfiles.append(ctx.outputs.require_patch_script)

    # First replace any instances of "$(rlocation " with "$$(rlocation " to preserve
    # legacy uses of "$(rlocation"
    expanded_args = [preserve_legacy_templated_args(a) for a in ctx.attr.templated_args]

    # chdir has to include rlocation lookup for windows
    # that means we have to generate a script so there's an entry in the runfiles manifest
    if ctx.attr.chdir:
        # limitation of ctx.actions.declare_file - you have to chdir within the package
        if ctx.attr.chdir == ctx.label.package:
            relative_dir = None
        elif ctx.attr.chdir.startswith(ctx.label.package + "/"):
            relative_dir = ctx.attr.chdir[len(ctx.label.package) + 1:]
        else:
            fail("""nodejs_binary/nodejs_test only support chdir inside the current package but %s is not a subfolder of %s""" % (ctx.attr.chdir, ctx.label.package))
        chdir_script = ctx.actions.declare_file(_join(relative_dir, "__chdir.js__"))
        ctx.actions.write(chdir_script, "process.chdir(__dirname)")
        runfiles.append(chdir_script)

        # this join is effectively a $(rootdir) expansion
        expanded_args.append("--node_options=--require=$$(rlocation %s)" % _join(ctx.workspace_name, chdir_script.short_path))

    # Next expand predefined source/output path variables:
    # $(execpath), $(rootpath) & legacy $(location)
    expanded_args = [expand_location_into_runfiles(ctx, a, ctx.attr.data) for a in expanded_args]

    # Finally expand predefined variables & custom variables
    rule_dir = _join(ctx.bin_dir.path, ctx.label.workspace_root, ctx.label.package)
    additional_substitutions = {
        "@D": rule_dir,
        "RULEDIR": rule_dir,
    }
    expanded_args = [ctx.expand_make_variables("templated_args", e, additional_substitutions) for e in expanded_args]

    substitutions = {
        # TODO: Split up results of multifile expansions into separate args and qoute them with
        #       "TEMPLATED_args": " ".join(["\"%s\"" % a for a in expanded_args]),
        #       Need a smarter split operation than `expanded_arg.split(" ")` as it will split
        #       up args with intentional spaces and it will fail for expanded files with spaces.
        "TEMPLATED_args": " ".join(expanded_args),
        "TEMPLATED_env_vars": env_vars,
        "TEMPLATED_expected_exit_code": str(expected_exit_code),
        "TEMPLATED_lcov_merger_script": _to_manifest_path(ctx, ctx.file._lcov_merger_script),
        "TEMPLATED_link_modules_script": _to_manifest_path(ctx, ctx.file._link_modules_script),
        "TEMPLATED_loader_script": _to_manifest_path(ctx, ctx.outputs.loader_script),
        "TEMPLATED_modules_manifest": _to_manifest_path(ctx, node_modules_manifest),
        "TEMPLATED_node_patches_script": _to_manifest_path(ctx, ctx.file._node_patches_script),
        "TEMPLATED_require_patch_script": _to_manifest_path(ctx, ctx.outputs.require_patch_script),
        "TEMPLATED_runfiles_helper_script": _to_manifest_path(ctx, ctx.file._runfile_helpers_main),
        "TEMPLATED_vendored_node": _to_manifest_path(ctx, node_toolchain.nodeinfo.target_tool[DefaultInfo].files.to_list()[0]),
    }

    substitutions["TEMPLATED_entry_point_manifest"] = _ts_to_js(_to_manifest_path(ctx, _get_entry_point_file(ctx)))
    # Needed for tests using legacy implementation
    substitutions["TEMPLATED_entry_point_execroot_path"] = "\"%s\"" % _ts_to_js(_to_execroot_path(ctx, _get_entry_point_file(ctx)))
    if DirectoryFilePathInfo in ctx.attr.entry_point:
        fail("Not supported")

    ctx.actions.expand_template(
        template = ctx.file._launcher_template,
        output = ctx.outputs.launcher_sh,
        substitutions = substitutions,
        is_executable = True,
    )

    if is_windows(ctx):
        runfiles.append(ctx.outputs.launcher_sh)
        executable = create_windows_native_launcher_script(ctx, ctx.outputs.launcher_sh)
    else:
        executable = ctx.outputs.launcher_sh

    # syntax sugar: allows you to avoid repeating the entry point in data
    # entry point is only needed in runfiles if it is a .js file
    if len(ctx.files.entry_point) == 1 and ctx.files.entry_point[0].extension == "js":
        runfiles.extend(ctx.files.entry_point)

    return [
        DefaultInfo(
            executable = executable,
            runfiles = ctx.runfiles(
                transitive_files = depset(runfiles),
                files = node_tool_files + [
                            ctx.outputs.loader_script,
                            ctx.outputs.require_patch_script,
                        ] +

                        # We need this call to the list of Files.
                        # Calling the .to_list() method may have some perfs hits,
                        # so we should be running this method only once per rule.
                        # see: https://docs.bazel.build/versions/master/skylark/depsets.html#performance
                        node_modules.to_list() + sources.to_list(),
                collect_data = True,
            ),
        ),
        # TODO(alexeagle): remove sources and node_modules from the runfiles
        # when downstream usage is ready to rely on linker
        NodeRuntimeDepsInfo(
            deps = depset(ctx.files.entry_point, transitive = [node_modules, sources]),
            pkgs = ctx.attr.data,
        ),
        # indicates that the this binary should be instrumented by coverage
        # see https://docs.bazel.build/versions/master/skylark/lib/coverage_common.html
        # since this will be called from a nodejs_test, where the entrypoint is going to be the test file
        # we shouldn't add the entrypoint as a attribute to collect here
        coverage_common.instrumented_files_info(ctx, dependency_attributes = ["data"], extensions = ["js", "ts"]),
    ]

_NODEJS_EXECUTABLE_OUTPUTS = {
    "launcher_sh": "%{name}.sh",
    "loader_script": "%{name}_loader.js",
    "require_patch_script": "%{name}_require_patch.js",
}

# The name of the declared rule appears in
# bazel query --output=label_kind
# So we make these match what the user types in their BUILD file
# and duplicate the definitions to give two distinct symbols.
nodejs_binary = rule(
    implementation = _nodejs_binary_impl,
    attrs = BINARY_ATTRS,
    doc = "Runs some JavaScript code in NodeJS.",
    executable = True,
    outputs = _NODEJS_EXECUTABLE_OUTPUTS,
    toolchains = [
        "//lib:nodejs_toolchain_type",
        "@bazel_tools//tools/sh:toolchain_type",
    ],
)

# TODO Expose a rule-factory through which things like transitions can be added (e.g. to disable runfile links).
nodejs_test = rule(
    implementation = _nodejs_binary_impl,
    attrs = TEST_ATTRS,
    doc = """
        Identical to `nodejs_binary`, except this can be used with `bazel test` as well.
        When the binary returns zero exit code, the test passes; otherwise it fails.

        `nodejs_test` is a convenient way to write a novel kind of test based on running
        your own test runner. For example, the `ts-api-guardian` library has a way to
        assert the public API of a TypeScript program, and uses `nodejs_test` here:
        https://github.com/angular/angular/blob/master/tools/ts-api-guardian/index.bzl

        If you just want to run a standard test using a test runner from npm, use the generated
        *_test target created by npm_install/yarn_install, such as `mocha_test`.
        Some test runners like Karma and Jasmine have custom rules with added features, e.g. `jasmine_node_test`.

        By default, Bazel runs tests with a working directory set to your workspace root.
        Use the `chdir` attribute to change the working directory before the program starts.

        To debug a Node.js test, we recommend saving a group of flags together in a "config".
        Put this in your `tools/bazel.rc` so it's shared with your team:
        ```bash
        # Enable debugging tests with --config=debug
        test:debug --test_arg=--node_options=--inspect-brk --test_output=streamed --test_strategy=exclusive --test_timeout=9999 --nocache_test_results
        ```

        Now you can add `--config=debug` to any `bazel test` command line.
        The runtime will pause before executing the program, allowing you to connect a
        remote debugger.
    """,
    test = True,
    outputs = _NODEJS_EXECUTABLE_OUTPUTS,
    toolchains = [
        "//lib:nodejs_toolchain_type",
        "@bazel_tools//tools/sh:toolchain_type",
    ],
)
