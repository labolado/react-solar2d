#include "plugin_yoga.h"
#include <yoga/Yoga.h>

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
    {
        const char *k[] = { "inherit", "ltr", "rtl" };
        int v[] = { YGDirectionInherit, YGDirectionLTR, YGDirectionRTL };
        push_enum_table(L, "Direction", k, v, 3);
    }
    {
        const char *k[] = { "column", "columnReverse", "row", "rowReverse" };
        int v[] = { YGFlexDirectionColumn, YGFlexDirectionColumnReverse,
                    YGFlexDirectionRow, YGFlexDirectionRowReverse };
        push_enum_table(L, "FlexDirection", k, v, 4);
    }
    {
        const char *k[] = { "flexStart", "center", "flexEnd",
                            "spaceBetween", "spaceAround", "spaceEvenly" };
        int v[] = { YGJustifyFlexStart, YGJustifyCenter, YGJustifyFlexEnd,
                    YGJustifySpaceBetween, YGJustifySpaceAround, YGJustifySpaceEvenly };
        push_enum_table(L, "Justify", k, v, 6);
    }
    {
        const char *k[] = { "auto", "flexStart", "center", "flexEnd",
                            "stretch", "baseline", "spaceBetween", "spaceAround",
                            "spaceEvenly" };
        int v[] = { YGAlignAuto, YGAlignFlexStart, YGAlignCenter, YGAlignFlexEnd,
                    YGAlignStretch, YGAlignBaseline, YGAlignSpaceBetween,
                    YGAlignSpaceAround, YGAlignSpaceEvenly };
        push_enum_table(L, "Align", k, v, 9);
    }
    {
        const char *k[] = { "noWrap", "wrap", "wrapReverse" };
        int v[] = { YGWrapNoWrap, YGWrapWrap, YGWrapWrapReverse };
        push_enum_table(L, "Wrap", k, v, 3);
    }
    {
        const char *k[] = { "visible", "hidden", "scroll" };
        int v[] = { YGOverflowVisible, YGOverflowHidden, YGOverflowScroll };
        push_enum_table(L, "Overflow", k, v, 3);
    }
    {
        const char *k[] = { "flex", "none" };
        int v[] = { YGDisplayFlex, YGDisplayNone };
        push_enum_table(L, "Display", k, v, 2);
    }
    {
        const char *k[] = { "static_", "relative", "absolute" };
        int v[] = { YGPositionTypeStatic, YGPositionTypeRelative, YGPositionTypeAbsolute };
        push_enum_table(L, "PositionType", k, v, 3);
    }
    {
        const char *k[] = { "left", "top", "right", "bottom",
                            "start", "end_", "horizontal", "vertical", "all" };
        int v[] = { YGEdgeLeft, YGEdgeTop, YGEdgeRight, YGEdgeBottom,
                    YGEdgeStart, YGEdgeEnd, YGEdgeHorizontal, YGEdgeVertical, YGEdgeAll };
        push_enum_table(L, "Edge", k, v, 9);
    }
    {
        const char *k[] = { "column", "row", "all" };
        int v[] = { YGGutterColumn, YGGutterRow, YGGutterAll };
        push_enum_table(L, "Gutter", k, v, 3);
    }
}
