"Rules for running Rollup under Bazel"

load("@bazel_skylib//rules:run_binary.bzl", "run_binary")
load("@build_bazel_rules_nodejs//:index.bzl", "nodejs_binary")
load("@build_bazel_rules_nodejs//:providers.bzl", "NODE_CONTEXT_ATTRS", "node_modules_aspect")
load("@build_bazel_rules_nodejs//internal/linker:link_node_modules.bzl", "module_mappings_aspect")

_DOC = "Runs the rollup.js CLI under Bazel."

_ROLLUP_ATTRS = dict(NODE_CONTEXT_ATTRS, **{
    "args": attr.string_list(
        doc = """
            Command line arguments to pass to Rollup. Can be used to override config file settings.

            These argument passed on the command line before arguments that are added by the rule.
            Run `bazel` with `--subcommands` to see what Rollup CLI command line was invoked.

            See the <a href="https://rollupjs.org/guide/en/#command-line-flags">Rollup CLI docs</a> for a complete list of supported arguments.
        """,
        default = [],
    ),
    "config_file": attr.label(
        doc = """
            A `rollup.config.js` file

            Passed to the `--config` option, see [the config doc](https://rollupjs.org/guide/en/#configuration-files)

            If not set, a default basic Rollup config is used.
        """,
        allow_single_file = True,
        default = "//packages/rollup:rollup.config.js",
    ),
    "deps": attr.label_list(
        aspects = [module_mappings_aspect, node_modules_aspect],
        doc = """Other libraries that are required by the code, or by the rollup.config.js""",
    ),
    "entry_point": attr.label(
        doc = """
            The bundle's entry point (e.g. your main.js or app.js or index.js).

            This is just a shortcut for the `entry_points` attribute with a single output chunk named the same as the rule.

            For example, these are equivalent:

            ```python
            rollup_bundle(
                name = "bundle",
                entry_point = "index.js",
            )
            ```

            ```python
            rollup_bundle(
                name = "bundle",
                entry_points = {
                    "index.js": "bundle"
                }
            )
            ```

            If `rollup_bundle` is used on a `ts_library`, the `rollup_bundle` rule handles selecting the correct outputs from `ts_library`.
            In this case, `entry_point` can be specified as the `.ts` file and `rollup_bundle` will handle the mapping to the `.mjs` output file.

            For example:

            ```python
            ts_library(
                name = "foo",
                srcs = [
                    "foo.ts",
                    "index.ts",
                ],
            )

            rollup_bundle(
                name = "bundle",
                deps = [ "foo" ],
                entry_point = "index.ts",
            )
            ```
        """,
        allow_single_file = True,
    ),
    "entry_points": attr.label_keyed_string_dict(
        doc = """
            The bundle's entry points (e.g. your main.js or app.js or index.js).

            Passed to the [`--input` option](https://github.com/rollup/rollup/blob/master/docs/999-big-list-of-options.md#input) in Rollup.

            Keys in this dictionary are labels pointing to .js entry point files.
            Values are the name to be given to the corresponding output chunk.

            Either this attribute or `entry_point` must be specified, but not both.
        """,
        allow_files = True,
    ),
    "format": attr.string(
        doc = """
            Specifies the format of the generated bundle. One of the following:

            - `amd`: Asynchronous Module Definition, used with module loaders like RequireJS
            - `cjs`: CommonJS, suitable for Node and other bundlers
            - `esm`: Keep the bundle as an ES module file, suitable for other bundlers and inclusion as a `<script type=module>` tag in modern browsers
            - `iife`: A self-executing function, suitable for inclusion as a `<script>` tag. (If you want to create a bundle for your application, you probably want to use this.)
            - `umd`: Universal Module Definition, works as amd, cjs and iife all in one
            - `system`: Native format of the SystemJS loader
        """,
        values = ["amd", "cjs", "esm", "iife", "umd", "system"],
        default = "esm",
    ),
    "link_workspace_root": attr.bool(
        doc = """
            Link the workspace root to the bin_dir to support absolute requires like 'my_wksp/path/to/file'.
            If source files need to be required then they can be copied to the bin_dir with copy_to_bin.
        """,
    ),
    "output_dir": attr.bool(
        doc = """
            Whether to produce a directory output.

            We will use the [`--output.dir` option](https://github.com/rollup/rollup/blob/master/docs/999-big-list-of-options.md#outputdir) in rollup
            rather than `--output.file`.

            If the program produces multiple chunks, you must specify this attribute.
            Otherwise, the outputs are assumed to be a single file.
        """,
    ),
    "rollup_bin": attr.label(
        doc = "Target that executes the rollup binary",
        executable = True,
        cfg = "exec",
        default = (
            # BEGIN-INTERNAL
            "@npm" +
            # END-INTERNAL
            "//rollup/bin:rollup"
        ),
    ),
    "rollup_worker_bin": attr.label(
        doc = "Internal use only",
        executable = True,
        cfg = "exec",
        default = "//packages/rollup/bin:rollup-worker",
    ),
    "silent": attr.bool(
        doc = """
            Whether to execute the rollup binary with the --silent flag, defaults to False.

            Using --silent can cause rollup to [ignore errors/warnings](https://github.com/rollup/rollup/blob/master/docs/999-big-list-of-options.md#onwarn) 
            which are only surfaced via logging.  Since bazel expects printing nothing on success, setting silent to True
            is a more Bazel-idiomatic experience, however could cause rollup to drop important warnings.
        """,
    ),
    "sourcemap": attr.string(
        doc = """
            Whether to produce sourcemaps.

            Passed to the [`--sourcemap` option](https://github.com/rollup/rollup/blob/master/docs/999-big-list-of-options.md#outputsourcemap") in Rollup
        """,
        default = "inline",
        values = ["inline", "hidden", "true", "false"],
    ),
    "srcs": attr.label_list(
        doc = """
            Non-entry point JavaScript source files from the workspace.

            You must not repeat file(s) passed to entry_point/entry_points.
        """,
        # Don't try to constrain the filenames, could be json, svg, whatever
        allow_files = True,
    ),
    "supports_workers": attr.bool(
        doc = """
            Experimental! Use only with caution.

            Allows you to enable the Bazel Worker strategy for this library.
            When enabled, this rule invokes the "rollup_worker_bin"
            worker aware binary rather than "rollup_bin".
        """,
        default = False,
    ),
})

