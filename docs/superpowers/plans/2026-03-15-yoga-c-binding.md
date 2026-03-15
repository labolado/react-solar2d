# Yoga C Binding for Solar2D — Implementation Plan

> **Version:** 1.1 (reviewed, all issues fixed) | **Date:** 2026-03-15

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Solar2D native plugin that exposes Facebook Yoga's C API to Lua, enabling full CSS Flexbox layout in react-solar2d.

**Architecture:** Standard Solar2D plugin (`plugin.yoga`) wrapping Yoga's C API via Lua C binding. Yoga is compiled as a static library, linked into the plugin. The plugin exposes ~30 Lua functions mapping 1:1 to Yoga's C API. A thin Lua wrapper (`yoga.lua`) provides a higher-level OOP interface.

**Tech Stack:** C, Yoga C API (facebook/yoga v3.2.1), Solar2D Native SDK, CMake, Lua 5.1

**Prerequisites:**
- Solar2D Native SDK at `/Applications/Corona/Native/`
- Xcode (for macOS/iOS builds)
- CMake (for building Yoga from source)
- Yoga source: `git clone https://github.com/facebook/yoga.git`

**Key References:**
- Solar2D plugin template: `/Applications/Corona/Native/Project Template/App/`
- Corona headers: `/Applications/Corona/Native/Corona/shared/include/Corona/`
- Lua headers: `/Applications/Corona/Native/Corona/shared/include/lua/`
- Yoga C API: https://github.com/facebook/yoga/blob/main/yoga/YGNodeStyle.h
- Existing plugin example: `/Applications/Corona/Native/Project Template/App/ios/Plugin/PluginLibrary.mm`

---

## File Structure

```
react-solar2d/
├── plugins/
│   └── yoga/
│       ├── CMakeLists.txt              -- Build Yoga static lib + plugin shared lib
│       ├── src/
│       │   ├── plugin_yoga.c           -- Core binding: luaopen_plugin_yoga, node lifecycle
│       │   ├── yoga_node_style.c       -- Style setters/getters (width, height, flex, etc.)
│       │   ├── yoga_node_layout.c      -- Layout result getters (getLeft, getTop, etc.)
│       │   └── yoga_enums.c            -- Enum tables pushed to Lua
│       ├── include/
│       │   └── plugin_yoga.h           -- Shared macros, YGNode userdata helpers
│       ├── test/
│       │   ├── main.lua                -- Solar2D test scene
│       │   ├── test_yoga_basic.lua     -- Basic node creation + layout
│       │   ├── test_yoga_flex.lua      -- Flex grow/shrink/basis
│       │   ├── test_yoga_wrap.lua      -- Flex wrap + alignContent
│       │   └── test_yoga_gap.lua       -- Gap support (Yoga 3.x feature)
│       └── yoga/                       -- Git submodule: facebook/yoga
├── layout/
│   └── init.lua                        -- High-level Lua wrapper around plugin.yoga
```

---

## Chunk 1: Project Setup + Yoga Build

### Task 1.1: Create plugin directory structure and CMake build

**Files:**
- Create: `plugins/yoga/CMakeLists.txt`
- Create: `plugins/yoga/include/plugin_yoga.h`

- [ ] **Step 1: Clone Yoga as submodule**

```bash
cd /path/to/project
mkdir -p plugins/yoga/src plugins/yoga/include plugins/yoga/test
cd plugins/yoga
git submodule add https://github.com/facebook/yoga.git yoga
cd yoga && git checkout v3.2.1 && cd ..
```

> If not using git submodules, you can also just clone:
> `git clone --branch v3.2.1 --depth 1 https://github.com/facebook/yoga.git`

- [ ] **Step 2: Create CMakeLists.txt**

```cmake
# plugins/yoga/CMakeLists.txt
cmake_minimum_required(VERSION 3.16)
project(plugin_yoga C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)

# ---- Yoga static library ----
# Yoga 3.x uses C++ 20 internally but exposes a C API
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
```

- [ ] **Step 3: Create shared header**

```c
// plugins/yoga/include/plugin_yoga.h
#ifndef PLUGIN_YOGA_H
#define PLUGIN_YOGA_H

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// Metatable name for YGNodeRef userdata
#define YOGA_NODE_MT "YGNode"

// Helper: push a YGNodeRef as userdata
#include <yoga/Yoga.h>

static inline void yoga_push_node(lua_State *L, YGNodeRef node) {
    YGNodeRef *ud = (YGNodeRef *)lua_newuserdata(L, sizeof(YGNodeRef));
    *ud = node;
    luaL_getmetatable(L, YOGA_NODE_MT);
    lua_setmetatable(L, -2);
}

// Helper: check and get YGNodeRef from stack (NULL-safe after free)
static inline YGNodeRef yoga_check_node(lua_State *L, int index) {
    YGNodeRef *ud = (YGNodeRef *)luaL_checkudata(L, index, YOGA_NODE_MT);
    luaL_argcheck(L, *ud != NULL, index, "YGNode already freed");
    return *ud;
}

// Registration functions (defined in each .c file)
void yoga_register_style(lua_State *L);
void yoga_register_layout(lua_State *L);
void yoga_register_enums(lua_State *L);

#endif // PLUGIN_YOGA_H
```

- [ ] **Step 4: Verify Yoga builds**

```bash
cd /path/to/project/plugins/yoga
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --target yogacore
```

Expected: yogacore static library builds without errors.

- [ ] **Step 5: Commit**

```bash
cd /path/to/project
git add plugins/yoga/CMakeLists.txt plugins/yoga/include/plugin_yoga.h
git commit -m "feat: add Yoga C plugin project structure and CMake build"
```

---

## Chunk 2: Core Plugin — Node Lifecycle + Enums

### Task 2.1: Plugin entry point and node lifecycle

**Files:**
- Create: `plugins/yoga/src/plugin_yoga.c`

- [ ] **Step 1: Implement plugin entry point + node create/free/tree**

