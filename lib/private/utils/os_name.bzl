"""
Helper function for repository rules
"""

load("//lib/private:utils/check_version.bzl", "check_version")

visibility(["//lib/private"])

OS_ARCH_NAMES = [
    ("windows", "amd64"),
    ("darwin", "amd64"),
    ("darwin", "arm64"),
    ("linux", "amd64"),
    ("linux", "arm64"),
    ("linux", "s390x"),
]

OS_NAMES = ["_".join(os_arch_name) for os_arch_name in OS_ARCH_NAMES]

# TODO Rename to better reflect usage (mapping os/arch inputs to an os-arch string)
def os_name(rctx):
    """
    Get the os name for a repository rule

    Args:
      rctx: The repository rule context

    Returns:
      A string describing the os for a repository rule
    """

    os = rctx.attr.os
    arch = rctx.attr.arch
    if os == "windows":
        return OS_NAMES[0]
    elif os.startswith("mac os") or os == "darwin":
        if arch == "x86_64":
            return OS_NAMES[1]
        elif arch == "arm64" or arch == "aarch64":
            return OS_NAMES[2]
    elif os == "linux":
        if arch == "x86_64":
            return OS_NAMES[3]
        elif arch == "aarch64":
            return OS_NAMES[4]
        elif arch == "s390x":
            return OS_NAMES[5]

    fail("Unsupported operating system {} architecture {}".format(os, arch))

# TODO Reconsider
def is_windows_os(rctx):
    return os_name(rctx) == OS_NAMES[0]

# TODO Reconsider
def is_darwin_os(rctx):
    name = os_name(rctx)
    return name == OS_NAMES[1] or name == OS_NAMES[2]

# TODO Reconsider
def is_linux_os(rctx):
    name = os_name(rctx)
    return name == OS_NAMES[3] or name == OS_NAMES[4] or name == OS_NAMES[5]

def node_exists_for_os(node_version, os_name):
    "Whether a node binary is available for this platform"
    is_14_or_greater = check_version(node_version, "14.0.0")

    # There is no Apple Silicon native version of node before 14
    return is_14_or_greater or os_name != "darwin_arm64"

# TODO Rename, since this does not check host
def assert_node_exists_for_host(rctx):
    node_version = rctx.attr.node_version
    if not node_exists_for_os(node_version, os_name(rctx)):
        fail("No nodejs is available for {} at version {}".format(os_name(rctx), node_version) +
             "\n    Consider upgrading by setting node_version in a call to node_repositories in WORKSPACE." +
             "\n    Note that Node 16.x is the minimum published for Apple Silicon (M1 Macs)")
