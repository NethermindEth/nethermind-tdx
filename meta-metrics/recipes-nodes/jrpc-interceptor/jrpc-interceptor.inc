SUMMARY = "JSON-RPC Interceptor"
DESCRIPTION = "The tool allows to intercept HTTP (Json RPC) requests and publish the results as Prometheus metrics."
HOMEPAGE = "https://github.com/NethermindEth/jrpc-interceptor"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

inherit go-mod update-rc.d

GO_INSTALL = "${GO_IMPORT}"
GO_LINKSHARED = ""

GO_EXTLDFLAGS:append = ",-z,stack-size=0x800000"

# reproducible builds
INHIBIT_PACKAGE_DEBUG_SPLIT = '1'
INHIBIT_PACKAGE_STRIP = '1'
#GO_EXTRA_LDFLAGS:append = " -s -w -buildid="
#GOBUILDFLAGS:append = " -buildvcs=false"

RDEPENDS:${PN} += " nginx"

do_compile[network] = "1"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI += "file://init"
SRC_URI += "file://default.conf"
SRC_URI += "file://nginx.conf"

INITSCRIPT_NAME = "jrpc-interceptor"
INITSCRIPT_PARAMS = "defaults 97"

do_install:append() {
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${THISDIR}/init ${D}${sysconfdir}/init.d/jrpc-interceptor
}

FILES:${PN} += "${sysconfdir}/init.d/jrpc-interceptor"

do_install:append() {
    install -d ${D}${sysconfdir}/nginx
    install -d ${D}${sysconfdir}/nginx/conf.d

    install -m 0644 ${THISDIR}/nginx.conf ${D}${sysconfdir}/nginx/jrpc-interceptor-nginx.conf
    install -m 0644 ${THISDIR}/default.conf ${D}${sysconfdir}/nginx/conf.d/jrpc-interceptor-default.conf
}

FILES:${PN} += "${sysconfdir}/nginx/jrpc-interceptor-nginx.conf"
FILES:${PN} += "${sysconfdir}/nginx/conf.d/default.conf"

pkg_postinst:${PN}:append() {
    if [ -n "$D" ]; then
        exit 0
    fi
    if [ -f /etc/nginx/nginx.conf ]; then
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    fi
    ln -sf /etc/nginx/jrpc-interceptor-nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx || true
}
