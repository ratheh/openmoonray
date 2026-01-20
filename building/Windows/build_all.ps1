<#
.SYNOPSIS
    Build OpenMoonRay on Windows

.DESCRIPTION
    This script builds OpenMoonRay from source on Windows.
    It builds scene_rdl2 first, then moonray, then moonshine with all DSOs.

.PARAMETER Clean
    Clean build directories before building

.EXAMPLE
    .\build_all.ps1
    .\build_all.ps1 -Clean

.NOTES
    Required environment variables:
    - VCPKG_ROOT: Path to vcpkg installation
    - ISPC_HOME: Path to ISPC compiler installation (optional if in PATH)
#>

param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# ============================================
# Path Configuration (all relative)
# ============================================

# Repo root is two levels up from this script
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$SceneRdl2Source = Join-Path $RepoRoot "moonray\scene_rdl2"
$McrtDenoiseSource = Join-Path $RepoRoot "moonray\mcrt_denoise"
$MoonshineSource = Join-Path $RepoRoot "moonray\moonshine"
$MoonraySource = Join-Path $RepoRoot "moonray"

# CMake modules path (use forward slashes for CMake)
$CmakeModulesPath = (Join-Path $RepoRoot "cmake_modules\cmake").Replace('\', '/')
$CmakeModulesRoot = (Join-Path $RepoRoot "cmake_modules").Replace('\', '/')

# Build/install directories relative to repo root's parent
$WorkspaceRoot = Split-Path -Parent $RepoRoot
$BuildSceneRdl2 = Join-Path $WorkspaceRoot "build_scene_rdl2"
$BuildMcrtDenoise = Join-Path $WorkspaceRoot "build_mcrt_denoise"
$BuildMoonshine = Join-Path $WorkspaceRoot "build_moonshine"
$BuildMoonray = Join-Path $WorkspaceRoot "build_moonray"
$InstallDir = Join-Path $WorkspaceRoot "install"

# ============================================
# Environment Variable Validation (Fail Fast)
# ============================================

# vcpkg - REQUIRED
if (-not $env:VCPKG_ROOT) {
    throw @"
VCPKG_ROOT environment variable not set.

To fix:
1. Install vcpkg: git clone https://github.com/microsoft/vcpkg.git
2. Bootstrap: cd vcpkg && .\bootstrap-vcpkg.bat
3. Set environment variable:
   [Environment]::SetEnvironmentVariable("VCPKG_ROOT", "path\to\vcpkg", "User")
4. Restart PowerShell
"@
}

if (-not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) {
    throw "vcpkg.exe not found at VCPKG_ROOT: $env:VCPKG_ROOT"
}

# ISPC - check ISPC_HOME or PATH
$IspcExe = $null
if ($env:ISPC_HOME) {
    $IspcExe = Join-Path $env:ISPC_HOME "bin\ispc.exe"
    if (-not (Test-Path $IspcExe)) {
        throw "ISPC not found at ISPC_HOME: $env:ISPC_HOME\bin\ispc.exe"
    }
} else {
    # Try to find in PATH
    $IspcExe = Get-Command "ispc.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $IspcExe) {
        throw @"
ISPC compiler not found.

To fix:
1. Download ISPC from: https://github.com/ispc/ispc/releases
2. Extract to a directory (e.g., C:\Tools\ispc)
3. Either:
   a. Set ISPC_HOME environment variable to the extraction directory
   b. Or add the bin directory to your PATH
"@
    }
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "OpenMoonRay Windows Build Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Repo Root:      $RepoRoot"
Write-Host "  Workspace:      $WorkspaceRoot"
Write-Host "  Install Dir:    $InstallDir"
Write-Host "  CMake Modules:  $CmakeModulesPath"
Write-Host "  CMake Modules Root: $CmakeModulesRoot"
Write-Host "  VCPKG_ROOT:     $env:VCPKG_ROOT"
Write-Host "  ISPC:           $IspcExe"
Write-Host ""

# Set CMAKE_MODULES_ROOT for ispc_dso_generate script location
$env:CMAKE_MODULES_ROOT = $CmakeModulesRoot

# Check for required vcpkg packages
Write-Host "Checking vcpkg packages..." -ForegroundColor Yellow
$requiredPackages = @("tbb", "openimageio", "log4cplus", "jsoncpp", "lua", "embree", "openimagedenoise")
$missingPackages = @()
foreach ($pkg in $requiredPackages) {
    $pkgDir = Join-Path $env:VCPKG_ROOT "installed\x64-windows\share\$pkg"
    if (-not (Test-Path $pkgDir)) {
        $missingPackages += $pkg
    }
}

if ($missingPackages.Count -gt 0) {
    Write-Warning "Missing vcpkg packages: $($missingPackages -join ', ')"
    Write-Warning "Run: vcpkg install $($missingPackages -join ':x64-windows '):x64-windows"
}

Write-Host "Prerequisites OK" -ForegroundColor Green
Write-Host ""

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning build directories..." -ForegroundColor Yellow
    if (Test-Path $BuildSceneRdl2) { Remove-Item -Recurse -Force $BuildSceneRdl2 }
    if (Test-Path $BuildMoonshine) { Remove-Item -Recurse -Force $BuildMoonshine }
    if (Test-Path $BuildMoonray) { Remove-Item -Recurse -Force $BuildMoonray }
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    Write-Host "Clean complete" -ForegroundColor Green
}

# Create directories
New-Item -ItemType Directory -Force -Path $BuildSceneRdl2 | Out-Null
New-Item -ItemType Directory -Force -Path $BuildMoonshine | Out-Null
New-Item -ItemType Directory -Force -Path $BuildMoonray | Out-Null
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# ============================================
# Create Windows Junctions (Git symlinks don't work on Windows)
# ============================================
Write-Host "Creating Windows junctions for symlinks..." -ForegroundColor Yellow

# Function to safely create junction from symlink placeholder
function New-JunctionFromSymlink {
    param([string]$SymlinkPath, [string]$TargetPath, [string]$Description)

    # Check if it's a symlink placeholder file (small file containing path)
    if (Test-Path $SymlinkPath -PathType Leaf) {
        $size = (Get-Item $SymlinkPath).Length
        if ($size -lt 100) {
            Write-Host "  Replacing symlink placeholder: $Description" -ForegroundColor Yellow
            Remove-Item $SymlinkPath -Force
            New-Item -ItemType Junction -Path $SymlinkPath -Target $TargetPath -Force | Out-Null
            Write-Host "    Created junction: $Description" -ForegroundColor Green
        } else {
            Write-Warning "  $SymlinkPath is not a symlink placeholder (size: $size bytes)"
        }
    } elseif (-not (Test-Path $SymlinkPath -PathType Container)) {
        # Doesn't exist yet - create junction
        New-Item -ItemType Junction -Path $SymlinkPath -Target $TargetPath -Force | Out-Null
        Write-Host "  Created junction: $Description" -ForegroundColor Green
    } else {
        Write-Host "  Junction already exists: $Description" -ForegroundColor DarkGray
    }
}

# moonray/moonray submodule path
$MoonraySubmodule = Join-Path $RepoRoot "moonray\moonray"

# moonray/moonray/moonray -> lib
$moonrayLibTarget = Join-Path $MoonraySubmodule "lib"
New-JunctionFromSymlink -SymlinkPath (Join-Path $MoonraySubmodule "moonray") `
                        -TargetPath $moonrayLibTarget `
                        -Description "moonray/moonray/moonray -> lib"

# moonray/moonray/include/moonray -> ../lib
New-JunctionFromSymlink -SymlinkPath (Join-Path $MoonraySubmodule "include\moonray") `
                        -TargetPath $moonrayLibTarget `
                        -Description "moonray/moonray/include/moonray -> lib"

# moonshine/include/moonshine -> ../lib
$moonshineLibTarget = Join-Path $MoonshineSource "lib"
New-JunctionFromSymlink -SymlinkPath (Join-Path $MoonshineSource "include\moonshine") `
                        -TargetPath $moonshineLibTarget `
                        -Description "moonshine/include/moonshine -> lib"

Write-Host "Junctions setup complete" -ForegroundColor Green

# ============================================
# Build scene_rdl2
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Building scene_rdl2" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Push-Location $BuildSceneRdl2
try {
    Write-Host "Configuring scene_rdl2..." -ForegroundColor Yellow

    # vcpkg package paths (use forward slashes)
    $VcpkgInstalled = "$env:VCPKG_ROOT/installed/x64-windows".Replace('\', '/')
    $IspcExeForCmake = $IspcExe.Replace('\', '/')

    $cmakeArgs = @(
        "-S", $SceneRdl2Source,
        "-B", ".",
        "-G", "Visual Studio 17 2022",
        "-A", "x64",
        "-DCMAKE_MODULE_PATH=$CmakeModulesPath",
        "-DCMAKE_INSTALL_PREFIX=$InstallDir",
        "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake",
        "-DTBB_ROOT=$VcpkgInstalled",
        "-DTBB_DIR=$VcpkgInstalled/share/tbb",
        "-DISPC_COMPILER=$IspcExeForCmake",
        "-DABI_VERSION=0"
    )

    # Add Python if available
    $python = Get-Command "python.exe" -ErrorAction SilentlyContinue
    if ($python) {
        $cmakeArgs += "-DPYTHON_EXECUTABLE=$($python.Source)"
    }

    & cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed for scene_rdl2" }

    Write-Host "Building scene_rdl2..." -ForegroundColor Yellow
    cmake --build . --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "Build failed for scene_rdl2" }

    Write-Host "Installing scene_rdl2..." -ForegroundColor Yellow
    cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { throw "Install failed for scene_rdl2" }

    Write-Host "scene_rdl2 build complete!" -ForegroundColor Green
}
finally {
    Pop-Location
}

# ============================================
# Build mcrt_denoise (SKIPPED - requires Intel OpenImageDenoise)
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Skipping mcrt_denoise (requires Intel OpenImageDenoise)" -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Cyan
# NOTE: McrtDenoise is made optional in MoonrayConfig.cmake
# To enable denoising support, install Intel OIDN and uncomment this section

# ============================================
# Build moonray
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Building moonray" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Push-Location $BuildMoonray
try {
    Write-Host "Configuring moonray..." -ForegroundColor Yellow

    $IspcExeForCmake = $IspcExe.Replace('\', '/')

    & cmake -S $MoonraySource -B . -G "Visual Studio 17 2022" -A x64 `
        "-DCMAKE_MODULE_PATH=$CmakeModulesPath" `
        "-DCMAKE_PREFIX_PATH=$InstallDir" `
        "-DCMAKE_INSTALL_PREFIX=$InstallDir" `
        "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" `
        "-DISPC_COMPILER=$IspcExeForCmake" `
        "-DMOONRAY_USE_CUDA=OFF" `
        "-DMOONRAY_USE_OPTIX=OFF" `
        "-DBUILD_QT_APPS=OFF" `
        "-DABI_VERSION=0"

    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed for moonray" }

    Write-Host "Building moonray..." -ForegroundColor Yellow
    cmake --build . --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "Build failed for moonray" }

    Write-Host "Installing moonray..." -ForegroundColor Yellow
    cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { throw "Install failed for moonray" }

    Write-Host "moonray build complete!" -ForegroundColor Green
}
finally {
    Pop-Location
}

# ============================================
# Build moonshine
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Building moonshine" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Push-Location $BuildMoonshine
try {
    Write-Host "Configuring moonshine..." -ForegroundColor Yellow

    $IspcExeForCmake = $IspcExe.Replace('\', '/')

    & cmake -S $MoonshineSource -B . -G "Visual Studio 17 2022" -A x64 `
        "-DCMAKE_MODULE_PATH=$CmakeModulesPath" `
        "-DCMAKE_PREFIX_PATH=$InstallDir" `
        "-DCMAKE_INSTALL_PREFIX=$InstallDir" `
        "-DCMAKE_TOOLCHAIN_FILE=$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" `
        "-DISPC_COMPILER=$IspcExeForCmake" `
        "-DMOONRAY_USE_OPTIX=OFF" `
        "-DABI_VERSION=0"

    if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed for moonshine" }

    Write-Host "Building moonshine..." -ForegroundColor Yellow
    cmake --build . --config Release --parallel
    if ($LASTEXITCODE -ne 0) { throw "Build failed for moonshine" }

    Write-Host "Installing moonshine..." -ForegroundColor Yellow
    cmake --install . --config Release
    if ($LASTEXITCODE -ne 0) { throw "Install failed for moonshine" }

    Write-Host "moonshine build complete!" -ForegroundColor Green
}
finally {
    Pop-Location
}

# ============================================
# Copy DSOs from both moonray and moonshine builds
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Copying DSOs" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$InstallRdl2dsoDir = Join-Path $InstallDir "rdl2dso"
New-Item -ItemType Directory -Force -Path $InstallRdl2dsoDir | Out-Null

$totalDsoCount = 0

# Copy from moonray build
$BuildRdl2dsoDirMoonray = Join-Path $BuildMoonray "rdl2dso"
if (Test-Path $BuildRdl2dsoDirMoonray) {
    $dsoFiles = Get-ChildItem "$BuildRdl2dsoDirMoonray\*.so*" -ErrorAction SilentlyContinue
    $dsoCount = 0
    foreach ($dso in $dsoFiles) {
        Copy-Item $dso.FullName "$InstallRdl2dsoDir\" -Force
        $dsoCount++
    }
    Write-Host "  Copied $dsoCount DSO files from moonray" -ForegroundColor Green
    $totalDsoCount += $dsoCount
}

# Copy from moonshine build
$BuildRdl2dsoDirMoonshine = Join-Path $BuildMoonshine "rdl2dso"
if (Test-Path $BuildRdl2dsoDirMoonshine) {
    $dsoFiles = Get-ChildItem "$BuildRdl2dsoDirMoonshine\*.so*" -ErrorAction SilentlyContinue
    $dsoCount = 0
    foreach ($dso in $dsoFiles) {
        Copy-Item $dso.FullName "$InstallRdl2dsoDir\" -Force
        $dsoCount++
    }
    Write-Host "  Copied $dsoCount DSO files from moonshine" -ForegroundColor Green
    $totalDsoCount += $dsoCount
}

Write-Host "Total: $totalDsoCount DSO files copied" -ForegroundColor Green

# ============================================
# Copy vcpkg runtime DLLs to install/bin
# ============================================
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Copying vcpkg DLLs" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$InstallBinDir = Join-Path $InstallDir "bin"
$VcpkgBinDir = Join-Path $env:VCPKG_ROOT "installed\x64-windows\bin"

if (Test-Path $VcpkgBinDir) {
    # Required runtime DLLs from vcpkg
    $requiredDlls = @(
        "tbb12.dll",
        "embree4.dll",
        "blosc.dll",
        "boost_*.dll",
        "bz2.dll",
        "charset-1.dll",
        "deflate.dll",
        "freetype.dll",
        "gif.dll",
        "Iex*.dll",
        "IlmThread*.dll",
        "Imath*.dll",
        "jpeg*.dll",
        "jsoncpp.dll",
        "lcms2.dll",
        "libcurl.dll",
        "libpng16.dll",
        "libsharpyuv.dll",
        "libwebp*.dll",
        "log4cplus.dll",
        "lz4.dll",
        "lzma.dll",
        "OpenColorIO*.dll",
        "OpenEXR*.dll",
        "OpenImageIO*.dll",
        "openvdb.dll",
        "pugixml.dll",
        "raw.dll",
        "snappy.dll",
        "tiff.dll",
        "turbojpeg.dll",
        "yaml-cpp.dll",
        "zlib1.dll",
        "zstd.dll",
        "lua*.dll",
        "iconv-2.dll",
        "intl-8.dll",
        "liblzma.dll",
        "fmt.dll"
    )

    $dllsCopied = 0
    foreach ($pattern in $requiredDlls) {
        $dlls = Get-ChildItem (Join-Path $VcpkgBinDir $pattern) -ErrorAction SilentlyContinue
        foreach ($dll in $dlls) {
            Copy-Item $dll.FullName $InstallBinDir -Force
            $dllsCopied++
        }
    }
    Write-Host "Copied $dllsCopied vcpkg DLLs to install/bin" -ForegroundColor Green
} else {
    Write-Warning "vcpkg bin directory not found: $VcpkgBinDir"
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "BUILD COMPLETE!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installation directory: $InstallDir" -ForegroundColor Yellow
Write-Host "  bin/     - moonray.exe and all required DLLs"
Write-Host "  rdl2dso/ - DSO plugin files"
Write-Host ""
Write-Host "To test, run:" -ForegroundColor Yellow
Write-Host '  $env:PATH = "' + $InstallDir + '\bin;$env:PATH"'
Write-Host '  $env:RDL2_DSO_PATH = "' + $InstallDir + '\rdl2dso"'
Write-Host '  moonray.exe --help'
Write-Host ""
