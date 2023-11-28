"""
Platform information and resolvers.
"""

visibility(["//lib/private", "//lib"])

PLATFORMS = {
    # Used to uniquely identify a given platform
    "darwin_amd64": {
        # Unique ID for platform
        # Also used to map to NodeJS download info
        # See lib/private/repositories/nodejs_download/data/node_versions.bzl
        "id": "darwin_amd64",
        # Normalised OS string
        "os": "darwin",
        # Normalised CPU architecture string
        "arch": "amd64",
        # Constraints for this platform
        "constraints": [
            "@platforms//os:osx",
            "@platforms//cpu:x86_64",
        ],
    },
    "darwin_arm64": {
        "id": "darwin_arm64",
        "os": "darwin",
        "arch": "arm64",
        "constraints": [
            "@platforms//os:osx",
            "@platforms//cpu:aarch64",
        ],
    },
    "linux_amd64": {
        "id": "linux_amd64",
        "os": "linux",
        "arch": "amd64",
        "constraints": [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    },
    "linux_arm64": {
        "id": "linux_arm64",
        "os": "linux",
        "arch": "arm64",
        "constraints": [
            "@platforms//os:linux",
            "@platforms//cpu:aarch64",
        ],
    },
    "linux_s390x": {
        "id": "linux_s390x",
        "os": "linux",
        "arch": "s390x",
        "constraints": [
            "@platforms//os:linux",
            "@platforms//cpu:s390x",
        ],
    },
    "windows_amd64": {
        "id": "windows_amd64",
        "os": "windows",
        "arch": "amd64",
        "constraints": [
            "@platforms//os:windows",
            "@platforms//cpu:x86_64",
        ],
    },
    "windows_arm64": {
        "id": "windows_arm64",
        "os": "windows",
        "arch": "arm64",
        "constraints": [
            "@platforms//os:windows",
            "@platforms//cpu:aarch64",
        ],
    },
}

def get_platform(os, arch):
    """
    Resolves the platform data for the current platform.

    Args:
        os: e.g. from `repository_ctx.os.name`.
        arch: e.g. from `repository_ctx.os.arch`.

    Returns:
        Dictionary containing platform data.
    """

    if os == "linux":
        if arch == "x86_64" or arch == "amd64":
            return PLATFORMS["linux_amd64"]
        elif arch == "arm64" or arch == "aarch64":
            return PLATFORMS["linux_arm64"]
        elif arch == "s390x":
            return PLATFORMS["linux_s390x"]
    elif os.startswith("mac os") or os == "darwin":
        if arch == "x86_64" or arch == "amd64":
            return PLATFORMS["darwin_amd64"]
        elif arch == "arm64" or arch == "aarch64":
            return PLATFORMS["darwin_arm64"]
    elif os == "windows":
        if arch == "x86_64" or arch == "amd64":
            return PLATFORMS["windows_amd64"]
        elif arch == "arm64" or arch == "aarch64":
            return PLATFORMS["windows_arm64"]

    fail("Unsupported operating system {} architecture {}".format(os, arch))
