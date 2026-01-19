# OpenMoonRay Third-Party Dependencies

This document lists all third-party dependencies of the OpenMoonRay project and their licenses. This is intended to help with license compliance for commercial use.

## License Summary

| License Type    | Commercial Use | Copyleft          | Notes                                            |
|-----------------|----------------|-------------------|--------------------------------------------------|
| Apache 2.0      | Yes            | No                | Permissive, patent grant                         |
| BSD 2-Clause    | Yes            | No                | Permissive                                       |
| BSD 3-Clause    | Yes            | No                | Permissive                                       |
| MIT             | Yes            | No                | Permissive                                       |
| Boost (BSL-1.0) | Yes            | No                | Permissive                                       |
| zlib            | Yes            | No                | Permissive                                       |
| Public Domain   | Yes            | No                | No restrictions                                  |
| LGPL 2.1/3.0    | Yes*           | Weak              | Dynamic linking OK, modifications must be shared |
| MPL 2.0         | Yes*           | Weak (file-level) | File-level copyleft only                         |
| Proprietary     | Varies         | N/A               | Check specific terms                             |

---

## OpenMoonRay Core License

**License:** Apache 2.0
**Commercial Use:** Yes
**Copyleft:** No

MoonRay itself is licensed under Apache 2.0, which is permissive and allows commercial use, modification, and distribution without requiring you to open-source your own code.

---

## External Runtime Dependencies

These libraries are linked at build time and required at runtime.

### Core Rendering Libraries

| Library              | License             | Commercial OK | Copyleft | Notes                                         |
|----------------------|---------------------|---------------|----------|-----------------------------------------------|
| **Embree** (Intel)   | Apache 2.0          | Yes           | No       | Ray tracing kernels                           |
| **OpenEXR**          | BSD 3-Clause        | Yes           | No       | HDR image format                              |
| **Imath**            | BSD 3-Clause        | Yes           | No       | Math library (from OpenEXR)                   |
| **OpenImageIO**      | BSD 3-Clause        | Yes           | No       | Image I/O library                             |
| **OpenVDB**          | MPL 2.0             | Yes           | Weak*    | Sparse volume data. *File-level copyleft only |
| **OpenSubdiv**       | Modified Apache 2.0 | Yes           | No       | Subdivision surfaces                          |
| **OpenImageDenoise** | Apache 2.0          | Yes           | No       | AI denoising (Intel)                          |
| **Random123**        | BSD 3-Clause        | Yes           | No       | Random number generation                      |

### Parallel Computing

| Library                             | License      | Commercial OK | Copyleft | Notes                   |
|-------------------------------------|--------------|---------------|----------|-------------------------|
| **TBB** (Threading Building Blocks) | Apache 2.0   | Yes           | No       | Intel threading library |
| **ISPC** (compiler)                 | BSD 3-Clause | Yes           | No       | SIMD compiler           |

### GPU Acceleration (Optional)

| Library          | License              | Commercial OK | Copyleft | Notes                                    |
|------------------|----------------------|---------------|----------|------------------------------------------|
| **CUDA Toolkit** | Proprietary (NVIDIA) | Yes*          | No       | *Free to redistribute runtime            |
| **OptiX**        | Proprietary (NVIDIA) | Yes*          | No       | *Free to use, redistribution terms apply |

### System/Utility Libraries

| Library          | License                                     | Commercial OK | Copyleft | Notes                  |
|------------------|---------------------------------------------|---------------|----------|------------------------|
| **Boost**        | BSL-1.0                                     | Yes           | No       | C++ utility libraries  |
| **Python**       | PSF License                                 | Yes           | No       | Scripting              |
| **Lua**          | MIT                                         | Yes           | No       | Scripting              |
| **zlib**         | zlib License                                | Yes           | No       | Compression            |
| **OpenSSL**      | Apache 2.0 (3.0+) / OpenSSL License (older) | Yes           | No       | Cryptography           |
| **curl/libcurl** | curl License (MIT-style)                    | Yes           | No       | HTTP client            |
| **JsonCpp**      | MIT                                         | Yes           | No       | JSON parsing           |
| **Log4cplus**    | Apache 2.0 / BSD                            | Yes           | No       | Logging                |
| **libuuid**      | BSD                                         | Yes           | No       | UUID generation (Unix) |
| **libunwind**    | MIT                                         | Yes           | No       | Stack unwinding        |

