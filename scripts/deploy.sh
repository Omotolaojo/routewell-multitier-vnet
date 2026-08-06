#!/usr/bin/env bash

set -e

echo "Getting your public IP..."

ADMIN_IP=$(curl -s -4 ifconfig.me)

echo "Admin IP: $ADMIN_IP"

# Variables for the deployment
LOCATION="westeurope"
RG="rg-routewell"
VNET="vnet-routewell"

ADDRESS_SPACE="10.10.0.0/16"

WEB_SUBNET="web-subnet"
WEB_PREFIX="10.10.0.0/27"

APP_SUBNET="app-subnet"
APP_PREFIX="10.10.1.0/26"

DB_SUBNET="db-subnet"
DB_PREFIX="10.10.2.0/28"
 
 # create the resource group, virtual network, and subnets
echo "Creating Resource Group..."

az group create \
  --name "$RG" \
  --location "$LOCATION"

echo "Creating Virtual Network..."

az network vnet create \
  --resource-group "$RG" \
  --name "$VNET" \
  --address-prefixes "$ADDRESS_SPACE"

echo "Creating Web Subnet..."

az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$WEB_SUBNET" \
  --address-prefixes "$WEB_PREFIX"

echo "Creating App Subnet..."

az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$APP_SUBNET" \
  --address-prefixes "$APP_PREFIX"

echo "Creating Database Subnet..."

az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --name "$DB_SUBNET" \
  --address-prefixes "$DB_PREFIX"

echo "Deployment Complete."

# List the subnets in the virtual network
az network vnet subnet list \
  --resource-group "$RG" \
  --vnet-name "$VNET" \
  --output table

# create the network security groups and associate them with the subnets
echo "Creating Network Security Groups..."

az network nsg create \
    --resource-group "$RG" \
    --name web-nsg \
    --location "$LOCATION"

az network nsg create \
    --resource-group "$RG" \
    --name app-nsg \
    --location "$LOCATION"

az network nsg create \
    --resource-group "$RG" \
    --name db-nsg \
    --location "$LOCATION"

echo "Associating NSGs with subnets..."

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name "$WEB_SUBNET" \
    --network-security-group web-nsg

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name "$APP_SUBNET" \
    --network-security-group app-nsg

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$VNET" \
    --name "$DB_SUBNET" \
    --network-security-group db-nsg

echo "Creating Web NSG Rules..."
#HTTP access from the Internet to the Web tier
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name web-nsg \
    --name Allow-HTTP \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix "Internet" \
    --source-port-range "*" \
    --destination-port-ranges 80

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name web-nsg \
    --name Allow-SSH \
    --priority 120 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix "${ADMIN_IP}/32" \
    --source-port-range "*" \
    --destination-port-range 22

echo "Creating App NSG Rules..."

# Allow Web tier to access the App tier on port 8080
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name app-nsg \
    --name Allow-Web-To-App \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix 10.10.0.0/27 \
    --source-port-range "*" \
    --destination-port-range 8080

# Allow SSH only from the Web subnet (jump host — App has no public IP,
# so the admin's real IP can never reach it directly)
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name app-nsg \
    --name Allow-SSH \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix 10.10.0.0/27 \
    --source-port-range "*" \
    --destination-port-range 22

# Block all other traffic from the Virtual Network
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name app-nsg \
    --name Deny-Other-VNet-Inbound \
    --priority 200 \
    --direction Inbound \
    --access Deny \
    --protocol "*" \
    --source-address-prefix VirtualNetwork \
    --source-port-range "*" \
    --destination-address-prefix "*" \
    --destination-port-range "*"

echo "Creating Database NSG Rules..."

# Allow App tier to reach PostgreSQL
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name db-nsg \
    --name Allow-App-To-DB \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix 10.10.1.0/26 \
    --source-port-range "*" \
    --destination-port-range 5432

# Allow SSH only from the App subnet
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name db-nsg \
    --name Allow-SSH \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix 10.10.1.0/26 \
    --source-port-range "*" \
    --destination-port-range 22

# Block all other traffic from the Virtual Network
az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name db-nsg \
    --name Deny-Other-VNet-Inbound \
    --priority 200 \
    --direction Inbound \
    --access Deny \
    --protocol "*" \
    --source-address-prefix VirtualNetwork \
    --source-port-range "*" \
    --destination-address-prefix "*" \
    --destination-port-range "*"

echo "Creating Public IP..."

az network public-ip create \
    --resource-group "$RG" \
    --name web-pip \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static

echo "Creating Web NIC..."

az network nic create \
    --resource-group "$RG" \
    --name web-nic \
    --vnet-name "$VNET" \
    --subnet "$WEB_SUBNET" \
    --network-security-group web-nsg \
    --public-ip-address web-pip

echo "Creating App NIC..."

az network nic create \
    --resource-group "$RG" \
    --name app-nic \
    --vnet-name "$VNET" \
    --subnet "$APP_SUBNET" \
    --network-security-group app-nsg

echo "Creating Database NIC..."

az network nic create \
    --resource-group "$RG" \
    --name db-nic \
    --vnet-name "$VNET" \
    --subnet "$DB_SUBNET" \
    --network-security-group db-nsg


echo "Creating Web VM..."

az vm create \
    --resource-group "$RG" \
    --name web-vm \
    --nics web-nic \
    --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
    --size Standard_D2s_v3 \
    --admin-username azureuser \
    --ssh-key-values ~/.ssh/id_rsa.pub

echo "Creating App VM..."

az vm create \
    --resource-group "$RG" \
    --name app-vm \
    --nics app-nic \
    --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
    --size Standard_D2s_v3 \
    --admin-username azureuser \
    --ssh-key-values ~/.ssh/id_rsa.pub

echo "Creating Database VM..."

az vm create \
    --resource-group "$RG" \
    --name db-vm \
    --nics db-nic \
    --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest \
    --size Standard_D2s_v3 \
    --admin-username azureuser \
    --ssh-key-values ~/.ssh/id_rsa.pub


echo ""
echo "===================================="
echo "RouteWell deployment completed!"
echo "===================================="
