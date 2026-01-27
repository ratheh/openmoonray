<#
.SYNOPSIS
    Package MoonRay Windows build for GitHub Release

.DESCRIPTION
    Creates a redistributable ZIP package from the MoonRay install directory.
    The package includes bin, lib, include, and rdl2dso directories.

.PARAMETER Version
    Version string for the package (default: 1.7.0.0-windows-1)

.PARAMETER InstallDir
    Path to MoonRay install directory (default: relative to script)

.PARAMETER OutputDir
    Path for output package (default: releases folder next to install)

.EXAMPLE
    .\package_release.ps1
    .\package_release.ps1 -Version "1.7.0.0-windows-2"

.NOTES
    Output: moonray-windows-x64-<version>.zip
#>

param(
    [string]$Version = "1.7.0.0-windows-1",
    [string]$InstallDir = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

# ============================================
# Path Configuration (all relative)
# ============================================

# Repo root is two levels up from this script
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$WorkspaceRoot = Split-Path -Parent $RepoRoot

# Default paths relative to workspace
if ([string]::IsNullOrEmpty($InstallDir)) {
    $InstallDir = Join-Path $WorkspaceRoot "install"
}
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = Join-Path $WorkspaceRoot "releases"
}

$PackageName = "moonray-windows-x64-$Version"
$PackageDir = Join-Path $OutputDir $PackageName
$ZipFile = Join-Path $OutputDir "$PackageName.zip"

# ============================================
# Validation
# ============================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "MoonRay Release Packager" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Version:    $Version"
Write-Host "Install:    $InstallDir"
Write-Host "Output:     $OutputDir"
Write-Host ""

# Check install directory exists
if (-not (Test-Path $InstallDir)) {
    Write-Error "Install directory not found: $InstallDir"
    exit 1
}

# Check required subdirectories
$RequiredDirs = @("bin", "lib", "include", "rdl2dso")
foreach ($dir in $RequiredDirs) {
    $path = Join-Path $InstallDir $dir
    if (-not (Test-Path $path)) {
        Write-Error "Required directory not found: $path"
        exit 1
    }
}

# Check for moonray.exe
$moonrayExe = Join-Path $InstallDir "bin\moonray.exe"
if (-not (Test-Path $moonrayExe)) {
    Write-Error "moonray.exe not found: $moonrayExe"
    exit 1
}

# Check for scene_rdl2.lib
$sceneRdl2Lib = Join-Path $InstallDir "lib\scene_rdl2.lib"
if (-not (Test-Path $sceneRdl2Lib)) {
    Write-Error "scene_rdl2.lib not found: $sceneRdl2Lib"
    exit 1
}

Write-Host "Validation passed!" -ForegroundColor Green
Write-Host ""

# ============================================
# Create Package
# ============================================

Write-Host "Creating package: $PackageName" -ForegroundColor Yellow

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Clean existing package directory
if (Test-Path $PackageDir) {
    Write-Host "  Removing existing package directory..."
    Remove-Item -Recurse -Force $PackageDir
}
New-Item -ItemType Directory -Path $PackageDir | Out-Null

# Copy required directories
foreach ($dir in $RequiredDirs) {
    $src = Join-Path $InstallDir $dir
    $dst = Join-Path $PackageDir $dir
    Write-Host "  Copying $dir..."
    Copy-Item -Recurse $src $dst
}

# Copy coredata if exists
$coredata = Join-Path $InstallDir "coredata"
if (Test-Path $coredata) {
    Write-Host "  Copying coredata..."
    Copy-Item -Recurse $coredata (Join-Path $PackageDir "coredata")
}

# ============================================
# Check for hardcoded absolute paths in cmake files
# ============================================

Write-Host "  Checking cmake files for hardcoded absolute paths..."
$cmakeFiles = Get-ChildItem -Path (Join-Path $PackageDir "lib\cmake") -Recurse -Filter "*.cmake" -ErrorAction SilentlyContinue
$hardcodedPathPatterns = @(
    '[A-Z]:/Tools/',
    '[A-Z]:/Users/',
    '[A-Z]:/moonray/',
    '[A-Z]:\\Tools\\',
    '[A-Z]:\\Users\\',
    '[A-Z]:\\moonray\\'
)
$foundHardcoded = $false
foreach ($file in $cmakeFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    foreach ($pattern in $hardcodedPathPatterns) {
        if ($content -match $pattern) {
            Write-Host "  WARNING: Hardcoded path found in $($file.Name): $($Matches[0])" -ForegroundColor Red
            $foundHardcoded = $true
        }
    }
}
if ($foundHardcoded) {
    Write-Error "Hardcoded absolute paths detected in cmake export files. Fix the CMakeLists.txt source and rebuild."
    exit 1
} else {
    Write-Host "  No hardcoded paths found - cmake files are relocatable." -ForegroundColor Green
}

