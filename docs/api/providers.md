<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Providers.


```starlark
load("build_bazel_rules_nodejs//lib:providers.bzl", ...)
```

<a id="DeclarationInfo"></a>

## DeclarationInfo

<pre>
DeclarationInfo(<a href="#DeclarationInfo-declarations">declarations</a>, <a href="#DeclarationInfo-transitive_declarations">transitive_declarations</a>, <a href="#DeclarationInfo-type_blacklisted_declarations">type_blacklisted_declarations</a>)
</pre>

The DeclarationInfo provider allows JS rules to communicate typing information.
TypeScript's .d.ts files are used as the interop format for describing types.
package.json files are included as well, as TypeScript needs to read the "typings" property.

Do not create DeclarationInfo instances directly, instead use the declaration_info factory function.

Note: historically this was a subset of the string-typed "typescript" provider.

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="DeclarationInfo-declarations"></a>declarations |  A depset of typings files produced by this rule    |
| <a id="DeclarationInfo-transitive_declarations"></a>transitive_declarations |  A depset of typings files produced by this rule and all its transitive dependencies. This prevents needing an aspect in rules that consume the typings, which improves performance.    |
| <a id="DeclarationInfo-type_blacklisted_declarations"></a>type_blacklisted_declarations |  A depset of .d.ts files that we should not use to infer JSCompiler types (via tsickle)    |


<a id="ExternalNpmPackageInfo"></a>

## ExternalNpmPackageInfo

<pre>
ExternalNpmPackageInfo(<a href="#ExternalNpmPackageInfo-direct_sources">direct_sources</a>, <a href="#ExternalNpmPackageInfo-has_directories">has_directories</a>, <a href="#ExternalNpmPackageInfo-path">path</a>, <a href="#ExternalNpmPackageInfo-sources">sources</a>, <a href="#ExternalNpmPackageInfo-workspace">workspace</a>)
</pre>

Provides information about one or more external npm packages

**FIELDS**


| Name  | Description |
| :------------- | :------------- |
| <a id="ExternalNpmPackageInfo-direct_sources"></a>direct_sources |  Depset of direct source files in these external npm package(s)    |
| <a id="ExternalNpmPackageInfo-has_directories"></a>has_directories |  True if any sources are directories    |
| <a id="ExternalNpmPackageInfo-path"></a>path |  The local workspace path that these external npm deps should be linked at. If empty, they will be linked at the root.    |
| <a id="ExternalNpmPackageInfo-sources"></a>sources |  Depset of direct & transitive source files in these external npm package(s) and transitive dependencies    |
| <a id="ExternalNpmPackageInfo-workspace"></a>workspace |  The workspace name that these external npm package(s) are provided from    |


