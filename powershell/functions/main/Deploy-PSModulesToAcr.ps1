<#
.SYNOPSIS
    Deploys PowerShell modules into an Azure Container Registry.

.DESCRIPTION
    This function detects PowerShell module folders in the source path provided and uploads them to an Azure Container Registry.
    Authentication is already handled by the azure/login action.

.PARAMETER moduleSourcePath
    Path containing the PowerShell module folders.

.PARAMETER acrName
    Name of the Azure Container Registry

.EXAMPLE
    .\deploy-ps-modules-to-acr.ps1 -moduleSourcePath '.\modules' -acrName 'yourazureacrname'

.NOTES
    Ensure that that the Az PowerShell module is present

    This script is intended to be used as part of a GitHub composite action.  It is designed to execute after the actions/checkout and azure/login
    GitHub actions have been executed as it leverages the repo structure and the existing logon context.
#>

function Deploy-PsModulesToAcr {

    [CmdletBinding(SupportsShouldProcess = $true)]

    param (

        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [string]$moduleSourcePath,

        [Parameter(Mandatory = $true)]
        [string]$acrName,

        [Parameter(Mandatory = $true)]
        [string]$acrLoginServer,

        [Parameter(Mandatory = $true)]
        [string]$resourceGroupName
    )

    # Used with automated testing or just to output info into logs
    $outputObject = [PSCustomObject]@{
        moduleSourcePath = $moduleSourcePath
        acrName          = $acrName
        validModules     = $null
    }

    # Make sure the latest version of PSResourceGet is available (1.1.0-preview1 is required as of Aug 2024)

    $PSResourceModuleName = 'Microsoft.PowerShell.PSResourceGet'
    $PSResourceModuleVersion = '1.1.0-preview1'

    $installPSResourceSplat = @{
        Repository = 'PSGallery'
        Name       = $PSResourceModuleName
        Version    = $PSResourceModuleVersion
    }

    $previewVersion = Get-InstalledPSResource -Name 'Microsoft.PowerShell.PSResourceGet' -ErrorAction SilentlyContinue | Where-Object { $_.Prerelease -eq 'preview1' -and $_.Version.toString() -eq '1.1.0' }
    if ( !($previewVersion)) {
        Write-Information "Installing Microsoft.PowerShell.PSResourceGet v1.1.0 preview1"
        Install-PSResource @installPSResourceSplat -TrustRepository -WhatIf:$false -Scope CurrentUser -Force

        Write-Information "Importing Microsoft.PowerShell.PSResourceGet v1.1.0 preview1 into the current user session"
        Import-Module -Name $PSResourceModuleName -RequiredVersion $PSResourceModuleVersion
    }

    Write-Information "Using module source path: $moduleSourcePath"

    $validModules = Get-ValidModules -moduleSourcePath $moduleSourcePath

    if ($PSCmdlet.ShouldProcess("PSResourceRepository", "Create if not present for ACR")) {

        # Create a local PSResourceRepository for the ACR if it doesn't already exist
        $PSRepositoryHosts = ( Get-PSResourceRepository | Select-Object -ExpandProperty Uri).host

        if ($acrLoginServer -notin $PSRepositoryHosts) {

            Write-Information "Registering PSResourceRepository for $acrName"
            $acrUrl = "https://$($acrLoginServer)"
            write-Information $acrUrl
            Register-PSResourceRepository -Name $acrName -Uri $acrUrl
        }
        $repos = Get-PSResourceRepository | Select-Object Name, URI | ConvertTo-Json
        Write-Information $repos
    }

    # Publish modules to ACR
    foreach ($validModule in $validModules) {

        try {
            if ($PSCmdlet.ShouldProcess("Azure Container Registry", "Publish Module")) {

                $moduleName = $validModule.Name
                $moduleVersion = $validModule.Version
                $path = $validModule.Path
                Write-Information "Publishing $moduleName v$moduleVersion to $acrName"
                $publishPSResourceSplat = @{
                    Path       = $path
                    Repository = $acrName
                }
                Publish-PSResource @publishPSResourceSplat
            }
        }
        catch {
            throw "Unable to complete deployment for module $moduleName. $_"
        }
    }

    $outputObject.validModules = $validModules
    return $outputObject
}
