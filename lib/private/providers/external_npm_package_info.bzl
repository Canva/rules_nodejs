"""
ExternalNpmPackageInfo providers to collect node_modules from deps.
"""

visibility(["//lib/private"])

# ExternalNpmPackageInfo provider is provided by targets that are external npm packages by
# `js_library` rule when package_name is set to "node_modules", as well as other targets that
# have direct or transitive deps on `js_library` targets via the `node_modules_aspect` below.
ExternalNpmPackageInfo = provider(
    doc = "Provides information about one or more external npm packages",
    fields = {
        "direct_sources": "Depset of direct source files in these external npm package(s)",
        "has_directories": "True if any sources are directories",
        "path": "The local workspace path that these external npm deps should be linked at. If empty, they will be linked at the root.",
        "sources": "Depset of direct & transitive source files in these external npm package(s) and transitive dependencies",
        "workspace": "The workspace name that these external npm package(s) are provided from",
    },
)
