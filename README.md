[![PowerShell Composite Action CI](https://github.com/ethorneloe/deploy-ps-modules-to-acr/actions/workflows/ci.yml/badge.svg)](https://github.com/ethorneloe/deploy-ps-modules-to-acr/actions/workflows/ci.yml)

# deploy-ps-modules-to-acr

A GitHub composite action for deploying PowerShell script modules contained within your repo into an Azure Container Registry, where they can then be consumed by other Azure resources using `Install-PSResource`

*Note that this action uses version `1.1.0-preview1` of the `Microsoft.PowerShell.PSResourceGet` module.*

# Example
```yaml
name: Test Deployment

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy-powershell-modules:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Authenticate to Azure
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID}}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Deploy PowerShell modules to acr
        uses: ethorneloe/deploy-ps-modules-to-acr@v1
        with:
          acr-name: ${{ secrets.AZURE_CONTAINER_REGISTRY_NAME}}
          resource-group-name: ${{ secrets.AZURE_RESOURCE_GROUP_NAME}}
          module-source-path: "./powershell/modules"
```

# Use Case
Changes to your custom Powershell script modules need to be deployed to an `acr` (Azure Container Registry) based on the `ModuleVersion` set in the .psd1 files of the modules. For example, internally developed PowerShell modules that are required to be kept as internal or private repos, and these need to be available for use by other Azure resources on the same private vnet as the `acr`.  These Azure resources can then pull down the versioned module using a managed identity and rbac using `Install-PSResource`.

# Requirements
- An Azure subscription with an acr configured.
- An app registration or identity with write access to publish to the acr.
- One or more Powershell script modules contained in a directory within your repo. Currently only script modules that are defined as folders with .psm1 and .psd1 files are supported, and the .psd1 must use valid module manifest format. More info on manifest files can be found [here](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.4)
- Your GitHub workflow already contains the `actions/checkout` and `azure/login` steps as shown in the example, with `enable-AzPSSession` set to true.
- If you are using an acr with private endpoint then make sure you configure your workflow to specify an appropriate runner or runner group.

# Inputs
## acr-name
Your Azure Container Registry name
```yaml
with:
  acr-name: 'exampleacr'
```

## resource-group-name
The resource group containing your acr
```yaml
with:
  resource-group-name: 'example-resource-group'
```

## module-source-path
The path within your git repo containing the powershell module folder or folders. If not specified, the default is the `github.workspace` context variable.
```yaml
with:
  module-source-path: './powershell/modules'
```
