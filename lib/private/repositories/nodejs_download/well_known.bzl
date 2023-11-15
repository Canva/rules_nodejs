"""
Well known values and value options to support referencing NodeJS in a pre-toolchains world.
"""

visibility(["//lib/private"])

BUILT_IN_NODE_PLATFORMS = [
    "darwin_amd64",
    "darwin_arm64",
    "linux_amd64",
    "linux_arm64",
    "windows_amd64",
    "linux_s390x",
]
