"""
Rules.


```starlark
load("build_bazel_rules_nodejs//lib:rules.bzl", ...)
```
"""

load("//lib/private:rules.bzl", _pkg_npm = "pkg_npm", _js_library = "js_library", _nodejs_binary = "nodejs_binary", _nodejs_test = "nodejs_test")

visibility(["public"])

nodejs_binary = _nodejs_binary
nodejs_test = _nodejs_test
pkg_npm = _pkg_npm
js_library = _js_library
