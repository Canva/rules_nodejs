<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules.


```starlark
load("build_bazel_rules_nodejs//lib:rules.bzl", ...)
```

<a id="nodejs_binary"></a>

## nodejs_binary

<pre>
nodejs_binary(<a href="#nodejs_binary-name">name</a>, <a href="#nodejs_binary-data">data</a>, <a href="#nodejs_binary-chdir">chdir</a>, <a href="#nodejs_binary-configuration_env_vars">configuration_env_vars</a>, <a href="#nodejs_binary-default_env_vars">default_env_vars</a>, <a href="#nodejs_binary-entry_point">entry_point</a>, <a href="#nodejs_binary-env">env</a>,
              <a href="#nodejs_binary-link_workspace_root">link_workspace_root</a>, <a href="#nodejs_binary-templated_args">templated_args</a>)
</pre>

Runs some JavaScript code in NodeJS.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nodejs_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nodejs_binary-data"></a>data |  Runtime dependencies which may be loaded during execution.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="nodejs_binary-chdir"></a>chdir |  Working directory to run the binary or test in, relative to the workspace. By default, Bazel always runs in the workspace root. Due to implementation details, this argument must be underneath this package directory.<br><br>To run in the directory containing the `nodejs_binary` / `nodejs_test`, use<br><br>    chdir = package_name()<br><br>(or if you're in a macro, use `native.package_name()`)<br><br>WARNING: this will affect other paths passed to the program, either as arguments or in configuration files, which are workspace-relative. You may need `../../` segments to re-relativize such paths to the new working directory.   | String | optional |  `""`  |
| <a id="nodejs_binary-configuration_env_vars"></a>configuration_env_vars |  Pass these configuration environment variables to the resulting binary. Chooses a subset of the configuration environment variables (taken from `ctx.var`), which also includes anything specified via the --define flag. Note, this can lead to different outputs produced by this rule.   | List of strings | optional |  `[]`  |
| <a id="nodejs_binary-default_env_vars"></a>default_env_vars |  Default environment variables that are added to `configuration_env_vars`.<br><br>This is separate from the default of `configuration_env_vars` so that a user can set `configuration_env_vars` without losing the defaults that should be set in most cases.<br><br>The set of default  environment variables is:<br><br>- `VERBOSE_LOGS`: use by some rules & tools to turn on debug output in their logs - `NODE_DEBUG`: used by node.js itself to print more logs - `RUNFILES_LIB_DEBUG`: print diagnostic message from Bazel runfiles.bash helper   | List of strings | optional |  `["VERBOSE_LOGS", "NODE_DEBUG", "RUNFILES_LIB_DEBUG"]`  |
| <a id="nodejs_binary-entry_point"></a>entry_point |  The script which should be executed first, usually containing a main function.<br><br>If the entry JavaScript file belongs to the same package (as the BUILD file), you can simply reference it by its relative name to the package directory:<br><br><pre><code class="language-starlark">nodejs_binary(&#10;    name = "my_binary",&#10;    ...&#10;    entry_point = ":file.js",&#10;)</code></pre><br><br>You can specify the entry point as a typescript file so long as you also include the ts_library target in data:<br><br><pre><code class="language-starlark">ts_library(&#10;    name = "main",&#10;    srcs = ["main.ts"],&#10;)&#10;&#10;nodejs_binary(&#10;    name = "bin",&#10;    data = [":main"]&#10;    entry_point = ":main.ts",&#10;)</code></pre><br><br>The rule will use the corresponding `.js` output of the ts_library rule as the entry point.<br><br>If the entry point target is a rule, it should produce a single JavaScript entry file that will be passed to the nodejs_binary rule. For example:<br><br><pre><code class="language-starlark">filegroup(&#10;    name = "entry_file",&#10;    srcs = ["main.js"],&#10;)&#10;&#10;nodejs_binary(&#10;    name = "my_binary",&#10;    entry_point = ":entry_file",&#10;)</code></pre><br><br>The entry_point can also be a label in another workspace:<br><br><pre><code class="language-starlark">nodejs_binary(&#10;    name = "history-server",&#10;    entry_point = "@npm//:node_modules/history-server/modules/cli.js",&#10;    data = ["@npm//history-server"],&#10;)</code></pre>   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="nodejs_binary-env"></a>env |  Specifies additional environment variables to set when the target is executed, subject to location expansion.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="nodejs_binary-link_workspace_root"></a>link_workspace_root |  Link the workspace root to the bin_dir to support absolute requires like 'my_wksp/path/to/file'. If source files need to be required then they can be copied to the bin_dir with copy_to_bin.   | Boolean | optional |  `False`  |
| <a id="nodejs_binary-templated_args"></a>templated_args |  Arguments which are passed to every execution of the program. To pass a node startup option, prepend it with `--node_options=`, e.g. `--node_options=--preserve-symlinks`.<br><br>Subject to 'Make variable' substitution. See https://docs.bazel.build/versions/master/be/make-variables.html.<br><br>1. Subject to predefined source/output path variables substitutions.<br><br>The predefined variables `execpath`, `execpaths`, `rootpath`, `rootpaths`, `location`, and `locations` take label parameters (e.g. `$(execpath //foo:bar)`) and substitute the file paths denoted by that label.<br><br>See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_label_variables for more info.<br><br>NB: This $(location) substition returns the manifest file path which differs from the *_binary & *_test args and genrule bazel substitions. This will be fixed in a future major release. See docs string of `expand_location_into_runfiles` macro in `internal/common/expand_into_runfiles.bzl` for more info.<br><br>The recommended approach is to now use `$(rootpath)` where you previously used $(location).<br><br>To get from a `$(rootpath)` to the absolute path that `$$(rlocation $(location))` returned you can either use `$$(rlocation $(rootpath))` if you are in the `templated_args` of a `nodejs_binary` or `nodejs_test`:<br><br>BUILD.bazel: <pre><code class="language-starlark">nodejs_test(&#10;    name = "my_test",&#10;    data = [":bootstrap.js"],&#10;    templated_args = ["--node_options=--require=$$(rlocation $(rootpath :bootstrap.js))"],&#10;)</code></pre><br><br>or if you're in the context of a .js script you can pass the $(rootpath) as an argument to the script and use the javascript runfiles helper to resolve to the absolute path:<br><br>BUILD.bazel: <pre><code class="language-starlark">nodejs_test(&#10;    name = "my_test",&#10;    data = [":some_file"],&#10;    entry_point = ":my_test.js",&#10;    templated_args = ["$(rootpath :some_file)"],&#10;)</code></pre><br><br>my_test.js <pre><code class="language-starlark">const runfiles = require(process.env['BAZEL_NODE_RUNFILES_HELPER']);&#10;const args = process.argv.slice(2);&#10;const some_file = runfiles.resolveWorkspaceRelative(args[0]);</code></pre><br><br>NB: Bazel will error if it sees the single dollar sign $(rlocation path) in `templated_args` as it will try to expand `$(rlocation)` since we now expand predefined & custom "make" variables such as `$(COMPILATION_MODE)`, `$(BINDIR)` & `$(TARGET_CPU)` using `ctx.expand_make_variables`. See https://docs.bazel.build/versions/master/be/make-variables.html.<br><br>To prevent expansion of `$(rlocation)` write it as `$$(rlocation)`. Bazel understands `$$` to be the string literal `$` and the expansion results in `$(rlocation)` being passed as an arg instead of being expanded. `$(rlocation)` is then evaluated by the bash node launcher script and it calls the `rlocation` function in the runfiles.bash helper. For example, the templated arg `$$(rlocation $(rootpath //:some_file))` is expanded by Bazel to `$(rlocation ./some_file)` which is then converted in bash to the absolute path of `//:some_file` in runfiles by the runfiles.bash helper before being passed as an argument to the program.<br><br>NB: nodejs_binary and nodejs_test will preserve the legacy behavior of `$(rlocation)` so users don't need to update to `$$(rlocation)`. This may be changed in the future.<br><br>2. Subject to predefined variables & custom variable substitutions.<br><br>Predefined "Make" variables such as $(COMPILATION_MODE) and $(TARGET_CPU) are expanded. See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_variables.<br><br>Custom variables are also expanded including variables set through the Bazel CLI with --define=SOME_VAR=SOME_VALUE. See https://docs.bazel.build/versions/master/be/make-variables.html#custom_variables.<br><br>Predefined genrule variables are not supported in this context.   | List of strings | optional |  `[]`  |


<a id="nodejs_test"></a>

## nodejs_test

<pre>
nodejs_test(<a href="#nodejs_test-name">name</a>, <a href="#nodejs_test-data">data</a>, <a href="#nodejs_test-chdir">chdir</a>, <a href="#nodejs_test-configuration_env_vars">configuration_env_vars</a>, <a href="#nodejs_test-default_env_vars">default_env_vars</a>, <a href="#nodejs_test-entry_point">entry_point</a>, <a href="#nodejs_test-env">env</a>,
            <a href="#nodejs_test-expected_exit_code">expected_exit_code</a>, <a href="#nodejs_test-link_workspace_root">link_workspace_root</a>, <a href="#nodejs_test-templated_args">templated_args</a>)
</pre>

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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nodejs_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nodejs_test-data"></a>data |  Runtime dependencies which may be loaded during execution.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="nodejs_test-chdir"></a>chdir |  Working directory to run the binary or test in, relative to the workspace. By default, Bazel always runs in the workspace root. Due to implementation details, this argument must be underneath this package directory.<br><br>To run in the directory containing the `nodejs_binary` / `nodejs_test`, use<br><br>    chdir = package_name()<br><br>(or if you're in a macro, use `native.package_name()`)<br><br>WARNING: this will affect other paths passed to the program, either as arguments or in configuration files, which are workspace-relative. You may need `../../` segments to re-relativize such paths to the new working directory.   | String | optional |  `""`  |
| <a id="nodejs_test-configuration_env_vars"></a>configuration_env_vars |  Pass these configuration environment variables to the resulting binary. Chooses a subset of the configuration environment variables (taken from `ctx.var`), which also includes anything specified via the --define flag. Note, this can lead to different outputs produced by this rule.   | List of strings | optional |  `[]`  |
| <a id="nodejs_test-default_env_vars"></a>default_env_vars |  Default environment variables that are added to `configuration_env_vars`.<br><br>This is separate from the default of `configuration_env_vars` so that a user can set `configuration_env_vars` without losing the defaults that should be set in most cases.<br><br>The set of default  environment variables is:<br><br>- `VERBOSE_LOGS`: use by some rules & tools to turn on debug output in their logs - `NODE_DEBUG`: used by node.js itself to print more logs - `RUNFILES_LIB_DEBUG`: print diagnostic message from Bazel runfiles.bash helper   | List of strings | optional |  `["VERBOSE_LOGS", "NODE_DEBUG", "RUNFILES_LIB_DEBUG"]`  |
| <a id="nodejs_test-entry_point"></a>entry_point |  The script which should be executed first, usually containing a main function.<br><br>If the entry JavaScript file belongs to the same package (as the BUILD file), you can simply reference it by its relative name to the package directory:<br><br><pre><code class="language-starlark">nodejs_binary(&#10;    name = "my_binary",&#10;    ...&#10;    entry_point = ":file.js",&#10;)</code></pre><br><br>You can specify the entry point as a typescript file so long as you also include the ts_library target in data:<br><br><pre><code class="language-starlark">ts_library(&#10;    name = "main",&#10;    srcs = ["main.ts"],&#10;)&#10;&#10;nodejs_binary(&#10;    name = "bin",&#10;    data = [":main"]&#10;    entry_point = ":main.ts",&#10;)</code></pre><br><br>The rule will use the corresponding `.js` output of the ts_library rule as the entry point.<br><br>If the entry point target is a rule, it should produce a single JavaScript entry file that will be passed to the nodejs_binary rule. For example:<br><br><pre><code class="language-starlark">filegroup(&#10;    name = "entry_file",&#10;    srcs = ["main.js"],&#10;)&#10;&#10;nodejs_binary(&#10;    name = "my_binary",&#10;    entry_point = ":entry_file",&#10;)</code></pre><br><br>The entry_point can also be a label in another workspace:<br><br><pre><code class="language-starlark">nodejs_binary(&#10;    name = "history-server",&#10;    entry_point = "@npm//:node_modules/history-server/modules/cli.js",&#10;    data = ["@npm//history-server"],&#10;)</code></pre>   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="nodejs_test-env"></a>env |  Specifies additional environment variables to set when the target is executed, subject to location expansion.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="nodejs_test-expected_exit_code"></a>expected_exit_code |  The expected exit code for the test. Defaults to 0.   | Integer | optional |  `0`  |
| <a id="nodejs_test-link_workspace_root"></a>link_workspace_root |  Link the workspace root to the bin_dir to support absolute requires like 'my_wksp/path/to/file'. If source files need to be required then they can be copied to the bin_dir with copy_to_bin.   | Boolean | optional |  `False`  |
| <a id="nodejs_test-templated_args"></a>templated_args |  Arguments which are passed to every execution of the program. To pass a node startup option, prepend it with `--node_options=`, e.g. `--node_options=--preserve-symlinks`.<br><br>Subject to 'Make variable' substitution. See https://docs.bazel.build/versions/master/be/make-variables.html.<br><br>1. Subject to predefined source/output path variables substitutions.<br><br>The predefined variables `execpath`, `execpaths`, `rootpath`, `rootpaths`, `location`, and `locations` take label parameters (e.g. `$(execpath //foo:bar)`) and substitute the file paths denoted by that label.<br><br>See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_label_variables for more info.<br><br>NB: This $(location) substition returns the manifest file path which differs from the *_binary & *_test args and genrule bazel substitions. This will be fixed in a future major release. See docs string of `expand_location_into_runfiles` macro in `internal/common/expand_into_runfiles.bzl` for more info.<br><br>The recommended approach is to now use `$(rootpath)` where you previously used $(location).<br><br>To get from a `$(rootpath)` to the absolute path that `$$(rlocation $(location))` returned you can either use `$$(rlocation $(rootpath))` if you are in the `templated_args` of a `nodejs_binary` or `nodejs_test`:<br><br>BUILD.bazel: <pre><code class="language-starlark">nodejs_test(&#10;    name = "my_test",&#10;    data = [":bootstrap.js"],&#10;    templated_args = ["--node_options=--require=$$(rlocation $(rootpath :bootstrap.js))"],&#10;)</code></pre><br><br>or if you're in the context of a .js script you can pass the $(rootpath) as an argument to the script and use the javascript runfiles helper to resolve to the absolute path:<br><br>BUILD.bazel: <pre><code class="language-starlark">nodejs_test(&#10;    name = "my_test",&#10;    data = [":some_file"],&#10;    entry_point = ":my_test.js",&#10;    templated_args = ["$(rootpath :some_file)"],&#10;)</code></pre><br><br>my_test.js <pre><code class="language-starlark">const runfiles = require(process.env['BAZEL_NODE_RUNFILES_HELPER']);&#10;const args = process.argv.slice(2);&#10;const some_file = runfiles.resolveWorkspaceRelative(args[0]);</code></pre><br><br>NB: Bazel will error if it sees the single dollar sign $(rlocation path) in `templated_args` as it will try to expand `$(rlocation)` since we now expand predefined & custom "make" variables such as `$(COMPILATION_MODE)`, `$(BINDIR)` & `$(TARGET_CPU)` using `ctx.expand_make_variables`. See https://docs.bazel.build/versions/master/be/make-variables.html.<br><br>To prevent expansion of `$(rlocation)` write it as `$$(rlocation)`. Bazel understands `$$` to be the string literal `$` and the expansion results in `$(rlocation)` being passed as an arg instead of being expanded. `$(rlocation)` is then evaluated by the bash node launcher script and it calls the `rlocation` function in the runfiles.bash helper. For example, the templated arg `$$(rlocation $(rootpath //:some_file))` is expanded by Bazel to `$(rlocation ./some_file)` which is then converted in bash to the absolute path of `//:some_file` in runfiles by the runfiles.bash helper before being passed as an argument to the program.<br><br>NB: nodejs_binary and nodejs_test will preserve the legacy behavior of `$(rlocation)` so users don't need to update to `$$(rlocation)`. This may be changed in the future.<br><br>2. Subject to predefined variables & custom variable substitutions.<br><br>Predefined "Make" variables such as $(COMPILATION_MODE) and $(TARGET_CPU) are expanded. See https://docs.bazel.build/versions/master/be/make-variables.html#predefined_variables.<br><br>Custom variables are also expanded including variables set through the Bazel CLI with --define=SOME_VAR=SOME_VALUE. See https://docs.bazel.build/versions/master/be/make-variables.html#custom_variables.<br><br>Predefined genrule variables are not supported in this context.   | List of strings | optional |  `[]`  |


<a id="pkg_npm"></a>

## pkg_npm

<pre>
pkg_npm(<a href="#pkg_npm-name">name</a>, <a href="#pkg_npm-deps">deps</a>, <a href="#pkg_npm-srcs">srcs</a>, <a href="#pkg_npm-nested_packages">nested_packages</a>, <a href="#pkg_npm-node_context_data">node_context_data</a>, <a href="#pkg_npm-package_name">package_name</a>, <a href="#pkg_npm-package_path">package_path</a>,
        <a href="#pkg_npm-substitutions">substitutions</a>, <a href="#pkg_npm-tgz">tgz</a>, <a href="#pkg_npm-validate">validate</a>, <a href="#pkg_npm-vendor_external">vendor_external</a>)
</pre>

The pkg_npm rule creates a directory containing a publishable npm artifact.

Example:

```starlark
load("@build_bazel_rules_nodejs//:index.bzl", "pkg_npm")

pkg_npm(
    name = "my_package",
    srcs = ["package.json"],
    deps = [":my_typescript_lib"],
    substitutions = {"//internal/": "//"},
)
```

You can use a pair of `// BEGIN-INTERNAL ... // END-INTERNAL` comments to mark regions of files that should be elided during publishing.
For example:

```javascript
function doThing() {
    // BEGIN-INTERNAL
    // This is a secret internal-only comment
    doInternalOnlyThing();
    // END-INTERNAL
}
```

With the Bazel stamping feature, pkg_npm will replace any placeholder version in your package with the actual version control tag.
See the [stamping documentation](https://github.com/bazelbuild/rules_nodejs/blob/master/docs/index.md#stamping)

Usage:

`pkg_npm` yields four labels. Build the package directory using the default label:

```sh
$ bazel build :my_package
Target //:my_package up-to-date:
  bazel-out/fastbuild/bin/my_package
$ ls -R bazel-out/fastbuild/bin/my_package
```

Dry-run of publishing to npm, calling `npm pack` (it builds the package first if needed):

```sh
$ bazel run :my_package.pack
INFO: Running command line: bazel-out/fastbuild/bin/my_package.pack
my-package-name-1.2.3.tgz
$ tar -tzf my-package-name-1.2.3.tgz
```

Actually publish the package with `npm publish` (also builds first):

```sh
# Check login credentials
$ bazel run @nodejs//:npm_node_repositories who
# Publishes the package
$ bazel run :my_package.publish
```

You can pass arguments to npm by escaping them from Bazel using a double-hyphen, for example:

`bazel run my_package.publish -- --tag=next`

It is also possible to use the resulting tar file file from the `.pack` as an action input via the `.tar` label.
To make use of this label, the `tgz` attribute must be set, and the generating `pkg_npm` rule must have a valid `package.json` file
as part of its sources:

```starlark
pkg_npm(
    name = "my_package",
    srcs = ["package.json"],
    deps = [":my_typescript_lib"],
    tgz = "my_package.tgz",
)

my_rule(
    name = "foo",
    srcs = [
        "//:my_package.tar",
    ],
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="pkg_npm-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="pkg_npm-deps"></a>deps |  Other targets which produce files that should be included in the package, such as `rollup_bundle`   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="pkg_npm-srcs"></a>srcs |  Files inside this directory which are simply copied into the package.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="pkg_npm-nested_packages"></a>nested_packages |  Other pkg_npm rules whose content is copied into this package.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="pkg_npm-node_context_data"></a>node_context_data |  Provides info about the build context, such as stamping.<br><br>By default it reads from the bazel command line, such as the `--stamp` argument. Use this to override values for this target, such as enabling or disabling stamping. You can use the `node_context_data` rule in `@build_bazel_rules_nodejs//internal/node:context.bzl` to create a NodeContextInfo.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@build_bazel_rules_nodejs//internal:node_context_data"`  |
| <a id="pkg_npm-package_name"></a>package_name |  Optional package_name that this npm package may be imported as.   | String | optional |  `""`  |
| <a id="pkg_npm-package_path"></a>package_path |  The directory in the workspace to link to. If set, link this pkg_npm to the node_modules under the package path specified. If unset, the default is to link to the node_modules root of the workspace.   | String | optional |  `""`  |
| <a id="pkg_npm-substitutions"></a>substitutions |  Key-value pairs which are replaced in all the files while building the package.<br><br>You can use values from the workspace status command using curly braces, for example `{"0.0.0-PLACEHOLDER": "{STABLE_GIT_VERSION}"}`.<br><br>See the section on stamping in the [README](stamping)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="pkg_npm-tgz"></a>tgz |  If set, will create a `.tgz` file that can be used as an input to another rule, the tar will be given the name assigned to this attribute.<br><br>NOTE: If this attribute is set, a valid `package.json` file must be included in the sources of this target   | String | optional |  `""`  |
| <a id="pkg_npm-validate"></a>validate |  Whether to check that the attributes match the package.json   | Boolean | optional |  `False`  |
| <a id="pkg_npm-vendor_external"></a>vendor_external |  External workspaces whose contents should be vendored into this workspace. Avoids `external/foo` path segments in the resulting package.   | List of strings | optional |  `[]`  |


<a id="js_library"></a>

## js_library

<pre>
js_library(<a href="#js_library-name">name</a>, <a href="#js_library-srcs">srcs</a>, <a href="#js_library-package_name">package_name</a>, <a href="#js_library-package_path">package_path</a>, <a href="#js_library-deps">deps</a>, <a href="#js_library-kwargs">kwargs</a>)
</pre>

Groups JavaScript code so that it can be depended on like an npm package.

`js_library` is intended to be used internally within Bazel, such as between two libraries in your monorepo.
This rule doesn't perform any build steps ("actions") so it is similar to a `filegroup`.
However it provides several Bazel "Providers" for interop with other rules.

> Compare this to `pkg_npm` which just produces a directory output, and therefore can't expose individual
> files to downstream targets and causes a cascading re-build of all transitive dependencies when any file
> changes. Also `pkg_npm` is intended to publish your code for external usage outside of Bazel, like
> by publishing to npm or artifactory, while `js_library` is for internal dependencies within your repo.

`js_library` also copies any source files into the bazel-out folder.
This is the same behavior as the `copy_to_bin` rule.
By copying the complete package to the output tree, we ensure that the linker (our `npm link` equivalent)
will make your source files available in the node_modules tree where resolvers expect them.
It also means you can have relative imports between the files
rather than being forced to use Bazel's "Runfiles" semantics where any program might need a helper library
to resolve files between the logical union of the source tree and the output tree.

### Example

A typical example usage of `js_library` is to expose some sources with a package name:

```starlark
ts_project(
    name = "compile_ts",
    srcs = glob(["*.ts"]),
)

js_library(
    name = "my_pkg",
    # Code that depends on this target can import from "@myco/mypkg"
    package_name = "@myco/mypkg",
    # Consumers might need fields like "main" or "typings"
    srcs = ["package.json"],
    # The .js and .d.ts outputs from above will be part of the package
    deps = [":compile_ts"],
)
```

> To help work with "named AMD" modules as required by `concatjs_devserver` and other Google-style "concatjs" rules,
> `js_library` has some undocumented advanced features you can find in the source code or in our examples.
> These should not be considered a public API and aren't subject to our usual support and semver guarantees.

### Outputs

Like all Bazel rules it produces a default output by providing [DefaultInfo].
You'll get these outputs if you include this in the `srcs` of a typical rule like `filegroup`,
and these will be the printed result when you `bazel build //some:js_library_target`.
The default outputs are all of:
- [DefaultInfo] produced by targets in `deps`
- A copy of all sources (InputArtifacts from your source tree) in the bazel-out directory

When there are TypeScript typings files, `js_library` provides [DeclarationInfo](#declarationinfo)
so this target can be a dependency of a TypeScript rule. This includes any `.d.ts` files in `srcs` as well
as transitive ones from `deps`.
It will also provide [OutputGroupInfo] with a "types" field, so you can select the typings outputs with
`bazel build //some:js_library_target --output_groups=types` or with a `filegroup` rule using the
[output_group] attribute.

In order to work with the linker (similar to `npm link` for first-party monorepo deps), `js_library` provides
[LinkablePackageInfo](#linkablepackageinfo) for use with our "linker" that makes this package importable.

It also provides:
- [ExternalNpmPackageInfo](#externalnpmpackageinfo) to interop with rules that expect third-party npm packages.
- [JSModuleInfo](#jsmoduleinfo) so rules like bundlers can collect the transitive set of .js files
- [JSNamedModuleInfo](#jsnamedmoduleinfo) for rules that expect named AMD or `goog.module` format JS

[OutputGroupInfo]: https://docs.bazel.build/versions/master/skylark/lib/OutputGroupInfo.html
[DefaultInfo]: https://docs.bazel.build/versions/master/skylark/lib/DefaultInfo.html
[output_group]: https://docs.bazel.build/versions/master/be/general.html#filegroup.output_group


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="js_library-name"></a>name |  The name for the target   |  none |
| <a id="js_library-srcs"></a>srcs |  The list of files that comprise the package   |  `[]` |
| <a id="js_library-package_name"></a>package_name |  The name it will be imported by. Should match the "name" field in the package.json file.<br><br>If package_name == "$node_modules$" this indictates that this js_library target is one or more external npm packages in node_modules. This is a special case that used be covered by the internal only `external_npm_package` attribute. NB: '$' is an illegal character for npm packages names so this reserved name will not conflict with any valid package_name values<br><br>This is used by the yarn_install & npm_install repository rules for npm dependencies installed by yarn & npm. When true, js_library will provide ExternalNpmPackageInfo.<br><br>It can also be used for user-managed npm dependencies if node_modules is layed out outside of bazel. For example,<br><br><pre><code class="language-starlark">js_library(&#10;    name = "node_modules",&#10;    srcs = glob(&#10;        include = [&#10;            "node_modules/**/*.js",&#10;            "node_modules/**/*.d.ts",&#10;            "node_modules/**/*.json",&#10;            "node_modules/.bin/*",&#10;        ],&#10;        exclude = [&#10;            # Files under test & docs may contain file names that&#10;            # are not legal Bazel labels (e.g.,&#10;            # node_modules/ecstatic/test/public/ä¸­æ/æªæ¡.html)&#10;            "node_modules/**/test/**",&#10;            "node_modules/**/docs/**",&#10;            # Files with spaces in the name are not legal Bazel labels&#10;            "node_modules/**/* */**",&#10;            "node_modules/**/* *",&#10;        ],&#10;    ),&#10;    # Special value to provide ExternalNpmPackageInfo which is used by downstream&#10;    # rules that use these npm dependencies&#10;    package_name = "$node_modules$",&#10;)</code></pre><br><br>See `examples/user_managed_deps` for a working example of user-managed npm dependencies.   |  `None` |
| <a id="js_library-package_path"></a>package_path |  The directory in the workspace to link to. If set, link this js_library to the node_modules under the package path specified. If unset, the default is to link to the node_modules root of the workspace.   |  `""` |
| <a id="js_library-deps"></a>deps |  Other targets that provide JavaScript code   |  `[]` |
| <a id="js_library-kwargs"></a>kwargs |  Other attributes   |  none |


