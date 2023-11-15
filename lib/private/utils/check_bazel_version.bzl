"""
Check Bazel version

We recommend forcing all users to update to at least the same version of Bazel
as the continuous integration, so they don't trip over incompatibilities with
rules used in the project.
"""

load("//lib/private:utils/check_version.bzl", "check_version", "check_version_range")

visibility(["//lib/private"])

# From https://github.com/tensorflow/tensorflow/blob/5541ef4fbba56cf8930198373162dd3119e6ee70/tensorflow/workspace.bzl#L44

# Check that a specific bazel version is being used.
# Args: minimum_bazel_version in the form "<major>.<minor>.<patch>"
def check_bazel_version(minimum_bazel_version, message = ""):
    """
    Verify the users Bazel version is at least the given one.

    This can be used in rule implementations that depend on changes in Bazel,
    to warn users about a mismatch between the rule and their installed Bazel
    version.

    This should *not* be used in users WORKSPACE files. To locally pin your
    Bazel version, just create the .bazelversion file in your workspace.

    Args:
      minimum_bazel_version: a string indicating the minimum version
      message: optional string to print to your users, could be used to help them update
    """
    if "bazel_version" not in dir(native):
        fail("\nCurrent Bazel version is lower than 0.2.1, expected at least %s\n" %
             minimum_bazel_version)
    elif native.bazel_version and not check_version(native.bazel_version, minimum_bazel_version):
        fail("\nCurrent Bazel version is {}, expected at least {}\n{}".format(
            native.bazel_version,
            minimum_bazel_version,
            message,
        ))

# Check that a bazel version being used is in the version range.
# Args:
#   minimum_bazel_version in the form "<major>.<minor>.<patch>"
#   maximum_bazel_version in the form "<major>.<minor>.<patch>"
def check_bazel_version_range(minimum_bazel_version, maximum_bazel_version, message = ""):
    """
    Verify the users Bazel version is in the version range.

    This should be called from the `WORKSPACE` file so that the build fails as
    early as possible. For example:

    ```
    # in WORKSPACE:
    load("@build_bazel_rules_nodejs//:index.bzl", "check_bazel_version_range")
    check_bazel_version_range("0.11.0", "0.22.0")
    ```

    Args:
      minimum_bazel_version: a string indicating the minimum version
      maximum_bazel_version: a string indicating the maximum version
      message: optional string to print to your users, could be used to help them update
    """
    if "bazel_version" not in dir(native):
        fail("\nCurrent Bazel version is lower than 0.2.1, expected at least %s\n" %
             minimum_bazel_version)
    elif not native.bazel_version:
        print("\nCurrent Bazel is not a release version, cannot check for " +
              "compatibility.")
        print("Make sure that you are running at least Bazel %s.\n" % minimum_bazel_version)
    elif not check_version_range(
        native.bazel_version,
        minimum_bazel_version,
        maximum_bazel_version,
    ):
        fail("\nCurrent Bazel version is {}, expected >= {} and <= {}\n{}".format(
            native.bazel_version,
            minimum_bazel_version,
            maximum_bazel_version,
            message,
        ))
