-- tests/navigation/test_state.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local NavState = require("navigation.NavigationState")

T.describe("NavigationState", function()

    T.it("creates initial stack state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
            { name = "Detail" },
        }, "Home")
        T.expect(state.type).toBe("stack")
        T.expect(state.index).toBe(1)
        T.expect(#state.routes).toBe(2)
        T.expect(state.routes[1].name).toBe("Home")
        T.expect(state.routes[1].key).toBeTruthy()
    end)

    T.it("push adds route and advances index", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.push(state, "Detail", { id = 42 })
        T.expect(next.index).toBe(2)
        T.expect(#next.routes).toBe(2)
        T.expect(next.routes[2].name).toBe("Detail")
        T.expect(next.routes[2].params.id).toBe(42)
    end)

    T.it("pop removes top route", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", {})
        local next = NavState.pop(state)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
        T.expect(next.routes[1].name).toBe("Home")
    end)

    T.it("pop on single route returns same state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.pop(state)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
    end)

    T.it("replace swaps current route", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", {})
        local next = NavState.replace(state, "Settings", { tab = "general" })
        T.expect(next.index).toBe(2)
        T.expect(next.routes[2].name).toBe("Settings")
        T.expect(next.routes[2].params.tab).toBe("general")
    end)

    T.it("switchTab changes index", function()
        local state = NavState.createState("tab", {
            { name = "News" },
            { name = "Quiz" },
            { name = "Game" },
        }, "News")
        local next = NavState.switchTab(state, "Quiz")
        T.expect(next.index).toBe(2)
    end)

    T.it("switchTab with unknown name returns same state", function()
        local state = NavState.createState("tab", {
            { name = "News" },
        }, "News")
        local next = NavState.switchTab(state, "Unknown")
        T.expect(next.index).toBe(1)
    end)

    T.it("reset replaces entire state", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "A", {})
        state = NavState.push(state, "B", {})
        local next = NavState.reset(state, {
            { name = "Login" },
        }, 1)
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
        T.expect(next.routes[1].name).toBe("Login")
    end)

    T.it("setParams updates current route params", function()
        local state = NavState.createState("stack", {
            { name = "Detail" },
        }, "Detail")
        state.routes[1].params = { id = 1 }
        local next = NavState.setParams(state, { id = 2, title = "New" })
        T.expect(next.routes[1].params.id).toBe(2)
        T.expect(next.routes[1].params.title).toBe("New")
    end)

    T.it("navigate finds existing route in stack", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        state = NavState.push(state, "Detail", { id = 1 })
        local next = NavState.navigate(state, "Home", {})
        T.expect(next.index).toBe(1)
        T.expect(#next.routes).toBe(1)
    end)

    T.it("navigate pushes if route not in stack", function()
        local state = NavState.createState("stack", {
            { name = "Home" },
        }, "Home")
        local next = NavState.navigate(state, "Detail", { id = 5 })
        T.expect(next.index).toBe(2)
        T.expect(next.routes[2].name).toBe("Detail")
    end)

end)

T.summary()
