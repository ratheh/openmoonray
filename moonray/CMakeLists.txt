# Copyright 2023-2024 DreamWorks Animation LLC
# SPDX-License-Identifier: Apache-2.0

# macOS 26/clang-21 + slim-SDK build: hydra (USD render delegate) and moonray_arras (Arras
# distributed rendering) are NOT in the warp_moonray SDK contract (headless renderer + scene_rdl2
# + rdl2dso only); the standalone `moonray` binary links neither. They are mutually entangled
# (hd_moonray <-> mcrt_dataio client_receiver), and moonray_arras' telemetry hits non-suppressible
# clang-21 narrowing errors. Excluded. (Qt apps off via -DBUILD_QT_APPS=NO; moonray_gui consumes
# the same client_receiver telemetry.)
# add_subdirectory(hydra)
add_subdirectory(mcrt_denoise)
add_subdirectory(moonray)
# add_subdirectory(moonray_arras)
add_subdirectory(moonray_dcc_plugins)
add_subdirectory(moonshine)
if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/moonshine_dwa)
    add_subdirectory(moonshine_dwa)
endif()
add_subdirectory(moonshine_usd)
add_subdirectory(render_profile_viewer)
add_subdirectory(scene_rdl2)

if (${BUILD_QT_APPS})
    add_subdirectory(moonray_gui)
endif()
