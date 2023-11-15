"""
Toolchain implementations.
"""

load("//lib/private:rules/directory_file_path.bzl", _directory_file_path = "directory_file_path")
load("//lib/private:rules/js_library.bzl", _js_library = "js_library")
load("//lib/private:rules/nodejs_binary_test/impl.bzl", _nodejs_binary = "nodejs_binary", _nodejs_test = "nodejs_test")
load("//lib/private:rules/pkg_npm.bzl", _pkg_npm = "pkg_npm")

visibility(["//", "//lib", "//lib/private"])

pkg_npm = _pkg_npm
js_library = _js_library
nodejs_binary = _nodejs_binary
nodejs_test = _nodejs_test
directory_file_path = _directory_file_path
