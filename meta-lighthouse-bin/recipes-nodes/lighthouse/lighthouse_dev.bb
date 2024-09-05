DESCRIPTION = "Copy binary to the image"
LICENSE = "CLOSED"
FILESEXTRAPATHS:prepend := "${THISDIR}:"
BINARY = "lighthouse"
SRC_URI += "file://${BINARY}"
SRC_URI += "file://init"
S = "${WORKDIR}"

INITSCRIPT_NAME = "${BINARY}"
INITSCRIPT_PARAMS = "defaults 98"

inherit update-rc.d

do_install() {
	install -d ${D}${bindir}
	install -m 0777 ${BINARY} ${D}${bindir}
	install -d ${D}${sysconfdir}/init.d
	cp init ${D}${sysconfdir}/init.d/${BINARY}
	chmod 755 ${D}${sysconfdir}/init.d/${BINARY}
}
FILES_${PN} += "${bindir}"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
