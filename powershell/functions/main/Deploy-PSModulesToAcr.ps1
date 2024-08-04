<#
.SYNOPSIS
    Deploys PowerShell modules to an Azure Container Registry.

.DESCRIPTION
    This function scans the specified source path for PowerShell modules and uploads them to a specified Azure Container Registry (ACR).
    It is designed to work within an automated process, utilizing an existing authenticated session provided by preceding Azure login actions.

.PARAMETER moduleSourcePath
    The file system path that contains the PowerShell module directories. Each directory should include the module files (.psm1, .psd1).

.PARAMETER acrName
    The name of the Azure Container Registry to which the modules will be deployed.

.PARAMETER acrLoginServer
    The login server URL of the Azure Container Registry. This URL is typically the ACR name suffixed by '.azurecr.io'.

.PARAMETER resourceGroupName
    The name of the Azure resource group that contains the Azure Container Registry.

.EXAMPLE
    .\deploy-ps-modules-to-acr.ps1 -moduleSourcePath '.\modules' -acrName 'myACR' -acrLoginServer 'myACR.azurecr.io' -resourceGroupName 'MyResourceGroup'
    Deploys all PowerShell modules found in the '.\modules' directory to the 'myACR' container registry in Azure.

.NOTES
    This function requires the Az module and an authenticated Azure session. Ensure that the azure/login GitHub action has been executed before running this script.
    This script is intended for use as part of a GitHub Actions workflow.

.LINK
    https://learn.microsoft.com/en-us/powershell/gallery/powershellget/how-to/use-acr-repository?view=powershellget-3.x

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

    Write-Information "Using module source path: $moduleSourcePath"

    $validModules = Get-ValidModules -moduleSourcePath $moduleSourcePath

    if ($PSCmdlet.ShouldProcess("PSResourceRepository", "Create if not present for ACR")) {

        # Create a local PSResourceRepository for the ACR if it doesn't already exist
        $PSRepositoryHosts = ( Get-PSResourceRepository | Select-Object -ExpandProperty Uri).host

        if ($acrLoginServer -notin $PSRepositoryHosts) {

            Write-Information "Registering PSResourceRepository for $acrName"
            $acrUrl = "https://$($acrLoginServer)"
            Register-PSResourceRepository -Name $acrName -Uri $acrUrl
        }
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
