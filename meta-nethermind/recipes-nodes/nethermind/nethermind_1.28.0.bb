DESCRIPTION = "Nethermind - Ethereum client"
HOMEPAGE = "https://nethermind.io/"
LICENSE = "GPL-3.0-only & LGPL-3.0-only"
LIC_FILES_CHKSUM = "file://../../../LICENSE-GPL;md5=1ebbd3e34237af26da5dc08a4e440464 \
                    file://../../../LICENSE-LGPL;md5=3000208d539ec061b899bce1d9ce9404 "

inherit dotnet update-rc.d

SRC_URI = "https://github.com/NethermindEth/nethermind/archive/refs/tags/1.28.0.tar.gz;name=nethermind"
SRC_URI[nethermind.md5sum] = "df891d13f9891f5c476a8467e4266cf2"
SRC_URI[nethermind.sha256sum] = "b2e90689b927f4e41b11e0c260ac7515051dd95cbeebf19ebc6d608dc1b1a1f9"
SRC_URI += "file://init;name=init"

do_configure[network] = "1"
do_compile[network] = "1"

# meta-dotnet configuration
DOTNET_PROJECT = "."
ENABLE_TRIMMING = "false"
RELEASE_DIR = "${ARTIFACTS_DIR}/publish/Nethermind.Runner/release_${BUILD_TARGET}/"
S = "${WORKDIR}/nethermind-${PV}/src/Nethermind/Nethermind.Runner"

# update-rc.d configuration
INITSCRIPT_NAME = "nethermind"
INITSCRIPT_PARAMS = "defaults 98"

RDEPENDS:${PN} += " disk-encryption"

# set the interpreter for the resulting binary
DEPENDS += " patchelf-native"
do_compile:append() {
    patchelf --set-interpreter /lib/ld-linux-x86-64.so.2 ${RELEASE_DIR}/nethermind
}

FILES:${PN} += "${sysconfdir}/init.d/nethermind"

# install the init script
do_install:append() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/nethermind/init ${D}${sysconfdir}/init.d/nethermind
}
