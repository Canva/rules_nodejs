"""
Use Rules for NodeJS without bzlmod.
"""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("//lib/private:repositories.bzl", _yarn_install = "yarn_install", _nodejs_download = "nodejs_download", _nodejs_download_host = "nodejs_download_host", _nodejs_toolchain_configure = "nodejs_toolchain_configure", _nodejs_toolchains = "nodejs_toolchains")
load("//lib/private:utils/platform.bzl", "PLATFORMS")

# Based off lib/private/extensions/nodejs.bzl
def nodejs_download(**attrs):
    name = attrs["name"]
    attrs = dicts.omit(attrs, ["name"])
    for platform in PLATFORMS.values():
        _nodejs_download(
            name = "%s_%s" % (name, platform["id"]),
            os = platform["os"],
            arch = platform["arch"],
            **attrs,
        )
        _nodejs_toolchain_configure(
            name = "%s_%s_config" % (name, platform["id"]),
            target_tool = "@%s_%s//:node_bin" % (name, platform["id"]),
        )
    _nodejs_toolchains(
        name = name,
        node_version = attrs["node_version"],
    )
    _nodejs_download_host(
        name = "%s_host" % name,
        **attrs,
    )

node_modules_yarn = _yarn_install
