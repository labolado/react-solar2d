-- tests/navigation/test_deeplink.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local DeepLinking = require("navigation.DeepLinking")

T.describe("DeepLinking", function()

    local linkingConfig = {
        prefixes = { "myapp://", "https://myapp.com/" },
        config = {
            screens = {
                Home = "",
                Detail = "detail/:id",
                Settings = "settings",
            }
        }
    }

    T.it("resolves root URL to Home", function()
        local state = DeepLinking.resolve("myapp://", linkingConfig)
        T.expect(state).toBeTruthy()
        T.expect(#state.routes >= 1).toBeTruthy()
        T.expect(state.routes[1].name).toBe("Home")
    end)

    T.it("resolves detail URL with params", function()
        local state = DeepLinking.resolve("myapp://detail/123", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Detail")
        T.expect(lastRoute.params.id).toBe("123")
    end)

    T.it("resolves settings URL", function()
        local state = DeepLinking.resolve("myapp://settings", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Settings")
    end)

    T.it("strips prefix correctly", function()
        local state = DeepLinking.resolve("https://myapp.com/detail/42", linkingConfig)
        T.expect(state).toBeTruthy()
        local lastRoute = state.routes[state.index]
        T.expect(lastRoute.name).toBe("Detail")
        T.expect(lastRoute.params.id).toBe("42")
    end)

    T.it("returns nil for unknown URL", function()
        local state = DeepLinking.resolve("myapp://unknown/path", linkingConfig)
        T.expect(state).toBeNil()
    end)

end)

T.summary()