```c
// plugins/yoga/src/plugin_yoga.c
#include "plugin_yoga.h"
#include <yoga/Yoga.h>
#include <string.h>

// ---- Node lifecycle ----

// yoga.newNode() → YGNode userdata
static int l_node_new(lua_State *L) {
    YGNodeRef node = YGNodeNew();
    yoga_push_node(L, node);
    return 1;
}

// node:free()
static int l_node_free(lua_State *L) {
    YGNodeRef *ud = (YGNodeRef *)luaL_checkudata(L, 1, YOGA_NODE_MT);
    if (*ud) { YGNodeFree(*ud); *ud = NULL; }
    return 0;
}

// node:freeRecursive()
// WARNING: child node userdata will become dangling — only call on root
static int l_node_free_recursive(lua_State *L) {
    YGNodeRef *ud = (YGNodeRef *)luaL_checkudata(L, 1, YOGA_NODE_MT);
    if (*ud) { YGNodeFreeRecursive(*ud); *ud = NULL; }
    return 0;
}

// ---- Tree operations ----

// node:insertChild(child, index)  -- index is 0-based
static int l_node_insert_child(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    YGNodeRef child = yoga_check_node(L, 2);
    int index = (int)luaL_checkinteger(L, 3);
    YGNodeInsertChild(node, child, (uint32_t)index);
    return 0;
}

// node:removeChild(child)
static int l_node_remove_child(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    YGNodeRef child = yoga_check_node(L, 2);
    YGNodeRemoveChild(node, child);
    return 0;
}

// node:getChildCount() → number
static int l_node_get_child_count(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    lua_pushinteger(L, (int)YGNodeGetChildCount(node));
    return 1;
}

// node:getChild(index) → YGNode  -- index is 0-based
static int l_node_get_child(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    int index = (int)luaL_checkinteger(L, 2);
    YGNodeRef child = YGNodeGetChild(node, (uint32_t)index);
    if (child) {
        yoga_push_node(L, child);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// ---- Layout calculation ----

// node:calculateLayout(width, height, direction?)
// direction: "ltr" (default), "rtl", "inherit"
static int l_node_calculate_layout(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    float width = (float)luaL_optnumber(L, 2, YGUndefined);
    float height = (float)luaL_optnumber(L, 3, YGUndefined);

    YGDirection dir = YGDirectionLTR;
    if (lua_isstring(L, 4)) {
        const char *s = lua_tostring(L, 4);
        if (strcmp(s, "rtl") == 0) dir = YGDirectionRTL;
        else if (strcmp(s, "inherit") == 0) dir = YGDirectionInherit;
    }

    YGNodeCalculateLayout(node, width, height, dir);
    return 0;
}

// node:markDirty()
static int l_node_mark_dirty(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    YGNodeMarkDirty(node);
    return 0;
}

// node:isDirty() → boolean
static int l_node_is_dirty(lua_State *L) {
    YGNodeRef node = yoga_check_node(L, 1);
    lua_pushboolean(L, YGNodeIsDirty(node));
    return 1;
}

// ---- GC ----
static int l_node_gc(lua_State *L) {
    // Note: we do NOT auto-free here because nodes may be part of a tree
    // and the parent's freeRecursive handles cleanup.
    // Users must explicitly call free() or freeRecursive() on root.
    return 0;
}

// ---- Method table for YGNode metatable ----
static const luaL_Reg node_methods[] = {
    { "free", l_node_free },
    { "freeRecursive", l_node_free_recursive },
    { "insertChild", l_node_insert_child },
    { "removeChild", l_node_remove_child },
    { "getChildCount", l_node_get_child_count },
    { "getChild", l_node_get_child },
    { "calculateLayout", l_node_calculate_layout },
    { "markDirty", l_node_mark_dirty },
    { "isDirty", l_node_is_dirty },
    // Style setters/getters added by yoga_register_style()
    // Layout getters added by yoga_register_layout()
    { NULL, NULL }
};

// ---- Module functions ----
static const luaL_Reg module_funcs[] = {
    { "newNode", l_node_new },
    { NULL, NULL }
};

// ---- Entry point ----
// Lua: local yoga = require("plugin.yoga")
#if __has_include("CoronaMacros.h")
#include "CoronaMacros.h"
#else
#define CORONA_EXPORT extern
#endif

CORONA_EXPORT
int luaopen_plugin_yoga(lua_State *L) {
    // Create YGNode metatable
    luaL_newmetatable(L, YOGA_NODE_MT);

    // __index = metatable itself (methods on userdata)
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    // __gc
    lua_pushcfunction(L, l_node_gc);
    lua_setfield(L, -2, "__gc");

    // Register base node methods
    luaL_register(L, NULL, node_methods);

    // Register style setters/getters onto the metatable
    yoga_register_style(L);

    // Register layout getters onto the metatable
    yoga_register_layout(L);

    lua_pop(L, 1); // pop metatable

    // Create module table (no global pollution)
    lua_newtable(L);
    luaL_register(L, NULL, module_funcs);

    // Add enum tables
    yoga_register_enums(L);

    return 1;
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/yoga/src/plugin_yoga.c
git commit -m "feat: add Yoga plugin entry point with node lifecycle and tree operations"
```

---

### Task 2.2: Enum tables

**Files:**
- Create: `plugins/yoga/src/yoga_enums.c`

- [ ] **Step 1: Implement enum registration**

