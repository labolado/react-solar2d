#include "plugin_yoga.h"
#include <yoga/Yoga.h>

// ---- Dimensions ----
static int l_set_width(lua_State *L) {
    YGNodeStyleSetWidth(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_width_percent(lua_State *L) {
    YGNodeStyleSetWidthPercent(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_width_auto(lua_State *L) {
    YGNodeStyleSetWidthAuto(yoga_check_node(L, 1));
    return 0;
}
static int l_set_height(lua_State *L) {
    YGNodeStyleSetHeight(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_height_percent(lua_State *L) {
    YGNodeStyleSetHeightPercent(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_height_auto(lua_State *L) {
    YGNodeStyleSetHeightAuto(yoga_check_node(L, 1));
    return 0;
}
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

// ---- Flex ----
static int l_set_flex_direction(lua_State *L) {
    YGNodeStyleSetFlexDirection(yoga_check_node(L, 1), (YGFlexDirection)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_justify_content(lua_State *L) {
    YGNodeStyleSetJustifyContent(yoga_check_node(L, 1), (YGJustify)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_align_items(lua_State *L) {
    YGNodeStyleSetAlignItems(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_align_self(lua_State *L) {
    YGNodeStyleSetAlignSelf(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_align_content(lua_State *L) {
    YGNodeStyleSetAlignContent(yoga_check_node(L, 1), (YGAlign)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_flex_wrap(lua_State *L) {
    YGNodeStyleSetFlexWrap(yoga_check_node(L, 1), (YGWrap)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_flex(lua_State *L) {
    YGNodeStyleSetFlex(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_flex_grow(lua_State *L) {
    YGNodeStyleSetFlexGrow(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_flex_shrink(lua_State *L) {
    YGNodeStyleSetFlexShrink(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_flex_basis(lua_State *L) {
    YGNodeStyleSetFlexBasis(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_flex_basis_percent(lua_State *L) {
    YGNodeStyleSetFlexBasisPercent(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}
static int l_set_flex_basis_auto(lua_State *L) {
    YGNodeStyleSetFlexBasisAuto(yoga_check_node(L, 1));
    return 0;
}

// ---- Edge-based (padding, margin, border, position) ----
static int l_set_padding(lua_State *L) {
    YGNodeStyleSetPadding(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_padding_percent(lua_State *L) {
    YGNodeStyleSetPaddingPercent(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_margin(lua_State *L) {
    YGNodeStyleSetMargin(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_margin_percent(lua_State *L) {
    YGNodeStyleSetMarginPercent(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_margin_auto(lua_State *L) {
    YGNodeStyleSetMarginAuto(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_border(lua_State *L) {
    YGNodeStyleSetBorder(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_position(lua_State *L) {
    YGNodeStyleSetPosition(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_position_percent(lua_State *L) {
    YGNodeStyleSetPositionPercent(yoga_check_node(L, 1), (YGEdge)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}

// ---- Other ----
static int l_set_position_type(lua_State *L) {
    YGNodeStyleSetPositionType(yoga_check_node(L, 1), (YGPositionType)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_display(lua_State *L) {
    YGNodeStyleSetDisplay(yoga_check_node(L, 1), (YGDisplay)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_overflow(lua_State *L) {
    YGNodeStyleSetOverflow(yoga_check_node(L, 1), (YGOverflow)luaL_checkinteger(L, 2));
    return 0;
}
static int l_set_gap(lua_State *L) {
    YGNodeStyleSetGap(yoga_check_node(L, 1), (YGGutter)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_gap_percent(lua_State *L) {
    YGNodeStyleSetGapPercent(yoga_check_node(L, 1), (YGGutter)luaL_checkinteger(L, 2), (float)luaL_checknumber(L, 3));
    return 0;
}
static int l_set_aspect_ratio(lua_State *L) {
    YGNodeStyleSetAspectRatio(yoga_check_node(L, 1), (float)luaL_checknumber(L, 2));
    return 0;
}

// ---- Registration ----
void yoga_register_style(lua_State *L) {
    static const luaL_Reg style_methods[] = {
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
        { "setPadding", l_set_padding },
        { "setPaddingPercent", l_set_padding_percent },
        { "setMargin", l_set_margin },
        { "setMarginPercent", l_set_margin_percent },
        { "setMarginAuto", l_set_margin_auto },
        { "setBorder", l_set_border },
        { "setPosition", l_set_position },
        { "setPositionPercent", l_set_position_percent },
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
