SUMMARY = "Official Go implementation of the Ethereum protocol"
DESCRIPTION = "geth is the command line interface for running a full ethereum node implemented in Go."
HOMEPAGE = "https://geth.ethereum.org"
LICENSE = "GPL-3.0-only & LGPL-3.0-only"
LIC_FILES_CHKSUM = "file://src/${GO_WORKDIR}/COPYING;md5=1ebbd3e34237af26da5dc08a4e440464 \
		    file://src/${GO_WORKDIR}/COPYING.LESSER;md5=e6a600fd5e1d9cbde2d983680233ad02"

inherit go-mod update-rc.d useradd

GO_INSTALL = "${GO_IMPORT}/cmd/geth"
GO_LINKSHARED = ""

GO_EXTLDFLAGS:append = ",-z,stack-size=0x800000"

# reproducible builds
INHIBIT_PACKAGE_DEBUG_SPLIT = '1'
INHIBIT_PACKAGE_STRIP = '1'
#GO_EXTRA_LDFLAGS:append = " -s -w -buildid="
#GOBUILDFLAGS:append = " -buildvcs=false"

DEPENDS += " eth-group"
RDEPENDS:${PN}-dev += " bash"
RDEPENDS:${PN} += " disk-encryption json-config eth-group lighthouse"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "-r -s /bin/false -G eth geth"

do_compile[network] = "1"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI += "file://init"
INITSCRIPT_NAME = "geth"
INITSCRIPT_PARAMS = "defaults 99"

do_install:append() {
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/init ${D}${sysconfdir}/init.d/geth
    
    # Create directory for geth data
    install -d ${D}/persistent/geth
    chown geth:eth ${D}/persistent/geth
    chmod 0770 ${D}/persistent/geth
}

FILES:${PN} += "/persistent/geth"
