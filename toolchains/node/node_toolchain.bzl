"""
Exports for backward compatibility with Rules NodeJS v3.
"""

load("//lib:toolchains.bzl", _NodeInfo = "NodeInfo", _node_toolchain = "node_toolchain")

visibility(["public"])

NodeInfo = _NodeInfo
node_toolchain = _node_toolchain
