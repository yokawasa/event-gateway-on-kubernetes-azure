#!/bin/sh
set -x -e

cwd=`dirname "$0"`
expr "$0" : "/.*" > /dev/null || cwd=`(cd "$cwd" && pwd)`

RESOURCE_GROUP="rg-eventgateway"
REGION="eastus"
FUNCTION_NAME="myazfunc001" 
STORAGE_NAME="myazfuncstore001"

## Create Storage Account for Azure Function
echo "Create Storage Account for Azure Function..."
az storage account create \
    --name $STORAGE_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Standard_LRS \
    --kind Storage

## Create Functions App (Consumption Plan)
echo "Create Functions App (Consumption Plan)..."
az functionapp create \
    --name $FUNCTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --consumption-plan-location $REGION \
    --storage-account $STORAGE_NAME
# [NOTE] Use 'az functionapp list-consumption-locations' to view available locations

## Deploying functions
echo "Deploying functions..."
cd $cwd/../functions
zip -r functions.zip .
az functionapp deployment source config-zip  --name $FUNCTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --src functions.zip
rm functions.zip
echo "echo function URL: https://${FUNCTION_NAME}.azurewebsites.net/api/echo"
