package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local GestureHandler = require("lib.gesture-handler")

T.describe("lib/gesture-handler", function()
    T.it("PanGestureController transitions through states", function()
        local states = {}
        local translations = {}
        local ctrl = GestureHandler._internal.createPanController({
            minDist = 5,
            onHandlerStateChange = function(event)
                table.insert(states, event.state)
            end,
            onGestureEvent = function(event)
                table.insert(translations, event.nativeEvent.translationX)
            end,
        })

        ctrl:onTouchStart({ x = 0, y = 0, time = 0 })
        ctrl:onTouchMove({ x = 2, y = 0, time = 8 }) -- below threshold
        ctrl:onTouchMove({ x = 8, y = 0, time = 16 })
        ctrl:onTouchEnd({ x = 10, y = 1, time = 32 })

        T.expect(states[1]).toBe(GestureHandler.State.BEGAN)
        T.expect(states[2]).toBe(GestureHandler.State.ACTIVE)
        T.expect(states[#states]).toBe(GestureHandler.State.END)
        T.expect(#translations > 0).toBe(true)
        T.expect(translations[#translations] > 0).toBe(true)
    end)

    T.it("TapGestureController activates only when constraints satisfied", function()
        local states = {}
        local activated = false
        local ctrl = GestureHandler._internal.createTapController({
            maxDurationMs = 300,
            maxDist = 5,
            onHandlerStateChange = function(event)
                table.insert(states, event.state)
            end,
            onActivated = function()
                activated = true
            end,
        })

        ctrl:onTouchStart({ x = 10, y = 20, time = 0 })
        ctrl:onTouchMove({ x = 12, y = 22, time = 50 })
        ctrl:onTouchEnd({ x = 11, y = 21, time = 200 })

        T.expect(activated).toBe(true)
        T.expect(states[1]).toBe(GestureHandler.State.BEGAN)
        T.expect(states[2]).toBe(GestureHandler.State.ACTIVE)
        T.expect(states[3]).toBe(GestureHandler.State.END)

        -- Second tap exceeding distance should fail
        states = {}
        activated = false
        ctrl:onTouchStart({ x = 0, y = 0, time = 0 })
        ctrl:onTouchMove({ x = 20, y = 0, time = 100 })
        ctrl:onTouchEnd({ x = 20, y = 0, time = 120 })
        T.expect(activated).toBe(false)
        T.expect(states[#states]).toBe(GestureHandler.State.FAILED)
    end)

    T.it("LongPressGestureController waits for timer before ending", function()
        local states = {}
        local scheduled
        local fakeScheduler = {
            setTimeout = function(fn)
                scheduled = fn
                return {
                    cancel = function()
                        scheduled = nil
                    end,
                }
            end,
        }

        local ctrl = GestureHandler._internal.createLongPressController({
            minDurationMs = 10,
            _scheduler = fakeScheduler,
            onHandlerStateChange = function(event)
                table.insert(states, event.state)
            end,
        })

        ctrl:onTouchStart({ x = 0, y = 0, time = 0 })
        T.expect(states[1]).toBe(GestureHandler.State.BEGAN)
        T.expect(scheduled).toNotBe(nil)

        -- Simulate timer firing
        scheduled()
        T.expect(states[#states]).toBe(GestureHandler.State.ACTIVE)

        ctrl:onTouchEnd({ x = 0, y = 0, time = 20 })
        T.expect(states[#states]).toBe(GestureHandler.State.END)

        -- Restart and release before activation -> fail
        states = {}
        ctrl:onTouchStart({ x = 0, y = 0, time = 0 })
        ctrl:onTouchEnd({ x = 0, y = 0, time = 5 })
        T.expect(states[#states]).toBe(GestureHandler.State.FAILED)
    end)
end)

T.summary()
