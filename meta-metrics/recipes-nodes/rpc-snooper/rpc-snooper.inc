SUMMARY = "RPC Snooper"
DESCRIPTION = "RPC Snooper"
HOMEPAGE = "https://github.com/Hyodar/rpc-snooper"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

inherit go-mod update-rc.d

GO_INSTALL = "${GO_IMPORT}/cmd/snooper"
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

INITSCRIPT_NAME = "rpc-snooper"
INITSCRIPT_PARAMS = "defaults 97"

do_install:append() {
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/init ${D}${sysconfdir}/init.d/rpc-snooper
}

FILES:${PN} += "${sysconfdir}/init.d/rpc-snooper"
