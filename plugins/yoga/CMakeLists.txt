cmake_minimum_required(VERSION 3.16)
project(plugin_yoga C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

# ---- Yoga static library ----
set(YOGA_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/yoga)
file(GLOB_RECURSE YOGA_SOURCES
    ${YOGA_SRC_DIR}/yoga/*.cpp
)
add_library(yogacore STATIC ${YOGA_SOURCES})
target_include_directories(yogacore PUBLIC ${YOGA_SRC_DIR})
target_compile_features(yogacore PRIVATE cxx_std_20)

# ---- Solar2D headers ----
set(CORONA_NATIVE "/Applications/Corona/Native")
set(CORONA_INCLUDE "${CORONA_NATIVE}/Corona/shared/include")

# ---- Find Lua for standalone testing ----
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(LUA luajit lua5.1 lua-5.1 lua51 lua)
endif()
if(NOT LUA_FOUND)
    # Try LuaJIT first (Lua 5.1 compatible), then plain Lua
    find_library(LUA_LIBRARIES NAMES luajit-5.1 luajit lua5.1 lua
        PATHS /opt/homebrew/lib /usr/local/lib)
    find_path(LUA_INCLUDE_DIRS lua.h
        PATHS /opt/homebrew/include /usr/local/include
        PATH_SUFFIXES luajit-2.1 lua5.1 lua)
endif()

# ---- Plugin shared library ----
add_library(plugin_yoga SHARED
    src/plugin_yoga.c
    src/yoga_node_style.c
    src/yoga_node_layout.c
    src/yoga_enums.c
)

# Prefer standalone Lua headers if found; fall back to Corona headers
if(LUA_INCLUDE_DIRS)
    target_include_directories(plugin_yoga PRIVATE
        include
        ${LUA_INCLUDE_DIRS}
        ${YOGA_SRC_DIR}
    )
else()
    target_include_directories(plugin_yoga PRIVATE
        include
        ${CORONA_INCLUDE}/Corona
        ${CORONA_INCLUDE}/lua
        ${YOGA_SRC_DIR}
    )
endif()

set_target_properties(plugin_yoga PROPERTIES LINKER_LANGUAGE CXX)

option(SOLAR2D_PLUGIN "Build for Solar2D Simulator (no Lua linkage, .dylib)" OFF)

if(SOLAR2D_PLUGIN)
    # Solar2D mode: Lua symbols provided by host at runtime
    target_link_libraries(plugin_yoga PRIVATE yogacore)
    if(APPLE)
        set_target_properties(plugin_yoga PROPERTIES
            PREFIX ""
            SUFFIX ".dylib"
            OUTPUT_NAME "plugin_yoga"
            # Allow undefined Lua symbols — resolved by Corona Simulator at load time
            LINK_FLAGS "-undefined dynamic_lookup"
        )
    endif()
else()
    # Standalone mode: link LuaJIT for testing outside Solar2D
    target_link_libraries(plugin_yoga PRIVATE yogacore ${LUA_LIBRARIES})
    if(APPLE)
        set_target_properties(plugin_yoga PROPERTIES
            PREFIX ""
            SUFFIX ".so"
            OUTPUT_NAME "plugin_yoga"
        )
    endif()
endif()