```c
// plugins/yoga/src/yoga_enums.c
#include "plugin_yoga.h"
#include <yoga/Yoga.h>

// Helper: create a table with string→int mappings and push it
static void push_enum_table(lua_State *L, const char *name,
                            const char *keys[], int values[], int count) {
    lua_newtable(L);
    for (int i = 0; i < count; i++) {
        lua_pushinteger(L, values[i]);
        lua_setfield(L, -2, keys[i]);
    }
    lua_setfield(L, -2, name);
}

void yoga_register_enums(lua_State *L) {
    // Module table is at top of stack

    // Direction
    {
        const char *k[] = { "inherit", "ltr", "rtl" };
        int v[] = { YGDirectionInherit, YGDirectionLTR, YGDirectionRTL };
        push_enum_table(L, "Direction", k, v, 3);
    }

    // FlexDirection
    {
        const char *k[] = { "column", "columnReverse", "row", "rowReverse" };
        int v[] = { YGFlexDirectionColumn, YGFlexDirectionColumnReverse,
                    YGFlexDirectionRow, YGFlexDirectionRowReverse };
        push_enum_table(L, "FlexDirection", k, v, 4);
    }

    // JustifyContent
    {
        const char *k[] = { "flexStart", "center", "flexEnd",
                            "spaceBetween", "spaceAround", "spaceEvenly" };
        int v[] = { YGJustifyFlexStart, YGJustifyCenter, YGJustifyFlexEnd,
                    YGJustifySpaceBetween, YGJustifySpaceAround, YGJustifySpaceEvenly };
        push_enum_table(L, "Justify", k, v, 6);
    }

    // AlignItems / AlignSelf / AlignContent
    {
        const char *k[] = { "auto", "flexStart", "center", "flexEnd",
                            "stretch", "baseline", "spaceBetween", "spaceAround",
                            "spaceEvenly" };
        int v[] = { YGAlignAuto, YGAlignFlexStart, YGAlignCenter, YGAlignFlexEnd,
                    YGAlignStretch, YGAlignBaseline, YGAlignSpaceBetween,
                    YGAlignSpaceAround, YGAlignSpaceEvenly };
        push_enum_table(L, "Align", k, v, 9);
    }

    // FlexWrap
    {
        const char *k[] = { "noWrap", "wrap", "wrapReverse" };
        int v[] = { YGWrapNoWrap, YGWrapWrap, YGWrapWrapReverse };
        push_enum_table(L, "Wrap", k, v, 3);
    }

    // Overflow
    {
        const char *k[] = { "visible", "hidden", "scroll" };
        int v[] = { YGOverflowVisible, YGOverflowHidden, YGOverflowScroll };
        push_enum_table(L, "Overflow", k, v, 3);
    }

    // Display
    {
        const char *k[] = { "flex", "none" };
        int v[] = { YGDisplayFlex, YGDisplayNone };
        push_enum_table(L, "Display", k, v, 2);
    }

    // PositionType
    {
        const char *k[] = { "static", "relative", "absolute" };
        int v[] = { YGPositionTypeStatic, YGPositionTypeRelative, YGPositionTypeAbsolute };
        push_enum_table(L, "PositionType", k, v, 3);
    }

    // Edge (for padding, margin, border, position)
    {
        const char *k[] = { "left", "top", "right", "bottom",
                            "start", "end", "horizontal", "vertical", "all" };
        int v[] = { YGEdgeLeft, YGEdgeTop, YGEdgeRight, YGEdgeBottom,
                    YGEdgeStart, YGEdgeEnd, YGEdgeHorizontal, YGEdgeVertical, YGEdgeAll };
        push_enum_table(L, "Edge", k, v, 9);
    }

    // Gutter (for gap)
    {
        const char *k[] = { "column", "row", "all" };
        int v[] = { YGGutterColumn, YGGutterRow, YGGutterAll };
        push_enum_table(L, "Gutter", k, v, 3);
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/yoga/src/yoga_enums.c
git commit -m "feat: add Yoga enum tables (Direction, Flex, Align, Wrap, Edge, Gutter)"
```

---

## Chunk 3: Style Setters & Layout Getters

### Task 3.1: Style setters and getters

**Files:**
- Create: `plugins/yoga/src/yoga_node_style.c`

- [ ] **Step 1: Implement all style setters/getters**

This is the largest file — wraps every `YGNodeStyleSet*` / `YGNodeStyleGet*` function.

