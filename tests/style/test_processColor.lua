-- tests/style/test_processColor.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local processColor = require("style.processColor")

T.describe("processColor", function()
    T.it("converts #RRGGBB", function()
        local c = processColor("#FF0000")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        T.expect(c[4]).toBe(1)
    end)

    T.it("converts #RRGGBBAA", function()
        local c = processColor("#FF000080")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        -- 0x80 = 128, 128/255 ≈ 0.502
        T.expect(math.abs(c[4] - 0.502) < 0.01).toBeTruthy()
    end)

    T.it("converts #RGB shorthand", function()
        local c = processColor("#F00")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
    end)

    T.it("converts named colors", function()
        local c = processColor("red")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
    end)

    T.it("converts rgba(r,g,b,a)", function()
        local c = processColor("rgba(255, 0, 0, 0.5)")
        T.expect(c[1]).toBe(1)
        T.expect(c[2]).toBe(0)
        T.expect(c[3]).toBe(0)
        T.expect(c[4]).toBe(0.5)
    end)

    T.it("passes through table {r,g,b,a}", function()
        local c = processColor({0.5, 0.5, 0.5, 1})
        T.expect(c[1]).toBe(0.5)
    end)
end)

T.summary()
