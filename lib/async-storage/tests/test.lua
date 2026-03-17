-- lib/async-storage/tests/test.lua
-- Tests for AsyncStorage

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.helpers.test_runner")
local AsyncStorage = require("lib.async-storage")

T.describe("AsyncStorage", function()
    -- Clear storage before each test by using unique keys

    T.it("should set and get a string value", function()
        local success = AsyncStorage.setItem("test_key", "test_value")
        T.expect(success).toBe(true)

        local value = AsyncStorage.getItem("test_key")
        T.expect(value).toBe("test_value")
    end)

    T.it("should return nil for non-existent key", function()
        local value = AsyncStorage.getItem("non_existent_key")
        T.expect(value).toBe(nil)
    end)

    T.it("should update an existing value", function()
        AsyncStorage.setItem("update_key", "old_value")
        AsyncStorage.setItem("update_key", "new_value")

        local value = AsyncStorage.getItem("update_key")
        T.expect(value).toBe("new_value")
    end)

    T.it("should remove an item", function()
        AsyncStorage.setItem("remove_key", "value")
        local success = AsyncStorage.removeItem("remove_key")
        T.expect(success).toBe(true)

        local value = AsyncStorage.getItem("remove_key")
        T.expect(value).toBe(nil)
    end)

    T.it("should get all keys", function()
        AsyncStorage.setItem("allkeys_key1", "value1")
        AsyncStorage.setItem("allkeys_key2", "value2")
        AsyncStorage.setItem("allkeys_key3", "value3")

        local keys = AsyncStorage.getAllKeys()
        -- Filter to only keys from this test
        local count = 0
        for _, k in ipairs(keys) do
            if k:match("^allkeys_") then count = count + 1 end
        end
        T.expect(count).toBe(3)

        -- Sort for consistent comparison
        local filtered = {}
        for _, k in ipairs(keys) do
            if k:match("^allkeys_") then table.insert(filtered, k) end
        end
        table.sort(filtered)
        T.expect(filtered[1]).toBe("allkeys_key1")
        T.expect(filtered[2]).toBe("allkeys_key2")
        T.expect(filtered[3]).toBe("allkeys_key3")
    end)

    T.it("should clear all storage", function()
        AsyncStorage.setItem("key1", "value1")
        AsyncStorage.setItem("key2", "value2")

        local success = AsyncStorage.clear()
        T.expect(success).toBe(true)

        local keys = AsyncStorage.getAllKeys()
        T.expect(#keys).toBe(0)
    end)

    T.it("should handle empty string values", function()
        AsyncStorage.setItem("empty_key", "")
        local value = AsyncStorage.getItem("empty_key")
        T.expect(value).toBe("")
    end)

    T.it("should persist across cache clears", function()
        AsyncStorage.setItem("persist_key", "persist_value")

        -- Clear internal cache to simulate app restart
        AsyncStorage.cache = nil

        local value = AsyncStorage.getItem("persist_key")
        T.expect(value).toBe("persist_value")
    end)

    T.it("should work with JSON-encoded objects", function()
        local json = require("tests.helpers.json")
        local obj = { name = "John", age = 30, active = true }

        AsyncStorage.setItem("json_obj_key", json.encode(obj))
        local value = AsyncStorage.getItem("json_obj_key")
        local decoded = json.decode(value)

        T.expect(decoded.name).toBe("John")
        T.expect(decoded.age).toBe(30)
        T.expect(decoded.active).toBe(true)
    end)
end)

T.summary()
