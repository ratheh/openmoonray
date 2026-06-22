# Building & Publishing the macOS Moonray SDK (Apple Silicon)

How to build MoonRay on Apple-Silicon macOS from the `ratheh/openmoonray` `cmake_mnraker`
(v1.7-era) fork and package the **slim, relocatable SDK** consumed by Gemell's `warp_moonray`,
mirroring the existing Windows 1.7 release. **This build was completed on macOS 26.1 (Tahoe),
Xcode 26.5, Apple clang 21, CMake 3.26.5.** That toolchain is newer than what the fork was written
for, so a series of port patches are required (documented below); they are all macOS-26/clang-21
artifacts. Intended repo location: `building/macOS/BUILDING_MACOS.md`.

## 1. Output contract (pinned by Gemell `FindMoonRay.cmake` — keep stable)
```
Release (ratheh/openmoonray):  tag macOS-Build-1.7   asset moonray-macos-arm64-1.7.0.0-macos-1.zip
Extracted tree (relocatable; install names @rpath / @loader_path):
  bin/        moonray (headless, no .exe)
  lib/        libscene_rdl2.dylib, librender_logging.dylib + full transitive dylib closure (75 dylibs)
  include/    scene_rdl2/** (incl. common/arm/*) + boost / tbb / log4cplus
  rdl2dso/    shader DSOs (162 *.so)
  (no moonray_gui, no USD/hydra, no Arras, no Houdini/DCC, no Python bindings, no denoiser)
```

## 2. Prerequisites (Xcode 26.5 / macOS 26)
- Apple-Silicon mac. `git lfs install` BEFORE cloning.
- CMake 3.26.5 (doc-pinned; used here at `/Applications/MoonRay/cmake-3.26.5-macos-universal`).
- **Metal toolchain (REQUIRED on Tahoe, separate download):** `xcrun -sdk macosx metal --version`;
  if it errors, `xcodebuild -downloadComponent MetalToolchain` (~688 MB). The project compiles
  Metal-language targets via the Xcode generator, so this is a hard prerequisite.

## 3. Get the source — submodule-org fix
`.gitmodules` uses relative URLs resolving to `ratheh/<name>`, but `ratheh` only forked 4 submodules
(`scene_rdl2`, `moonray`, `moonshine`, `cmake_modules`); the other 15 live under `mnraker`. A plain
`git clone --recurse-submodules` fails (`could not read Username`). Fix: clone top-level, then repoint
the 15 missing submodules to `mnraker` and `git submodule update --init --recursive`. (Full loop in
the prior revision of this doc / the PRP.) Then the canonical symlinks:
`cd /Applications/MoonRay && ln -sf source/openmoonray/building . && ln -sf source/openmoonray openmoonray`.
**The `openmoonray` symlink is load-bearing** — configure from it so the preset's `${sourceParentDir}`
resolves `installs`/`build` under `/Applications/MoonRay`.

## 4. Build dependencies (Boost→USD), built once under clang; kept
The dependency stack builds into `/Applications/MoonRay/installs` (Boost 1.78, classic TBB 2020U2 +
oneTBB 12 for OIDN, OpenEXR, OpenVDB, embree, OpenImageIO, OpenColorIO, log4cplus 2.0.3, Qt5, USD…).
Toolchain port flags (set before configure; needed because Apple clang defaults pre-C++11 and libc++
dropped C++17-removed features):
```bash
export CXXFLAGS="-std=c++17 -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION -D_LIBCPP_ENABLE_CXX17_REMOVED_FEATURES -Wno-enum-constexpr-conversion"
```
- `building/macOS/user-config.jam`: add the same `-std=c++17` + libc++ macros + `-Wno-enum-constexpr-conversion` to Boost's clang line.
- `building/macOS/CMakeLists.txt`: add `-sNO_ZSTD=1 -sNO_LZMA=1` to the Boost `b2` command (no system libzstd/lzma).
- Configure with `-DBOOST_ARCH=arm64`. USD step needs Xcode's Python 3.9 framework (present in Xcode 26.5).
- **A dep ABI smoke test confirmed the clang-16-built deps link & run under clang 21** (no dep rebuild needed):
  compile a tiny TU using `log4cplus::Initializer` + `tbb::parallel_for` against `installs/{include,lib}`.

