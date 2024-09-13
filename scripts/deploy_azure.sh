#!/bin/bash

set -e

# Script to deploy the resulting image to Azure

for cmd in az azcopy jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' command not found."
        exit 1
    fi
done

for var in DISK_PATH VM_NAME AZURE_REGION AZURE_VM_SIZE AZURE_STORAGE_GB ALLOWED_IP CONFIG_PATH; do
    if [ -z "${!var}" ]; then
        echo "Error: '$var' is not set."
        exit 1
    fi
done

RESOURCE_GROUP_NAME=${VM_NAME}
OS_DISK_NAME=${VM_NAME}
STORAGE_DISK_NAME=${VM_NAME}-storage
NSG_NAME=${VM_NAME}
DISK_SIZE=$(wc -c < ${DISK_PATH})

OS_DISK_SKU="Standard_LRS"
STORAGE_DISK_SKU="StandardSSD_LRS"

CONFIG=$(cat ${CONFIG_PATH})

cleanup() {
    read -r -p "An error occurred. Do you want to remove the resource group? [y/N] " response
    response=${response,,}

    if [[ "$response" =~ ^(yes|y)$ ]]; then
        echo "Removing resource group ${RESOURCE_GROUP_NAME}..."
        az group delete --name ${RESOURCE_GROUP_NAME} --yes --no-wait
        echo "Resource group deletion initiated. It may take a few minutes to complete."
    fi
    exit 1
}

# Trap to catch errors
trap "cleanup" ERR

# Register necessary providers
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Attestation

# Create resource group
az group create --name ${RESOURCE_GROUP_NAME} --location ${AZURE_REGION}

# Create OS disk and copy the image to it
az disk create \
    -n ${OS_DISK_NAME} \
    -g ${RESOURCE_GROUP_NAME} \
    -l ${AZURE_REGION} \
    --os-type Linux \
    --upload-type Upload \
    --upload-size-bytes ${DISK_SIZE} \
    --sku ${OS_DISK_SKU} \
    --security-type ConfidentialVM_NonPersistedTPM \
    --hyper-v-generation V2

SAS_REQ=$( \
    az disk grant-access \
        -n ${OS_DISK_NAME} \
        -g ${RESOURCE_GROUP_NAME} \
        --access-level Write \
        --duration-in-seconds 86400 \
)
SAS_URI=$(echo ${SAS_REQ} | jq -r '.accessSas')
azcopy copy ${DISK_PATH} ${SAS_URI} --blob-type PageBlob
az disk revoke-access -n ${OS_DISK_NAME} -g ${RESOURCE_GROUP_NAME}

# Create storage disk
az disk create \
    -n ${STORAGE_DISK_NAME} \
    -g ${RESOURCE_GROUP_NAME} \
    -l ${AZURE_REGION} \
    --size-gb ${AZURE_STORAGE_GB} \
    --sku ${STORAGE_DISK_SKU}

# Create network security group
az network nsg create \
    --name ${NSG_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --location ${AZURE_REGION}

# Declare rules for the network security group
declare -A NSG_RULES=(
    ["AllowSSH"]=" \
        --priority 100 \
        --source-address-prefixes ${ALLOWED_IP} \
        --destination-port-ranges 22 \
        --access Allow \
        --protocol Tcp"
    ["TCP8545"]=" \
        --priority 110 \
        --destination-port-ranges 8545 \
        --access Allow \
        --protocol Tcp"
    ["TCP8551"]=" \
        --priority 111 \
        --destination-port-ranges 8551 \
        --access Allow \
        --protocol Tcp"
    ["TCP8645"]=" \
        --priority 112 \
        --destination-port-ranges 8645 \
        --access Allow \
        --protocol Tcp"
    ["TCP8745"]=" \
        --priority 113 \
        --destination-port-ranges 8745 \
        --access Allow \
        --protocol Tcp"
    ["ANY30303"]=" \
        --priority 114 \
        --destination-port-ranges 30303 \
        --access Allow"
)

# Create rules for the network security group
for rule_name in "${!NSG_RULES[@]}"; do
    az network nsg rule create \
        --nsg-name ${NSG_NAME} \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --name ${rule_name} \
        ${NSG_RULES[$rule_name]}
done

ATTESTATION_PROVIDER_URL=$(echo ${CONFIG} | jq '.ATTESTATION_PROVIDER_URL')
if [ "${ATTESTATION_PROVIDER_URL}" == "null" ]; then
    echo "ATTESTATION_PROVIDER_URL is set to 'null', creating attestation provider..."

    ATTESTATION_NAME=${RESOURCE_GROUP_NAME//-}$(openssl rand -hex 6)
    # Create attestation provider
    az attestation create \
        --name ${ATTESTATION_NAME} \
        --resource-group ${RESOURCE_GROUP_NAME} \
        --location ${AZURE_REGION}
    ATTESTATION_PROVIDER_URL=$( \
        az attestation show \
            --name ${ATTESTATION_NAME} \
            --resource-group ${RESOURCE_GROUP_NAME} \
        | jq -r '.attestUri'
    )
    echo "Attestation provider URL: ${ATTESTATION_PROVIDER_URL}"

    CONFIG=$(echo ${CONFIG} | jq --arg uri "${ATTESTATION_PROVIDER_URL}" '.ATTESTATION_PROVIDER_URL = $uri')
fi

echo "Final config:"
echo ${CONFIG} | jq .

TMP_CONFIG_PATH=$(mktemp)
echo ${CONFIG} > ${TMP_CONFIG_PATH}
echo "Final config written to ${TMP_CONFIG_PATH}"

# Create VM
az vm create \
    --name ${VM_NAME} \
    --size ${AZURE_VM_SIZE} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --attach-os-disk ${OS_DISK_NAME} \
    --security-type ConfidentialVM \
    --enable-vtpm true \
    --enable-secure-boot false \
    --os-disk-security-encryption-type NonPersistedTPM \
    --os-type Linux \
    --nsg ${NSG_NAME} \
    --attach-data-disks ${STORAGE_DISK_NAME} \
    --user-data ${TMP_CONFIG_PATH}

echo "VM created, you can connect to it with SSH"
echo "To delete the VM, run 'az group delete --name ${RESOURCE_GROUP_NAME}'"