```c
// plugins/yoga/src/yoga_node_style.c
#include "plugin_yoga.h"
#include <yoga/Yoga.h>

// ---- Simple value setters (float) ----

// node:setWidth(value)
static int l_set_width(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetWidth(n, (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setWidthPercent(value)
static int l_set_width_percent(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetWidthPercent(n, (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setWidthAuto()
static int l_set_width_auto(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetWidthAuto(n);
    return 0;
}

// node:setHeight(value)
static int l_set_height(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetHeight(n, (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setHeightPercent(value)
static int l_set_height_percent(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetHeightPercent(n, (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setHeightAuto()
static int l_set_height_auto(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    YGNodeStyleSetHeightAuto(n);
    return 0;
}

// ---- Min/Max dimensions ----

static int l_set_min_width(lua_State *L) {
    YGNodeStyleSetMinWidth(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

static int l_set_min_height(lua_State *L) {
    YGNodeStyleSetMinHeight(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

static int l_set_max_width(lua_State *L) {
    YGNodeStyleSetMaxWidth(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

static int l_set_max_height(lua_State *L) {
    YGNodeStyleSetMaxHeight(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// ---- Flex properties ----

// node:setFlexDirection(YGFlexDirection)
static int l_set_flex_direction(lua_State *L) {
    YGNodeStyleSetFlexDirection(yoga_check_node(L, 1), (YGFlexDirection)luaL_checkinteger(L, 2));
    return 0;
}

// node:setJustifyContent(YGJustify)
static int l_set_justify_content(lua_State *L) {
    YGNodeStyleSetJustifyContent(yoga_check_node(L, 1), (YGJustify)luaL_checkinteger(L, 2));
    return 0;
}

// node:setAlignItems(YGAlign)
static int l_set_align_items(lua_State *L) {
    YGNodeStyleSetAlignItems(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}

// node:setAlignSelf(YGAlign)
static int l_set_align_self(lua_State *L) {
    YGNodeStyleSetAlignSelf(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}

// node:setAlignContent(YGAlign)
static int l_set_align_content(lua_State *L) {
    YGNodeStyleSetAlignContent(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}

// node:setFlexWrap(YGWrap)
static int l_set_flex_wrap(lua_State *L) {
    YGNodeStyleSetFlexWrap(yoga_check_node(L, 1), (YGWrap)luaL_checkinteger(L, 2));
    return 0;
}

// node:setFlex(value)
static int l_set_flex(lua_State *L) {
    YGNodeStyleSetFlex(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setFlexGrow(value)
static int l_set_flex_grow(lua_State *L) {
    YGNodeStyleSetFlexGrow(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setFlexShrink(value)
static int l_set_flex_shrink(lua_State *L) {
    YGNodeStyleSetFlexShrink(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setFlexBasis(value)
static int l_set_flex_basis(lua_State *L) {
    YGNodeStyleSetFlexBasis(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setFlexBasisPercent(value)
static int l_set_flex_basis_percent(lua_State *L) {
    YGNodeStyleSetFlexBasisPercent(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// node:setFlexBasisAuto()
static int l_set_flex_basis_auto(lua_State *L) {
    YGNodeStyleSetFlexBasisAuto(yoga_check_node(L, 1));
    return 0;
}

// ---- Edge-based properties (padding, margin, border, position) ----

// node:setPadding(edge, value)
static int l_set_padding(lua_State *L) {
    YGNodeStyleSetPadding(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setPaddingPercent(edge, value)
static int l_set_padding_percent(lua_State *L) {
    YGNodeStyleSetPaddingPercent(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setMargin(edge, value)
static int l_set_margin(lua_State *L) {
    YGNodeStyleSetMargin(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setMarginPercent(edge, value)
static int l_set_margin_percent(lua_State *L) {
    YGNodeStyleSetMarginPercent(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setMarginAuto(edge)
static int l_set_margin_auto(lua_State *L) {
    YGNodeStyleSetMarginAuto(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2));
    return 0;
}

// node:setBorder(edge, value)
static int l_set_border(lua_State *L) {
    YGNodeStyleSetBorder(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setPosition(edge, value)
static int l_set_position(lua_State *L) {
    YGNodeStyleSetPosition(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setPositionPercent(edge, value)
static int l_set_position_percent(lua_State *L) {
    YGNodeStyleSetPositionPercent(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// ---- Position type, display, overflow ----

// node:setPositionType(YGPositionType)
static int l_set_position_type(lua_State *L) {
    YGNodeStyleSetPositionType(yoga_check_node(L, 1), (YGPositionType)luaL_checkinteger(L, 2));
    return 0;
}

// node:setDisplay(YGDisplay)
static int l_set_display(lua_State *L) {
    YGNodeStyleSetDisplay(yoga_check_node(L, 1), (YGDisplay)luaL_checkinteger(L, 2));
    return 0;
}

// node:setOverflow(YGOverflow)
static int l_set_overflow(lua_State *L) {
    YGNodeStyleSetOverflow(yoga_check_node(L, 1), (YGOverflow)luaL_checkinteger(L, 2));
    return 0;
}

// ---- Gap (Yoga 3.x) ----

// node:setGap(gutter, value)
static int l_set_gap(lua_State *L) {
    YGNodeStyleSetGap(yoga_check_node(L, 1),
        (YGGutter)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// node:setGapPercent(gutter, value)
static int l_set_gap_percent(lua_State *L) {
    YGNodeStyleSetGapPercent(yoga_check_node(L, 1),
        (YGGutter)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// ---- Aspect ratio ----

// node:setAspectRatio(ratio)
static int l_set_aspect_ratio(lua_State *L) {
    YGNodeStyleSetAspectRatio(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// ---- Registration ----

void yoga_register_style(lua_State *L) {
    // Metatable is at top of stack
    static const luaL_Reg style_methods[] = {
        // Dimensions
        { "setWidth", l_set_width },
        { "setWidthPercent", l_set_width_percent },
        { "setWidthAuto", l_set_width_auto },
        { "setHeight", l_set_height },
        { "setHeightPercent", l_set_height_percent },
        { "setHeightAuto", l_set_height_auto },
        { "setMinWidth", l_set_min_width },
        { "setMinHeight", l_set_min_height },
        { "setMaxWidth", l_set_max_width },
        { "setMaxHeight", l_set_max_height },
        // Flex
        { "setFlexDirection", l_set_flex_direction },
        { "setJustifyContent", l_set_justify_content },
        { "setAlignItems", l_set_align_items },
        { "setAlignSelf", l_set_align_self },
        { "setAlignContent", l_set_align_content },
        { "setFlexWrap", l_set_flex_wrap },
        { "setFlex", l_set_flex },
        { "setFlexGrow", l_set_flex_grow },
        { "setFlexShrink", l_set_flex_shrink },
        { "setFlexBasis", l_set_flex_basis },
        { "setFlexBasisPercent", l_set_flex_basis_percent },
        { "setFlexBasisAuto", l_set_flex_basis_auto },
        // Edge-based
        { "setPadding", l_set_padding },
        { "setPaddingPercent", l_set_padding_percent },
        { "setMargin", l_set_margin },
        { "setMarginPercent", l_set_margin_percent },
        { "setMarginAuto", l_set_margin_auto },
        { "setBorder", l_set_border },
        { "setPosition", l_set_position },
        { "setPositionPercent", l_set_position_percent },
        // Other
        { "setPositionType", l_set_position_type },
        { "setDisplay", l_set_display },
        { "setOverflow", l_set_overflow },
        { "setGap", l_set_gap },
        { "setGapPercent", l_set_gap_percent },
        { "setAspectRatio", l_set_aspect_ratio },
        { NULL, NULL }
    };
    luaL_register(L, NULL, style_methods);
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/yoga/src/yoga_node_style.c
git commit -m "feat: add Yoga style setters (dimensions, flex, padding, margin, gap, aspect-ratio)"
```

---

### Task 3.2: Layout result getters

**Files:**
- Create: `plugins/yoga/src/yoga_node_layout.c`

- [ ] **Step 1: Implement layout getters**

