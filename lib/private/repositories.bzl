"""
Repository rule implementations.
"""

load("//lib/private:repositories/nodejs_download/impl.bzl", _nodejs_download = "nodejs_download")
load("//lib/private:repositories/nodejs_host_alias.bzl", _nodejs_host_alias = "nodejs_host_alias")
load("//lib/private:repositories/nodejs_toolchain_configure/impl.bzl", _node_toolchain_configure = "node_toolchain_configure")
load("//lib/private:repositories/yarn_install/attrs.bzl", _YARN_INSTALL_ATTRS = "YARN_INSTALL_ATTRS")
load("//lib/private:repositories/yarn_install/impl.bzl", _yarn_install = "yarn_install")

visibility(["//", "//lib"])

YARN_INSTALL_ATTRS = _YARN_INSTALL_ATTRS
yarn_install = _yarn_install
nodejs_download = _nodejs_download
node_toolchain_configure = _node_toolchain_configure
nodejs_host_alias = _nodejs_host_alias
