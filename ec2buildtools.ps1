# run with
# Set-ExecutionPolicy -Scope Process Bypass -Force .\ec2buildtools.ps1
# ============================================================
# AWS Windows EC2 - Visual Studio C++ Build Tools Installation
# Installs Visual Studio Build Tools 2022 on D:
# ============================================================

$ErrorActionPreference = "Stop"

# Configuration
$Drive = "D:"
$Root = "D:\"
$InstallPath = "D:\VSInstall"
$CachePath = "D:\VSCache"
$SharedPath = "D:\VSShared"
$TempPath = "D:\VSTemp"
$Installer = "D:\VSTemp\vs_BuildTools.exe"

$InstallerUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Visual Studio C++ Build Tools Installer"
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Check administrator privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    throw "Please run PowerShell as Administrator."
}

# 2. Check D: drive
if (-not (Test-Path $Root)) {
    throw "D: drive not found. Attach and initialize an EBS volume first."
}

$Disk = Get-PSDrive D
Write-Host "D: available: $([math]::Round($Disk.Free / 1GB, 2)) GB"

if ($Disk.Free -lt 15GB) {
    throw "Not enough free space on D:. At least 15 GB is recommended."
}

# 3. Create directories
Write-Host "`nCreating directories..." -ForegroundColor Yellow

@(
    $InstallPath
    $CachePath
    $SharedPath
    $TempPath
) | ForEach-Object {
    New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

# 4. Configure temporary directories
$env:TEMP = $TempPath
$env:TMP = $TempPath

# 5. Download installer
Write-Host "`nDownloading Visual Studio Build Tools..." -ForegroundColor Yellow

if (-not (Test-Path $Installer)) {
    Invoke-WebRequest `
        -Uri $InstallerUrl `
        -OutFile $Installer
}

if (-not (Test-Path $Installer)) {
    throw "Visual Studio installer download failed."
}

# 6. Install components
Write-Host "`nInstalling C++ Build Tools..." -ForegroundColor Yellow
Write-Host "This may take some time."

$Arguments = @(
    "--quiet"
    "--wait"
    "--norestart"
    "--installPath"
    $InstallPath
    "--installWhileDownloading"
    "--path"
    "cache=$CachePath"
    "--path"
    "shared=$SharedPath"
    "--add"
    "Microsoft.VisualStudio.Workload.VCTools"
    "--includeRecommended"
)

$Process = Start-Process `
    -FilePath $Installer `
    -ArgumentList $Arguments `
    -Wait `
    -PassThru

# 7. Check installation result
Write-Host "`nInstaller exit code: $($Process.ExitCode)"

if ($Process.ExitCode -notin @(0, 3010, 1641)) {
    throw "Visual Studio installation failed. Exit code: $($Process.ExitCode)"
}

# 8. Verify compiler
$VsDevCmd = Join-Path $InstallPath "Common7\Tools\VsDevCmd.bat"

if (Test-Path $VsDevCmd) {
    Write-Host "`nVisual Studio Build Tools installed." -ForegroundColor Green

    cmd.exe /c "`"$VsDevCmd`" -arch=x64 && cl.exe"
} else {
    Write-Warning "VsDevCmd.bat not found. Check the installation."
}

# 9. Display disk usage
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " Installation Summary"
Write-Host "==========================================" -ForegroundColor Cyan

Get-PSDrive C,D | Select-Object `
    Name,
    @{Name="UsedGB";Expression={[math]::Round($_.Used / 1GB, 2)}},
    @{Name="FreeGB";Expression={[math]::Round($_.Free / 1GB, 2)}} |
    Format-Table -AutoSize

Write-Host "Installation: $InstallPath"
Write-Host "Cache:        $CachePath"
Write-Host "Shared:       $SharedPath"
Write-Host "Temp:         $TempPath"

Write-Host "`nInstallation process completed." -ForegroundColor Green
