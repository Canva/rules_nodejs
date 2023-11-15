"""
Provider implementations.
"""

load("//lib/private:providers/declaration_info.bzl", _DeclarationInfo = "DeclarationInfo", _declaration_info = "declaration_info")
load("//lib/private:providers/external_npm_package_info.bzl", _ExternalNpmPackageInfo = "ExternalNpmPackageInfo")
load(
    "//lib/private:providers/js_providers.bzl",
    _JSEcmaScriptModuleInfo = "JSEcmaScriptModuleInfo",
    _JSModuleInfo = "JSModuleInfo",
    _JSNamedModuleInfo = "JSNamedModuleInfo",
    _js_ecma_script_module_info = "js_ecma_script_module_info",
    _js_module_info = "js_module_info",
    _js_named_module_info = "js_named_module_info",
)
load("//lib/private:providers/linkable_package_info.bzl", _LinkablePackageInfo = "LinkablePackageInfo")
load("//lib/private:providers/node_context_info.bzl", _NodeContextInfo = "NodeContextInfo", _NODE_CONTEXT_ATTRS = "NODE_CONTEXT_ATTRS")
load("//lib/private:providers/node_info.bzl", _NodeInfo = "NodeInfo")
load("//lib/private:providers/node_runtime_deps_info.bzl", _NodeRuntimeDepsInfo = "NodeRuntimeDepsInfo")
load("//lib/private:providers/tree_artifacts.bzl", _DirectoryFilePathInfo = "DirectoryFilePathInfo")

visibility(["//", "//lib", "//lib/private"])

DeclarationInfo = _DeclarationInfo
declaration_info = _declaration_info
ExternalNpmPackageInfo = _ExternalNpmPackageInfo
NodeInfo = _NodeInfo
LinkablePackageInfo = _LinkablePackageInfo
DirectoryFilePathInfo = _DirectoryFilePathInfo
NodeRuntimeDepsInfo = _NodeRuntimeDepsInfo
NodeContextInfo = _NodeContextInfo
NODE_CONTEXT_ATTRS = _NODE_CONTEXT_ATTRS

# Providers for js_library
JSModuleInfo = _JSModuleInfo
js_module_info = _js_module_info
JSNamedModuleInfo = _JSNamedModuleInfo
js_named_module_info = _js_named_module_info
JSEcmaScriptModuleInfo = _JSEcmaScriptModuleInfo
js_ecma_script_module_info = _js_ecma_script_module_info
