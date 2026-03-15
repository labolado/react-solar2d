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

# ---- Plugin shared library ----
add_library(plugin_yoga SHARED
    src/plugin_yoga.c
    src/yoga_node_style.c
    src/yoga_node_layout.c
    src/yoga_enums.c
)
target_include_directories(plugin_yoga PRIVATE
    include
    ${CORONA_INCLUDE}/Corona
    ${CORONA_INCLUDE}/lua
    ${YOGA_SRC_DIR}
)
target_link_libraries(plugin_yoga PRIVATE yogacore)

# macOS: produce .so (Lua convention, not .dylib)
if(APPLE)
    set_target_properties(plugin_yoga PROPERTIES
        PREFIX ""
        SUFFIX ".so"
        OUTPUT_NAME "plugin_yoga"
    )
endif()
