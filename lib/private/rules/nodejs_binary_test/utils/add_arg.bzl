"""
Helper to add arguments to an `crx.actions.Args` object.
"""

visibility(["//lib/private"])

def add_arg(args, arg):
    """
    Add an argument

    Args:
        args: either a list or a ctx.actions.Args object
        arg: string arg to append on the end
    """
    if (type(args) == type([])):
        args.append(arg)
    else:
        args.add(arg)
