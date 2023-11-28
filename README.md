# Rules NodeJS

A fork of Rules NodeJS v3 updated to align with Bazel 6 ruleset standards (were viable).

Some other rulesets use Rules NodeJS, limited backward compatibility is available so fixes here also apply to those rulesets.

This ruleset targets Bazel 6, but is developed in Bazel 7. E2E tests (to be implemented) run using Bazel 6 and 7.

## Legacy Exports

These are kept only for backward compatibility and will be removed as dependency on implementation details is reduced.

- `//:index.bzl`
  - Repo rule `yarn_install`
  - Rule `nodejs_binary`
  - Rule `nodejs_test`
  - Rule `js_library`
  - Rule `pkg_npm`
- `//toolchains/node:node_toolchain.bzl`
  - Toolchain `node_toolchain`
- `//:providers.bzl`
  - Provider `NpmPackageInfo`
  - Provider `DeclarationInfo`

## Current Exports

The full current public API is accessible under `lib/`, excluding `lib/internal/` and `lib/private`.

## Installation

### Bzlmod

```starlark
# MODULE.bazel

# For the ruleset
# TODO Resolve collision on bazel registry
bazel_dep(name = "build_bazel_rules_nodejs", version = "3.8.0")

# For NodeJS
nodejs = use_extension("@build_bazel_rules_nodejs//lib:extensions.bzl", "nodejs")
nodejs.download(
    name = "nodejs",
    node_version = "20.8.0",
    yarn_version = "1.22.10",
)
use_repo(nodejs, "nodejs")
use_repo(nodejs, "nodejs_host")

register_toolchains("@nodejs//toolchains:all")

# For node_modules (via Yarn Classic)
node_modules = use_extension("@build_bazel_rules_nodejs//lib:extensions.bzl", "node_modules")
node_modules.yarn(
    name = "node_modules",
    package_json = "//:package.json",
    yarn_lock = "//:yarn.lock",
    host_node_bin = "@nodejs_host//:bin/node",
    host_yarn_bin = "@nodejs_host//:bin/yarn",
)
use_repo(node_modules, "node_modules")
```

### Workspace

```starlark
# WORKSPACE.bazel
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Required dependency, Skylib v1.4.2
http_archive(
    name = "bazel_skylib",
    sha256 = "66ffd9315665bfaafc96b52278f57c7e2dd09f5ede279ea6d39b2be471e7e3aa",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
    ],
)
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

# Required dependency, Aspect's Bazel Helpers Library v1.35.0
http_archive(
    name = "aspect_bazel_lib",
    sha256 = "e9505bd956da64b576c433e4e41da76540fd8b889bbd17617fe480a646b1bfb9",
    strip_prefix = "bazel-lib-1.35.0",
    url = "https://github.com/aspect-build/bazel-lib/releases/download/v1.35.0/bazel-lib-v1.35.0.tar.gz",
)
load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies")
aspect_bazel_lib_dependencies()

# For the ruleset
http_archive(
  # TODO ...
)

# For NodeJS
load("@build_bazel_rules_nodejs//lib:workspace.bzl", "nodejs_download")
nodejs_download(
    name = "nodejs",
    node_version = "20.8.0",
    yarn_version = "1.22.10",
)
register_toolchains("@nodejs//toolchains:all")

# For node_modules (via Yarn)
load("@build_bazel_rules_nodejs//lib:workspace.bzl", "node_modules_yarn")
node_modules_yarn(
    name = "node_modules",
    package_json = "//:package.json",
    yarn_lock = "//:yarn.lock",
    host_node_bin = "@nodejs_host//:bin/node",
    host_yarn_bin = "@nodejs_host//:bin/yarn",
)
```

## TODO

- Dist scripts
  - `lib/internal/rules/pkg_npm/npm_script_generater.js`
  - `lib/internal/rules/pkg_npm/packager.js`
- Update to Rules NodeJS v6 (dev dependency)
- Use NodeJS v20 (dev dependency)
- Add checks to `node.download(...)`
- Restore the NodeJS versions data script, or remove it in favour of making it easier to manually manage (akin to `@aspect_bazel_lib//lib:write_source_files.bzl`)
