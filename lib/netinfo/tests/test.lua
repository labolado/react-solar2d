-- lib/netinfo/tests/test.lua
-- Tests for NetInfo

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local NetInfo = require("lib.netinfo")

T.describe("NetInfo", function()
    T.it("should return initial state", function()
        local state = NetInfo.fetch()
        T.expect(state).toNotBe(nil)
        T.expect(type(state.isConnected)).toBe("boolean")
        T.expect(type(state.isInternetReachable)).toBe("boolean")
        T.expect(type(state.type)).toBe("string")
    end)

    T.it("should add and remove listener", function()
        local called = false
        local listener = function(state)
            called = true
        end

        local subscription = NetInfo.addEventListener("change", listener)
        T.expect(subscription).toNotBe(nil)
        T.expect(type(subscription.remove)).toBe("function")

        subscription.remove()
    end)

    T.it("should configure check interval", function()
        -- Should not error
        NetInfo.configure({ checkInterval = 10000 })
    end)
end)

T.summary()