## 5. macOS-26 / clang-21 SOURCE PORT PATCHES (the MoonRay build)
Apply these (all clang-21/SDK-26 artifacts; none affect render math), then build with CMake 3.26.5,
the Xcode generator, and the CXXFLAGS above. The build installs to `installs/openmoonray`.

| # | File / action | Why |
|---|---|---|
| A | **Backport `AlignedElementArray.h`** (`scene_rdl2/lib/common/mcrt_util/`): replace the `#if _POSIX_C_SOURCE…/#elif _MSC_VER/#endif` guard with upstream's **unconditional** `posix_memalign` impl (drop `_MSC_VER` — macOS-only tree). | Apple clang doesn't auto-define `_POSIX_C_SOURCE`; both branches skipped → `doAllocate/doFree` undeclared. Matches `OpenMoonRay/moonray` main. |
| B | **POSIX-guard `\|\| defined(__APPLE__)`** in `scene_rdl2/lib/common/platform/Platform.h` and `scene_rdl2/lib/common/fb_util/SnapshotDeltaTestUtil.cc` (same `posix_memalign` guard pattern). | Same root cause as A, in core `alignedMalloc` + a test util. |
| C | **Append a NEON `_mm_cmp_ps` shim + `_CMP_*` predicate macros** to `scene_rdl2/lib/common/arm/sse2neon.h` (the bundled copy is trimmed; `immintrin_emu.h` uses x86 asm). | `ssef.h`'s atan emulator uses AVX `_mm_cmp_ps`+`_CMP_GT/EQ/LT_OQ`, undefined on arm64. Map onto the basic SSE compares sse2neon provides. |
| D | **Give boost numeric mixture enums a fixed underlying type** — add `: int` to `enum {int_float,sign,udt_builtin}_mixture_enum` in `installs/include/boost/numeric/conversion/*_mixture_enum.hpp`. | Boost 1.78 MPL forms `integral_c<enum, value-1>` = `(enum)-1`, out of the enum's value range → **non-suppressible** clang-21 "not a constant expression" hard error in core code (OpenVdbSampler, numeric_cast). `: int` makes any int a valid enum constant. **One header fix clears the whole class.** |
| E | **Stale SDK paths in dep configs** — `sed -i '' 's#MacOSX15.2.sdk#MacOSX.sdk#g'` across `installs/cmake/pxrTargets.cmake`, `installs/lib/cmake/OpenSubdiv/*.cmake`, Qt `.prl`/`.pri` (11 files). | USD/Qt/OpenSubdiv were configured under the now-deleted 15.2 SDK and hardcoded `MacOSX15.2.sdk/usr/lib/libm.tbd` into exported targets → "no such file" at link. The version-agnostic `MacOSX.sdk` symlink won't go stale. |
| F | **Fix narrowing in `TelemetryLayoutPanel.cc`** (`static_cast<int>` on the unsigned `Vec2i{}` args) — superseded by G (excluded). | clang-21 `-Wc++11-narrowing-const-reference` is a hard error; unsigned→int in a brace-init. |
| G | **Exclude non-contract subsystems** (slim SDK = headless renderer): in `moonray/moonray/CMakeLists.txt` comment `add_subdirectory(hydra)` + `add_subdirectory(moonray_arras)`; in `scene_rdl2/CMakeLists.txt` comment `add_subdirectory(mod)` (Python bindings); configure with `-DBUILD_QT_APPS=NO`. | hydra (USD delegate), moonray_arras (Arras distributed + telemetry narrowing), Python bindings (boost::python→numeric_cast, pre-fix-D), moonray_gui (Qt) are NOT in the contract and the headless `moonray` links none of them. Keeps mcrt_denoise, moonray core, moonshine, scene_rdl2. |

