"""
This BUILD file is auto-generated from toolchains/node/BUILD.tpl
"""

package(default_visibility = ["//visibility:public"])

load("@build_bazel_rules_nodejs//lib:toolchains.bzl", "node_toolchain")

node_toolchain(
    name = "toolchain",
%{TOOL_ATTRS}
)
