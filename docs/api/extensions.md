<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Module extensions.

<a id="node_modules"></a>

## node_modules

<pre>
node_modules = use_extension("@build_bazel_rules_nodejs//lib:extensions.bzl", "node_modules")
node_modules.yarn(<a href="#node_modules.yarn-name">name</a>, <a href="#node_modules.yarn-data">data</a>, <a href="#node_modules.yarn-args">args</a>, <a href="#node_modules.yarn-environment">environment</a>, <a href="#node_modules.yarn-exports_directories_only">exports_directories_only</a>, <a href="#node_modules.yarn-frozen_lockfile">frozen_lockfile</a>,
                  <a href="#node_modules.yarn-generate_local_modules_build_files">generate_local_modules_build_files</a>, <a href="#node_modules.yarn-host_node_bin">host_node_bin</a>, <a href="#node_modules.yarn-host_yarn_bin">host_yarn_bin</a>, <a href="#node_modules.yarn-included_files">included_files</a>,
                  <a href="#node_modules.yarn-manual_build_file_contents">manual_build_file_contents</a>, <a href="#node_modules.yarn-package_json">package_json</a>, <a href="#node_modules.yarn-package_path">package_path</a>, <a href="#node_modules.yarn-quiet">quiet</a>, <a href="#node_modules.yarn-timeout">timeout</a>,
                  <a href="#node_modules.yarn-use_global_yarn_cache">use_global_yarn_cache</a>, <a href="#node_modules.yarn-yarn_lock">yarn_lock</a>)
</pre>


**TAG CLASSES**

<a id="node_modules.yarn"></a>

