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

workspace(
    name = "build_bazel_rules_nodejs",
    managed_directories = {
        "@angular_deps": ["packages/angular/node_modules"],
        # cypress_deps must be a managed directory to ensure it is downloaded before cypress_repository is run.
        "@cypress_deps": ["packages/cypress/test/node_modules"],
        "@internal_npm_install_test_patches_npm_symlinked": ["internal/npm_install/test/patches_npm_symlinked/node_modules"],
        "@internal_npm_install_test_patches_yarn_symlinked": ["internal/npm_install/test/patches_yarn_symlinked/node_modules"],
        "@internal_test_multi_linker_sub_deps": ["internal/linker/test/multi_linker/sub/node_modules"],
        "@npm": ["node_modules"],
        "@npm_node_patches": ["packages/node-patches/node_modules"],
    },
)

load("//:index.bzl", "SUPPORTED_BAZEL_VERSIONS", "node_repositories")

node_repositories(node_version = "18.16.1", yarn_version = "1.22.19")

#
# Install rules_nodejs dev dependencies
#

load("//:package.bzl", "rules_nodejs_dev_dependencies")

rules_nodejs_dev_dependencies()

#
# Setup local respositories
#

local_repository(
    name = "build_bazel_rules_typescript",
    path = "third_party/github.com/bazelbuild/rules_typescript",
)

local_repository(
    name = "internal_npm_package_test_vendored_external",
    path = "internal/pkg_npm/test/vendored_external",
)

#
# Setup rules_nodejs npm dependencies
#

load("@build_bazel_rules_nodejs//:npm_deps.bzl", "npm_deps")

npm_deps()

load("@build_bazel_rules_nodejs//internal/npm_tarballs:translate_package_lock.bzl", "translate_package_lock")

# Translate our package.lock file from JSON to Starlark
translate_package_lock(
    name = "npm_node_patches_lock",
    package_lock = "//packages/node-patches:package-lock.json",
)

load("@npm_node_patches_lock//:index.bzl", _npm_patches_repositories = "npm_repositories")

# Declare an external repository for each npm package fetchable by the lock file
_npm_patches_repositories()

# We have a source dependency on build_bazel_rules_typescript
# so we must repeat its transitive toolchain deps
load("@build_bazel_rules_typescript//:package.bzl", "rules_typescript_dev_dependencies")

rules_typescript_dev_dependencies()

# Install labs dependencies
load("//packages/labs:package.bzl", "npm_bazel_labs_dependencies")

npm_bazel_labs_dependencies()

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

gazelle_dependencies()

go_rules_dependencies()

go_register_toolchains()

load("@build_bazel_rules_typescript//internal:ts_repositories.bzl", "ts_setup_dev_workspace")

ts_setup_dev_workspace()

#
# Install @bazel/cypress dependencies
#
load("//packages/cypress:index.bzl", "cypress_repository")

cypress_repository(
    name = "cypress",
    cypress_bin = "@cypress_deps//:node_modules/cypress/bin/cypress",
    # Currently cypress cannot be installed on our Linux/Windows CI machines
    fail_on_error = False,
)

# Setup the rules_webtesting toolchain
load("@io_bazel_rules_webtesting//web:repositories.bzl", "web_test_repositories")

web_test_repositories()

load("@io_bazel_rules_webtesting//web/versioned:browsers-0.3.2.bzl", "browser_repositories")

browser_repositories(
    chromium = True,
    firefox = True,
)

# Setup esbuild dependencies
load("//packages/esbuild:esbuild_repo.bzl", "esbuild_dependencies")

esbuild_dependencies()

#
# Dependencies to run stardoc & generating documentation
#

load("@io_bazel_rules_sass//sass:sass_repositories.bzl", "sass_repositories")

sass_repositories()

load("@io_bazel_stardoc//:setup.bzl", "stardoc_repositories")

stardoc_repositories()

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")

rules_pkg_dependencies()

# Needed for starlark unit testing
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@build_bazel_integration_testing//tools:repositories.bzl", "bazel_binaries")

# Depend on the Bazel binaries
bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)

## Rules JS

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "aspect_rules_js",
    sha256 = "295a73d963bad4b04a3c488d60dc8a76a659ee64708be3a66be75726e6277c7e",
    strip_prefix = "rules_js-1.33.3",
    url = "https://github.com/aspect-build/rules_js/releases/download/v1.33.3/rules_js-v1.33.3.tar.gz",
)

load("@aspect_rules_js//js:repositories.bzl", "rules_js_dependencies")

rules_js_dependencies()

load("@rules_nodejs//nodejs:repositories.bzl", "nodejs_register_toolchains")

nodejs_register_toolchains(
    name = "nodejs_core",
    node_version = "18.13.0",
)

# For convenience, npm_translate_lock does this call automatically.
# Uncomment if you don't call npm_translate_lock at all.
#load("@bazel_features//:deps.bzl", "bazel_features_deps")
#bazel_features_deps()

load("@aspect_rules_js//npm:repositories.bzl", "npm_translate_lock")

npm_translate_lock(
    name = "pnpm",
    pnpm_lock = "//internal:pnpm-lock.yaml",
    npmrc = "//internal:.npmrc",
    verify_node_modules_ignored = "//:.bazelignore",
    data = [
        "//internal:package.json",
        "//internal:pnpm-workspace.yaml",
    ],
    quiet = False,
)

load("@pnpm//:repositories.bzl", "npm_repositories")

npm_repositories()

## Rules TS

http_archive(
    name = "aspect_rules_ts",
    sha256 = "4c3f34fff9f96ffc9c26635d8235a32a23a6797324486c7d23c1dfa477e8b451",
    strip_prefix = "rules_ts-1.4.5",
    url = "https://github.com/aspect-build/rules_ts/releases/download/v1.4.5/rules_ts-v1.4.5.tar.gz",
)

load("@aspect_rules_ts//ts:repositories.bzl", "rules_ts_dependencies")

rules_ts_dependencies(
    ts_version = "5.2.2",
    ts_integrity = "sha512-mI4WrpHsbCIcwT9cF4FZvr80QUeKvsUsUvKDoR+X/7XHQH98xYD8YHZg7ANtz2GtZt/CBq2QJ0thkGJMHfqc1w==",
)

## Aspect Bazel Lib
http_archive(
    name = "aspect_bazel_lib",
    sha256 = "ce259cbac2e94a6dff01aff9455dcc844c8af141503b02a09c2642695b7b873e",
    strip_prefix = "bazel-lib-1.37.0",
    url = "https://github.com/aspect-build/bazel-lib/releases/download/v1.37.0/bazel-lib-v1.37.0.tar.gz",
)

load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies")

aspect_bazel_lib_dependencies()
