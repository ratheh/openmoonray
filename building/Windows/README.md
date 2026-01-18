# Building OpenMoonRay on Windows

This guide explains how to build OpenMoonRay from source on Windows.

## Prerequisites

### Required Software

| Software | Version | Notes |
|----------|---------|-------|
| Visual Studio 2022 | Community+ | "Desktop development with C++" workload |
| CMake | 3.23+ | |
| ISPC | 1.26+ | Download from [GitHub](https://github.com/ispc/ispc/releases) |
| vcpkg | Latest | Package manager for dependencies |
| Git | Latest | With LFS support |
| Python | 3.11 | For Boost.Python bindings |

### Environment Variables

Set these environment variables before building:

| Variable | Description | Example |
|----------|-------------|---------|
| `VCPKG_ROOT` | vcpkg installation directory | `C:\Tools\vcpkg` |
| `ISPC_HOME` | ISPC compiler directory (optional if in PATH) | `C:\Tools\ispc` |

### vcpkg Dependencies

Install vcpkg (no spaces in path), set `VCPKG_ROOT`, then install:

```powershell
vcpkg install tbb:x64-windows
vcpkg install openvdb:x64-windows
vcpkg install "log4cplus[unicode]:x64-windows"
vcpkg install jsoncpp:x64-windows
vcpkg install "lua[tools]:x64-windows"
vcpkg install openimageio:x64-windows
vcpkg install curl:x64-windows
vcpkg install opencolorio:x64-windows
vcpkg install opensubdiv:x64-windows
vcpkg install cppunit:x64-windows
vcpkg install embree:x64-windows
vcpkg install random123:x64-windows
```

### ISPC Setup

1. Download ISPC v1.26.0+ for Windows
2. Extract to a directory of your choice
3. Either set `ISPC_HOME` environment variable to that directory, or add the `bin` subdirectory to your PATH
4. Verify: `ispc.exe --version`

## Quick Start

```powershell
# Clone the repository (choose your own location)
git clone --recurse-submodules https://github.com/mnraker/openmoonray.git openmoonray
cd openmoonray

# IMPORTANT: Switch submodules to windows branches
cd moonray/scene_rdl2 && git checkout windows && cd ../..
cd moonray/moonshine && git checkout windows && cd ../..
cd moonray/moonray && git checkout windows && cd ../..

# Create Windows junctions (required - Git symlinks don't work on Windows)
cd moonray/moonray
cmd /c "mklink /J moonray lib"
cd include
cmd /c "mklink /J moonray ..\lib"
cd ../../moonshine/include
cmd /c "mklink /J moonshine ..\lib"

# Build (from repo root)
cd ../../../building/Windows
.\build_all.ps1
```

## Build Script

The `build_all.ps1` script handles the complete build process:

```powershell
# Basic build
.\build_all.ps1

# Clean build
.\build_all.ps1 -Clean
```

The script builds in order:
1. scene_rdl2 - Core rendering library
2. moonshine - Shader library
3. moonray - Main renderer

## Testing the Build

After building, test from the workspace root (parent of openmoonray):

```powershell
# Set up environment (paths relative to workspace root)
$env:PATH = ".\install\bin;$env:VCPKG_ROOT\installed\x64-windows\bin;$env:PATH"
$env:RDL2_DSO_PATH = ".\install\rdl2dso"

# Test basic functionality
moonray.exe --help

# Test DSO loading
rdl2_json_exporter.exe --dso_path $env:RDL2_DSO_PATH
```

## Known Issues

### OpenVDB/log4cplus Incompatibility
VDB-related DSOs (VdbGeometry.so, OpenVdbMap.so) don't build due to vcpkg OpenVDB using deprecated C++17 features. Volume rendering is unavailable.

### Path Separator
Windows uses semicolon (`;`) not colon (`:`) for RDL2_DSO_PATH when specifying multiple directories.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "DSO could not be found" | Check RDL2_DSO_PATH uses absolute path with drive letter |
| ISPC "Pick an application" dialog | Verify ISPC path in build script |
| Link errors with ISPC objects | Don't delete build_scene_rdl2 directory |
| Junction errors | Run as Administrator, or remove text file first |

## References

- [General Build Instructions](../general_build.md)
- [OpenMoonRay Documentation](https://docs.openmoonray.org/)
- [mnraker Windows Port](https://github.com/mnraker/openmoonray)
