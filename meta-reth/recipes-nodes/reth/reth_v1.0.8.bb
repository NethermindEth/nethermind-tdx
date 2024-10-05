include reth.inc

FILESEXTRAPATHS:prepend := "${THISDIR}:"
SRC_URI = "git://github.com/paradigmxyz/reth;protocol=https;branch=main"
# SRC_URI += "file://libffi.patch"
SRCREV = "v1.0.8"

# DEPENDS += " libffi"
# RDEPENDS:${PN} += "libffi"