```c
// plugins/yoga/src/yoga_node_layout.c
#include "plugin_yoga.h"
#include <yoga/Yoga.h>

// node:getLeft() → number
static int l_get_left(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetLeft(yoga_check_node(L, 1)));
    return 1;
}

// node:getTop() → number
static int l_get_top(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetTop(yoga_check_node(L, 1)));
    return 1;
}

// node:getRight() → number
static int l_get_right(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetRight(yoga_check_node(L, 1)));
    return 1;
}

// node:getBottom() → number
static int l_get_bottom(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetBottom(yoga_check_node(L, 1)));
    return 1;
}

// node:getWidth() → number
static int l_get_width(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetWidth(yoga_check_node(L, 1)));
    return 1;
}

// node:getHeight() → number
static int l_get_height(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetHeight(yoga_check_node(L, 1)));
    return 1;
}

// node:getLayout() → { left, top, width, height }
// Convenience: returns all 4 values at once (less Lua↔C calls)
static int l_get_layout(lua_State *L) {
    YGNodeRef n = yoga_check_node(L, 1);
    lua_pushnumber(L, YGNodeLayoutGetLeft(n));
    lua_pushnumber(L, YGNodeLayoutGetTop(n));
    lua_pushnumber(L, YGNodeLayoutGetWidth(n));
    lua_pushnumber(L, YGNodeLayoutGetHeight(n));
    return 4;
}

// node:getPadding(edge) → number (computed padding after layout)
static int l_get_layout_padding(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetPadding(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2)));
    return 1;
}

// node:getLayoutBorder(edge) → number (computed border after layout)
static int l_get_layout_border(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetBorder(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2)));
    return 1;
}

// node:getLayoutMargin(edge) → number (computed margin after layout)
static int l_get_layout_margin(lua_State *L) {
    lua_pushnumber(L, YGNodeLayoutGetMargin(yoga_check_node(L, 1),
        (YGEdge)luaL_checkinteger(L, 2)));
    return 1;
}

void yoga_register_layout(lua_State *L) {
    // Metatable is at top of stack
    static const luaL_Reg layout_methods[] = {
        { "getLeft", l_get_left },
        { "getTop", l_get_top },
        { "getRight", l_get_right },
        { "getBottom", l_get_bottom },
        { "getWidth", l_get_width },
        { "getHeight", l_get_height },
        { "getLayout", l_get_layout },
        { "getLayoutPadding", l_get_layout_padding },
        { "getLayoutBorder", l_get_layout_border },
        { "getLayoutMargin", l_get_layout_margin },
        { NULL, NULL }
    };
    luaL_register(L, NULL, layout_methods);
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/yoga/src/yoga_node_layout.c
git commit -m "feat: add Yoga layout getters (position, size, padding, border, margin)"
```

---

## Chunk 4: Build, Test, Verify

### Task 4.1: Build the plugin

**Files:**
- Modify: `plugins/yoga/CMakeLists.txt` (already created, just build)

- [ ] **Step 1: Build the full plugin**

```bash
cd /path/to/project/plugins/yoga
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

Expected: `plugin_yoga.so` is produced in the build directory.

- [ ] **Step 2: Verify the .so loads in standalone Lua**

```bash
# Quick smoke test: try to load the module
cd /path/to/project/plugins/yoga/build
lua -e "package.cpath='./?.so;'..package.cpath; local y = require('plugin_yoga'); print(y); print(y.newNode)"
```

Expected: prints table address and function address (not nil, no errors).

- [ ] **Step 3: Commit build verification**

```bash
cd /path/to/project
git add plugins/yoga/CMakeLists.txt
git commit -m "build: verify Yoga plugin compiles and loads in Lua"
```

---

### Task 4.2: Basic layout test

**Files:**
- Create: `plugins/yoga/test/test_yoga_basic.lua`

- [ ] **Step 1: Write basic layout test**

```lua
-- plugins/yoga/test/test_yoga_basic.lua
-- Run: cd plugins/yoga/build && lua ../test/test_yoga_basic.lua

package.cpath = "./?.so;" .. package.cpath
local yoga = require("plugin_yoga")

local function assert_eq(actual, expected, msg)
    if math.abs(actual - expected) > 0.01 then
        error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
    end
end

print("Test 1: Basic node creation and layout")
do
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(400)
    root:calculateLayout()

    local l, t, w, h = root:getLayout()
    assert_eq(w, 300, "root width")
    assert_eq(h, 400, "root height")
    assert_eq(l, 0, "root left")
    assert_eq(t, 0, "root top")

    root:freeRecursive()
    print("  PASS")
end

print("Test 2: Column layout (default)")
do
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(400)

    local child1 = yoga.newNode()
    child1:setHeight(50)

    local child2 = yoga.newNode()
    child2:setHeight(80)

    root:insertChild(child1, 0)
    root:insertChild(child2, 1)
    root:calculateLayout()

    -- Default flexDirection = column, alignItems = stretch
    local _, t1, w1, h1 = child1:getLayout()
    local _, t2, w2, h2 = child2:getLayout()

    assert_eq(w1, 200, "child1 width (stretch)")
    assert_eq(h1, 50, "child1 height")
    assert_eq(t1, 0, "child1 top")
    assert_eq(w2, 200, "child2 width (stretch)")
    assert_eq(h2, 80, "child2 height")
    assert_eq(t2, 50, "child2 top")

    root:freeRecursive()
    print("  PASS")
end

print("Test 3: Row layout with flex grow")
do
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(100)
    root:setFlexDirection(yoga.FlexDirection.row)

    local child1 = yoga.newNode()
    child1:setFlexGrow(1)

    local child2 = yoga.newNode()
    child2:setFlexGrow(2)

    root:insertChild(child1, 0)
    root:insertChild(child2, 1)
    root:calculateLayout()

    local l1, _, w1 = child1:getLayout()
    local l2, _, w2 = child2:getLayout()

    assert_eq(w1, 100, "child1 width (flex:1)")
    assert_eq(w2, 200, "child2 width (flex:2)")
    assert_eq(l1, 0, "child1 left")
    assert_eq(l2, 100, "child2 left")

    root:freeRecursive()
    print("  PASS")
end

print("Test 4: Padding")
do
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(200)
    root:setPadding(yoga.Edge.all, 10)

    local child = yoga.newNode()
    child:setHeight(50)
    root:insertChild(child, 0)
    root:calculateLayout()

    local l, t, w = child:getLayout()
    assert_eq(l, 10, "child left (padding)")
    assert_eq(t, 10, "child top (padding)")
    assert_eq(w, 180, "child width (200 - 10 - 10)")

    root:freeRecursive()
    print("  PASS")
