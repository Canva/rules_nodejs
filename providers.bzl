"""
Exports for backward compatibility with Rules NodeJS v3.
"""

load("//lib:providers.bzl", _DeclarationInfo = "DeclarationInfo", _ExternalNpmPackageInfo = "ExternalNpmPackageInfo")

visibility(["public"])

DeclarationInfo = _DeclarationInfo

ExternalNpmPackageInfo = _ExternalNpmPackageInfo
# Export NpmPackageInfo for pre-3.0 legacy support in downstream rule sets
# such as rules_docker
# TODO(4.0): remove NpmPackageInfo
NpmPackageInfo = _ExternalNpmPackageInfo
