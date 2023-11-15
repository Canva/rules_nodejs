"""
`nodejs` module extension implementation.
"""

load("//lib/private:repositories.bzl", "nodejs_download", "node_toolchain_configure", "nodejs_host_alias")
load("//lib/private:utils/os_name.bzl", "OS_ARCH_NAMES")

visibility(["//lib/private"])

def _nodejs_impl(mctx):
    for mod in mctx.modules:
        # TODO Use mod.is_root to detect root module and include in returns
        for attrs in mod.tags.download:
            # TODO Confirm known version
            for os, arch in OS_ARCH_NAMES:
                # TODO Confirm records exist for OS
                # TODO Remove package manager bits, only needed by `yarn_install` host instance
                nodejs_download(
                    name = "nodejs_%s_%s" % (os, arch),
                    node_version = attrs.node_version,
                    yarn_version = attrs.yarn_version,
                    os = os,
                    arch = arch,
                )
                node_toolchain_configure(
                    name = "nodejs_%s_%s_config" % (os, arch),
                    target_tool = "@nodejs_%s_%s//:node_bin" % (os, arch),
                )
            # Toolchain registrations without triggering eager downloading
            # TODO Rename this to something more appropriate
            nodejs_host_alias(
                name = "nodejs",
                node_version = attrs.node_version,
            )
            # TODO Host tools for `yarn_install
            nodejs_download(
                name = "nodejs_host",
                node_version = attrs.node_version,
                yarn_version = attrs.yarn_version,
                os = mctx.os.name,
                arch = mctx.os.arch,
            )

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
