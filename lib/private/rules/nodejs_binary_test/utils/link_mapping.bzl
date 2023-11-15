"""
Helpers to map targets into `node_modules`.
"""

visibility(["//lib/private"])

def link_mapping(label, mappings, k, v):
    """
    Determines if label should be mapped into `node_modules`.

    Args:
        label: Label being inspected.
        mappings: Mappings to check.
        k: Package name.
        v: Package path.
    Returns:
        Boolean indicating if label given needs to be mapped.
    """
    # Check that two package name mapping do not map to two different source paths
    package_name = k.split(":")[0]
    source_path = v[1]

    # Special case for ts_library module_name for legacy behavior and for AMD name work-around
    # Mapping is tagged as "__tslibrary__".
    # See longer comment below in _get_module_mappings for more details.
    if v[0] != "__tslibrary__":
        for iter_key, iter_values in mappings.items():
            # Map key is of format "package_name:package_path"
            # Map values are of format [deprecated, source_path]
            iter_package_name = iter_key.split(":")[0]
            iter_source_path = iter_values[1]
            if iter_values[0] != "__tslibrary__" and package_name == iter_package_name and source_path != iter_source_path:
                fail("conflicting mapping at '%s': '%s' and '%s' map to conflicting %s and %s" % (label, k, iter_key, source_path, iter_source_path))

    # Allow __tslibrary__ special case to be overridden other matching mappings
    if k in mappings and mappings[k] != v:
        if mappings[k][0] == "__tslibrary__":
            return True
        elif v[0] == "__tslibrary__":
            return False
        fail(("conflicting mapping at '%s': '%s' maps to both %s and %s" % (label, k, mappings[k], v)), "deps")
    else:
        return True
