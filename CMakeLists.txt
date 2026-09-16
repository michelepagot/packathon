cmake_minimum_required(VERSION 3.16)
project(Packathon VERSION 0.1.0 LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

include(GNUInstallDirs)

# -----------------------------------------------------------------------------
# Build Options (Flexible Build Matrix for Classroom & Packaging Workflows)
# -----------------------------------------------------------------------------
set(RAYLIB_MODE "FETCH" CACHE STRING "Where to get raylib: FETCH (download from GitHub), SYSTEM (use OS-installed package), or LOCAL (use pre-staged source directory)")
set_property(CACHE RAYLIB_MODE PROPERTY STRINGS "FETCH" "SYSTEM" "LOCAL")

option(RAYLIB_SHARED "Build/link raylib dynamically as a shared library" OFF)
option(ENABLE_CPACK "Enable CPack packaging configuration" ON)

# Disable raylib examples and games when building from source
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)

if(RAYLIB_SHARED)
    set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
else()
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
endif()

# Raylib dependency acquisition
if(RAYLIB_MODE STREQUAL "SYSTEM")
    message(STATUS "Searching for system-installed raylib (RAYLIB_MODE=SYSTEM)...")
    find_package(raylib REQUIRED)
elseif(RAYLIB_MODE STREQUAL "LOCAL")
    message(STATUS "Using local pre-staged raylib source (RAYLIB_MODE=LOCAL)...")
    if(EXISTS "${CMAKE_BINARY_DIR}/_deps/raylib-src/CMakeLists.txt")
        add_subdirectory("${CMAKE_BINARY_DIR}/_deps/raylib-src" "${CMAKE_BINARY_DIR}/_deps/raylib-build" EXCLUDE_FROM_ALL)
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/build/_deps/raylib-src/CMakeLists.txt")
        add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/build/_deps/raylib-src" "${CMAKE_BINARY_DIR}/_deps/raylib-build" EXCLUDE_FROM_ALL)
    else()
        message(FATAL_ERROR "RAYLIB_MODE is set to LOCAL, but no raylib source found in ${CMAKE_BINARY_DIR}/_deps/raylib-src or ${CMAKE_CURRENT_SOURCE_DIR}/build/_deps/raylib-src. "
                            "Please extract raylib source there before building.")
    endif()
elseif(RAYLIB_MODE STREQUAL "FETCH")
    include(FetchContent)
    message(STATUS "Fetching raylib from GitHub via FetchContent (v5.5)...")
    FetchContent_Declare(
        raylib
        GIT_REPOSITORY https://github.com/raysan5/raylib.git
        GIT_TAG 5.5
        GIT_SHALLOW TRUE
    )
    FetchContent_GetProperties(raylib)
    if(NOT raylib_POPULATED)
        FetchContent_Populate(raylib)
        add_subdirectory(${raylib_SOURCE_DIR} ${raylib_BINARY_DIR} EXCLUDE_FROM_ALL)
    endif()
else()
    message(FATAL_ERROR "Unknown RAYLIB_MODE='${RAYLIB_MODE}'. Valid choices are: FETCH, SYSTEM, LOCAL.")
endif()

# Application target: ocio
add_executable(ocio
    src/main.c
)

target_include_directories(ocio PRIVATE src)
target_link_libraries(ocio PRIVATE raylib)
target_compile_definitions(ocio PRIVATE APP_VERSION="${PROJECT_VERSION}")

# Platform-specific link libraries if needed
if(UNIX AND NOT APPLE)
    target_link_libraries(ocio PRIVATE m)
endif()

# Place binary in bin/ directory for local builds
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set_target_properties(ocio PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    OUTPUT_NAME "ocio"
)


# -----------------------------------------------------------------------------
# Installation Rules (Standard GNU Layout)
# -----------------------------------------------------------------------------
install(TARGETS ocio
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    BUNDLE DESTINATION .
)

# Install Linux Desktop Integration files
if(UNIX AND NOT APPLE)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/ocio.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications"
    )
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icons/ocio.png"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps"
    )
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icons/ocio.svg"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps"
    )
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/packaging/org.packathon.ocio.metainfo.xml"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/metainfo"
    )
endif()

# -----------------------------------------------------------------------------
# CPack Packaging Configuration (Produces .deb, .rpm, tar.gz, zip named 'ocio')
# -----------------------------------------------------------------------------
if(ENABLE_CPACK)
    set(CPACK_PACKAGE_NAME "ocio")
    set(CPACK_PACKAGE_VENDOR "Packathon Project")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Ocio - Raylib eye tracking application from the Packathon packaging project")
    set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
    set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
    set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
    set(CPACK_PACKAGE_CONTACT "Packathon Maintainers <maintainers@packathon.org>")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")

    # Generator selection based on platform
    if(WIN32)
        set(CPACK_GENERATOR "ZIP")
    elseif(APPLE)
        set(CPACK_GENERATOR "TGZ;DragNDrop")
    else()
        set(CPACK_GENERATOR "TGZ;DEB;RPM")
    endif()

    # Debian (.deb) specific settings
    set(CPACK_DEBIAN_PACKAGE_NAME "ocio")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_CONTACT}")
    set(CPACK_DEBIAN_PACKAGE_SECTION "graphics")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
    if(NOT CPACK_DEBIAN_PACKAGE_ARCHITECTURE)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64")
            set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
        elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
            set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "arm64")
        endif()
    endif()
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6 (>= 2.17), libgl1, libx11-6")
    set(CPACK_DEBIAN_FILE_NAME "${CPACK_PACKAGE_NAME}_${PROJECT_VERSION}_${CPACK_DEBIAN_PACKAGE_ARCHITECTURE}.deb")

    # RPM (.rpm) specific settings
    set(CPACK_RPM_PACKAGE_NAME "ocio")
    set(CPACK_RPM_PACKAGE_LICENSE "MIT")
    set(CPACK_RPM_PACKAGE_GROUP "Amusements/Graphics")
    set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
    set(CPACK_RPM_FILE_NAME "${CPACK_PACKAGE_NAME}-${PROJECT_VERSION}-1.${CMAKE_SYSTEM_PROCESSOR}.rpm")

    # Archive (.tar.gz / .zip) naming
    set(CPACK_ARCHIVE_FILE_NAME "${CPACK_PACKAGE_NAME}-${PROJECT_VERSION}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")

    include(CPack)
endif()