end

print("Test 5: Gap (Yoga 3.x)")
do
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(100)
    root:setFlexDirection(yoga.FlexDirection.row)
    root:setGap(yoga.Gutter.column, 20)

    local child1 = yoga.newNode()
    child1:setWidth(50)

    local child2 = yoga.newNode()
    child2:setWidth(50)

    root:insertChild(child1, 0)
    root:insertChild(child2, 1)
    root:calculateLayout()

    local l1 = child1:getLeft()
    local l2 = child2:getLeft()

    assert_eq(l1, 0, "child1 left")
    assert_eq(l2, 70, "child2 left (50 + 20 gap)")

    root:freeRecursive()
    print("  PASS")
end

print("Test 6: Absolute positioning")
do
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(200)

    local child = yoga.newNode()
    child:setPositionType(yoga.PositionType.absolute)
    child:setPosition(yoga.Edge.left, 10)
    child:setPosition(yoga.Edge.top, 20)
    child:setWidth(50)
    child:setHeight(50)

    root:insertChild(child, 0)
    root:calculateLayout()

    local l, t = child:getLeft(), child:getTop()
    assert_eq(l, 10, "abs child left")
    assert_eq(t, 20, "abs child top")

    root:freeRecursive()
    print("  PASS")
end

print("Test 7: Flex wrap")
do
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(400)
    root:setFlexDirection(yoga.FlexDirection.row)
    root:setFlexWrap(yoga.Wrap.wrap)

    local c1 = yoga.newNode(); c1:setWidth(120); c1:setHeight(50)
    local c2 = yoga.newNode(); c2:setWidth(120); c2:setHeight(50)

    root:insertChild(c1, 0)
    root:insertChild(c2, 1)
    root:calculateLayout()

    local _, t1 = c1:getLeft(), c1:getTop()
    local _, t2 = c2:getLeft(), c2:getTop()

    assert_eq(t1, 0, "c1 top (first line)")
    assert_eq(t2, 50, "c2 top (second line)")

    root:freeRecursive()
    print("  PASS")
end

print("Test 8: Aspect ratio")
do
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(400)

    local child = yoga.newNode()
    child:setWidth(200)
    child:setAspectRatio(2) -- width/height = 2, so height = 100

    root:insertChild(child, 0)
    root:calculateLayout()

    local _, _, w, h = child:getLayout()
    assert_eq(w, 200, "child width")
    assert_eq(h, 100, "child height (aspect 2:1)")

    root:freeRecursive()
    print("  PASS")
end

print("\nAll tests passed!")
```

- [ ] **Step 2: Run the tests**

```bash
cd /path/to/project/plugins/yoga/build
lua ../test/test_yoga_basic.lua
```

Expected: "All tests passed!"

- [ ] **Step 3: Commit**

```bash
cd /path/to/project
git add plugins/yoga/test/test_yoga_basic.lua
git commit -m "test: add Yoga C binding basic tests (column, row, flex, padding, gap, wrap, aspect-ratio)"
```

---

### Task 4.3: Solar2D simulator integration test

**Files:**
- Create: `plugins/yoga/test/main.lua`

- [ ] **Step 1: Write Solar2D test scene**

```lua
-- plugins/yoga/test/main.lua
-- Open this file in Corona Simulator to test the plugin in-engine.
-- Prerequisite: copy plugin_yoga.so to the same directory or set package.cpath.

-- Try loading as Solar2D plugin first, fall back to direct cpath
local ok, yoga = pcall(require, "plugin.yoga")
if not ok then
    package.cpath = "./?.so;" .. package.cpath
    yoga = require("plugin_yoga")
end

-- Build a simple layout: header + content + footer
local root = yoga.newNode()
root:setWidth(display.contentWidth)
root:setHeight(display.contentHeight)

local header = yoga.newNode()
header:setHeight(60)

local content = yoga.newNode()
content:setFlexGrow(1)

local footer = yoga.newNode()
footer:setHeight(40)

root:insertChild(header, 0)
root:insertChild(content, 1)
root:insertChild(footer, 2)

root:calculateLayout()

-- Render results using Solar2D display objects
local colors = {
    { 0.2, 0.6, 1 },   -- header: blue
    { 0.9, 0.9, 0.9 },  -- content: light gray
    { 0.2, 0.8, 0.4 },  -- footer: green
}
local labels = { "Header (60px)", "Content (flex:1)", "Footer (40px)" }

for i = 0, 2 do
    local node = root:getChild(i)
    local l, t, w, h = node:getLayout()
    local c = colors[i + 1]

    local rect = display.newRect(l + w/2, t + h/2, w, h)
    rect:setFillColor(c[1], c[2], c[3])

    local text = display.newText({
        text = labels[i + 1],
        x = l + w/2,
        y = t + h/2,
        fontSize = 16,
    })
    text:setFillColor(0, 0, 0)
end

-- Display info
local info = display.newText({
    text = string.format("Yoga v3.2.1 | %dx%d", display.contentWidth, display.contentHeight),
    x = display.contentCenterX,
    y = display.contentHeight - 15,
    fontSize = 12,
})
info:setFillColor(1, 1, 1)

root:freeRecursive()
print("Yoga Solar2D integration test: SUCCESS")
```

- [ ] **Step 2: Copy plugin .so and open in Simulator**

```bash
cd /path/to/project/plugins/yoga
cp build/plugin_yoga.so test/
# Open test/main.lua in Corona Simulator
```

Expected: Three colored rectangles stacked vertically — blue header, gray content area, green footer. Content fills remaining space.

- [ ] **Step 3: Commit**

```bash
cd /path/to/project
git add plugins/yoga/test/
git commit -m "test: add Solar2D simulator integration test for Yoga plugin"
```

---

## Chunk 5: High-Level Lua Wrapper

### Task 5.1: RN-style Lua wrapper

**Files:**
- Create: `layout/init.lua`

This wraps the low-level `plugin.yoga` C API with a React Native-style interface that our reconciler will use.

- [ ] **Step 1: Implement the wrapper**

```lua
-- layout/init.lua
-- High-level Yoga wrapper for react-solar2d
-- Translates RN-style style tables into Yoga C API calls