### Image Format Libraries

| Library                         | License                                | Commercial OK | Copyleft | Notes                         |
|---------------------------------|----------------------------------------|---------------|----------|-------------------------------|
| **libjpeg** / **libjpeg-turbo** | IJG License / BSD-style                | Yes           | No       | JPEG codec                    |
| **libgif**                      | MIT                                    | Yes           | No       | GIF codec                     |
| **FreeType**                    | FreeType License (BSD-like) OR GPL 2.0 | Yes           | No       | Use FTL option for commercial |

### USD Integration (Optional)

| Library         | License             | Commercial OK | Copyleft | Notes                       |
|-----------------|---------------------|---------------|----------|-----------------------------|
| **USD** (Pixar) | Modified Apache 2.0 | Yes           | No       | Universal Scene Description |
| **Alembic**     | BSD 3-Clause        | Yes           | No       | Geometry caching            |
| **OpenColorIO** | BSD 3-Clause        | Yes           | No       | Color management            |

---

## Dependencies Requiring Attention

### LGPL Libraries (Dynamic Linking Recommended)

These libraries use LGPL which has weak copyleft provisions. **Dynamic linking** (shared libraries) avoids copyleft obligations for your own code.

| Library           | License   | Usage in MoonRay                           | Mitigation                              |
|-------------------|-----------|--------------------------------------------|-----------------------------------------|
| **libmicrohttpd** | LGPL 2.1+ | Arras networking                           | Dynamic link; or replace if needed      |
| **Qt5**           | LGPL 3.0  | GUI tools only (moonray_gui, arras_render) | Not required for headless/CLI rendering |

**For your use case (CLI tool, not directly linking):** Since you plan to use MoonRay via a command-line tool rather than linking directly, and keep the MoonRay fork open-source, the LGPL libraries should not cause issues. LGPL allows you to use LGPL libraries in proprietary software as long as:
1. You dynamically link (not statically link)
2. Users can replace the LGPL library with their own version
3. You provide the LGPL source code (or link to it)

### CppUnit (Testing Only)

| Library     | License | Notes                                                          |
|-------------|---------|----------------------------------------------------------------|
| **CppUnit** | LGPL    | **Test dependency only** - not included in production binaries |

### MPL 2.0 (OpenVDB)

OpenVDB uses MPL 2.0 which has **file-level copyleft**:
- You can use it in proprietary software
- If you modify OpenVDB source files, those specific modified files must be shared under MPL 2.0
- Your own code remains yours

### Intel MKL (Optional)

| Library       | License                           | Notes                                                   |
|---------------|-----------------------------------|---------------------------------------------------------|
| **Intel MKL** | Intel Simplified Software License | Free to use and redistribute; check current Intel terms |

---

## Bundled/Vendored Code (Included in MoonRay Source)

These are incorporated directly into MoonRay and covered in THIRD-PARTY.md:

