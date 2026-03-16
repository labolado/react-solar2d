-- tests/components/test_window_calc.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local calculateWindow = require("components.WindowCalculator")

T.describe("WindowCalculator", function()

    T.it("returns full range for small list", function()
        local w = calculateWindow(0, 400, 80, 5, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(5)
    end)

    T.it("returns windowed range at offset 0", function()
        local w = calculateWindow(0, 800, 80, 1000, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(30)
    end)

    T.it("returns windowed range at mid scroll", function()
        local w = calculateWindow(4000, 800, 80, 1000, 5)
        T.expect(w.first).toBe(31)
        T.expect(w.last).toBe(80)
    end)

    T.it("clamps at end of list", function()
        local w = calculateWindow(79200, 800, 80, 1000, 5)
        T.expect(w.first).toBe(971)
        T.expect(w.last).toBe(1000)
    end)

    T.it("handles empty list", function()
        local w = calculateWindow(0, 800, 80, 0, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(0)
    end)

    T.it("handles single item", function()
        local w = calculateWindow(0, 800, 80, 1, 5)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(1)
    end)

    T.it("respects windowSize=1 (no buffer)", function()
        local w = calculateWindow(0, 800, 80, 1000, 1)
        T.expect(w.first).toBe(1)
        T.expect(w.last).toBe(10)
    end)

end)

T.summary()
