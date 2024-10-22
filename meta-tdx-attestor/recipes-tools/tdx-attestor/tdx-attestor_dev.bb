include tdx-attestor.inc

SRC_URI = "git://git@snooper.${GO_IMPORT};protocol=ssh;branch=feat/attestor"
SRCREV = "${AUTOREV}"

GO_IMPORT = "github.com/NethermindEth/nethermind-tdx-snooper"
