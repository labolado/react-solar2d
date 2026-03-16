-- tests/react/test_context.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

display = require("tests.helpers.mock_display")
display.contentWidth = 320
display.contentHeight = 480
native = { systemFont = "Helvetica" }
timer = { performWithDelay = function() return {} end }
transition = { to = function() end }
Runtime = { addEventListener = function() end }

local T = require("tests.helpers.test_runner")
local React = require("react")
local ce = React.createElement
local HostConfig = require("renderer.HostConfig")
local Reconciler = require("react.Reconciler")

T.describe("Context.Provider + useContext", function()

    T.it("useContext returns default value without Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(Child, {}), container)

        T.expect(captured).toBe("light")
    end)

    T.it("useContext reads value from Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function App()
            return ce(ThemeContext.Provider, { value = "dark" },
                ce(Child, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(captured).toBe("dark")
    end)

    T.it("useContext reads from nearest Provider", function()
        local ThemeContext = React.createContext("light")
        local captured = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function Middle()
            return ce(ThemeContext.Provider, { value = "blue" },
                ce(Child, {}))
        end

        local function App()
            return ce(ThemeContext.Provider, { value = "dark" },
                ce(Middle, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(captured).toBe("blue")
    end)

    T.it("Provider updates propagate on re-render", function()
        local ThemeContext = React.createContext("light")
        local captured = nil
        local setTheme = nil

        local function Child()
            captured = React.useContext(ThemeContext)
            return ce("View", {})
        end

        local function App()
            local theme, _setTheme = React.useState("dark")
            setTheme = _setTheme
            return ce(ThemeContext.Provider, { value = theme },
                ce(Child, {}))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)
        T.expect(captured).toBe("dark")

        -- Update theme
        setTheme("ocean")
        reconciler.flushUpdates()
        T.expect(captured).toBe("ocean")
    end)

    T.it("multiple contexts work independently", function()
        local ThemeCtx = React.createContext("light")
        local LangCtx = React.createContext("en")
        local capturedTheme, capturedLang = nil, nil

        local function Child()
            capturedTheme = React.useContext(ThemeCtx)
            capturedLang = React.useContext(LangCtx)
            return ce("View", {})
        end

        local function App()
            return ce(ThemeCtx.Provider, { value = "dark" },
                ce(LangCtx.Provider, { value = "zh" },
                    ce(Child, {})))
        end

        local reconciler = Reconciler.create(HostConfig)
        local container = display.newGroup()
        reconciler.render(ce(App, {}), container)

        T.expect(capturedTheme).toBe("dark")
        T.expect(capturedLang).toBe("zh")
    end)

end)

T.summary()
