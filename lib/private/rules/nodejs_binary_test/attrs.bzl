"""
Attributes for `nodejs_binary` and `nodejs_test`.
"""

load("//lib/private:aspects.bzl", "module_mappings_aspect", "module_mappings_runtime_aspect", "node_modules_aspect")

visibility(["//lib/private"])

BINARY_ATTRS = {
    "chdir": attr.string(
        doc = """
            Working directory to run the binary or test in, relative to the workspace.
            By default, Bazel always runs in the workspace root.
            Due to implementation details, this argument must be underneath this package directory.

            To run in the directory containing the `nodejs_binary` / `nodejs_test`, use

                chdir = package_name()

            (or if you're in a macro, use `native.package_name()`)

            WARNING: this will affect other paths passed to the program, either as arguments or in configuration files,
            which are workspace-relative.
            You may need `../../` segments to re-relativize such paths to the new working directory.
        """,
    ),
    "configuration_env_vars": attr.string_list(
        doc = """
            Pass these configuration environment variables to the resulting binary.
            Chooses a subset of the configuration environment variables (taken from `ctx.var`), which also
            includes anything specified via the --define flag.
            Note, this can lead to different outputs produced by this rule.
        """,
        default = [],
    ),
    "data": attr.label_list(
        doc = "Runtime dependencies which may be loaded during execution.",
        allow_files = True,
        aspects = [node_modules_aspect, module_mappings_aspect, module_mappings_runtime_aspect],
    ),
    "default_env_vars": attr.string_list(
        doc = """
            Default environment variables that are added to `configuration_env_vars`.

            This is separate from the default of `configuration_env_vars` so that a user can set `configuration_env_vars`
            without losing the defaults that should be set in most cases.

            The set of default  environment variables is:

            - `VERBOSE_LOGS`: use by some rules & tools to turn on debug output in their logs
            - `NODE_DEBUG`: used by node.js itself to print more logs
            - `RUNFILES_LIB_DEBUG`: print diagnostic message from Bazel runfiles.bash helper
        """,
        default = ["VERBOSE_LOGS", "NODE_DEBUG", "RUNFILES_LIB_DEBUG"],
    ),
    "entry_point": attr.label(
        doc = """
            The script which should be executed first, usually containing a main function.

            If the entry JavaScript file belongs to the same package (as the BUILD file),
            you can simply reference it by its relative name to the package directory:

            ```starlark
            nodejs_binary(
                name = "my_binary",
                ...
                entry_point = ":file.js",
            )
            ```

            You can specify the entry point as a typescript file so long as you also include
            the ts_library target in data:

            ```starlark
            ts_library(
                name = "main",
                srcs = ["main.ts"],
            )

            nodejs_binary(
                name = "bin",
                data = [":main"]
                entry_point = ":main.ts",
            )
            ```

            The rule will use the corresponding `.js` output of the ts_library rule as the entry point.

            If the entry point target is a rule, it should produce a single JavaScript entry file that will be passed to the nodejs_binary rule.
            For example:

            ```starlark
            filegroup(
                name = "entry_file",
                srcs = ["main.js"],
            )

            nodejs_binary(
                name = "my_binary",
                entry_point = ":entry_file",
            )
            ```

            The entry_point can also be a label in another workspace:

            ```starlark
            nodejs_binary(
                name = "history-server",
                entry_point = "@npm//:node_modules/history-server/modules/cli.js",
                data = ["@npm//history-server"],
            )
            ```
        """,
        mandatory = True,
        allow_files = True,
    ),
    "env": attr.string_dict(
        doc = "Specifies additional environment variables to set when the target is executed, subject to location expansion.",
        default = {},
    ),
    "link_workspace_root": attr.bool(
        doc = """
            Link the workspace root to the bin_dir to support absolute requires like 'my_wksp/path/to/file'.
            If source files need to be required then they can be copied to the bin_dir with copy_to_bin.
        """,
    ),
    "templated_args": attr.string_list(
        doc = """
            Arguments which are passed to every execution of the program.
            To pass a node startup option, prepend it with `--node_options=`, e.g.
            `--node_options=--preserve-symlinks`.

            Subject to 'Make variable' substitution. See https://docs.bazel.build/versions/master/be/make-variables.html.

            1. Subject to predefined source/output path variables substitutions.

            The predefined variables `execpath`, `execpaths`, `rootpath`, `rootpaths`, `location`, and `locations` take
            label parameters (e.g. `$(execpath //foo:bar)`) and substitute the file paths denoted by that label.

            See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_label_variables for more info.

            NB: This $(location) substition returns the manifest file path which differs from the *_binary & *_test
            args and genrule bazel substitions. This will be fixed in a future major release.
            See docs string of `expand_location_into_runfiles` macro in `internal/common/expand_into_runfiles.bzl`
            for more info.

            The recommended approach is to now use `$(rootpath)` where you previously used $(location).

            To get from a `$(rootpath)` to the absolute path that `$$(rlocation $(location))` returned you can either use
            `$$(rlocation $(rootpath))` if you are in the `templated_args` of a `nodejs_binary` or `nodejs_test`:

            BUILD.bazel:
            ```starlark
            nodejs_test(
                name = "my_test",
                data = [":bootstrap.js"],
                templated_args = ["--node_options=--require=$$(rlocation $(rootpath :bootstrap.js))"],
            )
            ```

            or if you're in the context of a .js script you can pass the $(rootpath) as an argument to the script
            and use the javascript runfiles helper to resolve to the absolute path:

            BUILD.bazel:
            ```starlark
            nodejs_test(
                name = "my_test",
                data = [":some_file"],
                entry_point = ":my_test.js",
                templated_args = ["$(rootpath :some_file)"],
            )
            ```

            my_test.js
            ```starlark
            const runfiles = require(process.env['BAZEL_NODE_RUNFILES_HELPER']);
            const args = process.argv.slice(2);
            const some_file = runfiles.resolveWorkspaceRelative(args[0]);
            ```

            NB: Bazel will error if it sees the single dollar sign $(rlocation path) in `templated_args` as it will try to
            expand `$(rlocation)` since we now expand predefined & custom "make" variables such as `$(COMPILATION_MODE)`,
            `$(BINDIR)` & `$(TARGET_CPU)` using `ctx.expand_make_variables`. See https://docs.bazel.build/versions/master/be/make-variables.html.

            To prevent expansion of `$(rlocation)` write it as `$$(rlocation)`. Bazel understands `$$` to be
            the string literal `$` and the expansion results in `$(rlocation)` being passed as an arg instead
            of being expanded. `$(rlocation)` is then evaluated by the bash node launcher script and it calls
            the `rlocation` function in the runfiles.bash helper. For example, the templated arg
            `$$(rlocation $(rootpath //:some_file))` is expanded by Bazel to `$(rlocation ./some_file)` which
            is then converted in bash to the absolute path of `//:some_file` in runfiles by the runfiles.bash helper
            before being passed as an argument to the program.

            NB: nodejs_binary and nodejs_test will preserve the legacy behavior of `$(rlocation)` so users don't
            need to update to `$$(rlocation)`. This may be changed in the future.

            2. Subject to predefined variables & custom variable substitutions.

            Predefined "Make" variables such as $(COMPILATION_MODE) and $(TARGET_CPU) are expanded.
            See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_variables.

            Custom variables are also expanded including variables set through the Bazel CLI with --define=SOME_VAR=SOME_VALUE.
            See https://docs.bazel.build/versions/master/be/make-variables.html#custom_variables.

            Predefined genrule variables are not supported in this context.
        """,
    ),
    "_bash_runfile_helper": attr.label(
        default = Label("@bazel_tools//tools/bash/runfiles"),
    ),
    "_launcher_template": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:launcher.sh"),
        allow_single_file = True,
    ),
    "_lcov_merger_script": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:lcov_merger-js.js"),
        allow_single_file = True,
    ),
    "_link_modules_script": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:linker.js"),
        allow_single_file = True,
    ),
    "_loader_template": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:loader.js"),
        allow_single_file = True,
    ),
    "_node_patches_script": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:node_patches.js"),
        allow_single_file = True,
    ),
    "_require_patch_template": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:require_patch.js"),
        allow_single_file = True,
    ),
    "_runfile_helpers_bundle": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:runfiles_bundle.js"),
        allow_single_file = True,
    ),
    "_runfile_helpers_main": attr.label(
        default = Label("//lib/internal/rules/nodejs_binary_test:runfiles_main.js"),
        allow_single_file = True,
    ),
}

TEST_ATTRS = dict(BINARY_ATTRS, **{
    "expected_exit_code": attr.int(
        doc = "The expected exit code for the test. Defaults to 0.",
        default = 0,
    ),
})