# ============================================
# Cleanup
# ============================================

Write-Host "  Cleaning up unnecessary files..."

# Remove test output files (.exr in root)
Get-ChildItem -Path $PackageDir -Filter "*.exr" -ErrorAction SilentlyContinue | Remove-Item -Force

# Remove .pdb files (debug symbols) - keep build small
$pdbCount = (Get-ChildItem -Path $PackageDir -Recurse -Filter "*.pdb" -ErrorAction SilentlyContinue | Measure-Object).Count
if ($pdbCount -gt 0) {
    Write-Host "  Removing $pdbCount .pdb files..."
    Get-ChildItem -Path $PackageDir -Recurse -Filter "*.pdb" | Remove-Item -Force
}

# ============================================
# Create README
# ============================================

$readmeContent = @"
MoonRay Windows Build
=====================

Version: $Version
Build Date: $(Get-Date -Format "yyyy-MM-dd")
Source: https://github.com/ratheh/openmoonray
Branch: windows-build
Build Guide: https://github.com/ratheh/addons/blob/main/PRPs/OpenMoonRay-Windows-Build-Guide.md

Contents
--------
- bin/      : Executables (moonray.exe) and DLLs
- lib/      : Static libraries for linking (.lib files)
- include/  : Headers for compilation (scene_rdl2, moonray, moonshine)
- rdl2dso/  : Shader DSOs (.so files)

Quick Start
-----------
1. Extract this archive
2. Set environment variable: RDL2_DSO_PATH=<extract_path>\rdl2dso
3. Run: bin\moonray.exe --help

Example render:
  set RDL2_DSO_PATH=%CD%\rdl2dso
  bin\moonray.exe -in scene.rdla -out render.exr

For warp_moonray Integration
----------------------------
Place this folder at: <warp_moonray_build>\Release\moonray\
warp_moonray will automatically find bundled moonray without environment variables.

Base MoonRay Version
--------------------
- OpenMoonRay 1.7.0.0 (tag: openmoonray-1.7.0.0 + 1 commit)
- Windows-specific fixes applied (see Build Guide)

Dependencies (bundled)
----------------------
- Intel TBB 2021.x
- OpenVDB 11.x
- OpenEXR 3.x
- Log4cplus
- Boost 1.86
- And others (all DLLs included in bin/)

License
-------
MoonRay is licensed under the Apache License 2.0.
See: https://github.com/dreamworksanimation/openmoonray/blob/release/LICENSE
"@

$readmePath = Join-Path $PackageDir "README.txt"
$readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
Write-Host "  Created README.txt"

# ============================================
# Create ZIP Archive
# ============================================

Write-Host ""
Write-Host "Creating ZIP archive..." -ForegroundColor Yellow

if (Test-Path $ZipFile) {
    Remove-Item $ZipFile -Force
}

# Use Compress-Archive (built into PowerShell 5+)
# Note: We compress the contents, not the folder itself
Compress-Archive -Path "$PackageDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal

# ============================================
# Report Results
# ============================================

# Calculate sizes
$uncompressedBytes = (Get-ChildItem -Path $PackageDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
$compressedBytes = (Get-Item $ZipFile).Length

$uncompressedMB = [math]::Round($uncompressedBytes / 1MB, 1)
$compressedMB = [math]::Round($compressedBytes / 1MB, 1)
$ratio = [math]::Round($compressedBytes / $uncompressedBytes * 100, 1)

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Package:      $PackageName"
Write-Host "Uncompressed: $uncompressedMB MB"
Write-Host "Compressed:   $compressedMB MB ($ratio%)"
Write-Host ""
Write-Host "Output file:"
Write-Host "  $ZipFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Go to: https://github.com/ratheh/openmoonray/releases/new"
Write-Host "  2. Create tag: v$Version"
Write-Host "  3. Upload: $ZipFile"
Write-Host ""

# Count contents for summary
$exeCount = (Get-ChildItem -Path "$PackageDir\bin" -Filter "*.exe" | Measure-Object).Count
$dllCount = (Get-ChildItem -Path "$PackageDir\bin" -Filter "*.dll" | Measure-Object).Count
$libCount = (Get-ChildItem -Path "$PackageDir\lib" -Filter "*.lib" | Measure-Object).Count
$dsoCount = (Get-ChildItem -Path "$PackageDir\rdl2dso" -Filter "*.so" | Measure-Object).Count

Write-Host "Package contents:"
Write-Host "  - $exeCount executables"
Write-Host "  - $dllCount DLLs"
Write-Host "  - $libCount static libraries"
Write-Host "  - $dsoCount shader DSOs"