local ok, yoga = pcall(require, "plugin.yoga")
if not ok then
    -- Fallback for testing outside Solar2D
    package.cpath = "./plugins/yoga/build/?.so;" .. package.cpath
    yoga = require("plugin_yoga")
end

local M = {}

-- ---- Style property → Yoga API mapping ----

-- Helper: parse "50%" → 50, or return nil if not a percent string
local function parsePercent(v)
    if type(v) == "string" then
        return tonumber(v:match("^(.-)%%$"))
    end
    return nil
end

-- Simple dimension setters (supports number, "auto", "50%")
local dimensionSetters = {
    width = function(n, v)
        if v == "auto" then n:setWidthAuto()
        elseif parsePercent(v) then n:setWidthPercent(parsePercent(v))
        else n:setWidth(v) end
    end,
    height = function(n, v)
        if v == "auto" then n:setHeightAuto()
        elseif parsePercent(v) then n:setHeightPercent(parsePercent(v))
        else n:setHeight(v) end
    end,
    minWidth    = function(n, v) n:setMinWidth(v) end,
    minHeight   = function(n, v) n:setMinHeight(v) end,
    maxWidth    = function(n, v) n:setMaxWidth(v) end,
    maxHeight   = function(n, v) n:setMaxHeight(v) end,
}

-- Flex property setters
local flexDirectionMap = {
    column          = yoga.FlexDirection.column,
    ["column-reverse"] = yoga.FlexDirection.columnReverse,
    row             = yoga.FlexDirection.row,
    ["row-reverse"] = yoga.FlexDirection.rowReverse,
}

local justifyMap = {
    ["flex-start"]    = yoga.Justify.flexStart,
    center            = yoga.Justify.center,
    ["flex-end"]      = yoga.Justify.flexEnd,
    ["space-between"] = yoga.Justify.spaceBetween,
    ["space-around"]  = yoga.Justify.spaceAround,
    ["space-evenly"]  = yoga.Justify.spaceEvenly,
}

local alignMap = {
    auto         = yoga.Align.auto,
    ["flex-start"] = yoga.Align.flexStart,
    center       = yoga.Align.center,
    ["flex-end"] = yoga.Align.flexEnd,
    stretch      = yoga.Align.stretch,
    baseline     = yoga.Align.baseline,
    ["space-between"] = yoga.Align.spaceBetween,
    ["space-around"]  = yoga.Align.spaceAround,
    ["space-evenly"]  = yoga.Align.spaceEvenly,
}

local wrapMap = {
    nowrap          = yoga.Wrap.noWrap,
    wrap            = yoga.Wrap.wrap,
    ["wrap-reverse"] = yoga.Wrap.wrapReverse,
}

local positionTypeMap = {
    static   = yoga.PositionType.static,
    relative = yoga.PositionType.relative,
    absolute = yoga.PositionType.absolute,
}

local overflowMap = {
    visible = yoga.Overflow.visible,
    hidden  = yoga.Overflow.hidden,
    scroll  = yoga.Overflow.scroll,
}

-- Edge shortcut
local E = yoga.Edge

-- Apply a complete RN-style table to a Yoga node
function M.applyStyle(node, style)
    if not style then return end

    -- Dimensions
    for prop, setter in pairs(dimensionSetters) do
        if style[prop] ~= nil then setter(node, style[prop]) end
    end

    -- Flex container
    if style.flexDirection then
        node:setFlexDirection(flexDirectionMap[style.flexDirection] or yoga.FlexDirection.column)
    end
    if style.justifyContent then
        node:setJustifyContent(justifyMap[style.justifyContent] or yoga.Justify.flexStart)
    end
    if style.alignItems then
        node:setAlignItems(alignMap[style.alignItems] or yoga.Align.stretch)
    end
    if style.alignSelf then
        node:setAlignSelf(alignMap[style.alignSelf] or yoga.Align.auto)
    end
    if style.alignContent then
        node:setAlignContent(alignMap[style.alignContent] or yoga.Align.flexStart)
    end
    if style.flexWrap then
        node:setFlexWrap(wrapMap[style.flexWrap] or yoga.Wrap.noWrap)
    end

    -- Flex item
    if style.flex then node:setFlex(style.flex) end
    if style.flexGrow then node:setFlexGrow(style.flexGrow) end
    if style.flexShrink then node:setFlexShrink(style.flexShrink) end
    if style.flexBasis then
        if style.flexBasis == "auto" then
            node:setFlexBasisAuto()
        else
            node:setFlexBasis(style.flexBasis)
        end
    end

    -- Padding (RN shorthand: padding, paddingVertical, paddingHorizontal, paddingTop, etc.)
    if style.padding then node:setPadding(E.all, style.padding) end
    if style.paddingVertical then node:setPadding(E.vertical, style.paddingVertical) end
    if style.paddingHorizontal then node:setPadding(E.horizontal, style.paddingHorizontal) end
    if style.paddingTop then node:setPadding(E.top, style.paddingTop) end
    if style.paddingRight then node:setPadding(E.right, style.paddingRight) end
    if style.paddingBottom then node:setPadding(E.bottom, style.paddingBottom) end
    if style.paddingLeft then node:setPadding(E.left, style.paddingLeft) end

    -- Margin (same shorthand pattern + "auto" support)
    if style.margin then
        if style.margin == "auto" then node:setMarginAuto(E.all)
        else node:setMargin(E.all, style.margin) end
    end
    if style.marginVertical then
        if style.marginVertical == "auto" then node:setMarginAuto(E.vertical)
        else node:setMargin(E.vertical, style.marginVertical) end
    end
    if style.marginHorizontal then
        if style.marginHorizontal == "auto" then node:setMarginAuto(E.horizontal)
        else node:setMargin(E.horizontal, style.marginHorizontal) end
    end
    if style.marginTop then
        if style.marginTop == "auto" then node:setMarginAuto(E.top)
        else node:setMargin(E.top, style.marginTop) end
    end
    if style.marginRight then
        if style.marginRight == "auto" then node:setMarginAuto(E.right)
        else node:setMargin(E.right, style.marginRight) end
    end
    if style.marginBottom then
        if style.marginBottom == "auto" then node:setMarginAuto(E.bottom)
        else node:setMargin(E.bottom, style.marginBottom) end
    end
    if style.marginLeft then
        if style.marginLeft == "auto" then node:setMarginAuto(E.left)
        else node:setMargin(E.left, style.marginLeft) end
    end

    -- Border
    if style.borderWidth then node:setBorder(E.all, style.borderWidth) end
    if style.borderTopWidth then node:setBorder(E.top, style.borderTopWidth) end
    if style.borderRightWidth then node:setBorder(E.right, style.borderRightWidth) end
    if style.borderBottomWidth then node:setBorder(E.bottom, style.borderBottomWidth) end
    if style.borderLeftWidth then node:setBorder(E.left, style.borderLeftWidth) end

    -- Gap
    if style.gap then node:setGap(yoga.Gutter.all, style.gap) end
    if style.rowGap then node:setGap(yoga.Gutter.row, style.rowGap) end
    if style.columnGap then node:setGap(yoga.Gutter.column, style.columnGap) end

    -- Position
    if style.position then
        node:setPositionType(positionTypeMap[style.position] or yoga.PositionType.relative)
    end
    if style.top then node:setPosition(E.top, style.top) end
    if style.right then node:setPosition(E.right, style.right) end
    if style.bottom then node:setPosition(E.bottom, style.bottom) end
    if style.left then node:setPosition(E.left, style.left) end

    -- Display & overflow
    if style.display == "none" then node:setDisplay(yoga.Display.none) end
    if style.overflow then
        node:setOverflow(overflowMap[style.overflow] or yoga.Overflow.visible)
    end

    -- Aspect ratio
    if style.aspectRatio then node:setAspectRatio(style.aspectRatio) end
