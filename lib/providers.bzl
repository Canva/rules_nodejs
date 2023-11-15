"""
Providers.


```starlark
load("build_bazel_rules_nodejs//lib:providers.bzl", ...)
```
"""

load("//lib/private:providers.bzl", _DeclarationInfo = "DeclarationInfo", _ExternalNpmPackageInfo = "ExternalNpmPackageInfo")

visibility(["public"])

DeclarationInfo = _DeclarationInfo
ExternalNpmPackageInfo = _ExternalNpmPackageInfo
