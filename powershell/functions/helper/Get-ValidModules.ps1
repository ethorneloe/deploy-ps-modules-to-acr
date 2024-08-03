<#
.SYNOPSIS
    Retrieves a list of valid PowerShell modules based on .psd1 and .psm1 files.

.DESCRIPTION
    This function searches for valid PowerShell module directories within a specified path.
    A valid module directory contains both a valid .psd1 manifest and a .psm1 file. It searches recursively
    through the specified source path.

.PARAMETER moduleSourcePath
    The path where the function will begin searching for module directories. This path is
    scanned recursively.

.EXAMPLE
    $modulePath = "C:\Modules"
    $validModules = Get-ValidModules -moduleSourcePath $modulePath
    Write-Output $validModules

    Outputs the name and version of valid PowerShell modules found in the specified directory.

.OUTPUTS
    System.Collections.ArrayList
    Returns an array list containing the name and version of each module found.
#>

function Get-ValidModules {
    param(
        [Parameter(Mandatory = $true)]
        [string]$moduleSourcePath
    )

    $validModules = [System.Collections.ArrayList]@()

    # Get all directories recursively
    $directories = Get-ChildItem -Path $moduleSourcePath -Directory -Recurse

    # Check for folders that contain .psd1 and .psm1 and then check the validity of the .psd1 manifest
    foreach ($directory in $directories) {

        $psd1File = Get-ChildItem -Path $directory.FullName -Filter *.psd1 -ErrorAction SilentlyContinue
        $psm1File = Get-ChildItem -Path $directory.FullName -Filter *.psm1 -ErrorAction SilentlyContinue

        if ($psd1File -and $psm1File) {

            $moduleName = $psd1File.BaseName

            # Check the validity of the psd1 file
            try {
                $manifest = Test-ModuleManifest $psd1File -ErrorAction Stop
                $moduleVersion = $manifest.Version.ToString()
            }
            catch {
                Throw "Module manifest file is not formatted properly - $_"
            }

            Write-Information "Found $moduleName version $moduleVersion"

            $validModule = [PSCustomObject]@{
                Name    = $moduleName
                Version = $moduleVersion
                Path    = $directory.FullName
            }
            [void]$validModules.Add($validModule)
        }
    }

    if ($validModules.count -eq 0) {
        throw "No valid powershell modules found in this repo. Module folders need to contain a .psm1 file and a valid .psd1 manifest."
    }

    return $validModules
}
