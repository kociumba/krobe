#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('x86', 'amd64', 'arm', 'arm64')]
    [string]$DevShellArch = 'amd64',

    [Parameter(Mandatory=$false)]
    [ValidateSet('all', 'c', 'cpp', 'lib')]
    [string]$Target = 'all',

    [Parameter(Mandatory=$false)]
    [string]$WorkingDir = $PWD,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$Components = @(
    @{
        Name = "tcp_wrapper"
        Type = "c"
        SourceFile = "c\tcp_wrapper.c" 
        OutputFile = "bin\tcp_wrapper.obj"
    },
    @{
        Name = "proc_handlers"
        Type = "cpp"
        SourceFile = "cpp\proc_handlers.cpp"
        OutputFile = "bin\proc_handlers.obj"
    }
)

function Initialize-VSDevEnv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('x86', 'amd64', 'arm', 'arm64')]
        [string]$DevShellArch = 'amd64'
    )

    try {
        Write-Verbose "Starting Visual Studio Developer Environment initialization..."
        Write-Verbose "Requested Architecture: $DevShellArch"

        # 1. locate vswhere.exe
        $vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (-not (Test-Path (Split-Path $vswherePath -Parent))) {
            $altPath = Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe'
            if (Test-Path $altPath) {
                $vswherePath = $altPath
            }
        }

        if (-not (Test-Path $vswherePath)) {
            throw "vswhere.exe not found. Searched standard locations. Please ensure Visual Studio or Visual Studio Build Tools are installed."
        }
        Write-Verbose "vswhere.exe found at: $vswherePath"

        # 2. Use vswhere.exe to find the Visual Studio installation path
        $vswhereArgs = @('-latest', '-products', '*', '-property', 'installationPath', '-format', 'value', '-nologo')
        $vswhereArgs += @('-requires', 'Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64')

        Write-Verbose "Running vswhere.exe with arguments: $($vswhereArgs -join ' ')"
        $vsInstallPath = Invoke-Expression "& `"$vswherePath`" $vswhereArgs" | Select-Object -First 1

        if (-not $vsInstallPath -or [string]::IsNullOrWhiteSpace($vsInstallPath)) {
            throw "Compatible Visual Studio installation not found by vswhere.exe with the specified criteria. Ensure required components (including C++ Build Tools) are installed."
        }
        Write-Verbose "Visual Studio Installation Path found: $vsInstallPath"

        # 3. Construct the path to Launch-VsDevShell.ps1
        $devShellScript = Join-Path $vsInstallPath 'Common7\Tools\Launch-VsDevShell.ps1'
        if (-not (Test-Path $devShellScript)) {
            throw "Launch-VsDevShell.ps1 not found at the expected location: '$devShellScript'. The Visual Studio installation might be incomplete or corrupted."
        }
        Write-Verbose "Developer Shell script found at: $devShellScript"

        # 4. Initialize the Environment by dot-sourcing Launch-VsDevShell.ps1
        $devShellParams = @{ Arch = $DevShellArch }
        
        Write-Verbose "Initializing developer environment using: . `"$devShellScript`" -Arch $DevShellArch"
        . $devShellScript @devShellParams -ErrorAction Stop 1>$null 6>$null # Dot-source to apply to current scope
        
        Write-Host "Visual Studio Developer environment for '$DevShellArch' created successfully." -ForegroundColor Green
        return $true

    } catch {
        Write-Error "An error occurred initializing VS Dev Environment: $($_.Exception.Message)"
        return $false
    }
}

function Build-Component {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkingDir,
        
        [Parameter(Mandatory=$true)]
        [string]$SourceFile,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFile,
        
        [Parameter(Mandatory=$false)]
        [string]$ComponentType = "Component"
    )
    
    $compilerFlags = @(
        "/nologo", "/c", "/O2",
        "/DWIN32", "/D_WINDOWS",
        "/D_WINSOCK_DEPRECATED_NO_WARNINGS",
        "/D_CRT_SECURE_NO_WARNINGS"
    )
    
    $fullSourcePath = Join-Path $WorkingDir $SourceFile
    $fullOutputPath = Join-Path $WorkingDir $OutputFile
    
    $command = "cl $($compilerFlags -join ' ') `"$fullSourcePath`" /Fo:`"$fullOutputPath`""
    
    Write-Verbose "Building $ComponentType from $SourceFile"
    Write-Verbose "Executing: $command"
    
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "$ComponentType compilation failed with exit code $LASTEXITCODE"
        }
        Write-Verbose "$ComponentType built successfully."
        return $true
    }
    catch {
        Write-Error "Failed to build ${ComponentType}: $($_.Exception.Message)"
        return $false
    }
}