def _desugar_entry_point_names(name, entry_point, entry_points):
    """Users can specify entry_point (sugar) or entry_points (long form).

    This function allows our code to treat it like they always used the long form.

    It also performs validation:
    - exactly one of these attributes should be specified
    """
    if entry_point and entry_points:
        fail("Cannot specify both entry_point and entry_points")
    if not entry_point and not entry_points:
        fail("One of entry_point or entry_points must be specified")
    if entry_point:
        return [name]
    return entry_points.values()

def _desugar_entry_points(name, entry_point, entry_points):
    """Like above, but used by the implementation function, where the types differ.

    It also performs validation:
    - attr.label_keyed_string_dict doesn't accept allow_single_file
      so we have to do validation now to be sure each key is a label resulting in one file

    It converts from dict[target: string] to dict[file: string]
    """
    names = _desugar_entry_point_names(name, entry_point, entry_points)

    if entry_point:
        return {entry_point: names[0]}

    result = {}
    for ep in entry_points.items():
        entry_point = ep[0]
        name = ep[1]
        result[entry_point] = name
    return result



def rollup_bundle(
    name,
    config_file,
    srcs = [],
    deps = [],
    entry_point = None,
    entry_points = None,
    output_dir = False,
    format = "esm",
    silent = False,
    sourcemap = "inline",
    args = [],
    rollup_bin = "@npm//:node_modules/rollup/dist/bin/rollup",
    rollup_package = "@npm//rollup:rollup"):
    """
    Create a bundle with rollup.
    """
    templated_args = []
    run_args = []
    outs = ["foo"]

    # List entry point argument first to save some argv space
    # Rollup doc says
    # When provided as the first options, it is equivalent to not prefix them with --input
    r_entry_points = _desugar_entry_points(name, entry_point, entry_points).items()

    # If user requests an output_dir, then use output.dir rather than output.file
    # TODO resolve files to under runfiles
    if output_dir:
        # TODO This is probably wrong
        outs.append(name)
        for file, bundle_name in r_entry_points:
            run_args.append(bundle_name + "=" + file)
        run_args.append("--output.file")
        # TODO Need to route to out dir
        run_args.append(output_dir)
    else:
        run_args.append(r_entry_points[0][0])
        run_args.append("--output.file")
        # TODO Definitely wrong
        run_args.append(name)

    templated_args.append("--format")
    templated_args.append(format)

    if silent:
        templated_args.append("--silent")

    templated_args.append("--config")
    templated_args.append("--bazel_arg_runfiles_prefix=$(rootpath " + config_file + ")")

    # Prevent rollup's module resolver from hopping outside Bazel's sandbox
    # When set to false, symbolic links are followed when resolving a file.
    # When set to true, instead of being followed, symbolic links are treated as if the file is
    # where the link is.
    templated_args.append("--preserveSymlinks")

    if sourcemap != "false":
        templated_args.append("--sourcemap")
        templated_args.append(sourcemap)

    run_args = run_args + args

    rollupenv = name + "_rollupenv"

    # Responsible for constructing an environment containing Rollup and all bundle related inputs.
    nodejs_binary(
        name = rollupenv,
        templated_args = templated_args,
        entry_point = rollup_bin,
        data = srcs + deps + [
            rollup_package,
            config_file,
        ],
    )

    # TODO Need to set output location here
    run_binary(
        name = name,
        args = args,
        env = {},
        outs = outs,
        srcs = [],
        tool = ":" + rollupenv,
    )
