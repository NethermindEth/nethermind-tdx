SUMMARY = "Reth"
DESCRIPTION = "reth is the command line interface for running a full ethereum node implemented in rust."
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

inherit cargo_bin update-rc.d useradd

# Enable network for the compile task allowing cargo to download dependencies
do_compile[network] = "1"

export BINDGEN_EXTRA_CLANG_ARGS
BINDGEN_EXTRA_CLANG_ARGS = "--sysroot=${WORKDIR}/recipe-sysroot -I${WORKDIR}/recipe-sysroot/usr/include"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI += "file://init"
INITSCRIPT_NAME = "reth"
INITSCRIPT_PARAMS = "defaults 99"

S = "${WORKDIR}/git"

USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "-r -s /bin/false -G eth reth"

do_install:append() {
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/init ${D}${sysconfdir}/init.d/reth
    
    # Create directory for reth data
    install -d ${D}/persistent/reth
    chown reth:eth ${D}/persistent/reth
    chmod 0770 ${D}/persistent/reth
}

FILES:${PN} += "/persistent/reth"
TOOLCHAIN = "clang"
DEPENDS += "eth-group"
RDEPENDS:${PN} += "disk-encryption json-config eth-group lighthouse"

python () {
    # Check if INCLUDE_RCLONE is set in the environment or in local.conf
    include_rclone = d.getVar('INCLUDE_RCLONE')
    
    if include_rclone is None:
        # If not set, check the original environment
        origenv = d.getVar("BB_ORIGENV", False)
        if origenv:
            include_rclone = origenv.getVar('INCLUDE_RCLONE')
    
    if include_rclone:
        # If INCLUDE_RCLONE is set (to any non-empty value), keep its value
        d.setVar('INCLUDE_RCLONE', include_rclone)
    else:
        # If INCLUDE_RCLONE is not set, set it to '1' by default
        d.setVar('INCLUDE_RCLONE', '1')
}

# RDEPENDS:${PN} += "${@'reth-sync' if d.getVar('INCLUDE_RCLONE') == '1' else ''}"

INSANE_SKIP:${PN}:append = "already-stripped"
