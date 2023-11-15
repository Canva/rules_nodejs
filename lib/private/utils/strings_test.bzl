"""
Unit tests for string utilities.
"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//lib/private:utils/strings.bzl", "dedent")

def _dedent_test_impl(ctx):
  env = unittest.begin(ctx)
  asserts.equals(
    env,
    "some\ntext",
    dedent("""
        some
        text
    """)
)
  return unittest.end(env)

dedent_test = unittest.make(_dedent_test_impl)

# No need for a test_myhelper() setup function.

def strings_test_suite(name):
  # unittest.suite() takes care of instantiating the testing rules and creating
  # a test_suite.
  unittest.suite(
    name + "_dedent",
    dedent_test,
    # ...
  )