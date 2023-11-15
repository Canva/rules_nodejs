"""
Aspect implementations.
"""

load("//lib/private:aspects/module_mappings_aspect.bzl", _module_mappings_aspect = "module_mappings_aspect", _MODULE_MAPPINGS_ASPECT_RESULTS_NAME = "MODULE_MAPPINGS_ASPECT_RESULTS_NAME")
load("//lib/private:aspects/module_mappings_runtime_aspect.bzl", _module_mappings_runtime_aspect = "module_mappings_runtime_aspect")
load("//lib/private:aspects/node_modules_aspect.bzl", _node_modules_aspect = "node_modules_aspect")

visibility(["//lib/private"])

module_mappings_aspect = _module_mappings_aspect
MODULE_MAPPINGS_ASPECT_RESULTS_NAME = _MODULE_MAPPINGS_ASPECT_RESULTS_NAME
module_mappings_runtime_aspect = _module_mappings_runtime_aspect
node_modules_aspect = _node_modules_aspect
