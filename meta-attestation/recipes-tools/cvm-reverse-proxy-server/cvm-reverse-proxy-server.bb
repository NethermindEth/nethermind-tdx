SUMMARY = "CVM Reverse Proxy Server"
DESCRIPTION = "A bash script that runs the CVM reverse proxy server to an attestation service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}:"

SRC_URI = "file://init"
S = "${WORKDIR}"

INITSCRIPT_NAME = "cvm-reverse-proxy-server"
INITSCRIPT_PARAMS = "defaults 98"

RDEPENDS:${PN} += " cvm-reverse-proxy"

inherit update-rc.d

do_install() {
	install -d ${D}${sysconfdir}/init.d
	cp init ${D}${sysconfdir}/init.d/${INITSCRIPT_NAME}
	chmod 755 ${D}${sysconfdir}/init.d/${INITSCRIPT_NAME}
}
FILES_${PN} += "${bindir}"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
INHIBIT_PACKAGE_STRIP = "1"
