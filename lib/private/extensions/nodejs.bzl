"""
`nodejs` module extension implementation.
"""

load("//lib/private:repositories.bzl", "nodejs_download", "nodejs_toolchain_configure", "nodejs_toolchains")
load("//lib/private:utils/platform.bzl", "PLATFORMS")

visibility(["//lib/private"])

def _nodejs_impl(mctx):
    for mod in mctx.modules:
        # TODO Use mod.is_root to detect root module and include in returns
        for attrs in mod.tags.download:
            # TODO Confirm known version
            for platform in PLATFORMS.values():
                # TODO Confirm records exist for OS
                # TODO Remove package manager bits, only needed by `yarn_install` host instance
                nodejs_download(
                    name = "nodejs_%s" % platform["id"],
                    node_version = attrs.node_version,
                    yarn_version = attrs.yarn_version,
                    os = platform["os"],
                    arch = platform["arch"],
                )
                nodejs_toolchain_configure(
                    name = "nodejs_%s_config" % platform["id"],
                    target_tool = "@nodejs_%s//:node_bin" % platform["id"],
                )
            # Toolchain registrations without triggering eager downloading
            # TODO Rename this to something more appropriate
            nodejs_toolchains(
                name = "nodejs",
                node_version = attrs.node_version,
            )
            nodejs_download(
                name = "nodejs_host",
                node_version = attrs.node_version,
                yarn_version = attrs.yarn_version,
                os = mctx.os.name,
                arch = mctx.os.arch,
            )

    # TODO support custom name, pick for actual root module only
    return mctx.extension_metadata(
        # NOTE Generated repositories referenced by `@nodejs` are intentionally excluded
        root_module_direct_deps = ["nodejs", "nodejs_host"],
        root_module_direct_dev_deps = [],
    )

nodejs = module_extension(
    implementation = _nodejs_impl,
    tag_classes = {
        "download": tag_class(
            attrs = {
                "node_version": attr.string(
                    mandatory = True,
                ),
                "yarn_version": attr.string(
                    mandatory = True,
                ),
            },
            doc = "",
        ),
    },
)