end

-- Convenience: create node with style already applied
function M.newNode(style)
    local node = yoga.newNode()
    M.applyStyle(node, style)
    return node
end

-- Re-export raw yoga module for advanced usage
M.yoga = yoga
M.Edge = yoga.Edge
M.Gutter = yoga.Gutter

return M
```

- [ ] **Step 2: Write test for the Lua wrapper**

```lua
-- plugins/yoga/test/test_yoga_wrapper.lua
package.path = "/path/to/project/?.lua;" .. package.path
package.cpath = "/path/to/project/plugins/yoga/build/?.so;" .. package.cpath

local Layout = require("layout")

local function assert_eq(actual, expected, msg)
    if math.abs(actual - expected) > 0.5 then
        error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
    end
end

print("Test: RN-style wrapper")
do
    local root = Layout.newNode({
        width = 300,
        height = 400,
        flexDirection = "row",
        justifyContent = "space-between",
        padding = 10,
        gap = 5,
    })

    local left = Layout.newNode({ width = 80, height = 100 })
    local right = Layout.newNode({ flex = 1 })

    root:insertChild(left, 0)
    root:insertChild(right, 1)
    root:calculateLayout()

    local ll, lt, lw, lh = left:getLayout()
    local rl, rt, rw, rh = right:getLayout()

    assert_eq(ll, 10, "left.x (padding)")
    assert_eq(lt, 10, "left.y (padding)")
    assert_eq(lw, 80, "left.width")
    assert_eq(lh, 100, "left.height")

    -- right fills remaining: 300 - 10 - 10 - 80 - 5(gap) = 195
    assert_eq(rl, 95, "right.x")
    assert_eq(rw, 195, "right.width")

    root:freeRecursive()
    print("  PASS")
end

print("Test: Auto margin centering")
do
    local root = Layout.newNode({ width = 300, height = 100, flexDirection = "row" })
    local child = Layout.newNode({ width = 100, marginLeft = "auto", marginRight = "auto" })

    root:insertChild(child, 0)
    root:calculateLayout()

    local l = child:getLeft()
    assert_eq(l, 100, "centered via auto margin")

    root:freeRecursive()
    print("  PASS")
end

print("\nAll wrapper tests passed!")
```

- [ ] **Step 3: Run wrapper tests**

```bash
cd /path/to/project
lua plugins/yoga/test/test_yoga_wrapper.lua
```

Expected: "All wrapper tests passed!"

- [ ] **Step 4: Commit**

```bash
git add layout/init.lua plugins/yoga/test/test_yoga_wrapper.lua
git commit -m "feat: add RN-style Lua wrapper for Yoga C plugin"
```

---

## Summary

| Chunk | What | Files | LOC (est.) |
|-------|------|-------|------------|
| 1 | Project setup + CMake | CMakeLists.txt, plugin_yoga.h | ~60 |
| 2 | Plugin entry + enums | plugin_yoga.c, yoga_enums.c | ~200 |
| 3 | Style + layout getters | yoga_node_style.c, yoga_node_layout.c | ~300 |
| 4 | Build + test | test_yoga_basic.lua, main.lua | ~200 |
| 5 | Lua wrapper | layout/init.lua, test_yoga_wrapper.lua | ~250 |
| **Total** | | **10 files** | **~1010** |

Binding 层总共 ~500 行 C + ~250 行 Lua wrapper。对比自己写 2500 行 Flexbox 引擎，工作量少 80%，正确性 100%。

## Future Work (not in this plan)

1. **iOS static library** — Cross-compile Yoga + plugin as `.a` for device builds
2. **Android NDK build** — `.so` for arm64/armeabi-v7a via Gradle + CMake
3. **Text measurement callback** — `YGNodeSetMeasureFunc` for intrinsic text sizing
4. **Solar2D plugin packaging** — `.tgz` for marketplace distribution
5. **Integration with react-solar2d reconciler** — connect layout/init.lua to renderer pipeline
