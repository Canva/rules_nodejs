"""
NodeJS version data to simplify version specification.
"""

visibility(["//lib/private"])

NODE_VERSIONS = {
    # 20.8.0
    "20.8.0-darwin_arm64": ("node-v20.8.0-darwin-arm64.tar.gz", "node-v20.8.0-darwin-arm64", "cbcb7fdbcd9341662256df5e4488a0045242f87382879242093e0f0699511abc"),
    "20.8.0-darwin_amd64": ("node-v20.8.0-darwin-x64.tar.gz", "node-v20.8.0-darwin-x64", "a6f6b573ea656c149956f69f35e04ebb242b945d59972bea2e96a944bbf50ad1"),
    "20.8.0-linux_arm64": ("node-v20.8.0-linux-arm64.tar.xz", "node-v20.8.0-linux-arm64", "ec2d98894d58d07260e61e6a70b88cabea98292f0b2801cbeebd864d242e1087"),
    "20.8.0-linux_s390x": ("node-v20.8.0-linux-s390x.tar.xz", "node-v20.8.0-linux-s390x", "a529f569b6783bd3cb948b7cb5cfee2270a720db1b347e1e168f46ad9123394d"),
    "20.8.0-linux_amd64": ("node-v20.8.0-linux-x64.tar.xz", "node-v20.8.0-linux-x64", "66056a2acc368db142b8a9258d0539e18538ae832b3ccb316671b0d35cb7c72c"),
    "20.8.0-windows_amd64": ("node-v20.8.0-win-x64.zip", "node-v20.8.0-win-x64", "6afd5a7aa126f4e255f041de66c4a608f594190d34dcaba72f7b348d2410ca66"),
}