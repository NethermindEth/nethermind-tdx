SUMMARY = "TDX Attestor"
DESCRIPTION = "TDX Attestor"
HOMEPAGE = "https://github.com/NethermindEth/nethermind-tdx-snooper"
LICENSE = "CLOSED"

inherit go-mod update-rc.d

GO_INSTALL = "${GO_IMPORT}/cmd/attestor"
GO_LINKSHARED = ""

GO_EXTLDFLAGS:append = ",-z,stack-size=0x800000"

# reproducible builds
INHIBIT_PACKAGE_DEBUG_SPLIT = '1'
INHIBIT_PACKAGE_STRIP = '1'
#GO_EXTRA_LDFLAGS:append = " -s -w -buildid="
#GOBUILDFLAGS:append = " -buildvcs=false"

do_compile[network] = "1"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI += "file://init"
INITSCRIPT_NAME = "attestor"
INITSCRIPT_PARAMS = "defaults 99"

do_install:append() {
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/init ${D}${sysconfdir}/init.d/attestor
}
