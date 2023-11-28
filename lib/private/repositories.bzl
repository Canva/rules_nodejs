"""
Repository rule implementations.
"""

load("//lib/private:repositories/nodejs_download/impl.bzl", _nodejs_download = "nodejs_download", _nodejs_download_host = "nodejs_download_host")
load("//lib/private:repositories/nodejs_toolchain_configure/impl.bzl", _nodejs_toolchain_configure = "nodejs_toolchain_configure")
load("//lib/private:repositories/nodejs_toolchains.bzl", _nodejs_toolchains = "nodejs_toolchains")
load("//lib/private:repositories/yarn_install/attrs.bzl", _YARN_INSTALL_ATTRS = "YARN_INSTALL_ATTRS")
load("//lib/private:repositories/yarn_install/impl.bzl", _yarn_install = "yarn_install")

visibility(["//", "//lib"])

YARN_INSTALL_ATTRS = _YARN_INSTALL_ATTRS
yarn_install = _yarn_install
nodejs_download = _nodejs_download
nodejs_download_host = _nodejs_download_host
nodejs_toolchain_configure = _nodejs_toolchain_configure
nodejs_toolchains = _nodejs_toolchains
