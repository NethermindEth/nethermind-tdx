include geth.inc

SRC_URI = "git://${GO_IMPORT};protocol=https;branch=master"
SRCREV = "${AUTOREV}"

GO_IMPORT = "github.com/ethereum/go-ethereum"