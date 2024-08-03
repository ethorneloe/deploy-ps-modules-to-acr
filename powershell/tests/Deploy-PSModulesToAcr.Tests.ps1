
BeforeAll {

    # Configure variables used throughout all tests.

    # Get the main function name and the directory containing valid sample modules
    $parentDirectory = Join-Path $PSScriptRoot -ChildPath ".."
    $mainFunctionDirectory = Join-Path $parentDirectory -ChildPath "functions/main/"
    $mainFunction = Get-ChildItem -Path $mainFunctionDirectory -Filter "*.ps1"
    $mainFunctionName = $mainFunction | Select-Object -ExpandProperty Name
    $mainFunctionBaseName = $mainFunction | Select-Object -ExpandProperty BaseName

    $tempFolderName = "$($mainFunctionBaseName)_$($dateTimeString)"
    $tempBasePath = [System.IO.Path]::GetTempPath()
    $tempTestPath = [System.IO.Path]::Combine($tempBasePath, $tempFolderName)
    New-Item -Path $tempTestPath -type Directory | Out-Null
    $tempModuleSourcePath = "$tempTestPath\Modules"
    New-item -Path $tempModuleSourcePath -type Directory | Out-Null
    $testModuleDirectory = Join-Path $PSScriptRoot -ChildPath "test-modules"

    # Dot source in all the functions in this action repo
    $functions = Get-ChildItem -Path "$parentDirectory/functions" -Recurse -Filter "*.ps1"
    $functions | ForEach-Object {
        . $_.FullName
    }

    # Params for the main function calls in each test
    $params = @{
        acrName           = 'acrtest'
        moduleSourcePath  = $tempModuleSourcePath
        resourceGroupName = 'rgtest'
    }
}

Describe "Test Function $mainFunctionName" {

    BeforeEach {

        # Clear the temp test path containing the modules and archives created in each test
        if (Test-Path $tempModuleSourcePath ) { Get-ChildItem $tempModuleSourcePath | Remove-Item -Recurse -Force -Confirm:$false }
    }

    It "should throw an error if there are no valid module folders" {

        # Create module folder with only .psm1
        $onlyPsm1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "OnlyPsm1Module"
        New-Item -Path $onlyPsm1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $onlyPsm1ModulePath -ChildPath "OnlyPsm1Module.psm1") -ItemType File -Force | Out-Null

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain a .psm1 file and a valid .psd1 manifest."

        # Create module folder with only .psd1
        $onlyPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "OnlyPsd1Module"
        New-Item -Path $onlyPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $onlyPsd1ModulePath -ChildPath "OnlyPsd1Module.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain a .psm1 file and a valid .psd1 manifest."

        Remove-Item -Path "$tempModuleSourcePath/*" -Recurse -Force -Confirm:$false
        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain a .psm1 file and a valid .psd1 manifest."
    }

    It "should throw an error if a module does not contain a valid manifest file" {

        # Create invalid .psd1 file without ModuleVersion
        $invalidPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "InvalidPsd1Module"
        New-Item -Path $invalidPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psd1") -ItemType File -Force -Value "NoVersionInfo = '1.1.0'" | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psm1") -ItemType File -Force | Out-Null

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw
    }

    It "should extract module names and versions" {

        $params['moduleSourcePath'] = $testModuleDirectory

        $output = & $mainFunctionBaseName @params -WhatIf

        $output.validModules | Should -Not -Be $null

        foreach ($module in $output.validModules) {
            $module.Name | Should -Not -Be $null
            { [System.Version]::Parse($module.Version) } | Should -Not -Throw
        }
    }
}

AfterAll {
    Remove-Item -Path $tempTestPath -Recurse -Confirm:$false -Force -ErrorAction Stop
}