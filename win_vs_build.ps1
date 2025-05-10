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
        
        Write-Host "Visual Studio Developer environment for '$DevShellArch' initialized successfully." -ForegroundColor Green
        return $true

    } catch {
        Write-Error "An error occurred initializing VS Dev Environment: $($_.Exception.Message)"
        return $false
    }
}

function Build-ComponentC {
    param(
        [string]$WorkingDir
    )
    
    $command = "cl /nologo /c /EHsc /O2 /DWIN32 /D_WINDOWS /D_WINSOCK_DEPRECATED_NO_WARNINGS /D_CRT_SECURE_NO_WARNINGS `"$WorkingDir\c\tcp_wrapper.c`" /Fo:`"$WorkingDir\bin\tcp_wrapper.obj`""
    
    # Write-Host "Building C component..." -ForegroundColor Cyan
    Write-Verbose "Executing: $command"
    
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "C compilation failed with exit code $LASTEXITCODE"
        }
        Write-Verbose "C component built successfully." # -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to build C component: $($_.Exception.Message)"
        return $false
    }
}

function Build-ComponentCpp {
    param(
        [string]$WorkingDir
    )
    
    $command = "cl /nologo /c /EHsc /O2 /DWIN32 /D_WINDOWS /D_WINSOCK_DEPRECATED_NO_WARNINGS /D_CRT_SECURE_NO_WARNINGS `"$WorkingDir\cpp\proc_handlers.cpp`" /Fo:`"$WorkingDir\bin\proc_handlers.obj`""
    
    # Write-Host "Building C++ component..." -ForegroundColor Cyan
    Write-Verbose "Executing: $command"
    
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "C++ compilation failed with exit code $LASTEXITCODE"
        }
        Write-Verbose "C++ component built successfully." # -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to build C++ component: $($_.Exception.Message)"
        return $false
    }
}

function Create-Library {
    param(
        [string]$WorkingDir
    )
    
    $command = "lib /nologo /OUT:`"$WorkingDir\bin\krobe.lib`" `"$WorkingDir\bin\tcp_wrapper.obj`" `"$WorkingDir\bin\proc_handlers.obj`""
    
    # Write-Host "Creating library..." -ForegroundColor Cyan
    Write-Verbose "Executing: $command"
    
    try {
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            throw "Library creation failed with exit code $LASTEXITCODE"
        }
        Write-Verbose "Library created successfully." # -ForegroundColor Green
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
    if (-not (Test-Path "$WorkingDir\bin")) {
        New-Item -Path "$WorkingDir\bin" -ItemType Directory -Force | Out-Null
        Write-Verbose "Created bin directory at $WorkingDir\bin"
    }
    
    # Initialize VS environment
    $envInitialized = Initialize-VSDevEnv -DevShellArch $DevShellArch
    if (-not $envInitialized) {
        throw "Failed to initialize Visual Studio development environment."
    }
    
    # Build components based on target
    $success = $true
    
    switch ($Target) {
        'all' {
            $success = $success -and (Build-ComponentC -WorkingDir $WorkingDir)
            $success = $success -and (Build-ComponentCpp -WorkingDir $WorkingDir)
            $success = $success -and (Create-Library -WorkingDir $WorkingDir)
        }
        'c' {
            $success = $success -and (Build-ComponentC -WorkingDir $WorkingDir)
        }
        'cpp' {
            $success = $success -and (Build-ComponentCpp -WorkingDir $WorkingDir)
        }
        'lib' {
            $success = $success -and (Create-Library -WorkingDir $WorkingDir)
        }
    }
    
    if (-not $success) {
        throw "One or more build steps failed."
    }
    
    # Write-Host "All requested components built successfully." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}
