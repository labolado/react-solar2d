-- tests/style/test_stylesheet.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.helpers.test_runner")
local StyleSheet = require("style.StyleSheet")

T.describe("StyleSheet.create", function()
    T.it("returns style objects unchanged", function()
        local styles = StyleSheet.create({
            container = { flex = 1, backgroundColor = "red" },
            text = { fontSize = 16 },
        })
        T.expect(styles.container.flex).toBe(1)
        T.expect(styles.text.fontSize).toBe(16)
    end)

    T.it("freezes styles (read-only id assigned)", function()
        local styles = StyleSheet.create({
            box = { width = 100 },
        })
        T.expect(styles.box._id).toBeTruthy()
    end)
end)

T.describe("StyleSheet.flatten", function()
    T.it("merges array of styles", function()
        local result = StyleSheet.flatten({
            { flex = 1, padding = 10 },
            { padding = 20, margin = 5 },
        })
        T.expect(result.flex).toBe(1)
        T.expect(result.padding).toBe(20)
        T.expect(result.margin).toBe(5)
    end)

    T.it("handles nil in array", function()
        local result = StyleSheet.flatten({
            { flex = 1 },
            nil,
            { margin = 5 },
        })
        T.expect(result.flex).toBe(1)
        T.expect(result.margin).toBe(5)
    end)

    T.it("handles single style (not array)", function()
        local result = StyleSheet.flatten({ flex = 1 })
        T.expect(result.flex).toBe(1)
    end)

    T.it("handles false/nil input", function()
        local result = StyleSheet.flatten(nil)
        T.expect(type(result)).toBe("table")
    end)
end)

T.describe("StyleSheet.compose", function()
    T.it("composes two styles", function()
        local result = StyleSheet.compose(
            { flex = 1 },
            { margin = 5 }
        )
        T.expect(type(result)).toBe("table")
    end)
end)

T.summary()
