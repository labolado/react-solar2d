------------------------------------------------------------
-- test_yoga_basic.lua  --  8 basic Yoga C-binding tests
------------------------------------------------------------
local dir = debug.getinfo(1, "S").source:match("@(.+/)") or "./"
package.cpath = dir .. "../build/?.so;" .. package.cpath
local yoga = require("plugin_yoga")

local passed, failed = 0, 0

local function assert_eq(actual, expected, msg, tol)
    tol = tol or 0.5
    if math.abs(actual - expected) <= tol then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s  expected=%g  actual=%g", msg, expected, actual))
    end
end

------------------------------------------------------------
-- 1. Basic node creation and layout
------------------------------------------------------------
do
    print("Test 1: Basic node creation and layout")
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
    print("  OK")
end

------------------------------------------------------------
-- 2. Column layout - two children stacked vertically
------------------------------------------------------------
do
    print("Test 2: Column layout")
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(200)
    root:setFlexDirection(yoga.FlexDirection.column)

    local c1 = yoga.newNode()
    c1:setHeight(60)
    local c2 = yoga.newNode()
    c2:setHeight(80)

    root:insertChild(c1, 0)
    root:insertChild(c2, 1)
    root:calculateLayout()

    local _, t1, _, h1 = c1:getLayout()
    local _, t2, _, h2 = c2:getLayout()
    assert_eq(t1, 0,  "child1 top")
    assert_eq(h1, 60, "child1 height")
    assert_eq(t2, 60, "child2 top = child1.height")
    assert_eq(h2, 80, "child2 height")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 3. Row layout with flex grow 1:2
------------------------------------------------------------
do
    print("Test 3: Row layout with flex grow")
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(100)
    root:setFlexDirection(yoga.FlexDirection.row)

    local c1 = yoga.newNode()
    c1:setFlexGrow(1)
    local c2 = yoga.newNode()
    c2:setFlexGrow(2)

    root:insertChild(c1, 0)
    root:insertChild(c2, 1)
    root:calculateLayout()

    local l1, _, w1, _ = c1:getLayout()
    local l2, _, w2, _ = c2:getLayout()
    assert_eq(w1, 100, "child1 width (1/3 of 300)")
    assert_eq(w2, 200, "child2 width (2/3 of 300)")
    assert_eq(l1, 0,   "child1 left")
    assert_eq(l2, 100, "child2 left")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 4. Padding
------------------------------------------------------------
do
    print("Test 4: Padding")
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(200)
    root:setPadding(yoga.Edge.all, 10)

    local child = yoga.newNode()
    -- default alignItems=stretch so child stretches to content box
    root:insertChild(child, 0)
    root:calculateLayout()

    local cl, ct, cw, _ = child:getLayout()
    assert_eq(cl, 10,  "child left = padding")
    assert_eq(ct, 10,  "child top = padding")
    assert_eq(cw, 180, "child width = 200-10-10")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 5. Gap (Yoga 3.x column gap)
------------------------------------------------------------
do
    print("Test 5: Gap")
    local root = yoga.newNode()
    root:setWidth(300)
    root:setHeight(100)
    root:setFlexDirection(yoga.FlexDirection.row)
    root:setGap(yoga.Gutter.column, 20)

    local c1 = yoga.newNode()
    c1:setWidth(50)
    local c2 = yoga.newNode()
    c2:setWidth(50)

    root:insertChild(c1, 0)
    root:insertChild(c2, 1)
    root:calculateLayout()

    local l1, _, w1, _ = c1:getLayout()
    local l2, _, _, _  = c2:getLayout()
    assert_eq(l2, w1 + 20, "child2 left = child1.width + gap")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 6. Absolute positioning
------------------------------------------------------------
do
    print("Test 6: Absolute positioning")
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

    local cl, ct, cw, ch = child:getLayout()
    assert_eq(cl, 10, "abs child left")
    assert_eq(ct, 20, "abs child top")
    assert_eq(cw, 50, "abs child width")
    assert_eq(ch, 50, "abs child height")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 7. Flex wrap
------------------------------------------------------------
do
    print("Test 7: Flex wrap")
    local root = yoga.newNode()
    root:setWidth(200)
    root:setHeight(400)
    root:setFlexDirection(yoga.FlexDirection.row)
    root:setFlexWrap(yoga.Wrap.wrap)

    local c1 = yoga.newNode()
    c1:setWidth(120)
    c1:setHeight(40)
    local c2 = yoga.newNode()
    c2:setWidth(120)
    c2:setHeight(40)

    root:insertChild(c1, 0)
    root:insertChild(c2, 1)
    root:calculateLayout()

    local _, t1, _, _ = c1:getLayout()
    local l2, t2, _, _ = c2:getLayout()
    assert_eq(t1, 0,  "child1 on first line")
    assert_eq(l2, 0,  "child2 wraps to left=0")
    assert_eq(t2, 40, "child2 wraps to second line")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- 8. Aspect ratio
------------------------------------------------------------
do
    print("Test 8: Aspect ratio")
    local root = yoga.newNode()
    root:setWidth(400)
    root:setHeight(400)

    local child = yoga.newNode()
    child:setWidth(200)
    child:setAspectRatio(2)  -- width/height = 2, so height = 100

    root:insertChild(child, 0)
    root:calculateLayout()

    local _, _, cw, ch = child:getLayout()
    assert_eq(cw, 200, "aspect child width")
    assert_eq(ch, 100, "aspect child height (200/2)")
    root:freeRecursive()
    print("  OK")
end

------------------------------------------------------------
-- Summary
------------------------------------------------------------
print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
    os.exit(1)
end