| Library                                      | License       | Usage                    |
|----------------------------------------------|---------------|--------------------------|
| stb_image, stb_image_resize, stb_image_write | Public Domain | Image I/O                |
| Simplex Noise (Stefan Gustavson)             | Public Domain | Noise generation         | 
| pugixml                                      | MIT           | XML parsing              |
| RapidJSON                                    | MIT           | JSON parsing             | 
| LZ4                                          | BSD 2-Clause  | Compression              | 
| double-conversion                            | BSD 3-Clause  | Number formatting        |
| CLI11                                        | BSD 3-Clause  | Command-line parsing     |
| Vulkan Memory Allocator                      | MIT           | GPU memory management    |
| SPIRV-Reflect                                | Apache 2.0    | Shader reflection        |
| robin-map (Tessil)                           | MIT           | Hash map                 |
| surfgrad-bump                                | MIT           | Bump mapping             |
| pbrt v3 (portions)                           | BSD 2-Clause  | Random numbers, sampling |
| OpenShadingLanguage (LPE)                    | BSD 3-Clause  | Light path expressions   |
| OpenImageIO (portions)                       | BSD 3-Clause  | Texture filtering code   |
| pygilstate_check                             | MIT           | Python GIL handling      |

---

## Commercial Use Assessment

### For Your Use Case (CLI Tool, Closed-Source Wrapper)

Based on your description:
- MoonRay binaries built from open-source fork
- Used via command-line tool (separate process)
- Not directly linked into your proprietary code
- Your wrapper/host application remains closed-source

**Assessment: COMPATIBLE**

This usage pattern is compatible with all the licenses involved because:

1. **Apache 2.0 (MoonRay core):** Allows commercial use, no copyleft
2. **BSD/MIT (most dependencies):** Permissive, no copyleft
3. **LGPL (libmicrohttpd, Qt):**
   - Dynamic linking is fine
   - Your code is in a separate process, not linked
   - Qt is only used for optional GUI tools
4. **MPL 2.0 (OpenVDB):** File-level copyleft only; doesn't affect your code
5. **Proprietary (NVIDIA CUDA/OptiX):** Allows redistribution of runtime

### Requirements for Compliance

1. **Include license notices** - Ship a copy of this document or similar with your distribution
2. **Provide attribution** - Include copyright notices for all libraries
3. **Dynamic linking** - Ensure LGPL libraries are dynamically linked (default on most systems)
4. **Keep fork public** - As you stated, your MoonRay fork remains open-source
5. **Don't modify OpenVDB** - Or share those specific file changes if you do

---

## GPL v3 Libraries: NONE FOUND

**Good news:** After comprehensive analysis, MoonRay does not appear to depend on any GPL v3 licensed libraries. All dependencies are either:
- Permissive (Apache, BSD, MIT, BSL, Public Domain)
- Weak copyleft (LGPL, MPL) - compatible with your use case
- Proprietary with redistribution rights (NVIDIA)

---

## Dependency Source References

### vcpkg.json (Arras Core)
```json
{
  "dependencies": [
    "boost-system",
    "boost-chrono",
    "boost-date-time",
    "boost-filesystem",
    "boost-program-options",
    "curl",
    "libmicrohttpd",
    "jsoncpp",
    "openssl",
    "cppunit"
  ]
}
```

### CMake Dependencies (from CMakeLists.txt files)
- Embree (4.2+)
- OpenEXR
- OpenImageIO
- OpenVDB
- OpenSubdiv
- OpenImageDenoise
- TBB
- ISPC
- Python
- Lua
- Boost (Python component)
- JPEG
- ZLIB
- Random123
- Log4cplus
- CUDA/OptiX (optional)
- USD (optional)
- Qt5 (optional, GUI only)
- OpenGL (optional, GUI only)
- OpenColorIO (optional)
- Alembic (optional)

---

## Recommended Actions

1. **Review NVIDIA license terms** if using CUDA/OptiX for GPU acceleration
2. **Verify libmicrohttpd linking** - ensure dynamic linking in your builds
3. **Skip Qt5/GUI builds** if you only need command-line rendering
4. **Include attribution file** with your distribution listing all third-party licenses
5. **Consult legal counsel** for final verification of compliance for your specific use case

---

## Disclaimer

This document is for informational purposes only and does not constitute legal advice. License terms may change, and interpretations may vary. For commercial use, consult with a qualified attorney to ensure full compliance with all applicable licenses.

---

*Last updated: 2026-01-19*
*Generated for OpenMoonRay Windows Build Project*
