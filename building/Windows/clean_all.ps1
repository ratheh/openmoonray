<#
.SYNOPSIS
    Clean OpenMoonRay build artifacts on Windows

.DESCRIPTION
    This script removes all build output directories to enable a fresh build.
    Use this before build_all.ps1 to validate the build works from scratch.

.PARAMETER KeepInstall
    Keep the install directory (only clean build directories)

.EXAMPLE
    .\clean_all.ps1
    .\clean_all.ps1 -KeepInstall

.NOTES
    This removes:
    - build_scene_rdl2/
    - build_moonray/
    - build_moonshine/
    - install/ (unless -KeepInstall is specified)
#>

param(
    [switch]$KeepInstall
)

$ErrorActionPreference = "Stop"

# ============================================
# Path Configuration (all relative)
# ============================================

# Repo root is two levels up from this script
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkspaceRoot = Split-Path -Parent $RepoRoot

$BuildSceneRdl2 = Join-Path $WorkspaceRoot "build_scene_rdl2"
$BuildMoonshine = Join-Path $WorkspaceRoot "build_moonshine"
$BuildMoonray = Join-Path $WorkspaceRoot "build_moonray"
$InstallDir = Join-Path $WorkspaceRoot "install"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "OpenMoonRay Windows Clean Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Workspace: $WorkspaceRoot" -ForegroundColor Yellow
Write-Host ""

# ============================================
# Clean build directories
# ============================================

function Remove-BuildDir {
    param([string]$Path, [string]$Name)

    if (Test-Path $Path) {
        Write-Host "Removing $Name..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $Path
        Write-Host "  Removed: $Path" -ForegroundColor Green
    } else {
        Write-Host "  $Name not found (already clean)" -ForegroundColor DarkGray
    }
}

Remove-BuildDir -Path $BuildSceneRdl2 -Name "build_scene_rdl2"
Remove-BuildDir -Path $BuildMoonray -Name "build_moonray"
Remove-BuildDir -Path $BuildMoonshine -Name "build_moonshine"

if (-not $KeepInstall) {
    Remove-BuildDir -Path $InstallDir -Name "install"
} else {
    Write-Host "  Keeping install directory (-KeepInstall specified)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "CLEAN COMPLETE!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To rebuild from scratch, run:" -ForegroundColor Yellow
Write-Host "  .\build_all.ps1"
Write-Host ""
