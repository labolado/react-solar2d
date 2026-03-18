-- test_runner_solar2d.lua — Test runner for Solar2D environment
-- Returns a module with run(pattern) function

package.path = "./?.lua;./?/init.lua;" .. package.path

local M = {}

local testFiles = {
    { name = "createElement", path = "tests/react/test_createElement.lua" },
    { name = "hooks", path = "tests/react/test_hooks.lua" },
    { name = "hooks_nil", path = "tests/react/test_hooks_nil.lua" },
    { name = "reconciler", path = "tests/react/test_reconciler.lua" },
    { name = "processColor", path = "tests/style/test_processColor.lua" },
    { name = "stylesheet", path = "tests/style/test_stylesheet.lua" },
    { name = "hostConfig", path = "tests/renderer/test_hostConfig.lua" },
    { name = "hostConfig_styles", path = "tests/renderer/test_hostConfig_styles.lua" },
    { name = "hostConfig_new", path = "tests/renderer/test_hostConfig_new.lua" },
    { name = "view", path = "tests/components/test_view.lua" },
    { name = "text", path = "tests/components/test_text.lua" },
    { name = "scrollview", path = "tests/components/test_scrollview.lua" },
    { name = "flatlist", path = "tests/components/test_flatlist.lua" },
    { name = "textinput", path = "tests/components/test_textinput.lua" },
    { name = "window_calc", path = "tests/components/test_window_calc.lua" },
    { name = "pressable", path = "tests/components/test_pressable.lua" },
    { name = "modal", path = "tests/components/test_modal.lua" },
    { name = "context", path = "tests/react/test_context.lua" },
    { name = "nav_state", path = "tests/navigation/test_state.lua" },
    { name = "nav_stack", path = "tests/navigation/test_stack.lua" },
    { name = "nav_tab", path = "tests/navigation/test_tab.lua" },
    { name = "nav_drawer", path = "tests/navigation/test_drawer.lua" },
    { name = "nav_deeplink", path = "tests/navigation/test_deeplink.lua" },
    { name = "full_render", path = "tests/integration/test_full_render.lua" },
}

function M.run(pattern)
    pattern = pattern or "all"
    print("[TEST] Starting test run: " .. pattern)

    local totalPassed, totalFailed, totalFiles = 0, 0, 0
    local failedFiles = {}

    for _, testFile in ipairs(testFiles) do
        local shouldRun = (pattern == "all") or testFile.name:find(pattern, 1, true) or testFile.path:find(pattern, 1, true)

        if shouldRun then
            print("[TEST] Running: " .. testFile.path)

            -- Load test module
            local chunk, err = loadfile(testFile.path)
            if not chunk then
                print("  ERROR loading " .. testFile.path .. ": " .. tostring(err))
                totalFailed = totalFailed + 1
                table.insert(failedFiles, testFile.path)
            else
                -- Track test results
                local T = require("tests.helpers.test_runner")
                -- Reset counters
                T._tests = {}
                T._passed = 0
                T._failed = 0

                -- Run in protected mode
                local ok, result = pcall(chunk)
                if not ok then
                    print("  ERROR running " .. testFile.path .. ": " .. tostring(result))
                    totalFailed = totalFailed + 1
                    table.insert(failedFiles, testFile.path)
                else
                    totalPassed = totalPassed + T._passed
                    totalFailed = totalFailed + T._failed
                    totalFiles = totalFiles + 1

                    if T._failed > 0 then
                        table.insert(failedFiles, testFile.path)
                        print(string.format("  FAIL  %s (%d passed, %d failed)", testFile.path, T._passed, T._failed))
                    else
                        print(string.format("  PASS  %s (%d tests)", testFile.path, T._passed))
                    end
                end
            end
        end
    end

    print(string.format("\n[TEST] ======================================"))
    print(string.format("[TEST]   Total: %d passed, %d failed (%d files)", totalPassed, totalFailed, totalFiles))
    print(string.format("[TEST] ======================================"))

    if #failedFiles > 0 then
        print("[TEST] Failing files:")
        for _, f in ipairs(failedFiles) do
            print("  - " .. f)
        end
    end

    return { passed = totalPassed, failed = totalFailed, files = totalFiles }
end

return M
