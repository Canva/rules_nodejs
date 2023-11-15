"""
Module extensions.
"""

load("//lib/private:extensions.bzl", _node_modules = "node_modules", _nodejs = "nodejs")

visibility(["public"])

node_modules = _node_modules
nodejs = _nodejs
