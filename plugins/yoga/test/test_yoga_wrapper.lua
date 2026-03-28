local dir = debug.getinfo(1, "S").source:match("@(.+/)") or "./"
local root = dir .. "../../../"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
package.cpath = dir .. "../build/?.so;" .. package.cpath

local Layout = require("layout")

local function assert_eq(actual, expected, msg)
    if math.abs(actual - expected) > 0.5 then
        error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
    end
end

print("Test 1: RN-style wrapper basic")
do
    local root = Layout.newNode({
        width = 300, height = 400,
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

    assert_eq(ll, 10, "left.x")
    assert_eq(lt, 10, "left.y")
    assert_eq(lw, 80, "left.width")
    assert_eq(rw, 195, "right.width (300-10-10-80-5)")

    root:freeRecursive()
    print("  PASS")
end

print("Test 2: Auto margin centering")
do
    local root = Layout.newNode({ width = 300, height = 100, flexDirection = "row" })
    local child = Layout.newNode({ width = 100, marginLeft = "auto", marginRight = "auto" })
    root:insertChild(child, 0)
    root:calculateLayout()
    assert_eq(child:getLeft(), 100, "centered via auto margin")
    root:freeRecursive()
    print("  PASS")
end

print("Test 3: Percentage width")
do
    local root = Layout.newNode({ width = 400, height = 200 })
    local child = Layout.newNode({ width = "50%", height = 50 })
    root:insertChild(child, 0)
    root:calculateLayout()
    assert_eq(child:getWidth(), 200, "50% of 400")
    root:freeRecursive()
    print("  PASS")
end

print("\nAll wrapper tests passed!")
