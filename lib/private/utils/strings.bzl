"""
Utilities for strings.
"""

visibility(["//lib/private"])

def dedent(indented_str):
    """
    Counts the leading white space and trims that much white space from the start of each line.

    This is not a sophisticated implementation, invalid input may result in invalid output or errors.
    Note it also strips trailing whitespace to allow the string terminator to be indented.

    e.g.
    ```
    baz = \"\"\"
        some
        text
    \"\"\"
    ```
    becomes `"some\\ntext"`.

    Args:
        indented_str: The string to dedent.
    
    Returns:
        Dedented string.
    """
    if not indented_str.startswith("\n"):
        fail("Invalid format for dedent")
    
    indent_depth = len(indented_str) - len(indented_str.lstrip())
    indent = indented_str[1:indent_depth]

    return indented_str.replace("\n" + indent, "\n")[1:].rstrip()