### yarn

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="node_modules.yarn-name"></a>name |  -   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="node_modules.yarn-data"></a>data |  Data files required by this rule.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="node_modules.yarn-args"></a>args |  Arguments passed to yarn install.<br><br>See yarn CLI docs https://yarnpkg.com/en/docs/cli/install for complete list of supported arguments.   | List of strings | optional |  `[]`  |
| <a id="node_modules.yarn-environment"></a>environment |  Environment variables to set before calling the package manager.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="node_modules.yarn-exports_directories_only"></a>exports_directories_only |  Export only top-level package directory artifacts from node_modules.<br><br>Turning this on will decrease the time it takes for Bazel to setup runfiles and sandboxing when there are a large number of npm dependencies as inputs to an action.<br><br>This breaks compatibility for labels that reference files within npm packages such as `@npm//:node_modules/prettier/bin-prettier.js`. To reference files within npm packages, you can use the `directory_file_path` rule and/or `DirectoryFilePathInfo` provider. Note, some rules still need upgrading to support consuming `DirectoryFilePathInfo` where needed.<br><br>NB: This feature requires runfiles be enabled due to an issue in Bazel which we are still investigating.     On Windows runfiles are off by default and must be enabled with the `--enable_runfiles` flag when     using this feature.<br><br>NB: `ts_library` does not support directory npm deps due to internal dependency on having all input sources files explicitly specified.<br><br>NB: `protractor_web_test` and `protractor_web_test_suite` do not support directory npm deps.<br><br>For the `nodejs_binary` & `nodejs_test` `entry_point` attribute (which often needs to reference a file within an npm package) you can set the entry_point to a dict with a single entry, where the key corresponds to the directory label and the value corresponds to the path within that directory to the entry point.<br><br>For example,<br><br><pre><code>nodejs_binary(&#10;    name = "prettier",&#10;    data = ["@npm//prettier"],&#10;    entry_point = "@npm//:node_modules/prettier/bin-prettier.js",&#10;)</code></pre><br><br>becomes,<br><br><pre><code>nodejs_binary(&#10;    name = "prettier",&#10;    data = ["@npm//prettier"],&#10;    entry_point = { "@npm//:node_modules/prettier": "bin-prettier.js" },&#10;)</code></pre><br><br>For labels that are passed to `$(rootpath)`, `$(execpath)`, or `$(location)` you can simply break these apart into the directory label that gets passed to the expander & path part to follows it.<br><br>For example,<br><br><pre><code>$(rootpath @npm//:node_modules/prettier/bin-prettier.js")</code></pre><br><br>becomes,<br><br><pre><code>$(rootpath @npm//:node_modules/prettier)/bin-prettier.js</code></pre>   | Boolean | optional |  `False`  |
| <a id="node_modules.yarn-frozen_lockfile"></a>frozen_lockfile |  Use the `--frozen-lockfile` flag for yarn.<br><br>Don't generate a `yarn.lock` lockfile and fail if an update is needed.<br><br>This flag enables an exact install of the version that is specified in the `yarn.lock` file. This helps to have reproducible builds across builds.<br><br>To update a dependency or install a new one run the `yarn install` command with the vendored yarn binary. `bazel run @nodejs//:yarn install`. You can pass the options like `bazel run @nodejs//:yarn install -- -D <dep-name>`.   | Boolean | optional |  `True`  |
| <a id="node_modules.yarn-generate_local_modules_build_files"></a>generate_local_modules_build_files |  Enables the BUILD files auto generation for local modules installed with `file:` (npm) or `link:` (yarn)<br><br>When using a monorepo it's common to have modules that we want to use locally and publish to an external package repository. This can be achieved using a `js_library` rule with a `package_name` attribute defined inside the local package `BUILD` file. However, if the project relies on the local package dependency with `file:` (npm) or `link:` (yarn) to be used outside Bazel, this could introduce a race condition with both `npm_install` or `yarn_install` rules.<br><br>In order to overcome it, a link could be created to the package `BUILD` file from the npm external Bazel repository (so we can use a local BUILD file instead of an auto generated one), which require us to set `generate_local_modules_build_files = False` and complete a last step which is writing the expected targets on that same `BUILD` file to be later used both by `npm_install` or `yarn_install` rules, which are: `<package_name__files>`, `<package_name__nested_node_modules>`, `<package_name__contents>`, `<package_name__typings>` and the last one just `<package_name>`. If you doubt what those targets should look like, check the generated `BUILD` file for a given node module.<br><br>When true, the rule will follow the default behaviour of auto generating BUILD files for each `node_module` at install time.<br><br>When False, the rule will not auto generate BUILD files for `node_modules` that are installed as symlinks for local modules.   | Boolean | optional |  `True`  |
| <a id="node_modules.yarn-host_node_bin"></a>host_node_bin |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="node_modules.yarn-host_yarn_bin"></a>host_yarn_bin |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="node_modules.yarn-included_files"></a>included_files |  List of file extensions to be included in the npm package targets.<br><br>NB: This option has no effect when exports_directories_only is True as all files are automatically included in the exported directory for each npm package.<br><br>For example, [".js", ".d.ts", ".proto", ".json", ""].<br><br>This option is useful to limit the number of files that are inputs to actions that depend on npm package targets. See https://github.com/bazelbuild/bazel/issues/5153.<br><br>If set to an empty list then all files are included in the package targets. If set to a list of extensions, only files with matching extensions are included in the package targets. An empty string in the list is a special string that denotes that files with no extensions such as `README` should be included in the package targets.<br><br>This attribute applies to both the coarse `@wksp//:node_modules` target as well as the fine grained targets such as `@wksp//foo`.   | List of strings | optional |  `[]`  |
| <a id="node_modules.yarn-manual_build_file_contents"></a>manual_build_file_contents |  Experimental attribute that can be used to override the generated BUILD.bazel file and set its contents manually.<br><br>Can be used to work-around a bazel performance issue if the default `@wksp//:node_modules` target has too many files in it. See https://github.com/bazelbuild/bazel/issues/5153. If you are running into performance issues due to a large node_modules target it is recommended to switch to using fine grained npm dependencies.   | String | optional |  `""`  |
| <a id="node_modules.yarn-package_json"></a>package_json |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="node_modules.yarn-package_path"></a>package_path |  If set, link the 3rd party node_modules dependencies under the package path specified.<br><br>In most cases, this should be the directory of the package.json file so that the linker links the node_modules in the same location they are found in the source tree. In a future release, this will default to the package.json directory. This is planned for 4.0: https://github.com/bazelbuild/rules_nodejs/issues/2451   | String | optional |  `""`  |
| <a id="node_modules.yarn-quiet"></a>quiet |  If stdout and stderr should be printed to the terminal.   | Boolean | optional |  `True`  |
| <a id="node_modules.yarn-timeout"></a>timeout |  Maximum duration of the package manager execution in seconds.   | Integer | optional |  `3600`  |
| <a id="node_modules.yarn-use_global_yarn_cache"></a>use_global_yarn_cache |  Use the global yarn cache on the system.<br><br>The cache lets you avoid downloading packages multiple times. However, it can introduce non-hermeticity, and the yarn cache can have bugs.<br><br>Disabling this attribute causes every run of yarn to have a unique cache_directory.<br><br>If True, this rule will pass `--mutex network` to yarn to ensure that the global cache can be shared by parallelized yarn_install rules.<br><br>If False, this rule will pass `--cache-folder /path/to/external/repository/__yarn_cache` to yarn so that the local cache is contained within the external repository.   | Boolean | optional |  `True`  |
| <a id="node_modules.yarn-yarn_lock"></a>yarn_lock |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


<a id="nodejs"></a>

## nodejs

<pre>
nodejs = use_extension("@build_bazel_rules_nodejs//lib:extensions.bzl", "nodejs")
nodejs.download(<a href="#nodejs.download-name">name</a>, <a href="#nodejs.download-node_download_auth">node_download_auth</a>, <a href="#nodejs.download-node_repositories">node_repositories</a>, <a href="#nodejs.download-node_urls">node_urls</a>, <a href="#nodejs.download-node_version">node_version</a>, <a href="#nodejs.download-package_json">package_json</a>,
                <a href="#nodejs.download-preserve_symlinks">preserve_symlinks</a>, <a href="#nodejs.download-yarn_download_auth">yarn_download_auth</a>, <a href="#nodejs.download-yarn_repositories">yarn_repositories</a>, <a href="#nodejs.download-yarn_urls">yarn_urls</a>, <a href="#nodejs.download-yarn_version">yarn_version</a>)
</pre>


**TAG CLASSES**

<a id="nodejs.download"></a>

### download

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="nodejs.download-name"></a>name |  -   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="nodejs.download-node_download_auth"></a>node_download_auth |  Auth to use for all url requests Example: `{"type": "basic", "login": "<UserName>", "password": "<Password>" }`   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="nodejs.download-node_repositories"></a>node_repositories |  Custom list of node repositories to use<br><br>A dictionary mapping NodeJS versions to sets of hosts and their corresponding (filename, strip_prefix, sha256) tuples. You should list a node binary for every platform users have, likely Mac, Windows, and Linux.<br><br>By default, if this attribute has no items, we'll use a list of all public NodeJS releases.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional |  `{}`  |
| <a id="nodejs.download-node_urls"></a>node_urls |  Custom list of URLs to use to download NodeJS<br><br>Each entry is a template for downloading a node distribution.<br><br>The `{version}` parameter is substituted with the `node_version` attribute, and `{filename}` with the matching entry from the `node_repositories` attribute.   | List of strings | optional |  `["https://nodejs.org/dist/v{version}/{filename}"]`  |
| <a id="nodejs.download-node_version"></a>node_version |  The specific version of NodeJS to install.   | String | required |  |
| <a id="nodejs.download-package_json"></a>package_json |  (ADVANCED, not recommended) A list of labels, which indicate the package.json files that will be installed when you manually run the package manager, e.g. with `bazel run @nodejs//:yarn_node_repositories` or `bazel run @nodejs//:npm_node_repositories install`. If you use bazel-managed dependencies, you should omit this attribute.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="nodejs.download-preserve_symlinks"></a>preserve_symlinks |  Turn on --node_options=--preserve-symlinks for nodejs_binary and nodejs_test rules.<br><br>When this option is turned on, node will preserve the symlinked path for resolves instead of the default behavior of resolving to the real path. This means that all required files must be in be included in your runfiles as it prevents the default behavior of potentially resolving outside of the runfiles. For example, all required files need to be included in your node_modules filegroup. This option is desirable as it gives a stronger guarantee of hermeticity which is required for remote execution.   | Boolean | optional |  `True`  |
| <a id="nodejs.download-yarn_download_auth"></a>yarn_download_auth |  Auth to use for all url requests Example: `{"type": "basic", "login": "<UserName>", "password": "<Password>" }`   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="nodejs.download-yarn_repositories"></a>yarn_repositories |  Custom list of yarn repositories to use.<br><br>Dictionary mapping Yarn versions to their corresponding (filename, strip_prefix, sha256) tuples.<br><br>By default, if this attribute has no items, we'll use a list of all public NodeJS releases.   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> List of strings</a> | optional |  `{}`  |
| <a id="nodejs.download-yarn_urls"></a>yarn_urls |  Custom list of URLs to use to download Yarn<br><br>Each entry is a template, similar to the `node_urls` attribute, using `yarn_version` and `yarn_repositories` in the substitutions.<br><br>If this list is empty, we won't download yarn at all.   | List of strings | optional |  `["https://github.com/yarnpkg/yarn/releases/download/v{version}/{filename}"]`  |
| <a id="nodejs.download-yarn_version"></a>yarn_version |  The specific version of Yarn to install   | String | required |  |


