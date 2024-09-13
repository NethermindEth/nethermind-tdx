SUMMARY = "JSON Config"
DESCRIPTION = "A bash script that fetches and parses a JSON file and exports key-value pairs as environment variables, based on Flashbot's config-parser"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/:"
SRC_URI = "file://json_config_parse.sh \
           file://json_config_setup.sh \
           file://json-config-fetch.sh"

S = "${WORKDIR}"

python () {
    json_config_config_url = d.getVar("JSON_CONFIG_CONFIG_URL")
    json_config_allowed_keys = d.getVar("JSON_CONFIG_ALLOWED_KEYS")
    
    if json_config_config_url is None or json_config_allowed_keys is None:
        origenv = d.getVar("BB_ORIGENV", False)
        if origenv:
            if json_config_config_url is None:
                json_config_config_url = origenv.getVar("JSON_CONFIG_CONFIG_URL")
            if json_config_allowed_keys is None:
                json_config_allowed_keys = origenv.getVar("JSON_CONFIG_ALLOWED_KEYS")
        
    if json_config_config_url:
        d.setVar("JSON_CONFIG_CONFIG_URL", json_config_config_url)
        d.setVar("JSON_CONFIG_ALLOWED_KEYS", json_config_allowed_keys)
    else:
        # default to Azure metadata endpoint
        d.setVar("JSON_CONFIG_CONFIG_URL", "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text")
        d.setVar("JSON_CONFIG_ALLOWED_KEYS", "")
}

do_install() {
    # Create necessary directories
    install -d ${D}${bindir}
    install -d ${D}${sysconfdir}
    install -d ${D}${sysconfdir}/init.d
    install -d ${D}${sysconfdir}/profile.d

    # Install scripts
    install -m 0755 ${S}/json_config_parse.sh ${D}${bindir}
    install -m 0755 ${S}/json_config_setup.sh ${D}${bindir}
    install -m 0755 ${S}/json-config-fetch.sh ${D}${sysconfdir}/init.d/json-config-fetch

    # Create configuration file
    echo -n "" > ${D}${sysconfdir}/json-config.conf
    echo "export CONFIG_URL='${JSON_CONFIG_CONFIG_URL}'" >> ${D}${sysconfdir}/json-config.conf
    echo "export ALLOWED_KEYS='${JSON_CONFIG_ALLOWED_KEYS}'" >> ${D}${sysconfdir}/json-config.conf

    # Set up profile.d script to source json_config_setup.sh
    echo "source /usr/bin/json_config_setup.sh" > ${D}${sysconfdir}/profile.d/json_config.sh
}

RDEPENDS:${PN} += "jq curl coreutils"

inherit update-rc.d

INITSCRIPT_NAME = "json-config-fetch"
INITSCRIPT_PARAMS = "defaults 90"