Configure + build (run as ONE shell invocation; harness shell is zsh — avoid `${PIPESTATUS}` bashisms):
```bash
CM265=/Applications/MoonRay/cmake-3.26.5-macos-universal/CMake.app/Contents/bin/cmake
export CXXFLAGS="-std=c++17 -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION -D_LIBCPP_ENABLE_CXX17_REMOVED_FEATURES -Wno-enum-constexpr-conversion"
rm -rf /Applications/MoonRay/build
set -o pipefail
cd /Applications/MoonRay/openmoonray && $CM265 --preset macos-release -DBUILD_QT_APPS=NO 2>&1 | tee /tmp/cfg.log || { echo FATAL; exit 1; }
$CM265 --build --preset macos-release        # Xcode generator, install target; ~30-60 min
```
**U0 gate:**
```bash
test -x /Applications/MoonRay/installs/openmoonray/bin/moonray || exit 1
RDL2_DSO_PATH=/Applications/MoonRay/installs/openmoonray/rdl2dso \
  /Applications/MoonRay/installs/openmoonray/bin/moonray \
  -in /Applications/MoonRay/openmoonray/testdata/rectangle.rdla -out /tmp/u0.exr && test -s /tmp/u0.exr
```

## 6. Prove scene_rdl2 links under the Warp (clang) toolchain — U1 spike
See `spike.cpp`. **Two include roots** (MoonRay vs deps) and the **arm headers must be present**:
```bash
SDK=/Applications/MoonRay/installs/openmoonray; DEPS=/Applications/MoonRay/installs
# scene_rdl2's CMake does NOT install common/arm/*.h, but Math.h needs them on arm64 — copy them in:
mkdir -p "$SDK/include/scene_rdl2/common/arm"
cp -p $SDK/../../source/openmoonray/moonray/scene_rdl2/lib/common/arm/*.h "$SDK/include/scene_rdl2/common/arm/"
clang++ -std=c++17 -D_USE_MATH_DEFINES $CXXFLAGS \
  -I"$SDK/include" -I"$DEPS/include" -L"$SDK/lib" -lscene_rdl2 -lrender_logging \
  -Wl,-rpath,"$SDK/lib" spike.cpp -o spike && ./spike   # -> "scene_rdl2 spike OK: ..."
```

## 7. Package the slim, relocatable SDK — U2
The MoonRay build installs to `installs/openmoonray` while deps are in `installs` (two trees, all
@rpath-linked). `package_macos_sdk.sh` BFS-resolves the dylib closure across both lib dirs, rewrites
any absolute dep (the autotools deps openssl/curl/log4cplus bake absolute install-names) to `@rpath`,
adds `LC_RPATH @loader_path[/../lib]`, copies headers (incl. `common/arm`), and ad-hoc re-signs:
```bash
bash /Applications/MoonRay/package_macos_sdk.sh \
  /Applications/MoonRay/installs/openmoonray /Applications/MoonRay/installs \
  /Applications/MoonRay/pkg 1.7.0.0-macos-1
```
**Relocation checklist** (move the tree, then): no dependency line under `lib/`+`bin/`+`rdl2dso/` may
start with `/` other than `/usr/lib`|`/System`; `bin/moonray` deps via `@rpath` + an `LC_RPATH` of
`@loader_path/../lib`; relocated render of `rectangle.rdla` with `RDL2_DSO_PATH` set produces a
non-empty EXR. (Verified: 75 lib dylibs, 162 rdl2dso, 0 leaks, relocated render OK.)

## 8. Publish — U3 (manual; needs write access to ratheh/openmoonray)
`zip -ry moonray-macos-arm64-1.7.0.0-macos-1.zip moonray-macos-arm64-1.7.0.0-macos-1` (≈220 MB),
`unzip -t` to verify, then `gh release create macOS-Build-1.7 <asset> --repo ratheh/openmoonray …`
(see `PUBLISH_RELEASE.sh`). Then re-pin `MOONRAY_VERSION`/`MOONRAY_RELEASE_TAG` in the consumer's
`FindMoonRay.cmake` (companion PRP) and confirm it matches `bin/moonray` (no `.exe`) + the macOS asset.

## 9. Notes for re-build / version bump
Bump tag/asset/version together (`macOS-Build-<MAJ.MIN>`, `moonray-macos-arm64-<ver>.zip`). All §5
patches live in the source tree / dep installs; a clean dep rebuild re-introduces E (stale SDK paths)
and the arm-header gap (§6) — re-apply. The proper long-term fix is the upstream 3.6 sync
(see `PRPs/moonray-sdk-3.6-sync-plan.md`), where most of these are unnecessary.
