# Canva-specific fork of [bazelbuild/rules_nodejs@3.8.0](https://github.com/bazelbuild/rules_nodejs/tree/3.8.0)

This is a fork of rules_nodejs, starting at [v3.8.0](https://github.com/bazelbuild/rules_nodejs/tree/3.8.0). It contains a few fixes that we need for our internal use of the ruleset. This is not designed for use outside of Canva's internal repos. We offer no guarantees about stability, support, or backwards compatibility.

If you need similar fixes, we recommend that you fork the repo.

## Building

Tooling does not support Apple Silicon, use `--host_platform=//toolchains/node:darwin_amd64` if on macOS.
