#!/bin/bash

set -e

# Script to deploy a simple Ubuntu 22.04 VM in Azure with an attached storage disk

# Check for required commands
for cmd in az jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' command not found."
        exit 1
    fi
done

# Check for required environment variables
for var in ALLOWED_IP; do
    if [ -z "${!var}" ]; then
        echo "Error: '$var' is not set."
        exit 1
    fi
done

VM_NAME="non-tdx"
AZURE_VM_SIZE="Standard_D4s_v5"
AZURE_STORAGE_GB=1300
OS_DISK_SKU="PremiumV2_LRS"
STORAGE_DISK_SKU="PremiumV2_LRS"
AZURE_REGION="westus"

RESOURCE_GROUP_NAME=${VM_NAME}
OS_DISK_NAME=${VM_NAME}-os
STORAGE_DISK_NAME=${VM_NAME}-storage
NSG_NAME=${VM_NAME}-nsg

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

# Create resource group
az group create --name ${RESOURCE_GROUP_NAME} --location ${AZURE_REGION}

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

# Create NSG rule for SSH
az network nsg rule create \
    --nsg-name ${NSG_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes ${ALLOWED_IP} \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp

# Create VM
az vm create \
    --name ${VM_NAME} \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --image Ubuntu2204 \
    --size ${AZURE_VM_SIZE} \
    --attach-data-disks ${STORAGE_DISK_NAME} \
    --nsg ${NSG_NAME} \
    --public-ip-sku Standard \
    --admin-username azureuser \
    --generate-ssh-keys

echo "VM created successfully. You can connect to it using SSH."
echo "To delete the VM and associated resources, run: az group delete --name ${RESOURCE_GROUP_NAME}"
