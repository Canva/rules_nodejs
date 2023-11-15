"""
Helper functions to preserve legacy `$` usage in templated_args
"""

visibility(["//lib/private"])

def preserve_legacy_templated_args(input):
    """
    Converts legacy uses of `$` to `$$` so that the new call to ctx.expand_make_variables

    Converts any lone `$` that is not proceeded by a `(` to `$$. Also converts legacy `$(rlocation `
    to `$$(rlocation ` as that is a commonly used bash function so we don't want to break this
    legacy behavior.

    Args:
      input: String to be modified

    Returns:
      The modified string
    """
    result = ""
    length = len(input)
    for i in range(length):
        if input[i:].startswith("$(rlocation "):
            if i == 0 or input[i - 1] != "$":
                # insert an additional "$"
                result += "$"
        elif input[i] == "$" and (i + 1 == length or (i + 1 < length and input[i + 1] != "(" and input[i + 1] != "$")):
            if i == 0 or input[i - 1] != "$":
                # insert an additional "$"
                result += "$"
        result += input[i]
    return result
