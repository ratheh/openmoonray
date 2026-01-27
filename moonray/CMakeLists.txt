# Copyright 2023-2024 DreamWorks Animation LLC
# SPDX-License-Identifier: Apache-2.0

# Options for optional components
option(BUILD_HYDRA "Build Hydra plugin (requires USD/pxr)" OFF)
option(BUILD_MOONSHINE_USD "Build moonshine_usd (requires USD/pxr)" OFF)
option(BUILD_ARRAS "Build Arras distributed rendering support" OFF)
option(BUILD_DENOISE "Build denoiser (requires OpenImageDenoise)" OFF)
option(BUILD_DCC_PLUGINS "Build DCC plugins (Houdini)" OFF)

if(BUILD_HYDRA)
    add_subdirectory(hydra)
endif()

if(BUILD_DENOISE)
    add_subdirectory(mcrt_denoise)
endif()

add_subdirectory(moonray)

if(BUILD_ARRAS)
    add_subdirectory(moonray_arras)
endif()

if(BUILD_DCC_PLUGINS)
    add_subdirectory(moonray_dcc_plugins)
endif()
add_subdirectory(moonshine)

if(BUILD_MOONSHINE_USD)
    add_subdirectory(moonshine_usd)
endif()

add_subdirectory(render_profile_viewer)
add_subdirectory(scene_rdl2)

if (${BUILD_QT_APPS})
    add_subdirectory(moonray_gui)
endif()
