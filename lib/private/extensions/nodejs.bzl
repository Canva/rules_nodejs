"""
`nodejs` module extension implementation.
"""

load("//lib/private:repositories/nodejs_download/attrs.bzl", NODEJS_DOWNLOAD_COMMON_ATTRS = "COMMON_ATTRS")
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
                    name = "%s_%s" % (attrs.name, platform["id"]),
                    node_version = attrs.node_version,
                    yarn_version = attrs.yarn_version,
                    node_download_auth = attrs.node_download_auth,
                    node_repositories = attrs.node_repositories,
                    node_urls = attrs.node_urls,
                    preserve_symlinks = attrs.preserve_symlinks,
                    yarn_download_auth = attrs.yarn_download_auth,
                    yarn_repositories = attrs.yarn_repositories,
                    yarn_urls = attrs.yarn_urls,
                    os = platform["os"],
                    arch = platform["arch"],
                )
                nodejs_toolchain_configure(
                    name = "%s_%s_config" % (attrs.name, platform["id"]),
                    target_tool = "@%s_%s//:node_bin" % (attrs.name, platform["id"]),
                )
            # Toolchain registrations without triggering eager downloading
            nodejs_toolchains(
                name = attrs.name,
            )
            nodejs_download(
                name = "%s_host" % attrs.name,
                node_version = attrs.node_version,
                yarn_version = attrs.yarn_version,
                node_download_auth = attrs.node_download_auth,
                node_repositories = attrs.node_repositories,
                node_urls = attrs.node_urls,
                preserve_symlinks = attrs.preserve_symlinks,
                yarn_download_auth = attrs.yarn_download_auth,
                yarn_repositories = attrs.yarn_repositories,
                yarn_urls = attrs.yarn_urls,
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
            attrs = dict(NODEJS_DOWNLOAD_COMMON_ATTRS, **{
                "name": attr.string(
                    mandatory = True,
                ),
            }),
            doc = "",
        ),
    },
)
