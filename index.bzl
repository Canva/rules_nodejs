"""
Exports for backward compatibility with Rules NodeJS v3.
"""

load("//lib:rules.bzl", _nodejs_binary = "nodejs_binary", _nodejs_test = "nodejs_test", _pkg_npm = "pkg_npm", _js_library = "js_library")
load("//lib:workspace.bzl", _nodejs_download = "nodejs_download")
load("//lib/private:repositories.bzl", _yarn_install = "yarn_install")

visibility(["public"])

yarn_install = _yarn_install
node_repositories = _nodejs_download
nodejs_binary = _nodejs_binary
nodejs_test = _nodejs_test
pkg_npm = _pkg_npm
js_library = _js_library
