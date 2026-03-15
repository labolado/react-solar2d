-- tests/animated/test_animated.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")

local Animated = require("animated")

T.describe("Animated.Value", function()
    T.it("creates with initial value", function()
        local val = Animated.Value(0)
        T.expect(val:getValue()).toBe(0)
    end)

    T.it("creates with default 0", function()
        local val = Animated.Value()
        T.expect(val:getValue()).toBe(0)
    end)

    T.it("setValue updates value", function()
        local val = Animated.Value(0)
        val:setValue(42)
        T.expect(val:getValue()).toBe(42)
    end)

    T.it("addListener fires on setValue", function()
        local val = Animated.Value(0)
        local received = nil
        val:addListener(function(v) received = v.value end)
        val:setValue(10)
        T.expect(received).toBe(10)
    end)

    T.it("multiple listeners fire", function()
        local val = Animated.Value(0)
        local a, b = nil, nil
        val:addListener(function(v) a = v.value end)
        val:addListener(function(v) b = v.value end)
        val:setValue(5)
        T.expect(a).toBe(5)
        T.expect(b).toBe(5)
    end)

    T.it("stopAnimation calls callback with current value", function()
        local val = Animated.Value(7)
        local stopped = nil
        val:stopAnimation(function(v) stopped = v end)
        T.expect(stopped).toBe(7)
    end)
end)

T.describe("Animated.timing", function()
    T.it("returns animation with start/stop", function()
        local val = Animated.Value(0)
        local anim = Animated.timing(val, { toValue = 1, duration = 300 })
        T.expect(type(anim.start)).toBe("function")
        T.expect(type(anim.stop)).toBe("function")
    end)

    T.it("jumps to final value without transition API", function()
        local val = Animated.Value(0)
        local anim = Animated.timing(val, { toValue = 100 })
        local finished = false
        anim.start(function(r) finished = r.finished end)
        T.expect(val:getValue()).toBe(100)
        T.expect(finished).toBe(true)
    end)
end)

T.describe("Animated.spring", function()
    T.it("returns animation with start/stop", function()
        local val = Animated.Value(0)
        local anim = Animated.spring(val, { toValue = 1 })
        T.expect(type(anim.start)).toBe("function")
    end)

    T.it("reaches target value without transition API", function()
        local val = Animated.Value(0)
        Animated.spring(val, { toValue = 50 }).start()
        T.expect(val:getValue()).toBe(50)
    end)
end)

T.describe("Animated.sequence", function()
    T.it("runs animations in order", function()
        local val = Animated.Value(0)
        local order = {}
        local seq = Animated.sequence({
            Animated.timing(val, { toValue = 10 }),
            Animated.timing(val, { toValue = 20 }),
        })
        seq.start(function()
            order[#order + 1] = "done"
        end)
        T.expect(val:getValue()).toBe(20)
        T.expect(#order).toBe(1)
    end)

    T.it("handles empty sequence", function()
        local finished = false
        Animated.sequence({}).start(function(r) finished = r.finished end)
        T.expect(finished).toBe(true)
    end)
end)

T.describe("Animated.parallel", function()
    T.it("runs animations simultaneously", function()
        local a = Animated.Value(0)
        local b = Animated.Value(0)
        local finished = false
        Animated.parallel({
            Animated.timing(a, { toValue = 10 }),
            Animated.timing(b, { toValue = 20 }),
        }).start(function(r) finished = r.finished end)
        T.expect(a:getValue()).toBe(10)
        T.expect(b:getValue()).toBe(20)
        T.expect(finished).toBe(true)
    end)

    T.it("handles empty parallel", function()
        local finished = false
        Animated.parallel({}).start(function(r) finished = r.finished end)
        T.expect(finished).toBe(true)
    end)
end)

T.describe("Animated.loop", function()
    T.it("returns animation with start/stop", function()
        local val = Animated.Value(0)
        local anim = Animated.loop(Animated.timing(val, { toValue = 1 }), { iterations = 3 })
        T.expect(type(anim.start)).toBe("function")
        T.expect(type(anim.stop)).toBe("function")
    end)
end)

T.describe("Animated component markers", function()
    T.it("Animated.View is a string", function()
        T.expect(Animated.View).toBe("Animated.View")
    end)
    T.it("Animated.Text is a string", function()
        T.expect(Animated.Text).toBe("Animated.Text")
    end)
end)

T.summary()
