"""
Aspect to collect first-party packages.

Uused in node rules to link the node_modules before launching a program.
This supports path re-mapping, to support short module names.
See pathMapping doc: https://github.com/Microsoft/TypeScript/issues/5039

This reads the module_root and module_name attributes from rules in
the transitive closure, rolling these up to provide a mapping to the
linker, which uses the mappings to link a node_modules directory for
runtimes to locate all the first-party packages.
"""

load("//lib/private:providers.bzl", "LinkablePackageInfo")
load("//lib/private:rules/nodejs_binary_test/utils/link_mapping.bzl", _link_mapping = "link_mapping")

visibility(["//lib/private"])

def _debug(vars, *args):
    if "VERBOSE_LOGS" in vars.keys():
        print("[MODULES-LINKER]", *args)

# Arbitrary name; must be chosen to globally avoid conflicts with any other aspect
MODULE_MAPPINGS_ASPECT_RESULTS_NAME = "link_node_modules__aspect_result"

# Traverse 'srcs' in addition so that we can go across a genrule
_MODULE_MAPPINGS_DEPS_NAMES = ["data", "deps", "srcs"]

def _get_module_mappings(target, ctx):
    """Returns the module_mappings from the given attrs.

    Collects a {module_name - module_root} hash from all transitive dependencies,
    checking for collisions. If a module has a non-empty `module_root` attribute,
    all sources underneath it are treated as if they were rooted at a folder
    `module_name`.

    Args:
      target: target
      ctx: ctx

    Returns:
      The module mappings
    """
    mappings = {}

    # Propogate transitive mappings
    for name in _MODULE_MAPPINGS_DEPS_NAMES:
        for dep in getattr(ctx.rule.attr, name, []):
            for k, v in getattr(dep, MODULE_MAPPINGS_ASPECT_RESULTS_NAME, {}).items():
                if _link_mapping(target.label, mappings, k, v):
                    _debug(ctx.var, "target %s propagating module mapping %s: %s" % (dep.label, k, v))
                    mappings[k] = v

    # Look for LinkablePackageInfo mapping in this node
    if not LinkablePackageInfo in target:
        # No mappings contributed here, short-circuit with the transitive ones we collected
        _debug(ctx.var, "No LinkablePackageInfo for", target.label)
        return mappings

    # LinkablePackageInfo may be provided without a package_name so check for that case as well
    if not target[LinkablePackageInfo].package_name:
        # No mappings contributed here, short-circuit with the transitive ones we collected
        _debug(ctx.var, "No package_name in LinkablePackageInfo for", target.label)
        return mappings

    linkable_package_info = target[LinkablePackageInfo]

    if hasattr(linkable_package_info, "package_path") and linkable_package_info.package_path:
        mn = "%s:%s" % (linkable_package_info.package_name, linkable_package_info.package_path)
    else:
        # legacy (root linked) style mapping
        # TODO(4.0): remove this else condition and always use "%s:%s" style
        mn = linkable_package_info.package_name
    mr = ["__link__", linkable_package_info.path]

    # Special case for ts_library module_name for legacy behavior and for AMD name work-around
    # Tag the mapping as "__tslibrary__" so it can be overridden by any other mapping if found.
    #
    # In short, ts_library module_name attribute results in both setting the AMD name (which
    # desired and necessary in devmode which outputs UMD) and in making a linkable mapping. Because
    # of this, you can get in the situation where a ts_library module_name and a downstream pkg_name
    # package_name conflict and result in duplicate mappings. This work-around will make this
    # situation work however it is not a recommended pattern since a ts_library can be a dep of a
    # pkg_npm but not vice-verse at the moment since ts_library cannot handle directory artifacts as
    # deps.
    #
    # TODO(4.0): In a future major release, ts_library will get a package_name attribute to enable the linker
    # and the __tslibrary__ special case can be factored out.
    # This is planned for 4.0: https://github.com/bazelbuild/rules_nodejs/issues/2450.
    if hasattr(linkable_package_info, "_tslibrary") and linkable_package_info._tslibrary:
        mr[0] = "__tslibrary__"

    if _link_mapping(target.label, mappings, mn, mr):
        _debug(ctx.var, "target %s adding module mapping %s: %s" % (target.label, mn, mr))
        mappings[mn] = mr

    # Returns mappings of shape:
    # {
    #   "package_name": [legacy_tslibary_usage, source_path],
    #   "package_name:package_path": [legacy_tslibary_usage, source_path],
    #   ...
    # }
    # TODO(4.0): simplify to { "package_name:package_path": source_path, ... } once __tslibrary__ is no longer needed
    return mappings

def _module_mappings_aspect_impl(target, ctx):
    # Use a dictionary to construct the result struct
    # so that we can reference the MODULE_MAPPINGS_ASPECT_RESULTS_NAME variable
    return struct(**{
        MODULE_MAPPINGS_ASPECT_RESULTS_NAME: _get_module_mappings(target, ctx),
    })

module_mappings_aspect = aspect(
    _module_mappings_aspect_impl,
    attr_aspects = _MODULE_MAPPINGS_DEPS_NAMES,
)
