#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BuildCommand,

    [Parameter(Mandatory=$false)]
    [ValidateSet('x86', 'amd64', 'arm', 'arm64')]
    [string]$DevShellArch = 'amd64', # Default target architecture

    [Parameter(Mandatory=$false)]
    [string]$VSVersion, # Optional: Specify VS version range, e.g., "[17.0,18.0)" for VS 2022

    [Parameter(Mandatory=$false)]
    [string[]]$VSRequires = @('Microsoft.Component.MSBuild'), # Default required components. Add 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' for C++ build tools.

    [Parameter(Mandatory=$false)]
    [switch]$VSPrerelease # Include prerelease versions of VS
)

try {
    Write-Verbose "Starting Visual Studio Developer Environment initialization..."
    Write-Verbose "Requested Architecture: $DevShellArch"
    if ($VSVersion) { Write-Verbose "Requested VS Version: $VSVersion" }
    if ($VSPrerelease) { Write-Verbose "Including VS Prerelease versions" }
    Write-Verbose "Required VS Components: $($VSRequires -join ', ')"

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
    if ($VSVersion) {
        $vswhereArgs += @('-version', $VSVersion)
    }
    if ($VSRequires.Count -gt 0) {
        $effectiveVSRequires = $VSRequires
        if (-not ($effectiveVSRequires -join ' ').ToLower().Contains('microsoft.visualstudio.component.vc.tools')) {
            $effectiveVSRequires += 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' # Or a more specific one if needed
            Write-Verbose "Automatically added 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' to VSRequires for C/C++ compilation."
        }
        $vswhereArgs += @('-requires', ($effectiveVSRequires -join ' '))
    }
    if ($VSPrerelease) {
        $vswhereArgs += '-prerelease'
    }

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
    #    This loads variables into the current scope.
    #    -ErrorAction Stop will cause the script to halt if Launch-VsDevShell.ps1 fails.
    $devShellParams = @{ Arch = $DevShellArch }
    
    Write-Verbose "Initializing developer environment using: . `"$devShellScript`" -Arch $DevShellArch"
    . $devShellScript @devShellParams -ErrorAction Stop 1>$null 6>$null # Dot-source to apply to current scope
    
    Write-Host "Visual Studio Developer environment for '$DevShellArch' initialized successfully." -ForegroundColor Green

    # 5. Execute Build Commands if provided
    if (-not [string]::IsNullOrWhiteSpace($BuildCommand)) {
        Write-Host "Executing build command: $BuildCommand" -ForegroundColor Cyan
        Invoke-Expression $BuildCommand # Invoke-Expression allows complex commands like "cmd1 && cmd2"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build command failed with exit code $LASTEXITCODE."
        }
        Write-Host "Build executed successfully." -ForegroundColor Green
    } else {
        Write-Host "No build command provided. Environment is initialized." -ForegroundColor Yellow
    }

} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}

exit 0
