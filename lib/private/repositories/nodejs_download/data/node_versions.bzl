"""
NodeJS version data to simplify version specification.
"""

visibility(["//lib/private"])

NODE_VERSIONS = {
    # 20.8.0
    "20.8.0-darwin_arm64": ("node-v20.8.0-darwin-arm64.tar.gz", "node-v20.8.0-darwin-arm64", "cbcb7fdbcd9341662256df5e4488a0045242f87382879242093e0f0699511abc"),
    "20.8.0-darwin_amd64": ("node-v20.8.0-darwin-x64.tar.gz", "node-v20.8.0-darwin-x64", "a6f6b573ea656c149956f69f35e04ebb242b945d59972bea2e96a944bbf50ad1"),
    "20.8.0-linux_arm64": ("node-v20.8.0-linux-arm64.tar.xz", "node-v20.8.0-linux-arm64", "cec9be5a060f63bfda7ef5b5a368cba5cfa0ce673b117bae8c146ec5df767cbe"),
    "20.8.0-linux_s390x": ("node-v20.8.0-linux-s390x.tar.xz", "node-v20.8.0-linux-s390x", "7f1c1f515eb4a93ef00ef8630de6f1e308c21969ce4b3ff482269cedb7929595"),
    "20.8.0-linux_amd64": ("node-v20.8.0-linux-x64.tar.xz", "node-v20.8.0-linux-x64", "ae6f288a21a3bc7a82b79d3f00c52216df6de09c45eac0ea754243a9c7fb5e69"),
    "20.8.0-windows_amd64": ("node-v20.8.0-win-x64.zip", "node-v20.8.0-win-x64", "6afd5a7aa126f4e255f041de66c4a608f594190d34dcaba72f7b348d2410ca66"),
}