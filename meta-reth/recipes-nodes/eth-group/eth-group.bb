SUMMARY = "Ethereum services group"
DESCRIPTION = "Creates a common group for Ethereum-related services"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

USERADD_PACKAGES = "${PN}"
GROUPADD_PARAM:${PN} = "-r eth"

do_install[noexec] = "1"
ALLOW_EMPTY:${PN} = "1"
