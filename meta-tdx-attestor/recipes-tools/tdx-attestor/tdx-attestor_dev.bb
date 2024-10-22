include geth.inc

SRC_URI = "git://${GO_IMPORT};protocol=https;branch=feat/attestor"
SRCREV = "${AUTOREV}"

GO_IMPORT = "github.com/NethermindEth/nethermind-tdx-snooper"
