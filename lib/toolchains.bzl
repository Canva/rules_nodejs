"""
Toolchains.


```starlark
load("build_bazel_rules_nodejs//lib:toolchains.bzl", ...)
```
"""

load("//lib/private:toolchains.bzl", _node_toolchain = "node_toolchain")

visibility(["public"])

node_toolchain = _node_toolchain
