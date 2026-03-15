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
