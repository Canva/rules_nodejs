"""
Module extension implementations.
"""

load("//lib/private:extensions/node_modules.bzl", _node_modules = "node_modules")
load("//lib/private:extensions/nodejs.bzl", _nodejs = "nodejs")

visibility(["//", "//lib"])

node_modules = _node_modules
nodejs = _nodejs