function Create-Library {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WorkingDir,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputFile,
        
        [Parameter(Mandatory=$true)]
        [string[]]$ObjectFiles
    )
    
    $fullOutputPath = Join-Path $WorkingDir $OutputFile
    $objectFilePaths = $ObjectFiles | ForEach-Object { Join-Path $WorkingDir $_ }
    $objectFileArgs = $objectFilePaths | ForEach-Object { "`"$_`"" }
    
    $command = "lib /nologo /OUT:`"$fullOutputPath`" $($objectFileArgs -join ' ')"
    
    Write-Verbose "Creating library: $OutputFile"
    Write-Verbose "Executing: $command"
    
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "Library creation failed with exit code $LASTEXITCODE"
        }
        Write-Verbose "Library created successfully: $OutputFile"
        return $true
    }
    catch {
        Write-Error "Failed to create library: $($_.Exception.Message)"
        return $false
    }
}

# Main execution flow
try {
    # Ensure bin directory exists
    $binDir = Join-Path $WorkingDir "bin"
    if (-not (Test-Path $binDir)) {
        New-Item -Path $binDir -ItemType Directory -Force | Out-Null
        Write-Verbose "Created bin directory at $binDir"
    }
    
    # Initialize VS environment
    $envInitialized = Initialize-VSDevEnv -DevShellArch $DevShellArch
    if (-not $envInitialized) {
        throw "Failed to initialize Visual Studio development environment."
    }
    
    # Build components based on target
    $success = $true
    $builtObjects = @()
    
    switch ($Target) {
        'all' {
            # Build all components
            foreach ($component in $Components) {
                $componentSuccess = Build-Component `
                    -WorkingDir $WorkingDir `
                    -SourceFile $component.SourceFile `
                    -OutputFile $component.OutputFile `
                    -ComponentType "$($component.Type) component: $($component.Name)"
                
                if ($componentSuccess) {
                    $builtObjects += $component.OutputFile
                }
                
                $success = $success -and $componentSuccess
            }
            
            # Create library with all built objects
            if ($success -and $builtObjects.Count -gt 0) {
                $success = $success -and (Create-Library `
                    -WorkingDir $WorkingDir `
                    -OutputFile "bin\krobe.lib" `
                    -ObjectFiles $builtObjects)
            }
        }
        'c' {
            # Build only C components
            foreach ($component in $Components | Where-Object { $_.Type -eq "c" }) {
                $componentSuccess = Build-Component `
                    -WorkingDir $WorkingDir `
                    -SourceFile $component.SourceFile `
                    -OutputFile $component.OutputFile `
                    -ComponentType "C component: $($component.Name)"
                
                $success = $success -and $componentSuccess
            }
        }
        'cpp' {
            # Build only C++ components
            foreach ($component in $Components | Where-Object { $_.Type -eq "cpp" }) {
                $componentSuccess = Build-Component `
                    -WorkingDir $WorkingDir `
                    -SourceFile $component.SourceFile `
                    -OutputFile $component.OutputFile `
                    -ComponentType "C++ component: $($component.Name)"
                
                $success = $success -and $componentSuccess
            }
        }
        'lib' {
            # Create library with all component object files (assuming they're already built)
            $objectFiles = $Components | ForEach-Object { $_.OutputFile }
            $success = $success -and (Create-Library `
                -WorkingDir $WorkingDir `
                -OutputFile "bin\krobe.lib" `
                -ObjectFiles $objectFiles)
        }
    }
    
    if (-not $success) {
        throw "One or more build steps failed."
    }
    
    Write-Host "Native build successfull." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
