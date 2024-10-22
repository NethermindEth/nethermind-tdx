include geth.inc

SRC_URI = "git://${GO_IMPORT};protocol=ssh;branch=feat/attestor"
SRCREV = "${AUTOREV}"

GO_IMPORT = "github.com/NethermindEth/nethermind-tdx-snooper"
