<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Toolchains.


```starlark
load("build_bazel_rules_nodejs//lib:toolchains.bzl", ...)
```

<a id="node_toolchain"></a>

## node_toolchain

<pre>
node_toolchain(<a href="#node_toolchain-name">name</a>, <a href="#node_toolchain-target_tool">target_tool</a>)
</pre>

Defines a node toolchain.

For usage see https://docs.bazel.build/versions/master/toolchains.html#defining-toolchains.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="node_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="node_toolchain-target_tool"></a>target_tool |  A hermetically downloaded nodejs executable target for the target platform.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


