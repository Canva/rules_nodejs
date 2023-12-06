"""
Attributes for `yarn_install`.

These are stored separate to the implementation as the large volume of accompanying documentation
is distracting.
"""

visibility(["//lib/private"])


YARN_INSTALL_ATTRS = {
    "data": attr.label_list(
        doc = """
            Data files required by this rule.
        """,
    ),
    "environment": attr.string_dict(
        doc = "Environment variables to set before calling the package manager.",
        default = {},
    ),
    "exports_directories_only": attr.bool(
        default = False,
        doc = """
            Export only top-level package directory artifacts from node_modules.

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
        doc = """
            Enables the BUILD files auto generation for local modules installed with `file:` (npm) or `link:` (yarn)

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
        doc = """
            List of file extensions to be included in the npm package targets.

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
        doc = """
            Targets to link as npm packages.

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
        doc = """
            Experimental attribute that can be used to override the generated BUILD.bazel file and set its contents manually.

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
        doc = """
            If set, link the 3rd party node_modules dependencies under the package path specified.

            In most cases, this should be the directory of the package.json file so that the linker links the node_modules
            in the same location they are found in the source tree. In a future release, this will default to the package.json
            directory. This is planned for 4.0: https://github.com/bazelbuild/rules_nodejs/issues/2451
        """,
    ),
    "quiet": attr.bool(
        default = True,
        doc = "If stdout and stderr should be printed to the terminal.",
    ),
    "timeout": attr.int(
        default = 3600,
        doc = "Maximum duration of the package manager execution in seconds.",
    ),
    "args": attr.string_list(
        doc = """
            Arguments passed to yarn install.

            See yarn CLI docs https://yarnpkg.com/en/docs/cli/install for complete list of supported arguments.
        """,
        default = [],
    ),
    "frozen_lockfile": attr.bool(
        default = True,
        doc = """
            Use the `--frozen-lockfile` flag for yarn.

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
        doc = """
            Use the global yarn cache on the system.

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
    "host_node_bin": attr.label(
        mandatory = True,
        allow_single_file = True,
    ),
    "host_yarn_bin": attr.label(
        mandatory = True,
        allow_single_file = True,
    ),
    "_generate_build_file_script": attr.label(
        default = "//lib/internal/repositories/yarn_install:index.js",
    ),
    "_pre_process_package_json_script": attr.label(
        default = "//lib/internal/repositories/yarn_install:pre_process_package_json.js",
    ),
}