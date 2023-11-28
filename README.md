# Rules NodeJS

A fork of Rules NodeJS v3 updated to align with Bazel 6 ruleset standards (were viable).

Some other rulesets use Rules NodeJS, limited backward compatibility is available so fixes here also apply to those rulesets.

This ruleset targets Bazel 6, but is developed in Bazel 7. E2E tests (to be implemented) run using Bazel 6 and 7.

## Legacy Exports

These are kept only for backward compatibility and will be removed as dependency on implementation details is reduced.

- `//:index.bzl`
  - Repo rule `yarn_install`
  - Rule `nodejs_binary`
  - Rule `nodejs_test`
  - Rule `js_library`
  - Rule `pkg_npm`
- `//toolchains/node:node_toolchain.bzl`
  - Toolchain `node_toolchain`
- `//:providers.bzl`
  - Provider `NpmPackageInfo`
  - Provider `DeclarationInfo`

## Current Exports

The full current public API is accessible under `lib/`, excluding `lib/internal/` and `lib/private`.

## TODO

- Dist scripts
  - `lib/internal/rules/pkg_npm/npm_script_generater.js`
  - `lib/internal/rules/pkg_npm/packager.js`
- Update to Rules NodeJS v6 (dev dependency)
- Use NodeJS v20 (dev dependency)
- Add checks to `node.download(...)`
- Restore the NodeJS versions data script, or remove it in favour of making it easier to manually manage (akin to `@aspect_bazel_lib//lib:write_source_files.bzl`)
- Undo start of `yarn_install` refactor on this branch
